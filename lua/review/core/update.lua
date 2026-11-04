-- update(state, msg) → state, effects. Pure. Selects a handler by `msg.type` (dispatch table).

local M = {}

---@type table<string, fun(state: review.State, msg: review.Msg): review.State, review.Effect[]>
local handlers = vim.tbl_extend(
  "error",
  require("review.core.handlers.lifecycle"),
  require("review.core.handlers.stack"),
  require("review.core.handlers.ui"),
  require("review.core.handlers.store"),
  require("review.core.handlers.review"),
  require("review.core.handlers.comments")
)

--- A message is stale when the review is closed, or when it answers an older open.
---@param state review.State
---@param msg review.Msg
---@return boolean
local function is_stale(state, msg)
  if msg.type == "Opened" then
    return false
  end
  return not state.open or (msg.generation ~= nil and msg.generation ~= state.generation)
end

---@param state review.State
---@param msg review.Msg
---@return review.State, review.Effect[]
function M.update(state, msg)
  local handler = handlers[msg.type]
  if is_stale(state, msg) or not handler then
    return state, {}
  end
  return handler(state, msg)
end

return M
