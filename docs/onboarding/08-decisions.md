# 08 Decisions

> Source of truth: [spec/](../../spec/README.md) "Principles", [spec/stack.md](../../spec/stack.md), [spec/architecture.md](../../spec/architecture.md), [spec/roadmap.md](../../spec/roadmap.md) "How we avoid constant refactors".
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- Which decisions shape the system?
- For each: what was decided, instead of what, because of what, at what cost, since when?

## D-01 The plugin is an Elm Architecture program

- Decision: one immutable state, `update(state, msg) → state, effects`, views as functions of state, effects run
  by an interpreter.
- Instead of: modules that call each other and the Neovim API directly, with state in each module.
- Because: a refresh touches everything (stack, cache, buffers, folds, cursor). With one state and one update
  function, "what may a refresh change" has one answer. Core is testable with plain data.
- Cost: more files per behavior (message, handler, effect, interpreter case). Values from the outside (clock,
  ids, cursor) must travel inside messages.
- Since: v0.1, the skeleton. Built in full from the start on purpose, so later increments only add messages.
- See: [02](02-mental-model.md), [04](04-patterns.md).

## D-02 No runtime dependencies

- Decision: Neovim 0.12 and jj on `PATH`. Nothing else. Tests use plenary only.
- Instead of: nui.nvim for floats, plenary for async and jobs, a diff library.
- Because: fewer moving parts for the user. The plugin needs splits, scratch buffers, extmarks, `vim.system`, and
  coroutines. All are in Neovim 0.12.
- Cost: a 46-line async helper, a 57-line semaphore, a 24-line scheduler, written here.
- Since: v0.1.
- See: `shell/lib/`.

## D-03 A line key carries no change id and no line number

- Decision: `side | path | hash(line ± 2 context, whitespace removed) | occurrence`.
- Instead of: `change_id + line number`, or `commit_id + line number`.
- Because: the agent rewrites revisions. Change ids survive a rewrite, but line numbers do not. Commit ids change
  on every rewrite. Content with a little context survives squash, rebase, and amends elsewhere in the file.
- Cost: a change in a neighbor line (±2) un-reviews a line. A rename un-reviews the whole file. A reverted line
  gets its old mark back. All accepted.
- Since: the initial spec.
- See: [06](06-data.md) "Identity".

## D-04 Review state is JSON in `.jj/review/`

- Decision: `marks.json` and `comments.json` in the repo's `.jj/` directory, with a `version` field.
- Instead of: jj commit descriptions, a jj custom store, a database, a file in `$XDG_DATA_HOME`.
- Because: the agent must read comments without a plugin or an API. `.jj/` is never snapshotted by jj, so the
  state never enters a revision. One file per repo keeps the agent's job simple: `cat`.
- Cost: no lock between two Neovim instances on one repo. The agent must not write.
- Since: the initial spec.
- See: [06](06-data.md) "Persistence".

## D-05 Every jj read runs with `--ignore-working-copy`

- Decision: `root`, `op log`, `log`, `diff`, `file show` never snapshot. Only `edit` and `util snapshot` do.
- Instead of: let jj snapshot on each command, as the CLI does by default.
- Because: a snapshot creates an operation. The plugin refreshes on each operation. A read that creates an
  operation would refresh forever (I-3).
- Cost: changes the agent makes on disk without a jj command are not seen until a jj command runs.
  `:Review refresh` runs one snapshot by hand.
- Since: v0.1 (jj port).
- See: [07](07-edges.md) "jj".

## D-06 A review file is a buffer, not a window

- Decision: there is no diff window. Any window can show a review buffer. The buffer keeps its diff, marks, and
  keymaps in every window and tab until the review closes. `gd`, splits, `:b`, `<C-o>` all work.
- Instead of: a dedicated right window owned by the plugin, as diffview.nvim has.
- Because: Vim conventions (netrw, nvim-tree open files in the previous window). LSP jumps in working-copy
  mode land in a buffer that is still a review buffer.
- Cost: the plugin must choose a target window by rule, and must observe focus to know the current file. A
  buffer that gets a window needs a second draw (gutter width).
- Since: "Review buffers: a review file is a buffer, not a window" (after v0.7).
- See: [spec/ux.md](../../spec/ux.md) "Windows and buffers".

## D-07 The review lives in its own tab page

- Decision: `:Review` opens a new tab with the explorer on the left. `:Review` again goes to that tab.
- Instead of: a split in the current tab, or a floating layout.
- Because: the user's other windows do not move. The review has its own window set, so the target window rule
  stays simple.
- Cost: focus and `WinClosed` on the tab must be observed to close the review cleanly.
- Since: v0.2.
- See: [07](07-edges.md) "Neovim".

## D-08 Two modes, one renderer

- Decision: view mode draws on a scratch buffer with text from `jj file show`. Working-copy mode draws on the
  real file buffer with text from disk. The renderer is the same and takes buffer, old text, new text, hunks.
- Instead of: a diff-only mode (no LSP), or always the real file (no way to show an older revision).
- Because: the user wants LSP and edits on the revision under work, and a faithful view of older revisions.
- Cost: mode detection (`@`, or empty `@` and `@-`), buffer remade on a mode change, snapshot after save.
- Since: the initial spec (I-4); working-copy mode in v0.6.
- See: [05](05-walkthroughs.md) walkthrough 4.

## D-09 The default revset includes descendants

- Decision: `(trunk()..@)::`.
- Instead of: `trunk()..@`.
- Because: after `jj edit` on a middle revision, `@` moves down. `trunk()..@` would drop the revisions above it.
  `::` keeps them.
- Cost: a sibling made with `jj new` on a middle revision makes the stack non-linear → error state.
- Since: v0.6.
- See: [spec/stack.md](../../spec/stack.md) "Revset".

## D-10 Render is an effect, batched once per tick

- Decision: `update` returns `RenderExplorer` and `RenderDiff`. The shell sets a dirty flag per view and redraws
  at most once per event-loop tick. A render is a full redraw of the namespace.
- Instead of: redraw after every dispatch, or incremental extmark updates.
- Because: `update` decides what changed the screen. Twenty `DiffLoaded` messages give one redraw. Files are
  small, so a full redraw is fast enough.
- Cost: a render that needs a second pass (gutter width) must be scheduled from the shell.
- Since: v0.1.
- See: [07](07-edges.md) "Render batching".

## D-11 A generation counter instead of cancellation

- Decision: each `Opened` increments `generation`. Effects carry it, results carry it back. An old result is
  dropped.
- Instead of: cancel running jj processes, or tokens per request.
- Because: a jj call is short and harmless. Ignoring a late answer is enough and has no failure modes.
- Cost: a few redundant jj calls after a quick close and open.
- Since: v0.1.
- See: [02](02-mental-model.md) "Lifecycle".

## D-12 Functions of at most 15 lines, patterns by name

- Decision: every function fits in 15 lines. A long computation is a sequence of named helpers. Each pattern in
  use is named with its established name in the spec and in module headers.
- Instead of: no size rule; patterns as implicit habits.
- Because: an agent writes most of the code. Small named steps are reviewable by reading names. A named pattern
  is a shared vocabulary between the spec, the reviewer, and the agent.
- Cost: more helpers, more names to choose.
- Since: v0.1.
- See: [10](10-process.md).

## Not here
- Limits that are consequences, not decisions → [09](09-limits.md)
- Patterns with their cost → [04](04-patterns.md)
