# Roadmap (v0 increments)

Each increment gives something you can use in Neovim. Each one is a few JJ revisions.

## How we avoid constant refactors

**Built in full from v0.1 (the skeleton):**
- Elm runtime: `app.lua`, `update` dispatch table, effect interpreter, render batching.
- Ports: `jj`, `fs`, `async`.
- `core/state.lua` with the full `State` shape. Fields for later increments exist from the start (empty `marks`, empty `comments`).
- Directory layout from [architecture.md](architecture.md#directory-layout).

Later increments add messages, handlers, effects and view parts. They do not change how the parts connect.

**Built small, and extended later without changes to callers:**
- `view/diff.lua`: v0.2 draws hunks only. v0.3 adds mark state, v0.5 adds comments. Same input shape, more fields used.
- `parse/diff.lua`: handles all file statuses (added, modified, deleted, renamed, binary) from v0.2. Parsers are cheap to make complete, and costly to fix later.

**Not done before it is needed:** cache eviction, performance tuning, config options for things that do not exist yet.

## Development process

- Each step is one JJ revision with a description. After a step: `jj new`.
- `make check` (format, lint, typecheck, test) passes before a step is done.
- Tests come with the code, in the same revision.
- Development load: `~/dotfiles/nvim/.config/nvim/lua/plugins/review.nvim.lua` with `dir =` this repo.
- Tools: stylua and lua-language-server from PATH or Mason (`~/.local/share/nvim/mason/bin`). selene from PATH.
- lua-language-server check uses `.luarc.check.json` (`--configpath`). No `.luarc.json`: it overrides the library lazydev injects in the editor.
- The order of steps can change during the work. This file is updated when it does.

## v0.1 — See the stack

Open the explorer and see the revisions of the stack.

Features: F-01, F-02, part of F-03, F-15 (close).

Steps (one revision each):

1. **Tooling.** `Makefile` (`test`, `lint`, `format`, `typecheck`, `check`), `stylua.toml`, `selene.toml`, `.luarc.check.json`, `tests/minimal_init.lua`, `.gitignore`.
2. **Async and JJ port.** `shell/lib/async.lua` (coroutine run / await), `shell/jj.lua` (`vim.system`, `--ignore-working-copy`, result `{ ok, stdout, stderr }`). Tests with a temp JJ repo.
3. **Parse log and stack.** `parse/log.lua` (template with `\0` separators), `core/stack.lua` (remove empty, check linear, order newest first). Tests with fixtures.
4. **Elm runtime.** `config.lua`, `core/state.lua`, `core/msg.lua`, `core/effect.lua`, `core/update.lua` (dispatch table), `app.lua` (state, `dispatch`), `shell/effects.lua` (interpreter, render batching). Handlers: `Opened`, `Closed`, `RootResolved`, `OpChecked`, `StackLoaded`, `JjFailed`. Tests: `update` with plain data.
5. **Explorer.** `view/explorer.lua` (header, revision rows, `◆`, error state), `shell/apply.lua`, explorer window (left split, `explorer_width`), `q`. Tests: view output.
6. **Entry point.** `init.lua`: `setup()` with config validation, `:Review [revset]`, `:Review close`, `<leader>jvv`, `<leader>jvq`. Dotfiles entry.

In v0.1 the stack loads once per open (no watcher yet). The explorer shows revision rows without counts.

Status: done.

## v0.2 — Read the diffs

Browse the diff of every file in the stack. Read-only, no marks.

- `parse/diff.lua` (all file statuses).
- Explorer: file tree under each revision, fold / unfold with `<CR>`.
- `<CR>` on a file: open a scratch buffer (view mode) with content from `jj file show`.
- `view/diff.lua`: added lines, removed blocks, deleted and emptied files, `topfill`.
- `]R` / `[R` between files.

Features: F-04, part of F-05 (view mode), F-14 (`-w`).

Steps (one revision each): parse diff; load diffs (semaphore, `max_parallel_jj`); explorer file tree and folds;
review tab (`shell/layout.lua`); open a file in view mode; diff view; `]R` / `[R`.

Status: done.

## v0.3 — Mark reviewed

The core value. You review a static stack and see progress.

- `core/keys.lua`, `core/counts.lua`, `core/toggle.lua`.
- `shell/store.lua`: `marks.json`, atomic read-merge-write.
- `<leader>rr` (line, range), `<leader>rR` (block), `<leader>rf` (file, also in the explorer).
- Diff view: `✓` sign, dim. Explorer: counts, `✅`, default fold (oldest unreviewed revision open).
- `]r` / `[r`.
- Binary files (`0/1`).
- `:Review clear` (marks).

Features: F-03 (complete), F-06, F-07, F-08, F-09, F-16.

Steps (one revision each): line keys; counts and toggle; store; toggle keys; diff view state; explorer counts and
default fold; `]r` / `[r`; `:Review clear`.

Status: done.

## v0.4 — Live stack

The agent rewrites the stack. The view follows, and marks survive.

- `shell/watcher.lua`: `op_heads` watcher and focus check → `CheckOp`.
- Diff cache by commit id. Only rewritten revisions are fetched again.
- The open revision disappears → close the diff, go to the nearest older revision.

Features: F-13.

Steps (one revision each): watcher; refresh in core; open file follows a rewrite; explorer cursor keeps its
target.

Status: done.

## v0.5 — Comments

Write feedback for the agent.

- `core/comments.lua`: lookup (found, outdated, orphaned).
- `comments.json` in the store.
- `shell/comment_input.lua`: float window.
- `<leader>rc`, `<leader>rC`, `<leader>rx`. Comments on unchanged lines.
- Diff view: comment virtual lines, outdated style. Explorer: `💬`, `⚠`, orphaned section.
- `:Review clear` also deletes comments.

Features: F-10, F-11, F-12.

Steps (one revision each): comment anchors and placement; comments.json; write and delete comments; diff view
comments; explorer icons and orphaned comments.

Status: done.

## v0.6 — Working copy

Use LSP and edit code during the review.

- Mode detection (revision is `@`, or `@` is empty and revision is `@-`).
- Real file buffer in working-copy mode.
- `<leader>re` in the explorer: `jj edit`.
- `jj util snapshot` after save, then refresh.

Features: F-05 (complete), F-17.

## v0.7 — Finish v0

- `?` help in the explorer.
- `keymaps` and `icons` config tables.
- README with install and usage.
