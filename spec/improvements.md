# Improvement suggestions

Result of a code and architecture review (2026-11-07). The code base is in good shape: architecture, specs and
code agree, and all checks are green. The items below are refinements, not repairs.

Each item has an ID. Status: `open`, `decided`, `done`, `rejected`.

```
Layer       Lines   Verdict
----------  ------  --------------------------------------------------------------
spec/        ~960   Complete. Small drift (D).
core/       ~2100   Pure, typed, well cut. Two hidden invariants (A1, A2).
shell/      ~1700   Correct. Process-global state and one re-entrancy hazard (B).
view/        ~840   Pure. explorer.lua is the largest module (406 lines).
tests/      ~3200   Good coverage. update_spec.lua is 553 lines.
```

## A. Core: runtime and derived state

| ID | Status | Finding | Why it matters | Suggestion |
|---|---|---|---|---|
| A1 | open | `review_buffers.sync` is called by hand from 5 handlers (`StackLoaded`, `DiffLoaded`, `ContentLoaded`, `FileOpened`, `FocusChanged`). `folds.update_default` from 3. | A new handler that changes `stack`, `diffs` or `contents` and does not call `sync` gives a stale buffer. The invariant is not in one place. | Run a fixed derive pipeline after every handler in `update.lua`: `handler → folds.update_default → review_buffers.sync`. Both steps are idempotent. Pattern: reducer + post-reducer reconciliation. |
| A2 | open | `app.dispatch` is re-entrant. `jj.run_cb` calls `done` synchronously when `vim.system` fails. `layout.close` → `tabclose` → `WinClosed` → `app.dispatch(Closed)` inside the `Closed` dispatch. | The inner dispatch completes on the newer state. Then the outer loop runs the rest of its old effect list. The order is surprising and hard to test. | Give `app.lua` a message queue: `dispatch` enqueues; one loop drains the queue; a nested dispatch only enqueues. About 10 lines. Standard Elm runtime. |
| A3 | open | `assert(state.root, "root not resolved")` in 5 handlers. The rule says "core never throws". | `root` is `nil` only before `RootResolved`. The type allows a state that the logic forbids. | Make the session a tagged union: `closed` / `resolving{cwd}` / `ready{root, op_id, …}`. "Make illegal states unrepresentable". Larger refactor; ties to A4. |
| A4 | open | `State` is a flat bag of 18 fields with 4 lifetimes: session, repo cache, review data, UI. | `Opened` resets all. Handlers touch mixed concerns. It is hard to see what a refresh may change. | Group the fields: `state.session`, `state.repo` (stack, diffs, contents, disk_commit), `state.review` (marks, comments, loaded), `state.ui` (folds, buffers, current, show_removed). |
| A5 | open | `comments.place(state)` runs on every explorer render and every diff render. It builds anchor lines for every file of every revision. It uses `counts.stack(…, {})` as an "all diffs loaded" test. | O(stack) work per redraw. The loaded test is a hack by name. | Add `lookup.all_diffs_loaded(state)`. Memoize placements as derived state in the A1 pipeline (recompute only when `diffs`, `contents` or `comments` change). |
| A6 | open | `handlers/review.lua` `target_keys`: `#(source.lines or { "" })`. | A line, block or hunk target with no loaded text gets line count 1, so block placement is wrong. `Stepped` returns early in the same case; `ToggleRequested` does not. | Return `{}` for a non-file target when `lines` is nil. Same guard as `Stepped` and `comment_drafts.for_target`. |
| A7 | open | File-key equality is written 4 times: `handlers/ui.same_file`, `explorer_cursor.same`, `view/explorer.is_current`, `focus.lua` (via `vim.inspect`). | Four ad-hoc rules for one concept. | `core/file_key.lua`: `key(file)`, `equal(a, b)`. Move `review_buffers.key` there. |
| A8 | open | `CommentAnchor` is one class with a `type` field. `Msg`, `Effect`, `Stack` and `ExplorerTarget` are unions of classes. | F-20 (revision anchor) adds fields that do not apply to line anchors. The type checker cannot help. | A union of classes now, like `ExplorerTarget`. Cheap. |
| A9 | open | Constructors with 4 or 5 positional parameters: `msg.stepped(unit, change_id, path, line, offset)`, `msg.content_loaded(gen, commit_id, path, lines)`. | It is easy to swap `path` and `change_id`. The type checker does not catch two swapped strings. | Constructors with more than 3 fields take one table: `msg.stepped({ unit = …, … })`. |

## B. Shell

