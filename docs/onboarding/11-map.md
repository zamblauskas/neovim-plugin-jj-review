# 11 Map

> Source of truth: the file tree under `lua/review/` and `tests/`, [spec/architecture.md](../../spec/architecture.md) "Directory layout".
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- What is every module, in one sentence?
- Which pattern does each one embody?
- Which spec section or decision explains it?

The table is complete: 61 modules. A module missing here is a bug in this page.

## Entry and runtime

| Module | One sentence | Pattern | Explained in |
|---|---|---|---|
| `init.lua` | `setup()`, `:Review` with subcommands, global keymaps; wires the real ports into the runtime. | Composition root | [03](03-boundaries.md) |
| `app.lua` | Holds the current state; `dispatch(msg)` runs update and hands each effect to the interpreter. | Elm runtime | [02](02-mental-model.md), [09](09-limits.md) A2 |
| `config.lua` | Defaults, merge with user options, strict validation (unknown key is an error). | | [README.md](../../README.md) "Configuration" |

## core/ (pure)

| Module | One sentence | Pattern | Explained in |
|---|---|---|---|
| `state.lua` | The one state table and its initial value. | Elm model | [03](03-boundaries.md) "Where state lives" |
| `msg.lua` | 28 message classes with constructors. | Tagged union | [02](02-mental-model.md) |
| `effect.lua` | 23 effect classes with constructors. | Command | [02](02-mental-model.md) |
| `update.lua` | Drops stale messages; picks a handler by `msg.type`. | Dispatch table | [02](02-mental-model.md) "Lifecycle" |
| `handlers/lifecycle.lua` | `Opened` (new generation, reset), `Closed`. | | [05](05-walkthroughs.md) 1 |
| `handlers/stack.lua` | `RootResolved`, `RefreshRequested`, `OpChecked`, `StackLoaded`, `DiffLoaded`, `JjFailed`: load, cache by commit id, drop old entries. | Memoization | [05](05-walkthroughs.md) 3 |
| `handlers/ui.lua` | `FoldToggled`, `FileOpened`, `FileStepped`, `ContentLoaded`, `FocusChanged`, `BufferShown`, `RemovedToggled`. | | [05](05-walkthroughs.md) 4 |
| `handlers/store.lua` | `StoreLoaded`, `StoreFailed`, `Cleared`. | | [06](06-data.md) |
| `handlers/review.lua` | `ToggleRequested` (target → keys → patch), `Stepped` (next unreviewed or hunk, Strategy by unit). | Strategy | [05](05-walkthroughs.md) 2 |
| `handlers/comments.lua` | `CommentRequested` (draft), `CommentSubmitted`, `CommentDeleteRequested`, `CommentDeleted`. | | [06](06-data.md) "Comments" |
| `handlers/working_copy.lua` | `FileSaved` (snapshot if under root), `SnapshotRequested`, `EditRequested`, `CommandFailed`. | | [05](05-walkthroughs.md) 4 |
| `stack.lua` | Revset result → stack: remove empty, hidden parents replaced by their parents, check linear, newest first. | Tagged union (status) | [spec/stack.md](../../spec/stack.md) "Evaluation" |
| `keys.lua` | Line keys from a file diff: side, path, hash of ±2 context, occurrence. Comment anchors for unchanged lines. | | [06](06-data.md) "Identity" |
| `counts.lua` | Reviewed and total per file, revision, stack. Binary file counts 1. | | [06](06-data.md) "Derived data" |
| `toggle.lua` | Toggle rule (any unmarked → set all, else unset all) → patch; apply a patch to marks. | Command (patch as data) | [spec/data-model.md](../../spec/data-model.md) "Toggle rules" |
| `targets.lua` | Target (line, range, block, hunk, file) → selection (buffer lines or diff segments) → keys. | Strategy by target type | [06](06-data.md) "Entities" |
| `changes.lua` | Segments (added line, removed block) placed on buffer lines; the hunk at a line. | | [06](06-data.md) |
| `navigation.lua` | Next or previous line of a kind (unreviewed change, hunk) from a cursor line. No wrap. | Strategy by unit | |
| `review_buffers.lua` | Per open file a plan: release, wait, load, prepare, ready; then show the pending file. | Reconciler | [04](04-patterns.md), [09](09-limits.md) A1 |
| `modes.lua` | Which commit is on disk; view or working-copy mode per file. | | [spec/stack.md](../../spec/stack.md) "Modes" |
| `lookup.lua` | Revision by change id, file by path, new text lines of a file. | | |
| `file_tree.lua` | Files of a revision → tree entries in display order, with guide lines; directories collapsed when single. | | [spec/ux.md](../../spec/ux.md) "Explorer" |
| `folds.lua` | User fold choice per change id; default rule: oldest revision with unreviewed lines open, computed once per stack load. | | [spec/ux.md](../../spec/ux.md) "Default fold" |
| `explorer_cursor.lua` | The row the explorer cursor goes to after a redraw: same target, else nearest older revision, else newest. | | [05](05-walkthroughs.md) 3 |
| `explorer_actions.lua` | (action, row target) → message. One dispatcher for all explorer row actions. | Dispatch table | F-22 "Prepare in v0" |
| `comments.lua` | Comment types, patch, anchor lines, placement: found, outdated, orphaned. | | [06](06-data.md) "Comment placement" |
| `comment_drafts.lua` | Comment target → selection → draft: anchor, keys, snippet, title. One draft shape per selection kind. | Strategy by kind | [06](06-data.md) |
| `word_diff.lua` | Changed tokens of a replaced line: k-th removed line pairs with k-th added; over 60% changed → no highlight. | | [spec/ux.md](../../spec/ux.md) "Intra-line diff" |
| `keymap_docs.lua` | Key descriptions by section; one table for keymap `desc` and the `?` help. | | |

