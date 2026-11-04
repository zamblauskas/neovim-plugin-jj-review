-- Navigation between unreviewed changes of one file.

local changes = require("review.core.changes")

local M = {}

---@param segment review.Segment
---@param marks review.Marks
---@return boolean
local function is_unreviewed(segment, marks)
  return vim.iter(changes.keys(segment)):any(function(key)
    return marks[key] == nil
  end)
end

--- Line of the next (`offset` > 0) or previous (`offset` < 0) unreviewed change after `line`. No wrap.
---@param segments review.Segment[]
---@param marks review.Marks
---@param line integer
---@param offset integer
---@return integer?
function M.unreviewed_line(segments, marks, line, offset)
  local lines = vim
    .iter(segments)
    :filter(function(segment)
      return is_unreviewed(segment, marks)
    end)
    :map(function(segment)
      return segment.line
    end)
    :totable()
  if offset < 0 then
    lines = vim.iter(lines):rev():totable()
  end
  return vim.iter(lines):find(function(l)
    return (offset > 0 and l > line) or (offset < 0 and l < line)
  end)
end

return M
