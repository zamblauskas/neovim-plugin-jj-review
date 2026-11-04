-- Toggle targets: what a toggle key points at → line keys (spec/data-model.md "Toggle rules").

local changes = require("review.core.changes")
local keys = require("review.core.keys")

local M = {}

---@alias review.ToggleTarget
---| { type: "line", change_id: string, path: string, line: integer }
---| { type: "range", change_id: string, path: string, first: integer, last: integer }
---| { type: "block", change_id: string, path: string, line: integer }
---| { type: "file", change_id: string, path: string }

--- Segment selectors by target type (Strategy).
---@type table<string, fun(segment: review.Segment, target: table): boolean>
local SELECTS = {
  line = function(segment, target)
    return segment.type == "added" and segment.line == target.line
  end,
  range = function(segment, target)
    return segment.line >= target.first and segment.line <= target.last
  end,
  block = function(segment, target)
    return segment.type == "removed" and segment.line == target.line
  end,
}

--- Keys the target points at. Context lines and blank lines have no keys.
---@param file review.FileDiff
---@param line_count integer  -- lines in the buffer with the new text
---@param target review.ToggleTarget
---@return string[]
function M.keys(file, line_count, target)
  if target.type == "file" then
    return keys.of_file(file)
  end
  local out = {}
  for _, segment in ipairs(changes.segments(file, line_count)) do
    if SELECTS[target.type](segment, target) then
      vim.list_extend(out, changes.keys(segment))
    end
  end
  return out
end

return M
