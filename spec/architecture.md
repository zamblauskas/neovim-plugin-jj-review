# Architecture

Target: Neovim 0.12. No runtime dependencies. Tests: plenary busted.

## Patterns

| Pattern | Where |
|---|---|
| Functional Core, Imperative Shell | `core/`, `parse/`, `view/` are pure. `shell/` has all side effects. |
| Elm Architecture (Model, Update, View) | One immutable state. `update(state, msg) → state, effects`. Views are functions of state. |
| Command pattern (effects as data) | `update` returns effect descriptions. It never runs them. |
| Interpreter | `shell/effects.lua` runs effect descriptions and dispatches result messages. |
| Ports and Adapters | Shell talks to JJ, file system and clock through ports. Tests use fake adapters. |
| Observer | Watcher and autocmds turn outside events into messages. |
| Dispatch table (Strategy) | `update` and the effect interpreter select a handler by `msg.type` / `effect.type`. |
| Memoization (cache by immutable id) | File diffs cached by commit id. A commit id never changes content. |
| Tagged union (sum type) | Messages, effects, comment anchors, stack status. Field `type` is the tag. |
| Coroutine async/await | `shell/lib/async.lua`. Async code reads as a list of steps. |
| Read-merge-write + atomic rename | `shell/store.lua` writes `marks.json` and `comments.json`. |

## Layers

```
            ┌──────────── shell (side effects) ────────────┐
 jj CLI ──▶ │ jj   fs/store   watcher   apply   keymaps     │ ──▶ buffers, extmarks
            └──────┬───────────┬──────────▲─────────▲───────┘
                   │ text      │ JSON     │ msg     │ render specs
            ┌──────▼───────────▼──────────┴─────────┴───────┐
            │ core (pure, immutable)                        │
            │ parse · stack · keys · counts · toggle ·      │
            │ comments · update · view                      │
            └───────────────────────────────────────────────┘
```

Rules:
- `core/`, `parse/`, `view/` must not use `vim.api`, `vim.uv`, `vim.system` or anything that touches buffers, windows, files or processes. Pure helpers are allowed: `vim.fn.sha256`, `vim.tbl_*`, `vim.split`, `vim.iter`. Tests run in `nvim --headless` anyway.
- No module mutates a value it got. Updates return new tables.
- Max function size: 15 lines. Long computations are a sequence of named helpers.
- All public functions and data shapes have LuaCATS annotations.

## Directory layout

```
lua/review/
  init.lua              setup(), :Review command, global keymaps
  app.lua               runtime: holds current state, dispatch(msg) loop
  config.lua            defaults, merge, validation
  core/
    state.lua           initial state, `with` (immutable update)
    msg.lua             message classes and constructors
    effect.lua          effect classes and constructors
    update.lua          update(state, msg) → state, effects (dispatch table)
    handlers/           one file per message group (stack, marks, comments, ui)
    stack.lua           remove empty, check linear, order
    keys.lua            line keys (computed once per diff, kept on the diff lines)
    counts.lua          counts per file, revision, stack
    toggle.lua          toggle rules → mark patch {set, unset}; apply
    targets.lua         target (line, range, block, hunk, file) → selection (lines | segments) → keys
    navigation.lua      next / previous unreviewed change
    review_buffers.lua  review buffers (Reconciler): load, prepare, show, release after each change
    modes.lua           commit on disk; view or working-copy mode
    explorer_cursor.lua explorer cursor row after a redraw
    keymap_docs.lua     key descriptions by section (keymap desc, help)
    comments.lua        comment types, patch, anchor lines, placement: found / outdated / orphaned
    comment_drafts.lua  comment target → selection → anchor, keys, snippet, title (one draft per kind)
    folds.lua           explorer fold state: user choice, default rule
    file_tree.lua       files → tree entries in display order (explorer, ]R)
    explorer_actions.lua  (action, row target) → message
    lookup.lua          revision by change id, file by path; source (revision, file, new text)
    changes.lua         segments (added line, removed block) placed on buffer lines; hunk at a line
  lib/
    tbl.lua             pure table helpers: with (immutable update)
    list.lua            pure list helpers: pluck, index_by
    text.lua            display width, truncate
    color.lua           blend
  parse/
    log.lua             jj log template output → revisions
    diff.lua            jj diff --git output → file diffs
  view/
    explorer.lua        state → explorer lines, highlights, row targets
    help.lua            configured keymaps → help lines
    rows.lua            chunk rows → lines and highlights
    diff.lua            file diff + marks + comments → extmark specs
  shell/
    lib/
      async.lua         coroutine wrapper: run, await
      schedule.lua      once_per_tick (coalesce calls into one vim.schedule)
      semaphore.lua     run at most N async tasks at once (max_parallel_jj)
    jj.lua              JJ port adapter: build args, run with vim.system
    store.lua           marks.json: load, read-merge-write with a patch, atomic rename
    clock.lua           clock port: now()
    ids.lua             id port: comment ids
    effects.lua         effect interpreter, render batching
    apply.lua           apply view specs to buffers (namespaces)
    layout.lua          review tab port (Facade): tab page, target window for opening a file
    explorer.lua        explorer window port (only owner of its buffer and window)
    diff.lua            diff port: prepare, show, release review buffers; render all of them
    focus.lua           focus port (Observer): the focused review tab window → FocusChanged
    buffers.lua         review buffers by mode: scratch (view), real file (working copy); one per file key
    diff_keymaps.lua    diff buffer keymaps → messages
    highlights.lua      highlight groups (default links)
    watcher.lua         op_heads watcher + focus autocmds
    keymaps.lua         buffer-local keymaps → messages
    comment_input.lua   float window
    help.lua            help float (keymaps)
tests/
  core/  lib/  parse/  view/  shell/   (mirror of lua/review)
  helpers.lua                    run_async, temp JJ repo
  init_spec.lua                  end to end with a real JJ repo
```

