# 05 Walkthroughs

> Source of truth: [spec/architecture.md](../../spec/architecture.md) "Main flows", [spec/stack.md](../../spec/stack.md).
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- For each walkthrough: who triggers it, which units take part in which order, what crosses each edge?
- What stays the same and what changes, after the event?
- Which invariant (01) makes the event safe?
- What happens when a step fails?

Four events: open, toggle a line, the agent rewrites the stack, edit a file in working-copy mode.

## 1. You run `:Review`

Trigger: the user. `:Review` or `<leader>jvv`.

```
 user      init.lua     core (update)                 interpreter / ports              jj              Neovim
  │ :Review   │              │                               │                          │                │
  │──────────▶│ Opened{cwd}  │                               │                          │                │
  │           │─────────────▶│ generation+1, open=true       │                          │                │
  │           │              │ ─ OpenTab, RenderExplorer ───▶│ layout.open, explorer ───┼───────────────▶│ new tab, left split
  │           │              │ ─ ResolveRoot{cwd} ──────────▶│ jj root ─────────────────▶│                │
  │           │              │◀─ RootResolved{root} ─────────│◀─────────────────────────│                │
  │           │              │ ─ LoadStore, CheckOp, StartWatcher ──▶ read JSON; jj op log; watch op_heads         │
  │           │              │◀─ StoreLoaded{marks, comments}, OpChecked{op_id}                           │
  │           │              │ ─ LoadStack{revset} ─────────▶│ jj log -r revset ────────▶│                │
  │           │              │◀─ StackLoaded{revisions} ─────│◀─────────────────────────│                │
  │           │              │ remove empty, check linear, newest first                  │                │
  │           │              │ ─ LoadDiff ×n (semaphore 4), RenderExplorer ──▶ jj diff -r <commit> ×n    │
  │           │              │◀─ DiffLoaded{commit_id, files} ×n                        │                │
  │           │              │ keys computed per diff; counts; ─ RenderExplorer (batched) ───────────────▶│ rows, counts
  │           │              │ all diffs in → fold default: oldest revision with unreviewed lines is open │
```

| Thing | Stays | Changes |
|---|---|---|
| Other tabs | untouched | a new tab is current |
| Marks | read from disk | none |
| Diff cache | empty on first open; an `Opened` resets everything | filled commit by commit |

Why it is safe: I-3. `jj root`, `jj op log`, `jj log`, `jj diff` all run with `--ignore-working-copy`. The open
creates no jj operation, so the watcher does not fire on our own reads.

Failure: `jj root` fails (not a jj repo) → `JjFailed` → the explorer shows the error state. `jj log` returns a
stack that is not linear → stack status `error` with the problem revisions. A failed `jj diff` → `JjFailed`; if a
stack is loaded already, it is kept and a warning is shown.

## 2. You mark a line as reviewed

Trigger: `<leader>rr` on a line of a diff buffer.

```
 user     diff_keymaps (shell)       core                                     interpreter / ports       disk
  │ <leader>rr   │                     │                                            │                    │
  │─────────────▶│ reads cursor line,  │                                            │                    │
  │              │ clock.now()         │                                            │                    │
  │              │ ToggleRequested{target: line, now} ──▶│                          │                    │
  │              │                     │ targets.select → selection (lines 12..12)  │                    │
  │              │                     │ keys of the selection (added lines; blocks if attached)        │
  │              │                     │ toggle: any key unmarked → set all, else unset all → patch     │
  │              │                     │ state.marks = apply(patch)                 │                    │
  │              │                     │ ─ SaveMarks{patch}, RenderDiff, RenderExplorer ─▶│              │
  │              │                     │                                            │ read marks.json ──▶│
  │              │                     │                                            │ apply patch, write temp, rename
  │              │                     │                                            │ draw ✓ sign, dim; counts
```

| Thing | Stays | Changes |
|---|---|---|
| Buffer text | untouched | extmarks: sign `✓`, dimmed background |
| `marks.json` | other marks | the keys of the patch, with `created` timestamp |
| Counts | | file, revision, stack `reviewed/total` |
| Fold default | stays for this stack load | |

Why it is safe: I-1. The key is content plus two context lines. I-2. The file on disk is the truth; the patch is
applied to a fresh read, so a mark set by another instance a second ago is kept.

Failure: the write fails (disk, unknown JSON version) → `StoreFailed` → warning. The state already shows the mark;
the next refresh reads the file again and the mark disappears if it was not written.

## 3. The agent runs `jj squash` in another terminal

Trigger: any jj command that creates an operation. Also: Neovim gets focus, or a review buffer gets focus.

