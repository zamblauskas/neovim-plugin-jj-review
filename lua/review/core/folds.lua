-- Fold state of revisions in the explorer.
-- A user choice is stored per change id. Without a choice, a default rule decides.

local M = {}

---@alias review.FoldState "open"|"closed"
---@alias review.Folds table<string, review.FoldState>  -- by change id

--- Default rule: only the oldest revision is open.
---@param revisions review.Revision[]  -- newest first
---@param change_id string
---@return boolean
local function open_by_default(revisions, change_id)
  local oldest = revisions[#revisions]
  return oldest ~= nil and oldest.change_id == change_id
end

---@param folds review.Folds
---@param revisions review.Revision[]
---@param change_id string
---@return boolean
function M.is_open(folds, revisions, change_id)
  local choice = folds[change_id]
  if choice == nil then
    return open_by_default(revisions, change_id)
  end
  return choice == "open"
end

--- New fold state with the revision toggled.
---@param folds review.Folds
---@param revisions review.Revision[]
---@param change_id string
---@return review.Folds
function M.toggle(folds, revisions, change_id)
  local next_state = M.is_open(folds, revisions, change_id) and "closed" or "open"
  return vim.tbl_extend("force", folds, { [change_id] = next_state })
end

return M