## parse/ (pure)

| Module | One sentence | Pattern | Explained in |
|---|---|---|---|
| `log.lua` | The `jj log` template with `\0` separators and its parser → revisions. Returns the bad line on mismatch. | | [07](07-edges.md) "jj" |
| `diff.lua` | `jj diff --git` text → file diffs: statuses A, M, D, R, C, binary, blob hashes, hunks with 2 context lines. | | [07](07-edges.md) "jj" |

## view/ (pure)

| Module | One sentence | Pattern | Explained in |
|---|---|---|---|
| `explorer.lua` | State → explorer lines, highlights, row targets: header, revision rows, file tree, counts right-aligned, orphaned comments. | View | [spec/ux.md](../../spec/ux.md) "Explorer" |
| `rows.lua` | Chunk rows → lines and highlight ranges. | | |
| `diff.lua` | File diff + marks + comments + placements → extmark specs: line groups, signs, removed blocks, comment lines, token ranges. | View | [spec/ux.md](../../spec/ux.md) "Diff view" |
| `help.lua` | Configured keymaps → help lines. | | |

## lib/ (pure, no plugin type)

| Module | One sentence |
|---|---|
| `tbl.lua` | `with`, `without`: immutable table update. |
| `list.lua` | `pluck`, `index_by`. |
| `text.lua` | Display width, truncate with `…`. |
| `color.lua` | Blend two colors. |

## shell/ (side effects)

| Module | One sentence | Pattern | Explained in |
|---|---|---|---|
| `effects.lua` | Runs each effect through a port; turns results into messages; batches renders. | Interpreter | [02](02-mental-model.md) |
| `jj.lua` | Builds jj args, runs `vim.system`; every read gets `--ignore-working-copy`. | Port adapter | [07](07-edges.md) "jj" |
| `store.lua` | `marks.json`, `comments.json`: load; read-merge-write with a patch; write temp + rename; version check. | Read-merge-write | [06](06-data.md) "Persistence" |
| `watcher.lua` | fs_event on op_heads (debounced), `FocusGained`, `BufEnter review://*`, `BufWritePost` → callbacks. | Observer | [07](07-edges.md) "Events that come in" |
| `focus.lua` | Focused window of the review tab → `FocusChanged`; buffer got a window → `BufferShown`. | Observer | [spec/ux.md](../../spec/ux.md) "Windows and buffers" |
| `layout.lua` | The review tab; open or go to it; close; the target window for a file. | Facade | [07](07-edges.md) "Neovim" |
| `explorer.lua` | The explorer buffer and window; row keymaps; render; cursor kept on its target; resize. | Port, only owner | [03](03-boundaries.md) "Ownership" |
| `buffers.lua` | Review buffers by mode: scratch `review://` or real file; prepare keeps views; release wipes or strips. | Strategy by mode | [07](07-edges.md) "Neovim" |
| `diff.lua` | Prepare, show, release review buffers; draw every one; measure the gutter after a redraw; `topfill`. | Port | [07](07-edges.md) "Fragile points" |
| `diff_keymaps.lua` | Diff buffer keymaps → messages, with cursor line, visual range, and clock. | | |
| `apply.lua` | Apply a view (lines + highlights) or extmark specs to a buffer; full redraw of a namespace. | | [07](07-edges.md) "Diff drawing" |
| `highlights.lua` | `Review*` highlight groups: links to standard groups; blends; redone on `ColorScheme`. | | [README.md](../../README.md) "Highlight groups" |
| `comment_input.lua` | Float with a markdown buffer; `<C-s>` saves; `q` or `<Esc>` cancels. | | [spec/ux.md](../../spec/ux.md) "Comment input" |
| `help.lua` | Help float with the configured keys. | | |
| `ids.lua` | Comment ids (`c-xxxx`). | Port | |
| `clock.lua` | `now()` in ISO 8601 UTC. | Port | |
| `lib/async.lua` | Coroutine `run` and `await`; errors go to an `on_error` callback. | Coroutine async | [04](04-patterns.md) |
| `lib/schedule.lua` | `once_per_tick`: coalesce calls into one `vim.schedule`. | | [08](08-decisions.md) D-10 |
| `lib/semaphore.lua` | Run at most N async tasks at once. | Semaphore | [07](07-edges.md) "Subprocess" |

## Tests

| Test unit | Covers | How |
|---|---|---|
| `tests/core/*_spec.lua` (17 files) | every core module | plain data in, plain data out; `update_spec.lua` is the largest (553 lines) |
| `tests/parse/*_spec.lua` | log and diff parsers | fixtures `tests/fixtures/diff_statuses.txt`, `diff_paths_and_mode.txt` |
| `tests/view/*_spec.lua` | explorer, diff, help views | state → expected lines and specs |
| `tests/shell/*_spec.lua` (13 files, 3 of them under `lib/`) | every port, async, schedule, semaphore | fake ports; `jj_spec`, `watcher_spec` use a temp repo |
| `tests/lib/*_spec.lua` | the four lib modules | |
| `tests/init_spec.lua` | setup, `:Review`, open, close | real temp jj repo, end to end |
| `tests/config_spec.lua` | defaults, validation | |
| `tests/helpers.lua` | `run_async`, `temp_repo`, `jj` | shared setup |
| `tests/minimal_init.lua` | runtime path for `nvim --headless` | |

## Not here
- How the modules talk → [02](02-mental-model.md), [03](03-boundaries.md)
