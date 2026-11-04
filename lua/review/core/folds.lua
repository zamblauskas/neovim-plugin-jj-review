-- Fold state of revisions in the explorer.
-- A user choice is stored per change id. Without a choice, the default decides:
-- only the oldest revision with unreviewed lines is open. The default is computed once per stack load,
-- when all diffs and the marks are loaded, so a revision does not close while you review it.
-- Until then the last computed default stays; before the first one, the oldest revision is open.

local counts = require("review.core.counts")

local M = {}

---@alias review.FoldState "open"|"closed"
---@alias review.Folds table<string, review.FoldState>  -- by change id

---@class review.FoldDefault
---@field computed boolean   -- computed for the current stack load
---@field known boolean      -- computed at least once
---@field change_id? string  -- the open revision; nil when all are reviewed

---@type review.FoldDefault
M.INITIAL = { computed = false, known = false }

--- The default for a stack whose diffs are all loaded.
---@param revisions review.Revision[]  -- newest first
---@param diffs table<string, review.FileDiff[]>
---@param marks review.Marks
---@return review.FoldDefault
local function compute_default(revisions, diffs, marks)
  for i = #revisions, 1, -1 do
    local rev = revisions[i]
    if not counts.is_done(counts.files(diffs[rev.commit_id] or {}, marks)) then
      return { computed = true, known = true, change_id = rev.change_id }
    end
  end
  return { computed = true, known = true }
end

--- A new stack load: the default is computed again, the old one stays until then.
---@param default review.FoldDefault
---@return review.FoldDefault
function M.on_new_stack(default)
  return { computed = false, known = default.known, change_id = default.change_id }
end

--- The default for the state: computed once, when all diffs and the marks are loaded.
---@param state review.State
---@return review.FoldDefault
function M.update_default(state)
  local stack, default = state.stack, state.fold_default
  if default.computed or not state.marks_loaded or stack.type ~= "ok" then
    return default
  end
  if not counts.stack(stack.revisions, state.diffs, state.marks) then
    return default
  end
  return compute_default(stack.revisions, state.diffs, state.marks)
end

---@param default review.FoldDefault
---@param revisions review.Revision[]
---@param change_id string
---@return boolean
local function open_by_default(default, revisions, change_id)
  if default.known then
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
