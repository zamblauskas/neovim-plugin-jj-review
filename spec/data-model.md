# Data model

## Diff input

One diff engine: JJ. One call per revision: `jj diff -r <commit_id> --git -w --context 2`.
- 2 context lines give the ±2 neighbors of each changed line. That is all a line key needs.
- So counts for the full stack need no file content.
- The new text (`jj file show`) is read only for the file open in view mode.

Lines with whitespace-only changes are not reviewable. Blank added or removed lines (empty after whitespace is
removed) are not reviewable: no key, no count.

## Line key

Identity of a reviewable line. No change id. So a key survives squash, rebase and amend.

```
key = side | path | hash(normalize(context)) | occurrence
```

| Part | Value |
|---|---|
| `side` | `+` added line (new text), `-` removed line (old text) |
| `path` | Repo-relative path in the side's text |
| `context` | The line, plus 2 lines above and 2 below, from the same side's text. Missing lines (file edge) are empty. |
| `normalize` | Remove all whitespace |
| `hash` | `vim.fn.sha256` |
| `occurrence` | 1-based index among reviewable lines in the same file diff, same side, same hash, top to bottom. Unchanged lines elsewhere in the file do not count. |

Example. Revision changes `load()`:

```
old (parent)               new (revision)
10  fn load() {            10  fn load() {
11    let a = read();      11    let a = read_all();
12    let b = parse(a);    12    validate(a);
13    log(b);              13    return a;
14    return b;            14  }
15  }
```

- Removed old:12 → `- | src/load.rs | hash("letb=parse(a);" + old 10,11,13,14) | 1`
- Added new:12 → `+ | src/load.rs | hash("validate(a);" + new 10,11,13,14) | 1`

Consequences (accepted):
- A change in a neighbor line (±2) makes the line unreviewed again.
- A rename makes all lines of the file unreviewed.
- If a line comes back after the agent reverted it, its old mark is active again.

## Marks

File: `.jj/review/marks.json`. JJ never snapshots `.jj/`.

```json
{
  "version": 1,
  "marks": {
    "+|src/load.rs|9f2c…|1": { "created": "2026-11-02T19:30:00Z" }
  }
}
```

The value is an object, so v1 can add `last_seen` (F-21).

## Counts

- File: reviewable lines in the file diff whose key is in `marks`, over all reviewable lines.
- Revision: sum of its files.
- Stack: sum of its revisions.
- Binary file: total 1. Reviewed if the file key is marked. File key: `b | path | blob`. `blob` is the new git
  blob hash from the `index` line of the diff (the old one for a deleted file). No content is loaded.

## Targets and selections

A toggle key or a comment key points at a target. A target resolves to a selection of one of two kinds. The kind
decides what the toggle marks and what a comment is anchored to.

| Kind | Selects | Targets |
|---|---|---|
| Lines | Buffer lines `first..last` of the new text. Unchanged lines are included. | Line (cursor line), visual range |
| Segments | Changes of the diff: added lines and removed blocks (`core/changes.lua`). No unchanged lines. | Removed block, hunk |

| Target | Selection |
|---|---|
| Line | Lines: the cursor line. Attached removed blocks are not in it (`<leader>rR` is for those). |
| Visual range | Lines: the selected lines, with the removed blocks attached to them. |
| Removed block | Segments: the removed blocks attached to the cursor line (above or below it). None → no selection. |
| Hunk | Segments: every segment of the hunk at the cursor line. The cursor is in a hunk on any of its new lines (context included) or on a line a removed block of it is placed on. Between hunks → no selection. |
| File | The whole file diff. Not a selection: it has keys (all reviewable keys, or the binary file key) and no comment. |

A hunk is a jj hunk (`--context 2`): changes at most 4 unchanged lines apart form one hunk.

## Toggle rules

Keys of the selection: added lines in the lines, and the removed blocks attached to them when the selection
includes them; or the keys of the segments. If one or more keys are unmarked, mark all. Else unmark all. A line
without a key (context, blank) has nothing to toggle.

## Comments

File: `.jj/review/comments.json`. One file for the repo. The agent reads it.

```json
{
  "version": 1,
  "comments": [
    {
      "id": "c-7f3a",
      "anchor": { "type": "range", "side": "+", "start_line": 12, "end_line": 13 },
      "change_id": "kptxwzrq",
      "revision_description": "add service",
      "path": "src/load.rs",
      "keys": ["+|src/load.rs|…|1", "+|src/load.rs|…|1"],
      "snippet": "validate(a);\nreturn a;",
      "text": "Why validate here and not in read_all?",
      "created": "2026-11-02T19:31:00Z"
    }
  ]
}
```

- `anchor.type`: `line`, `range`, `block` in v0. `revision` in v1 (F-20).
- `keys`: the anchors of the lines (line, range) or of the removed lines (block).
- A comment on a lines selection: `line` when one line, else `range`; `side` `+`; `start_line`, `end_line` the
  lines; `keys` the anchors of every line in the lines (unchanged lines too); `snippet` the new text of the lines.
- A comment on a segments selection: `block` with `side` `-` when every segment is a removed block; else `line`
  or `range` with `side` `+`. `start_line`, `end_line`: the first and last line the segments are placed on.
  `keys`: the keys of the segments only. `snippet`: the removed and added text of the segments, top to bottom.
  So a hunk comment is placed below the last change of the hunk, not below its trailing context.
- A comment can be on unchanged lines in the diff. An unchanged line in a hunk gets an `=` key
  (`= | path | hash | occurrence`), calculated the same way from the new text, with its own occurrence count.
  It is only a comment anchor: no mark, no count, never equal to a review key.
- A comment on lines outside the hunks has no keys. It shows at `start_line` while its revision has the file.
- `start_line` / `end_line`: line numbers when the comment was made. Used for the outdated fallback.
- `snippet` and line numbers help the agent find the code.
- Only the user deletes comments (`<leader>rx`).

## Comment lookup

For each comment, in the open revision and file:

1. One key or more found in a diff of the stack (any revision, so a comment follows a squash) → show at the
   last found line (the end of the anchor). Normal style.
2. No key found, `change_id` is in the stack, and `path` is in its diff → show at `start_line` (clamped to file length). Outdated style (F-11).
3. Else → orphaned. Listed in the explorer (F-12).

Lines are clamped to the new text. No comment is placed while a diff of the stack is loading.

## Concurrency

The plugin and the agent can both have the files open. Rules:
- The plugin writes with write-to-temp + rename (atomic).
- The plugin reads the file again before each write and merges by key / comment id. A toggle is a patch
  `{ set, unset }`, applied to the file just read. So an unmark is not undone by a merge.
- The agent only reads. Only the plugin writes.
