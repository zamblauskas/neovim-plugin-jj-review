# 07 Edges

> Source of truth: [spec/architecture.md](../../spec/architecture.md) "JJ calls", "Rendering", [spec/ux.md](../../spec/ux.md) "Windows and buffers", `lua/review/shell/`.
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- Which outside systems do we touch? (complete list)
- For each touching point: which mechanism, from which unit, under which rule?
- Which touching points are fragile?
- Which outside events come in, and how do they become messages?

Three outside systems: Neovim, jj, the file system. Only `shell/` touches them. The tables are complete: a
Neovim API or a jj command that is not here is not used.

## Neovim

| Concern | Mechanism | Module | Rule or note |
|---|---|---|---|
| Review tab | tab page (`tabnew`, `tabclose`) | `shell/layout.lua` | One tab. `:Review` again goes to it. Close keeps the explorer only if it is the last tab. |
| Target window for a file | current window, else previous (`wincmd p`), else new split on the right | `shell/layout.lua` | Never the explorer, never a float. |
| Explorer | scratch buffer, left vertical split, fixed width | `shell/explorer.lua` | Full redraw per render. Rows render again on window resize. `:q` on it closes the review. |
| Explorer rows → actions | buffer-local keymaps by config name; row target table from the last render | `shell/explorer.lua`, `core/explorer_actions.lua` | One dispatcher for all row actions. |
| Review file, view mode | scratch buffer named `review://<change-id>/<path>`, `modifiable=false`, filetype by path | `shell/buffers.lua` | Text set on each prepare. Wiped on release; its windows get an empty buffer. |
| Review file, working-copy mode | the real file buffer (`bufadd`, `bufload`) | `shell/buffers.lua` | Text never changed by the plugin. On release only extmarks and keymaps go. |
| Keep cursor and scroll on text replace | `winsaveview` / `winrestview` per window that shows the buffer | `shell/buffers.lua` | Clamped to the new line count. |
| Diff drawing | extmarks: `line_hl_group`, signs, `virt_lines` (removed blocks, comments), `hl_group` ranges (changed tokens) | `shell/apply.lua`, `view/diff.lua` | Full redraw per render. One namespace for diffs, one for the explorer. |
| Removed block above line 1 | window `topfill` | `shell/diff.lua` | Else the virtual lines above line 1 are hidden. |
| Gutter width for virtual lines | measured from `getwininfo().textoff` after a redraw; `nvim__redraw` | `shell/diff.lua` | **Private API.** A statuscolumn gets its width on the first redraw, so the draw runs, measures on the next tick, draws again if changed. |
| Sign column | `signcolumn=yes` in each window of a review buffer | `shell/diff.lua` | Set before the gutter is measured, so the measure includes it. |
| Diff keymaps | buffer-local keymaps → messages; cursor line, visual range (`getpos`, feedkeys `<Esc>`) | `shell/diff_keymaps.lua` | The keymap reads the cursor and the clock, then dispatches. |
| Current file | autocmds `BufEnter`, `WinEnter` in the review tab, reported on the next tick | `shell/focus.lua` | Observer. Explorer and floats are not reported. Core never guesses the current file. |
| Buffer got a window | autocmd `BufWinEnter` → `BufferShown` | `shell/focus.lua` | The diff is drawn again: a hidden buffer has no gutter width. |
| Neovim got focus | autocmd `FocusGained` → refresh | `shell/watcher.lua` | Fallback when the file watcher is late or absent. |
| A review buffer got focus | autocmd `BufEnter` on `review://*` → refresh | `shell/watcher.lua` | |
| File saved | autocmd `BufWritePost` → `FileSaved{realpath}` | `shell/watcher.lua` | Core checks the path is under the root, then asks for a snapshot. |
| Subprocess | `vim.system`, async, callback on the main loop | `shell/jj.lua` | At most `max_parallel_jj` (default 4) diff calls at once. |
| Async as steps | coroutines: `async.run`, `async.await` | `shell/lib/async.lua` | Every port function runs inside `async.run`. |
| Render batching | `vim.schedule`, one flag per view | `shell/lib/schedule.lua` | At most one redraw per view per event-loop tick. |
| Debounce | `vim.uv` timer, 200 ms | `shell/watcher.lua` | |
| Comment input | float window, markdown buffer, insert mode; `<C-s>` saves, `q` or `<Esc>` cancels | `shell/comment_input.lua` | Empty text: no comment. |
| Help | float with the configured keys, from one key description table | `shell/help.lua`, `view/help.lua`, `core/keymap_docs.lua` | The same table gives keymap `desc`. |
| Colors | highlight groups linked to standard ones; blends computed from `nvim_get_hl`; redone on `ColorScheme` | `shell/highlights.lua` | All `Review*` groups can be overridden by a color scheme. |
| Notifications | `vim.notify` | `shell/effects.lua` | Levels info, warn, error. |
| User command, global keys | `:Review [revset|close|clear|refresh]`, `<leader>jvv`, `<leader>jvq` | `init.lua` | `:Review clear` asks for confirmation (`confirm`). |
| Reload changed files after `jj edit` | `:checktime` | `shell/effects.lua` | |
| Hashing | `vim.fn.sha256` | `core/keys.lua` | Pure. Allowed in core. |