LuaCATS classes live next to the code that makes them (no central `types.lua`).
Specs use `local assert = require("luassert")`: selene's `lua51` already defines `assert`.

**Shared helpers go in a lib folder.** A helper that does not use a plugin type or plugin data (for example table,
string, list, or scheduling operations) does not stay in the module that uses it first:
- Pure helper → `lib/<topic>.lua`. Every layer can require it.
- Helper with side effects (Neovim API, coroutines, timers) → `shell/lib/<topic>.lua`. Only `shell/` can require it.

Lib modules do not require `core/`, `parse/`, `view/`, or other `shell/` modules, and do not know the plugin name.

## State

See `core/state.lua` (`review.State`). Main fields: `config`, `open`, `generation`, `cwd`, `root`, `revset`,
`op_id`, `stack`, `diffs` (by commit id), `contents` (new text lines by commit id and path), `marks` (by line key),
`comments`, `folds` (user fold choice by change id), `buffers` (review files with a buffer, by file key),
`show_pending` (file to show when its buffer is ready), `current` (file in the last focused window).

**Generation.** Each `Opened` increments `generation`. Effects carry it, and their result messages carry it back.
`update` drops a message from an older generation, and every message except `Opened` while the review is closed.

## Messages

v0.6 adds `FileSaved{path}`, `SnapshotRequested`, `EditRequested{change_id}`, `CommandFailed{text}`. v0.5 adds `CommentRequested{target}`, `CommentSubmitted{draft, text, id, now}`, `CommentDeleteRequested{change_id,
path, line}`, `CommentDeleted{id}`; `StoreLoaded` carries comments. v0.4 adds `RefreshRequested` (watcher or focus → `CheckOp` and `LoadStore`). v0.3 has the lifecycle and JJ messages, `StoreLoaded{marks}`, `StoreFailed{error}`, `ToggleRequested{target, now}`,
`FoldToggled`, `FileOpened`, `FileStepped`, `Stepped{unit, change_id, path, line, offset}`. The rest is the plan.
A failed `jj diff` or `jj file show` is a `JjFailed` (stack error state). Messages that make marks carry `now`
(core has no clock).

| Group | Messages |
|---|---|
| Lifecycle | `Opened{cwd, revset}`, `Closed`, `Cleared`, `RefreshRequested`, `SnapshotRequested` |
| JJ | `RootResolved{root}`, `OpChecked{op_id}`, `StackLoaded{revisions}`, `DiffLoaded{commit_id, files}`, `ContentLoaded{commit_id, path, lines}`, `JjFailed{stderr}` |
| Store | `StoreLoaded{marks, comments}`, `StoreFailed{error}` |
| Review | `ToggleRequested{target, now}`, `Stepped{unit, change_id, path, line, offset}` (`unit`: `unreviewed`; the handler picks the line finder per unit, Strategy), `CommentSubmitted{anchor, text}`, `CommentDeleted{id}` |
| UI | `FoldToggled{change_id}`, `FileOpened{change_id, path}`, `FileStepped{change_id, path, offset}`, `FocusChanged{file?, path?}`, `BufferShown{file}`, `EditRequested{change_id}` |

