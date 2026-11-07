# review

Neovim plugin. Review a stack of [Jujutsu](https://github.com/jj-vcs/jj) revisions line by line.

Use case: an AI agent writes a feature as a stack of small jj revisions. You review the stack from the oldest
revision to the newest. You mark lines as reviewed and write comments for the agent. The agent reads the comments
and rewrites the revisions. Your marks survive the rewrite, so you review only the lines that changed.

## Requirements

- Neovim 0.12
- jj on `PATH`

No other plugins.

## Install

lazy.nvim:

```lua
{
  "zamblauskas/neovim-plugin-jj-review",
  config = function()
    require("review").setup()
  end,
}
```

## Usage

1. In a jj repo, run `:Review` (or `<leader>jvv`). A new tab opens: the explorer on the left, the diff on the right.
2. The explorer shows the stack, newest revision on top, with `reviewed/total` lines per file and revision.
   The oldest revision with unreviewed lines is open.
3. `<CR>` on a file opens its diff. Added lines are green. Removed lines are red virtual lines.
4. Mark lines with `<leader>rr` (line, or visual range), or a whole hunk with `<leader>rh`. Go to the next
   unreviewed change with `]r`.
5. Write a comment with `<leader>rc`. `<C-s>` saves it.
6. The agent rewrites the stack. The review refreshes on each jj operation. Marks stay on lines that did not change.

`?` in the explorer shows all keymaps.

### Modes

- **View mode**: the diff is in a read-only scratch buffer (`review://<change-id>/<path>`).
- **Working-copy mode**: the revision is `@`, or `@` is empty and the revision is `@-`. The diff is on your real
  file buffer. LSP and edits work. A save runs `jj util snapshot`, and the review refreshes.

`<leader>re` in the explorer runs `jj edit` on the revision under the cursor.

## Commands

| Command | Action |
|---|---|
| `:Review [revset]` | Open the review. Default revset: `(trunk()..@)::` |
| `:Review close` | Close the review tab |
| `:Review clear` | Delete all marks and comments in the repo (asks first) |

## Keymaps

Explorer:

| Key | Action |
|---|---|
| `<CR>` | Fold revision / open file |
| `<leader>rf` | Toggle reviewed: file |
| `<leader>re` | Make the revision the working copy (`jj edit`) |
| `<leader>rx` | Delete an orphaned comment |
| `?` | Help |
| `q` | Close review |

Diff buffer:

| Key | Action |
|---|---|
| `<leader>rr` | Toggle reviewed: line, or visual range |
| `<leader>rR` | Toggle reviewed: removed block at the line |
| `<leader>rh` | Toggle reviewed: hunk at the line |
| `<leader>rf` | Toggle reviewed: file |
| `<leader>rc` | Comment: line, or visual range |
| `<leader>rC` | Comment: removed block at the line |
| `<leader>rH` | Comment: hunk at the line |
| `<leader>rx` | Delete the comment at the line |
| `]r` / `[r` | Next / previous unreviewed change in the file |
| `]R` / `[R` | Next / previous file in the revision |
| `<leader>r-` | Show / hide removed lines (the buffer then reads as the file at the revision) |

Global: `<leader>jvv` opens, `<leader>jvq` closes.

## Configuration

Defaults:

```lua
require("review").setup({
  revset = "(trunk()..@)::",
  explorer_width = 40,
  max_parallel_jj = 4, -- jj diff calls at the same time
  dim_reviewed = true, -- dim reviewed lines
  inline_diff = true, -- highlight the changed tokens of a replaced line
  keymaps = { -- set a key to false to not map it
    open = "<leader>jvv",
    close = "<leader>jvq",
    enter = "<CR>",
    quit = "q",
    help = "?",
    edit = "<leader>re",
    toggle = "<leader>rr",
    toggle_block = "<leader>rR",
    toggle_hunk = "<leader>rh",
    toggle_file = "<leader>rf",
    comment = "<leader>rc",
    comment_block = "<leader>rC",
    comment_hunk = "<leader>rH",
    delete_comment = "<leader>rx",
    next_unreviewed = "]r",
    prev_unreviewed = "[r",
    next_file = "]R",
    prev_file = "[R",
    toggle_removed = "<leader>r-",
  },
  icons = {
    reviewed = "✅",
    comment = "💬",
    warning = "⚠",
    working_copy = "◆",
    mark = "✓",
  },
})
```

An unknown option name is an error.

### Highlight groups

All groups link to standard groups by default. Override them in your color scheme.

| Group | Default |
|---|---|
| `ReviewAdded` / `ReviewRemoved` | `DiffAdd` / `DiffDelete` |
| `ReviewAddedReviewed` / `ReviewRemovedReviewed` | 50% blend with the `Normal` background |
| `ReviewAddedFile` / `ReviewRemovedFile` (lines of a new / deleted file) | 25% blend |
| `ReviewAddedFileReviewed` / `ReviewRemovedFileReviewed` | 10% blend |
| `ReviewAddedText` / `ReviewRemovedText` (changed tokens) | background mixed with the `Added` / `Removed` foreground |
| `ReviewSign` | `DiagnosticOk` |
| `ReviewComment` / `ReviewCommentOutdated` | `DiagnosticInfo` / `DiagnosticWarn` |
| `ReviewCount` / `ReviewDone` | `Comment` / `DiagnosticOk` |
| `ReviewStatusAdded` / `Modified` / `Deleted` / `Renamed` | `Added` / `Changed` / `Removed` / `Special` |
| `ReviewChangeId` / `ReviewChangeIdRest` | `Special` / `Comment` |
| `ReviewCurrent` (explorer row of the file in the last focused window) | `Visual` |
| `ReviewWorkingCopy`, `ReviewHeader`, `ReviewDim`, `ReviewError`, `ReviewFold`, `ReviewDirectory` | see `lua/review/shell/highlights.lua` |

## Files for the agent

Review state is plain JSON in `.jj/review/` (jj never snapshots `.jj/`):

- `marks.json`: reviewed line keys.
- `comments.json`: comments. Each comment has the revision (`change_id`), `path`, line numbers, a `snippet` of the
  code, and the `text`. The agent reads this file. Only the plugin writes it.

The format is in [spec/data-model.md](spec/data-model.md).

## Development

`make check` runs format check (stylua), lint (selene), type check (lua-language-server) and tests (plenary).
The specification is in [spec/](spec/README.md).
