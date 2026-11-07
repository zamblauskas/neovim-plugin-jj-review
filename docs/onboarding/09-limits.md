# 09 Limits

> Source of truth: [spec/improvements.md](../../spec/improvements.md), [spec/stack.md](../../spec/stack.md), [spec/features.md](../../spec/features.md) "Not planned".
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- Which limits are by design? What is the reason, and what is the workaround?
- Which hidden invariants exist: rules that the types do not enforce and that a change can break silently?
- Which hazards are known and open? What is the tracking id?
- What would a reader assume that is not true?

Ids `A1` … `D5` are rows of `spec/improvements.md`. Their status lives there.

## By design

| Limit | Because | Workaround |
|---|---|---|
| The stack must be linear | A tree view is v2 (F-31). The linear check is one separate step, so it can be replaced. | Squash or rebase the sibling. |
| Edits made outside Neovim are not seen until a jj command runs | Reads never snapshot (I-3, D-05). | `:Review refresh` runs one `jj util snapshot`. |
| A change in a neighbor line (±2) un-reviews the line | The key hashes two lines of context (D-03). | None. Review it again. |
| A rename un-reviews the whole file | `path` is in the key. | None. |
| A reverted line gets its old mark back | Same content, same key. | Unmark it. |
| No edits in view mode | The revision is not on disk. | `<leader>re` makes it the working copy. |
| Whitespace-only changes are not reviewable | `jj diff -w`. Blank lines have no key. | None. |
| Comments are only deleted by the user | The agent must not write the review files (D-04). | `<leader>rx` in the diff or on the orphaned row. |
| Only `@` (or `@-` when `@` is empty) can be in working-copy mode | Its text must equal the disk. | `jj edit` from the explorer. |
| A deleted or binary file is always in view mode | No text on disk to show. | None. |

## Hidden invariants

These rules are kept by hand. Nothing in the types enforces them.

| Invariant | Where it is kept by hand | What breaks if missed | Id |
|---|---|---|---|
| After any change to `stack`, `diffs`, or `contents`, `review_buffers.sync` must run | 5 handlers call it: `StackLoaded`, `DiffLoaded`, `ContentLoaded`, `FileOpened`, `FocusChanged` | A buffer shows stale text. | A1 |
| After a change that affects which revision is open by default, `folds.update_default` must run | 3 handlers | The explorer opens the wrong revision. | A1 |
| `state.root` is set before any effect that needs it | `assert(state.root)` in 5 handlers | A throw inside core, which "never throws". | A3 |
| Every effect interpreter case exists for every effect type | the interpreter table | An unknown effect is a silent no-op. | B2 |
| `parse/log.TEMPLATE` and the parser match | one file | The stack never loads. | - |
| A port function runs inside `async.run` | every caller in `shell/effects.lua` | A yield outside a coroutine throws. | - |
| Cache entries of commits not in the stack are dropped on each stack load | `StackLoaded` handler | Memory grows with every rewrite. | - |
| File-key equality is written in 4 places the same way | `handlers/ui`, `explorer_cursor`, `view/explorer`, `focus` | One place drifts; the current file highlight is wrong. | A7 |

## Open hazards

| Hazard | Effect | Status, id |
|---|---|---|
| `dispatch` is re-entrant: a sync failure of `vim.system`, or `tabclose` → `WinClosed` → `Closed` inside a dispatch | The inner dispatch completes on newer state, then the outer loop runs the rest of its older effect list. Order is surprising. | open, A2. Fix: a message queue in `app.lua`. |
| No error boundary per effect | An interpreter that throws stops the rest of the effect list. The UI is stale with no message. | open, B2. Fix: `pcall` per effect, `Notify` on failure. |
| 8 shell modules keep state in module variables | One review per Neovim process. Tests must reset globals. Ports are not instances. | open, B1. |
| No lock on `marks.json` between two Neovim instances on one repo | Read-merge-write can lose an update from the other instance. | open, B5. Document or add a lock file. |
| `write_atomic` does not check the results of `write` and `close` | A full disk gives a silent partial temp file before the rename. | open, B4. |
| `nvim__redraw` is a private API | May change in Neovim 0.13. | open, B3. Isolated in one function. |
| A target with no loaded text gets line count 1 | A block or hunk toggle before the content is loaded places lines wrong. | open, A6. |
| `comments.place` runs on every render for every file of every revision | O(stack) per redraw. Fine today; grows with the stack. | open, A5. |
| `jj diff --git` paths with ` b/` inside | Header parse fails for that file. | known, C5. jj limit. |

## Things a reader may assume that are not true

- "The plugin diffs files." No. jj diffs. The plugin parses `jj diff --git` and draws it.
- "The plugin polls jj." No. It watches one directory and reacts to focus. Each check is one `jj op log` call.
- "Marks are per revision." No. A mark is per line content. The same line in two revisions is one mark.
- "A comment is tied to its line number." Only as a fallback (outdated). The keys find it after a rewrite.
- "Closing the diff window closes the file." There is no diff window. A review buffer lives until the review
  closes or its file leaves the stack.
- "The agent writes to the review files." No. The agent only reads. The plugin is the only writer.
- "The explorer cursor follows the open file." No. The current file is highlighted; the cursor stays where you
  left it.

## Not here
- Decisions that caused a limit → [08](08-decisions.md)
- Status of each improvement id → [spec/improvements.md](../../spec/improvements.md)
