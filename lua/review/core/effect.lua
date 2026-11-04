-- Effects: descriptions of side effects. `update` returns them; the shell runs them.

local M = {}

---@alias review.Effect
---| review.Effect.ResolveRoot
---| review.Effect.CheckOp
---| review.Effect.LoadStack
---| review.Effect.LoadDiff
---| review.Effect.LoadContent
---| review.Effect.OpenBuffer
---| review.Effect.RenderDiff
---| review.Effect.LoadStore
---| review.Effect.SaveMarks
---| review.Effect.ClearStore
---| review.Effect.SaveComments
---| review.Effect.OpenCommentInput
---| review.Effect.Snapshot
---| review.Effect.JjEdit
---| review.Effect.Notify
---| review.Effect.MoveCursor
---| review.Effect.StartWatcher
---| review.Effect.StopWatcher
---| review.Effect.CloseDiff
---| review.Effect.OpenTab
---| review.Effect.CloseTab
---| review.Effect.RenderExplorer

---@class review.Effect.ResolveRoot
---@field type "ResolveRoot"
---@field generation integer
---@field cwd string

---@class review.Effect.CheckOp
---@field type "CheckOp"
---@field generation integer
---@field root string

---@class review.Effect.LoadStack
---@field type "LoadStack"
---@field generation integer
---@field root string
---@field revset string

---@class review.Effect.LoadDiff
---@field type "LoadDiff"
---@field generation integer
---@field root string
---@field commit_id string

---@class review.Effect.LoadContent
---@field type "LoadContent"
---@field generation integer
---@field root string
---@field commit_id string
---@field path string

--- Show a file of a revision in the diff window (view mode: read-only scratch buffer).
---@class review.Effect.OpenBuffer
---@field type "OpenBuffer"
---@field change_id string
---@field path string
---@field lines string[]
---@field cursor_line integer  -- 1-based; the shell clamps it to the buffer
---@field keep_view boolean     -- the window shows an older version of the file: keep cursor and scroll
---@field mode review.Mode       -- working_copy: the real file buffer at `file_path`; view: a scratch buffer
---@field file_path? string      -- absolute path (working_copy)

---@class review.OpenBufferOpts
---@field keep_view? boolean
---@field mode? review.Mode
---@field file_path? string

--- Draw the diff of the open file (`state.open_file`) on its buffer.
---@class review.Effect.RenderDiff
---@field type "RenderDiff"

---@class review.Effect.LoadStore
---@field type "LoadStore"
---@field generation integer
---@field root string

--- Apply the patch to marks.json (read-merge-write).
---@class review.Effect.SaveMarks
---@field type "SaveMarks"
---@field generation integer
---@field root string
---@field patch review.MarkPatch

--- Apply the patch to comments.json (read-merge-write).
---@class review.Effect.SaveComments
---@field type "SaveComments"
---@field generation integer
---@field root string
---@field patch review.CommentPatch

--- Delete all marks and comments.
---@class review.Effect.ClearStore
---@field type "ClearStore"
---@field generation integer
---@field root string

---@class review.Effect.Notify
---@field type "Notify"
---@field level "info"|"warn"|"error"
---@field text string

--- Move the cursor of the current window to `line` (column 0).
---@class review.Effect.MoveCursor
---@field type "MoveCursor"
---@field line integer

--- Watch for jj operations and focus. Each event → RefreshRequested.
---@class review.Effect.StartWatcher
---@field type "StartWatcher"
---@field generation integer
---@field root string

---@class review.Effect.StopWatcher
---@field type "StopWatcher"

--- The open file is gone: the diff window shows an empty buffer; review buffers are wiped.
---@class review.Effect.CloseDiff
---@field type "CloseDiff"

--- Ask for the comment text. Submit → CommentSubmitted with the draft.
---@class review.Effect.OpenCommentInput
---@field type "OpenCommentInput"
---@field title string
---@field draft review.CommentDraft

