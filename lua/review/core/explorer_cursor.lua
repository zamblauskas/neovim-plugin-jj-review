-- Explorer cursor after a redraw: stay on the same target (revision or file row).
-- Target gone: its revision row; revision gone: the nearest older revision that still exists; else the newest.

local M = {}

---@alias review.RowTargets table<integer, review.ExplorerTarget>  -- by 1-based row

---@param a review.ExplorerTarget
---@param b review.ExplorerTarget
---@return boolean
local function same(a, b)
  return a.type == b.type and a.change_id == b.change_id and a.path == b.path
end

---@param targets review.RowTargets
---@return integer[]
local function sorted_rows(targets)
  local rows = vim.tbl_keys(targets)
  table.sort(rows)
  return rows
end

---@param targets review.RowTargets
---@param wanted review.ExplorerTarget
---@return integer?
local function find_row(targets, wanted)
  return vim.iter(sorted_rows(targets)):find(function(row)
    return same(targets[row], wanted)
  end)
end

---@param change_id string
---@return review.ExplorerTarget
local function revision(change_id)
  return { type = "revision", change_id = change_id }
end

--- Row of the first revision below `old_row` in the old rows that is still in the new rows.
---@param old_targets review.RowTargets
---@param old_row integer
---@param new_targets review.RowTargets
---@return integer?
local function nearest_older(old_targets, old_row, new_targets)
  for _, row in ipairs(sorted_rows(old_targets)) do
    local target = old_targets[row]
    local new_row = row > old_row and target.type == "revision" and find_row(new_targets, target)
    if new_row then
      return new_row
    end
  end
  return nil
end

---@param targets review.RowTargets
---@return integer?
local function first_revision(targets)
  return vim.iter(sorted_rows(targets)):find(function(row)
    return targets[row].type == "revision"
  end)
end

--- New cursor row, or nil to keep the row number (the old row had no target).
---@param old_targets review.RowTargets
---@param old_row integer
---@param new_targets review.RowTargets
---@return integer?
function M.row(old_targets, old_row, new_targets)
  local target = old_targets[old_row]
  if not target then
    return nil
  end
  return find_row(new_targets, target)
    or find_row(new_targets, revision(target.change_id))
    or nearest_older(old_targets, old_row, new_targets)
    or first_revision(new_targets)
end

return M
