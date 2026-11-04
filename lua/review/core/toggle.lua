-- Toggle rules (spec/data-model.md): if one key or more is not marked, mark all; else unmark all.
-- A toggle is a patch (Command pattern). The same patch applies to the state and to the file on disk.

local M = {}

---@class review.Mark
---@field created string  -- ISO 8601 UTC

---@alias review.Marks table<string, review.Mark>  -- by line key

---@class review.MarkPatch
---@field set review.Marks
---@field unset string[]

---@param marks review.Marks
---@param keys string[]
---@return string[]
local function unmarked(marks, keys)
  return vim.tbl_filter(function(key)
    return marks[key] == nil
  end, keys)
end

--- Patch that toggles `keys` as one unit.
---@param marks review.Marks
---@param keys string[]
---@param now string  -- ISO 8601 UTC, for new marks
---@return review.MarkPatch
function M.patch(marks, keys, now)
  local missing = unmarked(marks, keys)
  if #missing == 0 then
    return { set = {}, unset = keys }
  end
  local set = {}
  for _, key in ipairs(missing) do
    set[key] = { created = now }
  end
  return { set = set, unset = {} }
end

---@param patch review.MarkPatch
---@return boolean
function M.is_empty(patch)
  return next(patch.set) == nil and #patch.unset == 0
end

--- New marks with the patch applied.
---@param marks review.Marks
---@param patch review.MarkPatch
---@return review.Marks
function M.apply(marks, patch)
  local out = vim.tbl_extend("force", marks, patch.set)
  for _, key in ipairs(patch.unset) do
    out[key] = nil
  end
  return out
end

return M
