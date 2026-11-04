-- Handlers: explorer and diff UI.

local effect = require("review.core.effect")
local folds = require("review.core.folds")
local tbl = require("review.lib.tbl")

local M = {}

---@param state review.State
---@return review.Revision[]
local function revisions(state)
  return state.stack.type == "ok" and state.stack.revisions or {}
end

---@param state review.State
---@param msg review.Msg.FoldToggled
---@return review.State, review.Effect[]
function M.FoldToggled(state, msg)
  local next_folds = folds.toggle(state.folds, revisions(state), msg.change_id)
  return tbl.with(state, { folds = next_folds }), { effect.render_explorer() }
end

return M
