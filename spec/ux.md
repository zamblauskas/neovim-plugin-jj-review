# UX

## Layout

```
┌─ Explorer ──────────────────────┬─ Diff: uxl · src/app/service/controller.ts ───────┐
│ Stack 156/465                   │                                                   │
│                                 │                                                   │
│ ▸ uxl: final fixes     12/321   │  (see "Diff view")                                │
│ ▾ kpt: add service 💬     0/68  │                                                   │
│   src/app/service/              │                                                   │
│     controller.ts 💬      0/56  │                                                   │
│     index.ts           0/12     │                                                   │
│ ▸ ✅ jrg: base model  144/144   │                                                   │
│                                 │                                                   │
│ Orphaned comments (1)           │                                                   │
│   ⚠ user.ts:42 "rename this"    │                                                   │
└─────────────────────────────────┴───────────────────────────────────────────────────┘
```

- `:Review` opens a new tab page. Your other tabs do not change. `:Review` again goes to that tab.
- Explorer: left split, fixed width.
- `:Review close` closes the tab.

## Windows and buffers

The review follows Vim conventions (netrw, nvim-tree). There is no special diff window.

1. **A review file is a buffer, not a window.**
   - A review file is one revision at one path. It has one buffer: a scratch buffer (view mode) or the real file
     buffer (working-copy mode).
   - The buffer keeps its diff, marks, comments and keymaps in every window and tab, until the review closes.
   - `gd`, `<C-o>`, `:b`, splits: a review buffer shown again is up to date. The diff is drawn again when a
     buffer gets a window (`BufWinEnter`): the gutter of a hidden buffer has no width.
   - A real file buffer opened by other means (`gd`, `:e`) is a review buffer if its path is a file of the
     working-copy revision.
2. **The explorer opens a file in the previous window** (`wincmd p`) of the review tab, and focuses it.
   If there is no other window, it opens a split on the right.
3. **The current file is the review buffer in the last focused window** of the review tab (not the explorer,
   not a float).
   - The explorer highlights the row of the current file: full-line background (`ReviewCurrent`). No highlight
     when that window shows another buffer, or when the file's revision is closed. The cursor line wins over it.
     The explorer cursor does not move to the current file.
   - `]f` / `[f` step from the current file.
- The stack changes:
  - A rewritten file: its buffer shows the new diff.
  - A file that is gone: its buffer is released. A scratch buffer is wiped (a window that shows it gets an empty
    buffer). A real file buffer stays, without the review marks and keymaps.
- `:Review close`: all review buffers are released (scratch buffers wiped; marks and keymaps removed from real
  buffers).

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
- Counts are right-aligned to the text width of the explorer window. The rows render again when the window
  width changes. A long name is cut with `…`. The stack count shows when all
  diffs are loaded.
- `💬` and `⚠` come after the name. A long name is cut before them, so they stay visible.
- Orphaned comments section at the bottom: `⚠ path:line "first line of the text"`. Hidden if empty.

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
| Replaced line | Changed tokens of the removed line and of the added line get a stronger background |
| Comment | Virtual lines below the last line of the anchor, `💬` prefix, from the left edge with the gutter |
| Outdated comment | Virtual lines at the original line number, `⚠ outdated` prefix, other color |

Dim can be turned off in config (`dim_reviewed = false`). Dim colors are a 50% blend of `DiffAdd` / `DiffDelete`
with the `Normal` background. Removed lines start at the left edge with a gutter, so their text aligns with the
buffer text.

Intra-line diff (`inline_diff = true`): the k-th line of a removed block pairs with the k-th added line right after
it. Tokens are word runs, whitespace runs and single characters. A line with more than 60% of its tokens changed is
rewritten: no token highlight. Dimmed reviewed lines show no token highlight.

Placement rules:
- A removed block attaches to the next real line.
- At the end of the file, it attaches to the previous line.
- File deleted or emptied: buffer has one empty line. The block attaches below it.
- A block above line 1: the plugin sets `topfill` so the block is visible.

### Comment input

Float window with a multi-line buffer (markdown). Title shows the anchor (`controller.ts:12-14`,
`controller.ts:7 (removed)`). Opens in insert mode. Keys: `<C-s>` saves (normal and insert mode). `q` or `<Esc>` in
normal mode cancels. Empty text: no comment.

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
| `<leader>rh` | Show / hide removed blocks. Hidden: the buffer reads as the file at the revision. Marks and comments stay. |
| `<leader>rx` | Delete the comment shown at the cursor line (the first one if there are more) |
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
| `<leader>rx` | Delete the orphaned comment under the cursor |
| `q` | Close review |
| `?` | Help: a float with all configured keymaps by section. `q`, `<Esc>` or `?` closes it. |

## Commands

| Command | Action |
|---|---|
| `:Review [revset]` | Open the explorer for the stack. Default revset: `(trunk()..@)::` |
| `:Review close` | Close the explorer and review buffers |
| `:Review clear` | Delete all marks and comments in the repo. Asks for confirmation. Needs an open review. |
| `:Review refresh` | Snapshot the working copy (`jj util snapshot`), so changes made outside Neovim are seen. Needs an open review. |