## Effects

v0.3 has `ResolveRoot`, `CheckOp`, `LoadStack`, `LoadDiff`, `LoadContent`, `LoadStore`, `SaveMarks`, `ClearMarks` (v0.5: `ClearStore`),
`OpenTab`, `CloseTab`, `OpenBuffer` (now `PrepareBuffer` and `ShowBuffer`), `MoveCursor`, `RenderExplorer`, `RenderDiff`, `Notify`. The rest is the plan. Effects for JJ carry `generation` and `root`.

| Effect | Result message |
|---|---|
| `ResolveRoot{cwd}` | `RootResolved` or `JjFailed` |
| `CheckOp{root}` | `OpChecked` |
| `LoadStack{revset}` | `StackLoaded` or `JjFailed` |
| `LoadDiff{commit_id}` | `DiffLoaded` or `JjFailed` |
| `LoadContent{commit_id, path}` | `ContentLoaded` or `JjFailed` |
| `JjEdit{root, change_id}` | (watcher sees new operation → `OpChecked`), or `CommandFailed` |
| `Snapshot{root}` | (watcher sees new operation → `OpChecked`), or `CommandFailed` |
| `LoadStore{root}` | `StoreLoaded` or `StoreFailed` |
| `SaveMarks{root, patch}` / `SaveComments{root, patch}` / `ClearStore{root}` | none, or `StoreFailed` |
| `OpenCommentInput{title, draft}` | `CommentSubmitted` (on save) |
| `MoveCursor{line}` | none |
| `StartWatcher{root}` / `StopWatcher` | `RefreshRequested` on each jj operation or focus |
| `OpenTab` / `CloseTab` | none |
| `RenderExplorer` / `RenderDiff` | none |
| `PrepareBuffer{file, lines, mode, file_path}` / `ShowBuffer{file, cursor_line}` / `ReleaseBuffer{file}` | none |
| `Notify{level, text}` | none |

Render is an effect, so `update` decides when to redraw. The shell computes the view from the new state and applies it.

## Main flows

### Open

1. `Opened{revset}` → effects `LoadStore`, `CheckOp`.
2. `OpChecked` with a new op id → `LoadStack`.
3. `StackLoaded` → stack check in core. For each commit id not in the cache → `LoadDiff`. Then `RenderExplorer`.
4. `DiffLoaded` → store in cache, `RenderExplorer` (counts update as diffs arrive).

### Refresh

Trigger: watcher on `.jj/repo/op_heads/heads/` (debounced 200 ms; follows `.jj/repo` of a secondary workspace) or
focus → `RefreshRequested` → `CheckOp` and `LoadStore`. Same as Open steps 2–4. Only rewritten revisions (new commit
ids) are fetched again. Old cache entries not in the stack are dropped.

- Review buffers follow (`review_buffers.sync`): new commit or mode → prepared again, cursor and scroll kept;
  revision or file gone → `ReleaseBuffer`.
- A stack error (not linear) does not change the review buffers.
- `JjFailed` with a loaded stack keeps it and warns. The error state is only for the first load.
- The fold default is computed again per stack load; the old one stays until then.
- The explorer cursor stays on its target. Gone: its revision; revision gone: the nearest older; else the newest.

### Toggle reviewed

1. Keymap → `ToggleRequested{target}` (target: line, range, block, hunk, file). `targets.select` resolves it
   to a selection: buffer lines, or segments of the diff (spec/data-model.md "Targets and selections").
2. `core/toggle` returns a new mark set.
3. Effects: `SaveMarks`, `RenderDiff`, `RenderExplorer`.

### Open file

1. `<CR>` in explorer → `FileOpened{change_id, path}`. `]f` / `[f` → `FileStepped{change_id, path, offset}` → same
   as `FileOpened`.
2. The file is added to `state.buffers` and waits to be shown (`show_pending`).
3. `review_buffers.sync`: `LoadContent` if the text is not cached, then `PrepareBuffer`, `ShowBuffer`, `RenderDiff`.
   Deleted and binary files need no content.
4. The focus Observer reports `FocusChanged` → `current` → `RenderExplorer`. Core does not set `current` on open:
   the Observer is its one source.

## Windows and buffers

