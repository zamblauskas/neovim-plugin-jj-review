-- Handlers: find the repo, watch the operation, load the stack.

local effect = require("review.core.effect")
local folds = require("review.core.folds")
local keys = require("review.core.keys")
local modes = require("review.core.modes")
local open_file = require("review.core.open_file")
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

--- Cache entries of commits in the stack only. Other entries are dropped.
---@generic T
---@param cache table<string, T>
---@param built review.StackOk
---@return table<string, T>
local function keep_stack_commits(cache, built)
  local out = {}
  for _, rev in ipairs(built.revisions) do
    out[rev.commit_id] = cache[rev.commit_id]
  end
  return out
end

--- State with the new stack. An ok stack drops cache entries of other commits.
---@param state review.State
---@param built review.Stack
---@return review.State
local function with_stack(state, built)
  local next_state = tbl.with(state, { stack = built, fold_default = folds.on_new_stack(state.fold_default) })
  if built.type ~= "ok" then
    return next_state
  end
  return tbl.with(next_state, {
    diffs = keep_stack_commits(state.diffs, built),
    contents = keep_stack_commits(state.contents, built),
  })
end

--- Let the open file follow the new state. Its effects come after `effects`.
---@param state review.State
---@param effects review.Effect[]
---@return review.State, review.Effect[]
local function with_followed(state, effects)
  local next_state, follow_effects = open_file.follow(state)
  return next_state, vim.list_extend(effects, follow_effects)
end

---@param state review.State
---@param msg review.Msg.StackLoaded
---@return review.State, review.Effect[]
function M.StackLoaded(state, msg)
  local built = stack.build(msg.revisions)
  local next_state = tbl.with(with_stack(state, built), { disk_commit = modes.disk_commit(msg.revisions) })
  local effects = vim.list_extend({ effect.render_explorer() }, missing_diffs(state, built))
  return with_followed(tbl.with(next_state, { fold_default = folds.update_default(next_state) }), effects)
end

---@param state review.State
---@param msg review.Msg.DiffLoaded
---@return review.State, review.Effect[]
function M.DiffLoaded(state, msg)
  local diffs = tbl.with(state.diffs, { [msg.commit_id] = vim.tbl_map(keys.annotate, msg.files) })
  local next_state = tbl.with(state, { diffs = diffs })
  return with_followed(
    tbl.with(next_state, { fold_default = folds.update_default(next_state) }),
    { effect.render_explorer() }
  )
end

---@param state review.State
---@param msg review.Msg.JjFailed
---@return review.State, review.Effect[]
function M.JjFailed(state, msg)
  if state.stack.type == "ok" then
    return state, { effect.notify("warn", "jj failed, the stack is not updated: " .. vim.trim(msg.stderr)) }
  end
  return tbl.with(state, { stack = stack.jj_failed(msg.stderr) }), { effect.render_explorer() }
end

return M
