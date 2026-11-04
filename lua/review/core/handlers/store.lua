-- Handlers: review state from the store (marks.json).

local effect = require("review.core.effect")
local folds = require("review.core.folds")
local tbl = require("review.lib.tbl")

local M = {}

---@param state review.State
---@param msg review.Msg.StoreLoaded
---@return review.State, review.Effect[]
function M.StoreLoaded(state, msg)
  local next_state = tbl.with(state, { marks = msg.marks })
  return tbl.with(next_state, { fold_default = folds.default_for(next_state) }),
    { effect.render_explorer(), effect.render_diff() }
end

---@param state review.State
---@param msg review.Msg.StoreFailed
---@return review.State, review.Effect[]
function M.StoreFailed(state, msg)
  return state, { effect.notify("error", msg.error) }
end

---@param state review.State
---@return review.State, review.Effect[]
function M.Cleared(state)
  if not state.root then
    return state, {}
  end
  return tbl.with(state, { marks = {} }),
    {
      effect.clear_marks(state.generation, state.root),
      effect.render_explorer(),
      effect.render_diff(),
    }
end

return M
