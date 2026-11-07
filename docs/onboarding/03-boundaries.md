# 03 Boundaries

> Source of truth: [spec/architecture.md](../../spec/architecture.md) "Layers", "Directory layout".
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- What are the units of structure? One sentence each.
- In which direction may dependencies go? What is forbidden?
- Where is purity? Which units may touch the outside?
- Who owns what: each Neovim handle has one owner. Which module?
- Where does state live? Which state is in one place, and which is spread?
- What coding rules bind every unit?

## Units of structure

| Unit | Role | Pure? | May depend on | Must not |
|---|---|---|---|---|
| `core/` | The rules. State, messages, effects, handlers, line keys, counts, toggle, comments, navigation. | yes | `core/`, `parse/` types, `lib/` | touch buffers, windows, files, processes |
| `parse/` | jj text output → tables. `jj log` → revisions. `jj diff --git` → file diffs. | yes | `lib/` | know about state or Neovim |
| `view/` | State → lines, highlights, extmark specs. Explorer, diff, help, row layout. | yes | `core/`, `lib/` | touch a buffer |
| `lib/` | Pure helpers with no plugin type: table, list, text width, color blend. | yes | nothing | know the plugin name |
| `shell/` | All side effects. Ports to jj, disk, Neovim. The effect interpreter. | no | everything | hold rules that belong in core |
| `shell/lib/` | Helpers with side effects but no plugin type: coroutines, scheduling, semaphore. | no | nothing | require other `shell/` modules |
| `app.lua` | The runtime: holds the current state, runs update, hands effects to the interpreter. | no | core, shell | contain logic |
| `init.lua` | Entry: `setup()`, `:Review`, global keymaps. Wires the ports into the runtime. | no | everything | contain logic |
| `config.lua` | Defaults, merge, strict validation. | yes | nothing | be read from a global by core (core reads it from the state) |
| `tests/` | Mirror of `lua/review/`. Plenary busted. | - | - | - |

"Pure" means: no `vim.api`, `vim.uv`, `vim.system`, no buffer, window, file, or process. Pure helpers from
Neovim are allowed: `vim.fn.sha256`, `vim.tbl_*`, `vim.split`, `vim.iter`. Tests run in `nvim --headless`.

## Dependency direction

```
                init.lua ──▶ app.lua
                   │            │
                   ▼            ▼
   shell/ ─────▶ core/ ◀────── view/          shell may require anything.
     │             │             │            core, view, parse may require lib.
     │             ▼             │            Nothing requires shell except init, app, and shell itself.
     ├──────────▶ parse/         │            lib requires nothing.
     │             │             │
     └──────▶ lib/ ◀─┴───────────┘
     └──────▶ shell/lib/
```

The arrow that is forbidden: anything → `shell/`, except `init.lua`, `app.lua`, and `shell/` itself.

## Ownership

Each outside handle has exactly one owner. Other modules ask the owner.

| Resource | Owner | Rule |
|---|---|---|
| The review tab page | `shell/layout.lua` (Facade) | Only owner of the tab handle. Picks the target window for a file. |
| Explorer buffer and window | `shell/explorer.lua` | Only owner. Keeps the row targets of the last render. |
| Review buffers (scratch and real) | `shell/buffers.lua` | One buffer per file key. Strategy by mode. Registry by file key. |
| Diff namespace and gutter width | `shell/diff.lua` | Draws every review buffer. Measures the gutter. |
| File watcher and timer handles | `shell/watcher.lua` | Starts, stops, debounces. |
| Focus autocmds | `shell/focus.lua` (Observer) | Reports `FocusChanged`, `BufferShown`. Never sets state. |
| Highlight groups | `shell/highlights.lua` | Links and blends. Redone on `ColorScheme`. |
| `.jj/review/*.json` | `shell/store.lua` | Only writer. Read-merge-write, atomic rename. |
| jj subprocesses | `shell/jj.lua` | Builds args. Adds `--ignore-working-copy` to every read. |
| Comment float | `shell/comment_input.lua` | Opens, saves on `<C-s>`. |
| Comment ids, clock | `shell/ids.lua`, `shell/clock.lua` | Tiny ports so core stays pure and tests can fake them. |

## Where state lives

| State | Where | One place? |
|---|---|---|
| Everything core knows | `review.State`, one table held by `app.lua` | yes |
| Buffer numbers, window ids, tab id, watcher handles, last render targets, gutter widths | module-level variables in 8 shell modules | **no**. One review per process. Tests must reset them. See [09](09-limits.md) B1. |
| Marks and comments | `.jj/review/marks.json`, `comments.json` | yes, on disk. Core holds a copy, read again on each refresh. |

Core state in one sentence per group:

| Group | Fields | Lifetime |
|---|---|---|
| Session | `open`, `generation`, `cwd`, `root`, `revset`, `op_id` | one open |
| Repo cache | `stack`, `diffs` (by commit id), `contents` (by commit id and path), `disk_commit` | one jj operation |
| Review data | `marks`, `comments`, `marks_loaded` | read on each refresh |
| UI | `folds`, `fold_default`, `buffers`, `show_pending`, `current`, `show_removed` | one open |

## Rules that bind every unit

- Max function size: 15 lines. A long computation is a sequence of named helpers.
- No module mutates a value it got. Updates return new tables (`lib/tbl.with`).
- All public functions and data shapes have LuaCATS annotations. Types live next to the code that makes them.
- A helper that uses no plugin type goes to `lib/` (pure) or `shell/lib/` (side effects). Not in the module that
  needed it first.
- Comments in ASD-STE100 Simplified Technical English.
- Specs use `local assert = require("luassert")`, because the lint standard library already defines `assert`.

## Not here
- What each module does → [11](11-map.md)
- Why the boundaries are here → [08](08-decisions.md) D-01, D-08
- How each layer is tested → [10](10-process.md)
