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

return M