## jj

Every read runs with `--ignore-working-copy`. A read then never snapshots, never creates an operation, and never
triggers our own refresh (I-3). Only two commands write.

| Purpose | Command | Module | Note |
|---|---|---|---|
| Repo root | `jj root` | `shell/jj.lua` | Run in the `cwd` of the open. |
| Operation id | `jj op log -n1 --no-graph -T id` | `shell/jj.lua` | Compared with the last one. Same id → nothing to do. |
| Stack | `jj log -r <revset> --no-graph -T <template>` | `shell/jj.lua`, `parse/log.lua` | Template with `\0` separators: change id, shortest prefix, commit id, parent commit ids, empty, working copy, first description line. Template and parser change together. |
| Diff of one revision | `jj diff -r <commit_id> --git -w --context 2` | `shell/jj.lua`, `parse/diff.lua` | `-w`: whitespace changes are not reviewable. 2 context lines: all a line key needs. All statuses parsed: added, modified, deleted, renamed, copied, binary. |
| File content at a revision | `jj file show -r <commit_id> -- 'root-file:"<path>"'` | `shell/jj.lua` | Literal path: a bare path is a fileset expression and fails on special characters. Only for the open file in view mode. |
| Make a revision the working copy | `jj edit <change_id>` | `shell/jj.lua` | **Writes.** Then `:checktime`. The new operation refreshes. |
| Snapshot after a save, or `:Review refresh` | `jj util snapshot` | `shell/jj.lua` | **Writes.** The new operation refreshes. |

Default revset: `(trunk()..@)::`. Revisions between trunk and `@`, plus all their descendants. The descendants
matter: after `jj edit` on a middle revision, `@` moves down, and `trunk()..@` alone would drop the revisions
above it.

## File system

| Concern | Mechanism | Module | Rule or note |
|---|---|---|---|
| Review state | `<root>/.jj/review/marks.json`, `comments.json` | `shell/store.lua` | Read again before each write. Patch applied. Write `path.tmp.<pid>`, then `fs_rename`. `mkdir -p` first. |
| jj operations happened | `vim.uv` fs_event on `<repo>/op_heads/heads/` | `shell/watcher.lua` | Debounced 200 ms. Each jj command moves the op head file. |
| Secondary workspace | `.jj/repo` is a file with a path to the main repo | `shell/watcher.lua` | The watcher follows it, so a workspace sees operations made in the main repo. |
| Real path of a buffer | `fs_realpath` | `shell/focus.lua`, `shell/watcher.lua` | Symlinks resolved, same as the jj root. |

## Events that come in

| Outside event | Mechanism | Becomes |
|---|---|---|
| jj command ran (any terminal) | fs_event on op_heads, debounced | `RefreshRequested` → `CheckOp` + `LoadStore` |
| Neovim got focus | `FocusGained` | `RefreshRequested` |
| A review buffer got focus | `BufEnter review://*` | `RefreshRequested` |
| A file was written | `BufWritePost` | `FileSaved{path}` → `Snapshot` if under the root |
| Focused window shows another buffer | `BufEnter`, `WinEnter`, next tick | `FocusChanged{file?, path?}` |
| A review buffer got a window | `BufWinEnter` | `BufferShown{file}` |
| Window closed (explorer `:q`, tab closed) | `WinClosed` | `Closed` |
| Explorer window resized | `WinResized` | render again |
| Color scheme changed | `ColorScheme` | highlights set again |
| jj subprocess finished | `vim.system` callback | `StackLoaded`, `DiffLoaded`, `ContentLoaded`, `OpChecked`, `RootResolved`, `JjFailed`, `CommandFailed` |

## Fragile points

| Point | Why fragile | What to watch |
|---|---|---|
| `nvim__redraw` for the gutter measure | Private API. May change in Neovim 0.13. | Isolated in one function in `shell/diff.lua` ([09](09-limits.md) B3). |
| Virtual lines have no `hl_eol` | The background of a removed block must be padded by hand (`PAD_WIDTH = 400`). | A very wide window shows the end of the padding. |
| `jj diff --git` path quoting | jj does not quote paths. A path that contains ` b/` breaks the header parse. | Known jj limit ([09](09-limits.md) C5). |
| `jj log` template | The parser and the template are one unit. A jj template change breaks both. | `parse/log.lua` returns the bad line. |
| feedkeys `<Esc>` to leave visual mode | Works, but fragile with pending input. | ([09](09-limits.md) B6). |
| `vim.system` sync failure path | On a spawn failure the callback runs at once, inside the dispatch that started it. | Re-entrant dispatch ([09](09-limits.md) A2). |

## Not here
- What the data looks like once inside → [06](06-data.md)
- Why every read ignores the working copy → [08](08-decisions.md) D-05
