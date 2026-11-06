-- Handlers: working-copy mode (snapshot after save, jj edit).

local effect = require("review.core.effect")

local M = {}

---@param root string
---@param path string
---@return boolean
local function is_under(root, path)
  return vim.startswith(path, root .. "/") and not vim.startswith(path, root .. "/.jj/")
end

--- A file of the repo was saved: snapshot, so jj sees the change.
---@param state review.State
---@param msg review.Msg.FileSaved
---@return review.State, review.Effect[]
function M.FileSaved(state, msg)
  if not (state.root and is_under(state.root, msg.path)) then
    return state, {}
  end
  return state, { effect.snapshot(state.root) }
end

--- The user asked for a snapshot: jj sees changes made outside Neovim. A new operation refreshes the review.
---@param state review.State
---@return review.State, review.Effect[]
function M.SnapshotRequested(state)
  if not state.root then
    return state, {}
  end
  return state, { effect.snapshot(state.root) }
end

---@param state review.State
---@param msg review.Msg.EditRequested
---@return review.State, review.Effect[]
function M.EditRequested(state, msg)
  if not state.root then
    return state, {}
  end
  return state, { effect.jj_edit(state.root, msg.change_id) }
end

---@param state review.State
---@param msg review.Msg.CommandFailed
---@return review.State, review.Effect[]
function M.CommandFailed(state, msg)
  return state, { effect.notify("warn", msg.text) }
end

return M
