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
---| review.Effect.ClearMarks
---| review.Effect.Notify
---| review.Effect.MoveCursor
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

---@class review.Effect.ClearMarks
---@field type "ClearMarks"
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
function M.open_buffer(change_id, path, lines, cursor_line)
  return { type = "OpenBuffer", change_id = change_id, path = path, lines = lines, cursor_line = cursor_line }
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

---@return review.Effect.ClearMarks
function M.clear_marks(generation, root)
  return { type = "ClearMarks", generation = generation, root = root }
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

return M
