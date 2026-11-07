-- Targets: what a review key points at (toggle, comment) → a selection (spec/data-model.md "Targets and
-- selections"). A selection is lines of the buffer, or segments of the diff. Toggle takes the keys of either;
-- a comment is drafted per kind.

local changes = require("review.core.changes")
local keys = require("review.core.keys")

local M = {}

---@alias review.Target
---| { type: "line", change_id: string, path: string, line: integer }
---| { type: "range", change_id: string, path: string, first: integer, last: integer }
---| { type: "block", change_id: string, path: string, line: integer }
---| { type: "hunk", change_id: string, path: string, line: integer }
---| { type: "file", change_id: string, path: string }

---@alias review.Selection
---| { type: "lines", first: integer, last: integer, blocks: boolean }  -- buffer lines of the new text, unchanged lines included; `blocks`: with the removed blocks attached to them
---| { type: "segments", segments: review.Segment[] }   -- changes of the diff; never empty

--- Segments a target of each structural type selects (Strategy).
---@type table<string, fun(file: review.FileDiff, segments: review.Segment[], target: table): review.Segment[]>
local SEGMENTS_OF = {
  block = function(_, segments, target)
    return vim.tbl_filter(function(segment)
      return segment.type == "removed" and segment.line == target.line
    end, segments)
  end,
  hunk = function(file, segments, target)
    local index = changes.hunk_at(file, segments, target.line)
    return index and changes.of_hunk(segments, index) or {}
  end,
}

--- The selection of the target. Nil for a file target, and for a block or hunk target with no segments.
---@param file review.FileDiff
---@param line_count integer  -- lines in the buffer with the new text
---@param target review.Target
---@return review.Selection?
function M.select(file, line_count, target)
  if target.type == "line" then
    return { type = "lines", first = target.line, last = target.line, blocks = false }
  elseif target.type == "range" then
    return { type = "lines", first = target.first, last = target.last, blocks = true }
  elseif target.type == "file" then
    return nil
  end
  local segments = SEGMENTS_OF[target.type](file, changes.segments(file, line_count), target)
  return #segments > 0 and { type = "segments", segments = segments } or nil
end

--- Segments of the selection: its segments, or the ones placed on its lines (blocks only when included).
---@param file review.FileDiff
---@param line_count integer
---@param selection review.Selection
---@return review.Segment[]
function M.segments(file, line_count, selection)
  if selection.type == "segments" then
    return selection.segments
  end
  return vim.tbl_filter(function(segment)
    local on_lines = segment.line >= selection.first and segment.line <= selection.last
    return on_lines and (selection.blocks or segment.type == "added")
  end, changes.segments(file, line_count))
end

--- Keys the target points at. Context lines and blank lines have no keys.
---@param file review.FileDiff
---@param line_count integer
---@param target review.Target
---@return string[]
function M.keys(file, line_count, target)
  if target.type == "file" then
    return keys.of_file(file)
  end
  local selection = M.select(file, line_count, target)
  if not selection then
    return {}
  end
  return vim.iter(M.segments(file, line_count, selection)):map(changes.keys):flatten():totable()
end

return M
