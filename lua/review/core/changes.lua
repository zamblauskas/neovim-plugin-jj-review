-- Positions of changes in the new text of a file diff.

local M = {}

--- 1-based line in the new text of the first change. A removed block counts at the line it attaches to
--- (the next real line). 1 when the file has no hunks.
---@param file review.FileDiff
---@return integer
function M.first_line(file)
  local hunk = file.hunks[1]
  if not hunk then
    return 1
  end
  local new_line = hunk.new_start
  for _, line in ipairs(hunk.lines) do
    if line.kind ~= " " then
      return math.max(new_line, 1)
    end
    new_line = new_line + 1
  end
  return math.max(new_line, 1)
end

return M
