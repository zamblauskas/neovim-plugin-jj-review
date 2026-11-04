-- Handlers: review state from the store (marks.json).

local effect = require("review.core.effect")
local tbl = require("review.lib.tbl")

local M = {}

---@param state review.State
---@param msg review.Msg.StoreLoaded
---@return review.State, review.Effect[]
function M.StoreLoaded(state, msg)
  return tbl.with(state, { marks = msg.marks }), { effect.render_explorer(), effect.render_diff() }
end

---@param state review.State
---@param msg review.Msg.StoreFailed
---@return review.State, review.Effect[]
function M.StoreFailed(state, msg)
  return state, { effect.notify("error", msg.error) }
end

return M
