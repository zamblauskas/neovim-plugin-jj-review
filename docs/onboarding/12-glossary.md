# 12 Glossary

> Source of truth: [spec/README.md](../../spec/README.md) "Glossary".
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- What does each term mean here, in one sentence?
- Which Neovim and jj terms have a specific meaning here?
- Which terms do we not use, and what do we say instead?

## Terms

| Term | Meaning here |
|---|---|
| Stack | Linear list of non-empty revisions from the revset, newest first. |
| Revision | One jj change in the stack. Identified by its change id. Its commit id changes on each rewrite. |
| Rewrite | Any jj operation that gives a revision a new commit id: squash, rebase, amend, edit then save. |
| Reviewable line | An added or removed line that is not blank after whitespace is removed. Has a line key and counts. |
| Line key | Identity of a reviewable line: side, path, hash of the line with ±2 context, occurrence. No change id. |
| Mark | A line key in `marks.json`. The line is reviewed. |
| Comment | Text for the agent on a line, a range, or a removed block. In `comments.json`. |
| Found / outdated / orphaned | The three placement states of a comment: a key found; no key but revision and file present; else. |
| Removed block | Consecutive removed lines of one hunk, shown as virtual lines, marked as one unit. |
| Segment | One change placed on buffer lines: an added line or a removed block. |
| Hunk | A jj hunk with 2 context lines. Changes at most 4 lines apart are one hunk. |
| Target | What a key points at: line, range, block, hunk, file. |
| Selection | What a target resolves to: buffer lines, or diff segments. |
| Patch | A change to marks `{set, unset}` or to comments `{add, remove}`, applied to a fresh read of the file. |
| View mode | The file is a read-only scratch buffer with text from `jj file show`. |
| Working-copy mode | The file is the real buffer on disk. The revision is `@`, or `@` is empty and it is `@-`. |
| Review file | One revision at one path. File key: change id + path. One buffer per file key. |
| Review buffer | The buffer of a review file, in a mode. Keeps its diff, marks, keymaps in every window. |
| Current file | The review file in the last focused window of the review tab. Highlighted in the explorer. |
| Explorer | The left split: stack, file tree, counts, orphaned comments. |
| Message | A thing that happened, as data with a `type`. The only input of `update`. |
| Effect | A side effect to run, as data with a `type`. The only output of `update` besides the state. |
| Port | A shell module that talks to one outside thing (jj, disk, clock, ids, explorer, …). Tests use fakes. |
| Generation | Counter incremented on each open. A result from an older open is dropped. |
| Operation (op) | A jj operation. Each jj command makes one. The op id is the refresh trigger. |
| Refresh | Check the op id; if changed, load the stack again, fetch new diffs, read the store again, redraw. |
| Snapshot | `jj util snapshot`: jj records the working copy as the content of `@`. Makes an operation. |
| Store | `.jj/review/marks.json` and `comments.json`. |
| Fold default | The rule that opens only the oldest revision with unreviewed lines. |

## Neovim and jj terms with a specific meaning here

| Term | General meaning | Meaning here |
|---|---|---|
| Buffer | Text in memory, maybe tied to a file. | A review buffer is one per file key; scratch or real by mode. |
| Window | A viewport on a buffer. | There is no diff window. The target window is chosen by rule. |
| Tab page | A set of windows. | The review tab. One per review. |
| Extmark | An anchored annotation in a buffer. | The whole diff view: backgrounds, signs, virtual lines, token ranges. |
| Virtual lines | Lines drawn that are not in the buffer. | Removed blocks and comments. |
| `topfill` | Virtual lines shown above the first line of a window. | So a removed block above line 1 is visible. |
| Gutter | Sign, number, fold columns left of the text. | Measured after a redraw to pad virtual lines. |
| Scratch buffer | A buffer with no file. | View-mode review buffer, name `review://…`. |
| Change id | jj: stable id of a change across rewrites. | Revision identity; file key part; comment field. |
| Commit id | jj: id of one immutable commit. | Cache key for diffs and contents; changes on each rewrite. |
| Revset | jj: an expression that selects revisions. | Default `(trunk()..@)::`. |
| `@` | jj: the working-copy commit. | The revision in working-copy mode. |
| Workspace | jj: a second working copy of one repo. | `.jj/repo` is a file; the watcher follows it. |

## Terms we do not use

| Do not say | Say | Why |
|---|---|---|
| Commit | Revision | jj vocabulary. "Commit id" is the one exception: it names the immutable id. |
| Branch, PR | Stack | There is no remote and no forge. |
| Diff window | Target window, review buffer | There is no diff window (D-06). |
| Approve, resolve | Mark, reviewed | A mark is per line, not per comment or per revision. |
| Event | Message | One word for one thing. "Event" is kept for outside events that become messages. |
| Action, command (as a plugin concept) | Message, effect | Elm vocabulary. "Command pattern" names the design pattern only. |
| Controller, service, manager | Handler, port | No objects with behavior. Handlers are functions; ports are modules. |

## Not here
- Feature ids → [spec/features.md](../../spec/features.md)
- Improvement ids → [spec/improvements.md](../../spec/improvements.md)
