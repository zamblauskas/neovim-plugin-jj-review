-- Handlers: find the repo, watch the operation, load the stack.

local effect = require("review.core.effect")
local folds = require("review.core.folds")
local keys = require("review.core.keys")
local stack = require("review.core.stack")
local tbl = require("review.lib.tbl")

local M = {}

---@param state review.State
---@param msg review.Msg.RootResolved
---@return review.State, review.Effect[]
function M.RootResolved(state, msg)
  return tbl.with(state, { root = msg.root }),
    {
      effect.load_store(state.generation, msg.root),
      effect.check_op(state.generation, msg.root),
      effect.start_watcher(state.generation, msg.root),
    }
end

---@param state review.State
---@return review.State, review.Effect[]
function M.RefreshRequested(state)
  if not state.root then
    return state, {}
  end
  return state, { effect.check_op(state.generation, state.root), effect.load_store(state.generation, state.root) }
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

--- One LoadDiff per revision whose diff is not in the cache (memoization by commit id).
---@param state review.State
---@param built review.Stack
---@return review.Effect[]
local function missing_diffs(state, built)
  if built.type ~= "ok" then
    return {}
  end
  local missing = vim.tbl_filter(function(rev)
    return state.diffs[rev.commit_id] == nil
  end, built.revisions)
  return vim.tbl_map(function(rev)
    return effect.load_diff(state.generation, assert(state.root, "root not resolved"), rev.commit_id)
  end, missing)
end

---@param state review.State
---@param msg review.Msg.StackLoaded
---@return review.State, review.Effect[]
function M.StackLoaded(state, msg)
  local built = stack.build(msg.revisions)
  local effects = vim.list_extend({ effect.render_explorer() }, missing_diffs(state, built))
  return tbl.with(state, { stack = built, fold_default = folds.PENDING }), effects
end

---@param state review.State
---@param msg review.Msg.DiffLoaded
---@return review.State, review.Effect[]
function M.DiffLoaded(state, msg)
  local diffs = tbl.with(state.diffs, { [msg.commit_id] = vim.tbl_map(keys.annotate, msg.files) })
  local next_state = tbl.with(state, { diffs = diffs })
  local default = state.fold_default.ready and state.fold_default or folds.default_for(next_state)
  return tbl.with(next_state, { fold_default = default }), { effect.render_explorer() }
end

---@param state review.State
---@param msg review.Msg.JjFailed
---@return review.State, review.Effect[]
function M.JjFailed(state, msg)
  return tbl.with(state, { stack = stack.jj_failed(msg.stderr) }), { effect.render_explorer() }
end

return M
