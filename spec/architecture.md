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
    keys.lua            line keys
    counts.lua          counts per file, revision, stack
    toggle.lua          toggle rules → new mark set
    comments.lua        lookup: found / outdated / orphaned
    folds.lua           explorer fold state: user choice, default rule
    file_tree.lua       files → tree entries in display order (explorer, ]R)
    explorer_actions.lua  (action, row target) → message
    lookup.lua          revision by change id, file by path
    changes.lua         positions of changes in the new text
  lib/
    tbl.lua             pure table helpers: with (immutable update)
    list.lua            pure list helpers: pluck, index_by
  parse/
    log.lua             jj log template output → revisions
    diff.lua            jj diff --git output → file diffs
  view/
    explorer.lua        state → explorer lines, highlights, row targets
    diff.lua            file diff + marks + comments → extmark specs
  shell/
    lib/
      async.lua         coroutine wrapper: run, await
      schedule.lua      once_per_tick (coalesce calls into one vim.schedule)
      semaphore.lua     run at most N async tasks at once (max_parallel_jj)
    jj.lua              JJ port adapter: build args, run with vim.system
    store.lua           load, merge, atomic save of JSON
    effects.lua         effect interpreter, render batching
    apply.lua           apply view specs to buffers (namespaces)
    layout.lua          review tab port (Facade): tab page, diff window
    explorer.lua        explorer window port (only owner of its buffer and window)
    diff.lua            diff buffer port: review:// scratch buffers, render
    highlights.lua      highlight groups (default links)
    watcher.lua         op_heads watcher + focus autocmds
    keymaps.lua         buffer-local keymaps → messages
    comment_input.lua   float window
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
`comments`, `folds` (user fold choice by change id), `open_file` (`{change_id, path}`).

**Generation.** Each `Opened` increments `generation`. Effects carry it, and their result messages carry it back.
`update` drops a message from an older generation, and every message except `Opened` while the review is closed.

## Messages

v0.2 has the lifecycle messages (no `Cleared`), the JJ messages, `FoldToggled`, `FileOpened`, `FileStepped`. The rest is the plan.
A failed `jj diff` or `jj file show` is a `JjFailed` (stack error state).

| Group | Messages |
|---|---|
| Lifecycle | `Opened{cwd, revset}`, `Closed`, `Cleared` |
| JJ | `RootResolved{root}`, `OpChecked{op_id}`, `StackLoaded{revisions}`, `DiffLoaded{commit_id, files}`, `ContentLoaded{commit_id, path, lines}`, `JjFailed{stderr}` |
| Store | `StoreLoaded{marks, comments}` |
| Review | `ToggleRequested{target}`, `CommentSubmitted{anchor, text}`, `CommentDeleted{id}` |
| UI | `FoldToggled{change_id}`, `FileOpened{change_id, path}`, `FileStepped{offset}`, `EditRequested{change_id}` |

## Effects

v0.2 has `ResolveRoot`, `CheckOp`, `LoadStack`, `LoadDiff`, `LoadContent`, `OpenTab`, `CloseTab`, `OpenBuffer`,
`RenderExplorer`, `RenderDiff`. The rest is the plan. Effects for JJ carry `generation` and `root`.

| Effect | Result message |
|---|---|
| `ResolveRoot{cwd}` | `RootResolved` or `JjFailed` |
| `CheckOp{root}` | `OpChecked` |
| `LoadStack{revset}` | `StackLoaded` or `JjFailed` |
| `LoadDiff{commit_id}` | `DiffLoaded` or `JjFailed` |
| `LoadContent{commit_id, path}` | `ContentLoaded` or `JjFailed` |
| `JjEdit{change_id}` | (watcher sees new operation → `OpChecked`) |
| `LoadStore` / `SaveMarks` / `SaveComments` | `StoreLoaded` / none |
| `OpenTab` / `CloseTab` | none |
| `RenderExplorer` / `RenderDiff` | none |
| `OpenBuffer{change_id, path, lines, cursor_line}` (mode added in v0.6) | none |
| `Notify{level, text}` | none |

Render is an effect, so `update` decides when to redraw. The shell computes the view from the new state and applies it.

## Main flows

### Open

1. `Opened{revset}` → effects `LoadStore`, `CheckOp`.
2. `OpChecked` with a new op id → `LoadStack`.
3. `StackLoaded` → stack check in core. For each commit id not in the cache → `LoadDiff`. Then `RenderExplorer`.
4. `DiffLoaded` → store in cache, `RenderExplorer` (counts update as diffs arrive).

### Refresh

Trigger: watcher on `.jj/repo/op_heads/` or focus → `CheckOp`. Same as Open steps 2–4. Only rewritten revisions (new commit ids) are fetched again. Old cache entries not in the stack are dropped.

### Toggle reviewed

1. Keymap → `ToggleRequested{target}` (target: line, range, block, file).
2. `core/toggle` returns a new mark set.
3. Effects: `SaveMarks`, `RenderDiff`, `RenderExplorer`.

### Open file

1. `<CR>` in explorer → `FileOpened{change_id, path}`. `]R` / `[R` → `FileStepped{offset}` → same as `FileOpened`.
2. Mode: working-copy if the revision is `@`, or `@` is empty and the revision is `@-`. Else view.
3. View mode → `LoadContent` (if not cached), then `OpenBuffer` (scratch). Deleted and binary files need no
   content. Working-copy mode → `OpenBuffer` (real file).
4. `RenderDiff`.

## JJ calls

All reads use `--ignore-working-copy` (no snapshot, so no new operation, so no refresh loop).

| Purpose | Command |
|---|---|
| Op id | `jj op log -n1 --no-graph -T 'id'` |
| Stack | `jj log -r <revset> --no-graph -T <template>` (change id, commit id, parent change ids, empty, first line of description) |
| Diff | `jj diff -r <commit_id> --git -w --context 2` |
| Content | `jj file show -r <commit_id> -- 'root-file:"<path>"'` (literal path; a bare path is a fileset expression) |
| Edit | `jj edit <change_id>` |
| Snapshot after save (working-copy mode) | `jj util snapshot` |

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
  keymaps = { toggle = "<leader>rr", ... },  -- a key set to false is not mapped
  icons = { reviewed = "✅", comment = "💬", warning = "⚠", working_copy = "◆" },
})
```

Config is validated in `setup()` (`vim.validate`) and stored in the state. Core reads it from the state, not from a global.

## Tooling

- Format: stylua. Lint: selene. Types: lua-language-server check.
- `Makefile` targets: `test`, `lint`, `format`, `typecheck`, `check` (all).
