-- Navigation inside one file: the next or previous line of a kind (unreviewed change, hunk). No wrap.
-- Each kind gives its candidate lines; `step` picks the one after or before the cursor line.

local changes = require("review.core.changes")

local M = {}

--- The first of `lines` after `line` (`offset` > 0) or the last before it (`offset` < 0). `lines` ascending.
---@param lines integer[]
---@param line integer
---@param offset integer
---@return integer?
function M.step(lines, line, offset)
  if offset < 0 then
    lines = vim.iter(lines):rev():totable()
  end
  return vim.iter(lines):find(function(l)
    return (offset > 0 and l > line) or (offset < 0 and l < line)
  end)
end

---@param segment review.Segment
---@param marks review.Marks
---@return boolean
local function is_unreviewed(segment, marks)
  return vim.iter(changes.keys(segment)):any(function(key)
    return marks[key] == nil
  end)
end

--- Line of the next (`offset` > 0) or previous (`offset` < 0) unreviewed change after `line`.
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
  return M.step(lines, line, offset)
end

--- First line of each hunk (its first segment), ascending.
---@param segments review.Segment[]
---@return integer[]
local function hunk_lines(segments)
  local first = {}
  for _, segment in ipairs(segments) do
    first[segment.hunk] = math.min(first[segment.hunk] or segment.line, segment.line)
  end
  local lines = vim.tbl_values(first)
  table.sort(lines)
  return lines
end

--- Line of the next (`offset` > 0) or previous (`offset` < 0) hunk after `line`: its first change.
---@param segments review.Segment[]
---@param line integer
---@param offset integer
---@return integer?
function M.hunk_line(segments, line, offset)
  return M.step(hunk_lines(segments), line, offset)
end

return M
