-- Effects: descriptions of side effects. `update` returns them; the shell runs them.

local M = {}

---@alias review.Effect
---| review.Effect.ResolveRoot
---| review.Effect.CheckOp
---| review.Effect.LoadStack
---| review.Effect.LoadDiff
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

return M
