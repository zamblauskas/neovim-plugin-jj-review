-- Counts: reviewed / total reviewable lines per file, revision and stack. Computed in one place (F-35 prep).

local keys = require("review.core.keys")

local M = {}

---@class review.Count
---@field reviewed integer
---@field total integer

---@param a review.Count
---@param b review.Count
---@return review.Count
local function add(a, b)
  return { reviewed = a.reviewed + b.reviewed, total = a.total + b.total }
end

---@param file review.FileDiff
---@param marks review.Marks
---@return review.Count
function M.file(file, marks)
  local all = keys.of_file(file)
  local reviewed = #vim.tbl_filter(function(key)
    return marks[key] ~= nil
  end, all)
  return { reviewed = reviewed, total = #all }
end

---@param files review.FileDiff[]
---@param marks review.Marks
---@return review.Count
function M.files(files, marks)
  local total = { reviewed = 0, total = 0 }
  for _, file in ipairs(files) do
    total = add(total, M.file(file, marks))
  end
  return total
end

--- Count of the stack, or nil while a diff of the stack is not loaded.
---@param revisions review.Revision[]
---@param diffs table<string, review.FileDiff[]>
---@param marks review.Marks
---@return review.Count?
function M.stack(revisions, diffs, marks)
  local total = { reviewed = 0, total = 0 }
  for _, rev in ipairs(revisions) do
    local files = diffs[rev.commit_id]
    if not files then
      return nil
    end
    total = add(total, M.files(files, marks))
  end
  return total
end

---@param count review.Count
---@return boolean
function M.is_done(count)
  return count.reviewed == count.total
end

return M