```
 agent     .jj/repo/op_heads/   watcher (shell)        core                               jj          Neovim
  │ jj squash     │                 │                     │                                  │             │
  │──────────────▶│ dir changes     │                     │                                  │             │
  │               │────────────────▶│ debounce 200 ms     │                                  │             │
  │               │                 │ RefreshRequested ──▶│                                  │             │
  │               │                 │                     │ ─ CheckOp, LoadStore ───────────▶│ op log      │
  │               │                 │                     │◀─ OpChecked{op_id}  (changed)    │             │
  │               │                 │                     │◀─ StoreLoaded (marks read again) │             │
  │               │                 │                     │ ─ LoadStack ────────────────────▶│ log         │
  │               │                 │                     │◀─ StackLoaded                    │             │
  │               │                 │                     │ cache: keep commits in the new stack, drop the rest
  │               │                 │                     │ ─ LoadDiff for new commit ids only ─▶ diff ×k  │
  │               │                 │                     │ review_buffers.sync: per open file a plan     │
  │               │                 │                     │ ─ PrepareBuffer / ReleaseBuffer / LoadContent ──────────▶│ text replaced, cursor kept
  │               │                 │                     │ ─ RenderExplorer, RenderDiff ─────────────────────────▶│ counts, marks
```

| Thing | Stays | Changes |
|---|---|---|
| Marks | every line whose content and ±2 context did not change keeps its mark | a changed line, or a line next to a change, is unreviewed again |
| Diff cache | entries for commit ids still in the stack | entries of rewritten commits are fetched again; others dropped |
| Open buffer of a rewritten file | cursor and scroll | text and extmarks |
| Open buffer of a file that is gone | | released: scratch buffer wiped, real buffer loses marks and keymaps |
| Explorer cursor | its target, if still there; else nearest older revision; else newest | |
| Fold default | the old one until all diffs are loaded | computed again once per stack load |
| Your manual folds | kept until the review closes | |

Why it is safe: I-1 (marks by content) and I-3 (our reads create no operation, so this refresh does not trigger
another refresh).

Failure: `jj log` fails during a refresh → the last stack is kept, a warning is shown. The stack is not linear
after the rewrite (a sibling) → error state in the explorer, open buffers are not changed.

## 4. You edit a file in working-copy mode

Trigger: the revision under review is `@` (or `@` is empty and the revision is `@-`). Its text is on disk.

```
 user          explorer / buffers (shell)      core                                  jj              Neovim
  │ <CR> on file     │                           │                                      │                │
  │─────────────────▶│ FileOpened{change_id,path}│                                      │                │
  │                  │──────────────────────────▶│ modes.mode → working_copy (disk_commit == commit)     │
  │                  │                           │ ─ PrepareBuffer{mode=working_copy, file_path} ───────▶│ real buffer (bufadd), LSP attaches
  │                  │                           │ ─ ShowBuffer, RenderDiff ───────────────────────────▶│ extmarks on the real buffer
  │ edits, :w        │                           │                                      │                │
  │─────────────────▶│ BufWritePost → FileSaved{path}                                   │                │
  │                  │──────────────────────────▶│ path under root? ─ Snapshot{root} ──▶│ jj util snapshot (writes!)
  │                  │                           │                                      │ new operation  │
  │                  │ watcher: op_heads changed → RefreshRequested → walkthrough 3                      │
```

Between the edit and the save, extmarks move with the text (Neovim does that). Marks stay. After the save the
diff is recomputed from the new operation. `<leader>re` in the explorer runs `jj edit <change_id>` for a revision
that is not `@`; the refresh then makes the buffer again in working-copy mode, in the same windows.

| Thing | Stays | Changes |
|---|---|---|
| The real buffer | its text is never changed by the plugin; stays open after the review closes | review extmarks and keymaps are added, removed on release |
| LSP, `gd`, `:e` | work | a real file of the working-copy revision opened by `gd` is adopted as a review buffer |
| Mode | | changes after `jj edit`; the buffer is made again in the new mode |

Why it is safe: I-4. The same renderer draws the diff on a scratch buffer and on a real buffer. It takes: buffer,
old text, new text, hunks. I-3 has one exception on purpose: `jj util snapshot` and `jj edit` write, so they run
without `--ignore-working-copy`. They are user actions, so one operation and one refresh is the expected result.

Failure: `jj edit` or `jj util snapshot` fails → `CommandFailed` → warning. The buffer stays as it was.

## Not here
- The full list of messages → [spec/architecture.md](../../spec/architecture.md) "Messages"
- Comment placement (found, outdated, orphaned) → [06](06-data.md)
