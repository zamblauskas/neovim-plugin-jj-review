# UX

## Layout

```
┌─ Explorer ──────────────────────┬─ Diff: uxl · src/app/service/controller.ts ───────┐
│ Stack 156/465                   │                                                   │
│                                 │                                                   │
│ ▸ uxl: final fixes     12/321   │  (see "Diff view")                                │
│ ▾ kpt: add service    0/68  💬  │                                                   │
│   src/app/service/              │                                                   │
│     controller.ts      0/56  💬 │                                                   │
│     index.ts           0/12     │                                                   │
│ ▸ ✅ jrg: base model  144/144   │                                                   │
│                                 │                                                   │
│ Orphaned comments (1)           │                                                   │
│   ⚠ user.ts:42 "rename this"    │                                                   │
└─────────────────────────────────┴───────────────────────────────────────────────────┘
```

- `:Review` opens a new tab page. Your other tabs do not change. `:Review` again goes to that tab.
- Explorer: left split, fixed width.
- Diff: one file at a time, in the diff window (right). If you close it, the next file opens a new one.
- `:Review close` closes the tab.

## Explorer

- Order: newest revision on top (same as `jj log`).
- Revision row: `change-id-prefix: description   reviewed/total`.
- File rows under the revision, grouped by directory (tree). Directories first, then files, sorted by name.
  A directory with one subdirectory and no files is one row (`src/app/service/`). Directory rows have no counts
  and do not fold.
- File row: colored status letter (`A`, `M`, `D`, `R`, `C`), name, `← old/path` for a rename or copy,
  `(binary)` for a binary file.
- Counts: `reviewed / total` reviewable lines. Binary file: `0/1` or `1/1`.
- Icons:
  - `✅` everything reviewed (file or revision).
  - `💬` one comment or more in the file or revision.
  - `⚠` outdated or orphaned comment.
  - `◆` revision is the working copy (`@`).
- Default fold: only the oldest revision with unreviewed lines is unfolded. It is computed once per stack load,
  when all diffs are loaded, so a revision does not close while you review it. Before that, the oldest revision is
  open. A fold you set stays until the review closes.
- Counts are right-aligned to the explorer width. A long name is cut with `…`. The stack count shows when all
  diffs are loaded.
- Orphaned comments section at the bottom. Hidden if empty.

### Error state

```
┌─ Explorer ──────────────────────┐
│ ✖ Stack is not linear           │
│   revset: (trunk()..@)::        │
│   heads: uxl, mzo               │
└─────────────────────────────────┘
```

## Diff view

Overlay on one buffer. The plugin draws all of it with its own extmarks.

```
   10   │ fn load() {
        │-  let a = read();             ← removed block (virtual lines), red
        │-  let b = parse(a);
        │-  log(b);
        │-  return b;
 ✓ 11   │+  let a = read_all();         ← reviewed: sign ✓, dimmed
   12   │+  validate(a);
        │   💬 Why validate here and not in read_all?   ← comment (virtual lines)
   13   │+  return a;
   14   │ }
```

Visual states:

| State | Display |
|---|---|
| Added line, not reviewed | Green background |
| Added line, reviewed | Sign `✓`, dimmed green |
| Removed block, not reviewed | Red virtual lines above the next real line |
| Removed block, reviewed | Red virtual lines dimmed, `✓` in the gutter of the first line |
| Removed block, partly reviewed | `3/4` in the gutter of the first line |
| Comment | Virtual lines below the anchor line, `💬` prefix |
| Outdated comment | Virtual lines at the original line number, `⚠ outdated` prefix, other color |

Dim can be turned off in config (`dim_reviewed = false`). Dim colors are a 50% blend of `DiffAdd` / `DiffDelete`
with the `Normal` background. Removed lines start at the left edge with a gutter, so their text aligns with the
buffer text.

Placement rules:
- A removed block attaches to the next real line.
- At the end of the file, it attaches to the previous line.
- File deleted or emptied: buffer has one empty line. The block attaches below it.
- A block above line 1: the plugin sets `topfill` so the block is visible.

### Comment input

Float window with a multi-line buffer. Title shows the anchor (`controller.ts:12-14`).
Keys: `<C-s>` saves. `q` or `<Esc>` in normal mode cancels.

## Keymaps

### Global

Prefix `<leader>jv`.

| Key | Action |
|---|---|
| `<leader>jvv` | `:Review` (default revset) |
| `<leader>jvq` | `:Review close` |

### Diff view keymaps

Buffer-local. Only in review buffers.

| Key | Action |
|---|---|
| `<leader>rr` | Toggle reviewed: line, or visual range |
| `<leader>rR` | Toggle reviewed: removed block attached to the cursor line (above or below it) |
| `<leader>rf` | Toggle reviewed: file |
| `<leader>rc` | Add comment: line, or visual range. Unchanged lines are allowed. |
| `<leader>rC` | Add comment: removed block above the cursor |
| `<leader>rx` | Delete comment under the cursor |
| `]r` / `[r` | Next / previous unreviewed line or block, in this file only. No wrap. A block: its attach line. |
| `]R` / `[R` | Next / previous file in the revision |

No key to change revision. Use the explorer.
The cursor does not move after a mark. Use `]r` to go to the next unreviewed line.

### Explorer keymaps

| Key | Action |
|---|---|
| `<CR>` | On a revision: fold / unfold. On a file: open it. |
| `<leader>re` | Make the revision under the cursor the working copy (`jj edit`) |
| `<leader>rf` | Toggle reviewed: file under the cursor |
| `q` | Close review |
| `?` | Help |

## Commands

| Command | Action |
|---|---|
| `:Review [revset]` | Open the explorer for the stack. Default revset: `(trunk()..@)::` |
| `:Review close` | Close the explorer and review buffers |
| `:Review clear` | Delete all marks and comments in the repo. Asks for confirmation. Needs an open review. |
