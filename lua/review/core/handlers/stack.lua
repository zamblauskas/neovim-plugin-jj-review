-- Handlers: find the repo, watch the operation, load the stack.

local effect = require("review.core.effect")
local stack = require("review.core.stack")
local tbl = require("review.lib.tbl")

local M = {}

---@param state review.State
---@param msg review.Msg.RootResolved
---@return review.State, review.Effect[]
function M.RootResolved(state, msg)
  return tbl.with(state, { root = msg.root }), { effect.check_op(state.generation, msg.root) }
end

--- Load the stack only when the operation changed.
---@param state review.State
---@param msg review.Msg.OpChecked
---@return review.State, review.Effect[]
function M.OpChecked(state, msg)
  if msg.op_id == state.op_id then
    return state, {}
  end
  return tbl.with(state, { op_id = msg.op_id }),
    { effect.load_stack(state.generation, assert(state.root, "root not resolved"), state.revset) }
end

---@param state review.State
---@param msg review.Msg.StackLoaded
---@return review.State, review.Effect[]
function M.StackLoaded(state, msg)
  return tbl.with(state, { stack = stack.build(msg.revisions) }), { effect.render_explorer() }
end

---@param state review.State
---@param msg review.Msg.JjFailed
---@return review.State, review.Effect[]
function M.JjFailed(state, msg)
  return tbl.with(state, { stack = stack.jj_failed(msg.stderr) }), { effect.render_explorer() }
end

return M
