# 01 Problem

> Source of truth: [spec/README.md](../../spec/README.md), [README.md](../../README.md).
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- What does the system do, in one sentence? For whom?
- What is the core loop: who acts, what the system does, what comes back?
- Which invariants does every part of the system serve?
- What is it not? What is out of scope on purpose?
- What does it need to run?

## What and for whom

A Neovim plugin that lets you review a stack of Jujutsu (jj) revisions line by line, and keeps your progress
when the stack is rewritten.

The user is a person who asks an AI agent to build a feature as a stack of small jj revisions. The agent works in
another terminal. The user reads the stack in Neovim, marks lines as reviewed, and writes comments. The agent
reads the comments from a JSON file and rewrites the revisions. The marks survive the rewrite. The user reviews
only the lines that changed.

## The core loop

```
          ┌──────────────────────────────────────────────────────────────────────────────┐
          │                                                                              │
   you    │   :Review          mark lines <leader>rr        comment <leader>rc           │
          │   ──────▶ explorer ──────▶ diff view ──────────▶ .jj/review/comments.json    │
          │              ▲                                           │                   │
          │              │ refresh (new jj operation)                │ reads             │
          │              │                                           ▼                   │
   agent  │   jj squash / jj new / rewrites  ◀──────────────  fixes the code             │
          │              │                                                               │
          │              └──── .jj/review/marks.json: marks survive, keyed by content ───┘
          └──────────────────────────────────────────────────────────────────────────────┘
```

1. You open `:Review`. The explorer shows the stack, newest revision on top, with `reviewed/total` per file.
2. You open a file. Added lines are green, removed lines are red virtual lines.
3. You mark lines, hunks, or files. Counts update. You write comments for the agent.
4. The agent reads `comments.json`, rewrites the revisions. Each jj command is a jj operation.
5. The plugin sees the new operation and refreshes. Marks on unchanged lines stay. Changed lines are unreviewed.

## Invariants

Later pages refer to these by name.

| # | Invariant | Why | Where it is enforced |
|---|---|---|---|
| I-1 | **A mark belongs to line content, not to a revision.** | The agent rewrites revisions. Change ids and line numbers move. Content does not. So marks survive squash, rebase, amend. | Line key (06). `core/keys.lua`. |
| I-2 | **Review state is plain JSON that the agent reads directly.** | No API, no server, no plugin on the agent side. `cat .jj/review/comments.json` is the integration. | Store (06, 07). Versioned schema. |
| I-3 | **The plugin never creates a jj operation on its own.** | A refresh is triggered by a new operation. If a read created one, the plugin would refresh itself forever. | Every read runs with `--ignore-working-copy` (07). |
| I-4 | **One renderer. A mode only changes where the text comes from.** | View mode (scratch buffer) and working-copy mode (real file, LSP works) must look and behave the same. | Diff view takes buffer, old text, new text, hunks (02, 03). |

## Not in scope

| Not done | Because |
|---|---|
| Edit code in view mode | View mode shows a revision that is not on disk. Edits would have no place to go. Use working-copy mode. |
| Store review state in jj commits or descriptions | Marks must not change the stack the agent works on. |
| Review a stack with branches (tree) | Linear only. The linear check is one separate step, so a tree view (F-31) can replace it later. |
| GitHub or other forge integration | The counterpart is an agent on the same machine, not a remote. |
| Side-by-side diff | Inline overlay on one buffer. The renderer takes a diff model, so a second renderer is possible (F-30). |

## Requirements to run

| Need | Value |
|---|---|
| Neovim | 0.12 |
| jj | on `PATH` |
| Other plugins | none (tests use plenary) |
| Size | about 6500 lines of Lua in 61 modules, about 3200 lines of tests |

## Not here
- How it is built → [02](02-mental-model.md), [03](03-boundaries.md)
- Why it is built this way → [08](08-decisions.md)
- Keymaps and configuration → [README.md](../../README.md)
