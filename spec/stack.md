# Stack

## Revset

Default: `(trunk()..@)::`. Revisions between trunk and `@`, plus all their descendants.

Why not `trunk()..@`: after `jj edit` on a middle revision, `@` moves down. `trunk()..@` then drops all revisions above it. Descendants (`::`) keep them.

`:Review <revset>` overrides the default for the session.

## Evaluation

At open and at each refresh:

1. Evaluate the revset.
2. Remove empty revisions.
3. Check the rest is linear (each revision has one parent in the set, one head). If not → error state in the explorer ([ux.md](ux.md#error-state)).
4. Order: newest on top.

Step 3 is separate from steps 1–2. A tree view (F-31) replaces only step 3.

## Refresh

Trigger: the JJ operation id changed. Checked:
- When Neovim gets focus, or a review buffer gets focus.
- When `.jj/repo/op_heads/` changes (file watcher). The agent runs in another terminal, so focus may not change.

On refresh: evaluate the stack again, recompute diffs and counts, read `marks.json` again, redraw.

Changes the agent makes without a jj command are not seen until a jj command runs (the plugin never snapshots
in view mode).

No refresh loop: all JJ reads by the plugin use `--ignore-working-copy`. They never snapshot, so they never create an operation. In working-copy mode, saving a buffer triggers one snapshot, then one refresh.

## Rewrite behavior

| Event | Result |
|---|---|
| `jj edit` to a middle revision | Stack stays complete (descendants included). |
| Agent adds revisions on top | Included. |
| `jj new` on top (empty `@`) | Hidden (empty). |
| Squash top into its parent | Top disappears. Its lines are in the parent now. Marks match by key. |
| Squash root into its child | Root disappears. Same as above. |
| Squash root into trunk | JJ refuses (trunk is immutable). |
| New revision on a middle revision (sibling) | Not linear → error. |
| Abandon a revision | It disappears. Marks stay in the file. |
| Open revision disappears | Close the diff (empty buffer in the diff window). Explorer cursor goes to the nearest previous (older) revision still in the stack, else the newest. |
| Open file disappears from its revision | Close the diff. Explorer cursor goes to the revision row. |
| Open revision is rewritten | Show the new text of the file. Cursor and scroll stay. |
| Refresh fails (jj error) | Keep the last stack. Show a warning. |

## Modes

| Mode | Buffer | Content source | LSP / edit |
|---|---|---|---|
| View (default) | Scratch, read-only, name `review://<change-id>/<path>` | `jj file show -r <rev>` | No / No |
| Working-copy | Real file buffer | Disk | Yes / Yes |

- The plugin opens the real buffer when the revision content equals the working copy. Example: the revision is `@`, or `@` is empty and the revision is `@-`.
- A deleted file always uses a scratch buffer.
- `<leader>re` in the explorer runs `jj edit <rev>`. Then the refresh opens the real buffer.
- Both modes use the same renderer. It takes: buffer, old text, new text, diff hunks.
