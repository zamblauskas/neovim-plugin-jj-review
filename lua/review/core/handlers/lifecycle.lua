-- Handlers: open and close the review.

local effect = require("review.core.effect")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")

local M = {}

--- Open, or open again with a new revset. Earlier loads become stale (new generation).
---@param state review.State
---@param msg review.Msg.Opened
---@return review.State, review.Effect[]
function M.Opened(state, msg)
  local fresh = state_mod.initial(state.config)
  local next_state = tbl.with(fresh, {
    open = true,
    generation = state.generation + 1,
    cwd = msg.cwd,
    revset = msg.revset or state.config.revset,
  })
  return next_state,
    { effect.open_explorer(), effect.render_explorer(), effect.resolve_root(next_state.generation, msg.cwd) }
end

---@param state review.State
---@return review.State, review.Effect[]
function M.Closed(state)
  return tbl.with(state, { open = false }), { effect.close_explorer() }
end

return M