--- `jj util snapshot`. The new operation triggers a refresh through the watcher.
---@class review.Effect.Snapshot
---@field type "Snapshot"
---@field root string

--- `jj edit <change_id>`. Then buffers of changed files are checked (:checktime).
---@class review.Effect.JjEdit
---@field type "JjEdit"
---@field root string
---@field change_id string

---@class review.Effect.OpenTab
---@field type "OpenTab"

---@class review.Effect.CloseTab
---@field type "CloseTab"

---@class review.Effect.RenderExplorer
---@field type "RenderExplorer"

---@return review.Effect.ResolveRoot
function M.resolve_root(generation, cwd)
  return { type = "ResolveRoot", generation = generation, cwd = cwd }
end

---@return review.Effect.CheckOp
function M.check_op(generation, root)
  return { type = "CheckOp", generation = generation, root = root }
end

---@return review.Effect.LoadStack
function M.load_stack(generation, root, revset)
  return { type = "LoadStack", generation = generation, root = root, revset = revset }
end

---@return review.Effect.LoadDiff
function M.load_diff(generation, root, commit_id)
  return { type = "LoadDiff", generation = generation, root = root, commit_id = commit_id }
end

---@return review.Effect.OpenTab
function M.open_tab()
  return { type = "OpenTab" }
end

---@return review.Effect.CloseTab
function M.close_tab()
  return { type = "CloseTab" }
end

---@return review.Effect.RenderExplorer
function M.render_explorer()
  return { type = "RenderExplorer" }
end

---@return review.Effect.LoadContent
function M.load_content(generation, root, commit_id, path)
  return { type = "LoadContent", generation = generation, root = root, commit_id = commit_id, path = path }
end

---@return review.Effect.OpenBuffer
---@param opts? review.OpenBufferOpts
function M.open_buffer(change_id, path, lines, cursor_line, opts)
  opts = opts or {}
  return {
    type = "OpenBuffer",
    change_id = change_id,
    path = path,
    lines = lines,
    cursor_line = cursor_line,
    keep_view = opts.keep_view or false,
    mode = opts.mode or "view",
    file_path = opts.file_path,
  }
end

---@return review.Effect.CloseDiff
function M.close_diff()
  return { type = "CloseDiff" }
end

---@return review.Effect.RenderDiff
function M.render_diff()
  return { type = "RenderDiff" }
end

---@return review.Effect.LoadStore
function M.load_store(generation, root)
  return { type = "LoadStore", generation = generation, root = root }
end

---@param patch review.MarkPatch
---@return review.Effect.SaveMarks
function M.save_marks(generation, root, patch)
  return { type = "SaveMarks", generation = generation, root = root, patch = patch }
end

---@param patch review.CommentPatch
---@return review.Effect.SaveComments
function M.save_comments(generation, root, patch)
  return { type = "SaveComments", generation = generation, root = root, patch = patch }
end

---@return review.Effect.ClearStore
function M.clear_store(generation, root)
  return { type = "ClearStore", generation = generation, root = root }
end

---@param level "info"|"warn"|"error"
---@param text string
---@return review.Effect.Notify
function M.notify(level, text)
  return { type = "Notify", level = level, text = text }
end

---@param line integer
---@return review.Effect.MoveCursor
function M.move_cursor(line)
  return { type = "MoveCursor", line = line }
end

---@return review.Effect.StartWatcher
function M.start_watcher(generation, root)
  return { type = "StartWatcher", generation = generation, root = root }
end

---@return review.Effect.StopWatcher
function M.stop_watcher()
  return { type = "StopWatcher" }
end

---@param title string
---@param draft review.CommentDraft
---@return review.Effect.OpenCommentInput
function M.open_comment_input(title, draft)
  return { type = "OpenCommentInput", title = title, draft = draft }
end

---@return review.Effect.Snapshot
function M.snapshot(root)
  return { type = "Snapshot", root = root }
end

---@return review.Effect.JjEdit
function M.jj_edit(root, change_id)
  return { type = "JjEdit", root = root, change_id = change_id }
end

return M
