-- Fold state of revisions in the explorer.
-- A user choice is stored per change id. Without a choice, the default decides:
-- only the oldest revision with unreviewed lines is open. The default is computed once per stack load,
-- when all diffs are loaded, so a revision does not close while you review it.

local counts = require("review.core.counts")

local M = {}

---@alias review.FoldState "open"|"closed"
---@alias review.Folds table<string, review.FoldState>  -- by change id

---@class review.FoldDefault
---@field ready boolean      -- computed for this stack load
---@field change_id? string  -- the open revision; nil when all are reviewed

---@type review.FoldDefault
M.PENDING = { ready = false }

--- The default for a stack whose diffs are all loaded.
---@param revisions review.Revision[]  -- newest first
---@param diffs table<string, review.FileDiff[]>
---@param marks review.Marks
---@return review.FoldDefault
local function compute_default(revisions, diffs, marks)
  for i = #revisions, 1, -1 do
    local rev = revisions[i]
    if not counts.is_done(counts.files(diffs[rev.commit_id] or {}, marks)) then
      return { ready = true, change_id = rev.change_id }
    end
  end
  return { ready = true }
end

--- The default for the state: computed when all diffs of the stack are loaded, else PENDING.
---@param state review.State
---@return review.FoldDefault
function M.default_for(state)
  local stack = state.stack
  if stack.type ~= "ok" or not counts.stack(stack.revisions, state.diffs, state.marks) then
    return M.PENDING
  end
  return compute_default(stack.revisions, state.diffs, state.marks)
end

---@param default review.FoldDefault
---@param revisions review.Revision[]
---@param change_id string
---@return boolean
local function open_by_default(default, revisions, change_id)
  if default.ready then
    return default.change_id == change_id
  end
  local oldest = revisions[#revisions]
  return oldest ~= nil and oldest.change_id == change_id
end

---@param folds review.Folds
---@param default review.FoldDefault
---@param revisions review.Revision[]
---@param change_id string
---@return boolean
function M.is_open(folds, default, revisions, change_id)
  local choice = folds[change_id]
  if choice == nil then
    return open_by_default(default, revisions, change_id)
  end
  return choice == "open"
end

--- New fold state with the revision toggled.
---@param folds review.Folds
---@param default review.FoldDefault
---@param revisions review.Revision[]
---@param change_id string
---@return review.Folds
function M.toggle(folds, default, revisions, change_id)
  local next_state = M.is_open(folds, default, revisions, change_id) and "closed" or "open"
  return vim.tbl_extend("force", folds, { [change_id] = next_state })
end

return M