| ID | Status | Finding | Why it matters | Suggestion |
|---|---|---|---|---|
| B1 | open | 8 modules keep state in module upvalues: `buffers.registry`, `explorer.ui`, `explorer.targets`, `layout.ui`, `focus.observed`, `watcher.handles`, `diff.drawn_gutter`, `ids.counter`. | One review per process. Tests must reset globals. Ports are not real adapters: `init.create_app` passes module tables, not instances. | Ports as constructors: `explorer.new(app)`, `buffers.new()`, … return an instance. `init.lua` wires the instances. Real Ports and Adapters; fakes keep the same shape. |
| B2 | open | `app.dispatch` has no error boundary. An interpreter that throws stops the rest of the effect list (for example `RenderExplorer` after `SaveMarks`). | One bad port call leaves the UI stale, with no message. | `pcall` per effect in the runtime. On failure dispatch `Notify(error)`. |
| B3 | open | `shell/diff.lua` renders, then schedules a gutter check that may render again. It uses `nvim__redraw` (private API). | A feedback loop outside the message loop. A private API can change in Neovim 0.13. | Keep, but isolate: measure the gutter in one function with a comment on the 0.12 dependency. Or send `BufferShown` after the first redraw and let core ask for the second render. |
| B4 | open | `store.write_atomic`: the results of `fd:write` and `fd:close` are not checked. `vim.fn.mkdir` can throw. | A full disk gives a silent partial write before the rename. | Check both results. Wrap `mkdir` in `pcall`. |
| B5 | open | Read-merge-write has no lock. Two Neovim instances on one repo can lose an update. | The spec says "only the plugin writes", not "one plugin instance". | Document the limit, or add an `O_EXCL` lock file around `update`. Low priority. |
| B6 | open | `diff_keymaps.visual_range` leaves visual mode with `nvim_feedkeys("<Esc>", "nx")`. | Works, but feedkeys inside a mapping is fragile with pending input. | `vim.cmd("normal! \27")`, or read `getpos("v")` and exit with `<Esc>` in the mapping `rhs`. |
| B7 | open | `effects.new` default `{ max_parallel_jj = 4 }` repeats the config default. | Two sources of one number. | Make `opts` required. |

## C. View and parse

| ID | Status | Finding | Suggestion |
|---|---|---|---|
| C1 | open | `view/explorer.lua` is 406 lines. Row layout (`truncate_chunks`, `fit_left`, `fit`, `chunks_width`) is generic. | Move the layout functions to `view/rows.lua` (it already owns `flatten`). The explorer keeps only row content. |
| C2 | open | `line_group` builds highlight names by string concatenation: `base .. "File" .. "Reviewed"`. | A lookup table `{ added = { plain = "ReviewAdded", file = "ReviewAddedFile", … } }` makes the coupling to `highlights.lua` explicit and greppable. |
| C3 | open | `PAD_WIDTH = 400` is a magic constant for the virtual-line background. | Pass `win_width` in `DiffViewInput`, or document the Neovim limit (virt_lines have no `hl_eol`) at the constant. |
| C4 | open | Three files named `diff.lua` (parse, view, shell). | Rename `shell/diff.lua` to `shell/diff_port.lua` or `shell/review_files.lua`. Cosmetic. |
| C5 | open | `parse/diff.lua` `header_path` assumes the `a/P b/P` halves are equal. A path that contains ` b/` breaks it. | Known jj limit (no quoting). Add a test that documents it. |

## D. Spec drift

| ID | Status | Finding | Fix |
|---|---|---|---|
| D1 | open | `spec/README.md` links `open-questions.md`. The file does not exist. | Remove the row, or add the file. |
| D2 | open | `spec/architecture.md` "Messages" starts with a version changelog in prose. | Keep the table only. |
| D3 | open | `spec/architecture.md` directory layout lists `shell/keymaps.lua`. The file is `diff_keymaps.lua`. | Fix the name. |
| D4 | open | `spec/ux.md` "Windows and buffers" says `]f` / `[f`. The keys are `]R` / `[R`. | Fix the keys. |
| D5 | open | `spec/roadmap.md`: all v0 increments are done. There is no v1 plan. | Add the v1 increments (F-20, F-21, F-22). |

## Open decisions

| # | Decision | Options | Recommended |
|---|---|---|---|
| 1 | Scope of the first pass | a. A1, A2, A6, A7, B2, B4, D. Small revisions, no shape change. b. (a) plus A3, A4, B1. Touches every handler and test. c. D only. | a |
| 2 | Where the A1 derive steps live | a. In `update.lua`, after every handler. b. In `core/derive.lua`, called by `update.lua`. c. Keep manual calls; add a test per handler. | a |
| 3 | A2: nested dispatch | a. Queue it and drain in order. b. `assert(not running)`; fix the two known sources. | a |
| 4 | A3/A4: state shape before v1 | a. Yes, before v1. b. No; revisit with F-31. | — |
| 5 | B1: more than one review per process | a. Yes → do B1. b. No → document "one review per process". | — |
| 6 | B5: two Neovim instances on one repo | a. Yes → lock file. b. No → document the limit. | — |