The model of [ux.md](ux.md#windows-and-buffers).

- **File key**: `{change_id, path}`. One review file.
- **Review buffer**: one buffer per file key, in a mode (view: scratch; working copy: the real file). Core knows
  the file keys that have a buffer, and the commit and mode of their text (`state.buffers`). The shell knows the
  buffer numbers (`shell/buffers.lua`).
- **Reconciler** (`core/review_buffers.sync`): after each stack, diff or content change, every entry of
  `state.buffers` gets a plan (Strategy by kind): `release` (revision or file gone), `wait` (diff loading), `load`
  (text not cached; once per commit), `prepare` (new commit or mode), `ready`. Then the waiting file is shown if its
  buffer is ready.
- **Commands** (Command pattern): `PrepareBuffer` makes or updates the buffer (windows keep cursor and scroll; a
  mode change makes a new buffer, which takes the windows of the old one). `ShowBuffer` puts it in the target
  window; the first show sets the cursor. `ReleaseBuffer` releases it: a scratch buffer is wiped (its windows get
  an empty buffer); a real buffer loses marks and keymaps and stays.
- **Target window** (`layout.target_window`): the current window if it is in the review tab, not the explorer and
  not a float; else the previous window (`wincmd p`) by the same rule; else a new split on the right.
- **Current file** (`state.current`): `shell/focus.lua` (Observer) watches `BufEnter` / `WinEnter` in the review
  tab and sends `FocusChanged` when the focused window shows something else. The explorer and floats are not
  reported.
- **Adoption**: `FocusChanged{path}` for a real file of the working-copy revision (opened by `gd`, `:e`) adds it to
  `state.buffers`; it gets marks and keymaps like a file opened from the explorer.
- **Render**: `RenderDiff` draws every review buffer whose text is of the current commit.

## JJ calls

All reads use `--ignore-working-copy` (no snapshot, so no new operation, so no refresh loop). Only `jj edit` and
`jj util snapshot` (after a save) run without it.

| Purpose | Command |
|---|---|
| Op id | `jj op log -n1 --no-graph -T 'id'` |
| Stack | `jj log -r <revset> --no-graph -T <template>` (change id, commit id, parent change ids, empty, first line of description) |
| Diff | `jj diff -r <commit_id> --git -w --context 2` |
| Content | `jj file show -r <commit_id> -- 'root-file:"<path>"'` (literal path; a bare path is a fileset expression) |
| Edit | `jj edit <change_id>` |
| Snapshot after save (working-copy mode), or `:Review refresh` | `jj util snapshot` |

Diff calls for many revisions run in parallel, with a limit (config `max_parallel_jj`, default 4).

## Rendering

- Render effects are batched: the shell sets a dirty flag per view and redraws at most once per event-loop tick (`vim.schedule`). While the stack loads, 20 `DiffLoaded` messages give one or a few redraws, not 20.
- One namespace for the diff view, one for the explorer.
- On `RenderDiff`, the shell clears the namespace and applies all extmark specs for the file. Files are small, so full redraw is fast enough. Optimize only if measured.
- Between saves in working-copy mode, extmarks move with the text. The diff updates after save.

## Errors

- Core never throws. Failures are messages (`JjFailed`) or a stack status (`StackError`).
- Shell catches errors at the port edge and dispatches a message.
- JSON with an unknown `version` → the plugin does not write, and shows an error.

## Testing

| Layer | How |
|---|---|
| `parse/` | Fixture JJ output → expected tables |
| `core/` | Plain data in, plain data out. Most tests are here. |
| `view/` | State → expected lines and extmark specs |
| `shell/` | Fake ports (JJ, fs, clock). A few integration tests with a real temp JJ repo. |

## Configuration

```lua
require("review").setup({
  revset = "(trunk()..@)::",
  dim_reviewed = true,
  max_parallel_jj = 4,
  explorer_width = 40,
  keymaps = { toggle = "<leader>rr", toggle_hunk = "<leader>rh", ... },  -- a key set to false is not mapped
  icons = { reviewed = "✓", comment = "●", warning = "▲", working_copy = "◆", mark = "✓" },
})
```

Full defaults: `lua/review/config.lua` and the README. Explorer keys (`enter`, `quit`, `help`) are config keys too.

Config is validated in `setup()` (`vim.validate`) and stored in the state. Core reads it from the state, not from a global.
An unknown option name is an error (typos). A key is a string or `false`. Widths and limits are positive integers.
Key descriptions come from one table (`core/keymap_docs.lua`), used for keymap `desc` and the `?` help.

## Tooling

- Format: stylua. Lint: selene. Types: lua-language-server check.
- `Makefile` targets: `test`, `lint`, `format`, `typecheck`, `check` (all).
