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
| Coroutine async/await | `shell/async.lua`. Async code reads as a list of steps. |
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
  types.lua             LuaCATS classes for all shapes
  core/
    msg.lua             message constructors
    effect.lua          effect constructors
    update.lua          update(state, msg) → state, effects (dispatch table)
    handlers/           one file per message group (stack, marks, comments, ui)
    stack.lua           remove empty, check linear, order
    keys.lua            line keys
    counts.lua          counts per file, revision, stack
    toggle.lua          toggle rules → new mark set
    comments.lua        lookup: found / outdated / orphaned
  lib/
    tbl.lua             pure table helpers: with (immutable update)
  parse/
    log.lua             jj log template output → revisions
    diff.lua            jj diff --git output → file diffs
  view/
    explorer.lua        state → explorer lines, highlights, row map
    diff.lua            file diff + marks + comments → extmark specs
  shell/
    async.lua           coroutine wrapper: run, await
    jj.lua              JJ port adapter: build args, run with vim.system
    store.lua           load, merge, atomic save of JSON
    effects.lua         effect interpreter
    apply.lua           apply view specs to buffers (namespaces)
    watcher.lua         op_heads watcher + focus autocmds
    keymaps.lua         buffer-local keymaps → messages
    comment_input.lua   float window
tests/
  core/  lib/  parse/  view/  shell/   (mirror of lua/review)
  fixtures/                      jj output samples
```

## State

```lua
---@class State
---@field repo_root string
---@field revset string
---@field op_id string?
---@field stack StackOk|StackError|StackLoading
---@field diffs table<string, FileDiff[]>   -- by commit id (cache)
---@field marks table<string, Mark>         -- by line key
---@field comments Comment[]
---@field ui UiState                        -- folds, open file, mode
```

## Messages (draft)

| Group | Messages |
|---|---|
| Lifecycle | `Opened{revset}`, `Closed`, `Cleared` |
| JJ | `OpChecked{op_id}`, `StackLoaded{revisions}`, `DiffLoaded{commit_id, files}`, `ContentLoaded{commit_id, path, text}`, `JjFailed{args, stderr}` |
| Store | `StoreLoaded{marks, comments}` |
| Review | `ToggleRequested{target}`, `CommentSubmitted{anchor, text}`, `CommentDeleted{id}` |
| UI | `FoldToggled{change_id}`, `FileOpened{change_id, path}`, `EditRequested{change_id}` |

## Effects (draft)

| Effect | Result message |
|---|---|
| `CheckOp` | `OpChecked` |
| `LoadStack{revset}` | `StackLoaded` or `JjFailed` |
| `LoadDiff{change_id, commit_id}` | `DiffLoaded` |
| `LoadContent{commit_id, path}` | `ContentLoaded` |
| `JjEdit{change_id}` | (watcher sees new operation → `OpChecked`) |
| `LoadStore` / `SaveMarks` / `SaveComments` | `StoreLoaded` / none |
| `RenderExplorer` / `RenderDiff` | none |
| `OpenBuffer{change_id, path, mode}` | none |
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

1. `<CR>` in explorer → `FileOpened{change_id, path}`.
2. Mode: working-copy if the revision is `@`, or `@` is empty and the revision is `@-`. Else view.
3. View mode → `LoadContent`, then `OpenBuffer` (scratch). Working-copy mode → `OpenBuffer` (real file).
4. `RenderDiff`.

## JJ calls

All reads use `--ignore-working-copy` (no snapshot, so no new operation, so no refresh loop).

| Purpose | Command |
|---|---|
| Op id | `jj op log -n1 --no-graph -T 'id'` |
| Stack | `jj log -r <revset> --no-graph -T <template>` (change id, commit id, parent change ids, empty, first line of description) |
| Diff | `jj diff -r <commit_id> --git -w --context 2` |
| Content | `jj file show -r <commit_id> <path>` |
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
