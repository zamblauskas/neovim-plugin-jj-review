# review — specification

Neovim plugin. Review a stack of JJ revisions line by line.

## Use case

1. You ask an AI agent to implement a big feature as a stack of small, self-contained JJ revisions.
2. You go through the stack from the oldest revision to the newest.
3. You mark diff lines as reviewed. You add comments for the agent.
4. The agent reads the comments and rewrites the revisions.
5. Your marks survive the rewrite. You review only the lines that changed.

You see the count of lines left to review per file, per revision, and for the stack.

## Principles

- Marks belong to line content, not to a revision. They survive `jj squash`, rebase and amend.
- The data model is per line. The UI can group lines (for example, removed blocks).
- One renderer for all modes. A mode only changes where the buffer content comes from.
- Review state is in plain JSON files. The agent reads them directly.
- v0 code must not block v1 and v2 features. See "Prepare in v0" in [features.md](features.md).

## Documents

| File | Concern |
|---|---|
| [features.md](features.md) | Feature list per version (v0, v1, v2) with IDs |
| [ux.md](ux.md) | Layout, mockups, visual states, keymaps |
| [data-model.md](data-model.md) | Line keys, marks, comments, counts, JSON files |
| [stack.md](stack.md) | Revset, refresh, behavior when the stack is rewritten |
| [architecture.md](architecture.md) | Patterns, layers, modules, state, messages, effects, flows |
| [roadmap.md](roadmap.md) | v0 increments (v0.1 … v0.7), each one usable |
| [open-questions.md](open-questions.md) | Points not decided yet |

## Glossary

| Term | Meaning |
|---|---|
| Stack | Linear list of revisions from the revset. Empty revisions are hidden. |
| Revision | One JJ change in the stack. Identified by its change id. |
| Reviewable line | An added (`+`) or removed (`-`) line in the diff of a revision. Whitespace-only changes are not reviewable. |
| Removed block | Consecutive removed lines in one hunk. Shown as virtual lines. Marked as one unit. |
| Line key | Identity of a reviewable line. Path + side + hash of content and context + occurrence index. See [data-model.md](data-model.md#line-key). |
| Mark | A line key in `marks.json`. The line is reviewed. |
| Comment | Text for the agent, attached to one line, a line range or a removed block. |
| View mode | Diff in a read-only scratch buffer. Content from `jj file show`. No LSP. |
| Working-copy mode | Diff on the real file buffer. The revision is the working copy (`@`). LSP and edits work. |
| Explorer | Left split. Stack, files and counts. |
