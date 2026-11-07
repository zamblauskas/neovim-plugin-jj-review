# 06 Data

> Source of truth: [spec/data-model.md](../../spec/data-model.md).
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- What are the core entities? One sentence each.
- What is the identity of each? What makes two of them equal?
- What persists where? Who writes it, who reads it, in what format, with what concurrency rule?
- What survives what?
- Which derived data exists, and from what is it derived?

## Entities

| Entity | Identity | One sentence |
|---|---|---|
| Revision | change id (stable across rewrites); commit id (changes on every rewrite) | One jj change in the stack. Has parents, `empty`, `working_copy`, first line of description. |
| Stack | the revset | Linear list of non-empty revisions, newest first. Status `loading`, `ok`, or `error{reason}`. |
| File diff | commit id + path | One file of a revision's diff: status (A, M, D, R, C), old and new path, hunks, binary flag, blob hash. |
| Hunk | position in the file diff | A jj hunk with 2 context lines. Changes at most 4 unchanged lines apart form one hunk. |
| Reviewable line | line key | An added (`+`) or removed (`-`) line that is not blank after whitespace is removed. |
| Line key | itself, a string | `side | path | hash(context) | occurrence`. The identity of a reviewable line across rewrites. |
| Mark | line key | "This line is reviewed." Value: `{created}`. |
| Removed block | first removed line | Consecutive removed lines in one hunk. Shown as virtual lines. Marked as a unit by `<leader>rR`. |
| Segment | position in the buffer | A change placed on buffer lines: an added line, or a removed block attached to a line. |
| Target | type + position | What a key points at: line, visual range, removed block, hunk, file. |
| Selection | derived from a target | Either buffer lines `first..last`, or diff segments. Decides what a toggle marks and where a comment anchors. |
| Comment | id (`c-xxxx`) | Text for the agent on a line, range, or removed block. Carries change id, path, keys, line numbers, snippet. |
| Placement | comment id | Where a comment is shown now: `found`, `outdated`, or `orphaned`. |
| File key | change id + path | One review file. One buffer per file key. |

## Identity, with a worked example

```
key = side | path | hash(normalize(context)) | occurrence
```

| Part | Value |
|---|---|
| `side` | `+` added line (in the new text), `-` removed line (in the old text) |
| `path` | repo-relative path in that side's text |
| `context` | the line, plus 2 lines above and 2 below, from the same side's text. Missing lines at the file edge are empty. |
| `normalize` | remove all whitespace |
| `hash` | sha256 |
| `occurrence` | 1-based index among reviewable lines of the same file diff, same side, same hash, top to bottom |

The revision changes `load()`:

```
old (parent)                     new (revision)
10  fn load() {                  10  fn load() {
11    let a = read();            11    let a = read_all();
12    let b = parse(a);          12    validate(a);
13    log(b);                    13    return a;
14    return b;                  14  }
15  }
```

- Removed old line 12 → `- | src/load.rs | hash("letb=parse(a);" + old 10, 11, 13, 14) | 1`
- Added new line 12 → `+ | src/load.rs | hash("validate(a);" + new 10, 11, 13, 14) | 1`

No change id. No line number. So the key is the same after `jj squash`, `jj rebase`, or an amend that does not
touch lines 10 to 14.

An unchanged line inside a hunk gets an `=` key, computed the same way from the new text. It is only a comment
anchor. It is never a mark and never counts.

A binary file has one key: `b | path | blob`, where `blob` is the git blob hash from the diff index line. It
counts as 1 line.

## Persistence

| Data | Where | Writer | Reader | Format | Concurrency |
|---|---|---|---|---|---|
| Marks | `<root>/.jj/review/marks.json` | the plugin only | the plugin; the agent may | JSON, `version: 1`, object by key | read again before each write; patch `{set, unset}` applied; write temp + rename |
| Comments | `<root>/.jj/review/comments.json` | the plugin only | **the agent** | JSON, `version: 1`, list | same |
| Diff cache, contents | core state | | | | per process; dropped on close |

jj never snapshots `.jj/`, so the review files never enter a revision. A file with an unknown `version` is read
but never written: the plugin shows an error instead.

## Shapes

`marks.json`:

```json
{ "version": 1, "marks": { "+|src/load.rs|9f2c…|1": { "created": "2026-11-02T19:30:00Z" } } }
```

`comments.json`, one comment:

```json
{ "id": "c-7f3a", "anchor": { "type": "range", "side": "+", "start_line": 12, "end_line": 13 },
  "change_id": "kptxwzrq", "revision_description": "add service", "path": "src/load.rs",
  "keys": ["+|src/load.rs|…|1", "+|src/load.rs|…|1"], "snippet": "validate(a);\nreturn a;",
  "text": "Why validate here and not in read_all?", "created": "2026-11-02T19:31:00Z" }
```

The agent needs: `path`, `start_line`, `end_line`, `snippet`, `text`. `change_id` and `revision_description` say
which revision. `keys` are for the plugin to find the comment after a rewrite.

## What survives what

| Event | Marks | Comments |
|---|---|---|
| `jj squash` of a revision into its parent | kept: same content, same context | found in the parent: a key matches in any revision of the stack |
| `jj rebase` | kept | found |
| Amend that changes the line | gone (unreviewed again) | outdated: shown at the original line number, `▲` style, if the revision and the file are still there |
| Amend that changes a neighbor line (±2) | gone for that line too. Accepted. | outdated |
| Rename of the file | all marks of the file gone (`path` is in the key). Accepted. | outdated or orphaned |
| Revert: the line comes back | its old mark is active again. Accepted. | found again |
| `jj abandon` of the revision | marks stay in the file, nothing uses them | orphaned: listed in the explorer, deletable with `<leader>rx` |
| `:Review clear` | all deleted after confirmation | all deleted |
| Neovim restart | kept (on disk) | kept |
| Edits in working-copy mode before save | extmarks move with the text; marks unchanged | same |

## Comment placement, three states

For each comment, when a diff of every revision is loaded:

| State | Rule | Shown |
|---|---|---|
| found | one key or more is in a diff of the stack (any revision) | at the last found line, normal style `●` |
| outdated | no key found, but `change_id` is in the stack and `path` is in its diff | at `start_line` clamped to the file, `▲ outdated` style |
| orphaned | else | in the explorer section "Orphaned comments" |

A comment on lines outside any hunk has no keys. It is found at `start_line` while its file is in its revision.

## Derived data

| Derived | From | When recomputed |
|---|---|---|
| Line keys | the file diff (hunks, 2 context lines) | once per `DiffLoaded`, kept on the diff lines |
| Counts per file, revision, stack | reviewable keys ∩ marks | on every render (cheap: keys are precomputed) |
| Segments on buffer lines | file diff + buffer line count | per render of a diff |
| Fold default | stack + diffs + marks | once per stack load, when all diffs are in |
| Comment placements | comments + diffs + contents | on every explorer and diff render ([09](09-limits.md) A5) |
| Mode per file | `disk_commit` (from the raw log) + file status | per buffer plan |
| Review buffer plans | `state.buffers` + stack + diffs + contents | after each stack, diff, or content change (Reconciler) |

## Not here
- How the JSON is written atomically → [07](07-edges.md) "File system"
- Why the key has no change id → [08](08-decisions.md) D-03
