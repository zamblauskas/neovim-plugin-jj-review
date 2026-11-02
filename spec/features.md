# Features

IDs are stable. Other files refer to them.

## v0 — MVP

| ID | Feature | Details |
|---|---|---|
| F-01 | Open a stack: `:Review [revset]` | [stack.md](stack.md#revset) |
| F-02 | Stack validation: hide empty revisions, error if not linear | [stack.md](stack.md#evaluation) |
| F-03 | Explorer with counts per file, revision, stack | [ux.md](ux.md#explorer) |
| F-04 | Inline diff of one file, drawn with own extmarks | [ux.md](ux.md#diff-view) |
| F-05 | View mode and working-copy mode | [stack.md](stack.md#modes) |
| F-06 | Mark / unmark a line or a visual range of added lines | [data-model.md](data-model.md#toggle-rules) |
| F-07 | Mark / unmark a removed block | [data-model.md](data-model.md#toggle-rules) |
| F-08 | Mark / unmark a file | [data-model.md](data-model.md#toggle-rules) |
| F-09 | Navigation: `]r` `[r` in file, `]R` `[R` between files | [ux.md](ux.md#diff-view-keymaps) |
| F-10 | Add / delete a comment on a line, a range, or a removed block | [data-model.md](data-model.md#comments) |
| F-11 | Outdated comment: key not found, show at the original line number | [data-model.md](data-model.md#comment-lookup) |
| F-12 | Orphaned comments: list in the explorer | [ux.md](ux.md#explorer) |
| F-13 | Auto-refresh when the JJ operation changes | [stack.md](stack.md#refresh) |
| F-14 | Ignore whitespace changes in diff and in line keys | [data-model.md](data-model.md#line-key) |
| F-15 | `:Review close`, `:Review clear` | [ux.md](ux.md#commands) |
| F-16 | Binary files: count 0/1, mark with file toggle | [ux.md](ux.md#explorer) |
| F-17 | Make a revision the working copy (`jj edit`) from the explorer | [stack.md](stack.md#modes) |

## v1

| ID | Feature | Prepare in v0 |
|---|---|---|
| F-20 | Comment on a revision (not on a line) | Comment anchor is a tagged type. Line, range, block now. Revision later. |
| F-21 | Auto cleanup of old marks (`last_seen`, delete after N days) | Mark value is an object, not `true`. Field can be added. |
| F-22 | Mark / comment a file as a whole | Explorer row actions go through one action dispatcher. |

## v2

| ID | Feature | Prepare in v0 |
|---|---|---|
| F-30 | Side-by-side diff | Renderer takes a diff model, not raw `jj` output. A second renderer can use the same model. |
| F-31 | Stacks with branches (tree in explorer) | Stack model keeps the parent list of each revision. Linear check is a separate step. |
| F-32 | Expand a removed block to mark single removed lines | Marks are per removed line already. Only UI groups them. |
| F-33 | Diff window follows a squashed change (`jj evolog`) | Revision lookup is behind one function. |
| F-34 | Interdiff: show what changed since last review | Not planned. Line keys cover most of the need. |
| F-35 | Hook when a revision is fully reviewed | Counts are computed in one place and emit an event. |
| F-36 | CLI / MCP for the agent to read comments | Comments file has a versioned schema. |

## Not planned

- Edit code in view mode.
- Store review state in JJ commits or descriptions.
