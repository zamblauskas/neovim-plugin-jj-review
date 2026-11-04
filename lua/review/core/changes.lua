-- Changes of a file diff, placed on the lines of the buffer with the new text.
-- One placement for the view, toggle targets and navigation:
--   added line: on its new line;
--   removed block: above the next real line; at the end of the file, below the last line;
--   in a deleted or emptied file (one empty line), below that line.

local M = {}

---@class review.Segment
---@field type "added"|"removed"
---@field line integer              -- 1-based buffer line: the added line, or the line a block attaches to
---@field above boolean             -- removed block: shown above `line` (else below)
---@field lines review.DiffLine[]   -- one line for "added"; the block for "removed"
---@field next_line? integer        -- removed block: new line after the block (before clamping)

---@class review.PlaceContext
---@field line_count integer
---@field empty boolean  -- the new text is empty

--- Line a removed block attaches to, and whether it is above that line.
---@param next_line integer  -- 1-based new line after the block
---@param ctx review.PlaceContext
---@return integer, boolean
local function block_place(next_line, ctx)
  if ctx.empty then
    return 1, false
  elseif next_line > ctx.line_count then
    return math.max(ctx.line_count, 1), false
  end
  return next_line, true
end

--- First new line of the hunk. A hunk without new lines starts after `new_start`.
---@param hunk review.Hunk
---@return integer
local function first_new_line(hunk)
  return hunk.new_count == 0 and hunk.new_start + 1 or hunk.new_start
end

--- Add a removed line to the open block before `line_no`, or start a new block.
---@param out review.Segment[]
---@param line review.DiffLine
---@param line_no integer
---@param ctx review.PlaceContext
local function add_removed(out, line, line_no, ctx)
  local last = out[#out]
  if last and last.type == "removed" and last.next_line == line_no then
    table.insert(last.lines, line)
    return
  end
  local place, above = block_place(line_no, ctx)
  table.insert(out, { type = "removed", line = place, above = above, lines = { line }, next_line = line_no })
end

---@param hunk review.Hunk
---@param ctx review.PlaceContext
---@param out review.Segment[]
local function hunk_segments(hunk, ctx, out)
  local line_no = first_new_line(hunk)
  for _, line in ipairs(hunk.lines) do
    if line.kind == "-" then
      add_removed(out, line, line_no, ctx)
    else
      if line.kind == "+" then
        table.insert(out, { type = "added", line = line_no, above = false, lines = { line } })
      end
      line_no = line_no + 1
    end
  end
end

--- The new text is empty: the file is deleted, or a hunk ends the new text at line 0.
---@param file review.FileDiff
---@return boolean
local function new_text_empty(file)
  return file.status == "deleted"
    or vim.iter(file.hunks):any(function(hunk)
      return hunk.new_start == 0 and hunk.new_count == 0
    end)
end

--- Segments of the file, top to bottom. A binary file has none.
---@param file review.FileDiff
---@param line_count integer  -- lines in the buffer with the new text
---@return review.Segment[]
function M.segments(file, line_count)
  local ctx, out = { line_count = line_count, empty = new_text_empty(file) }, {}
  if not file.binary then
    for _, hunk in ipairs(file.hunks) do
      hunk_segments(hunk, ctx, out)
    end
  end
  return out
end

--- Keys of the reviewable lines of a segment.
---@param segment review.Segment
---@return string[]
function M.keys(segment)
  local out = {}
  for _, line in ipairs(segment.lines) do
    if line.key then
      table.insert(out, line.key)
    end
  end
  return out
end

--- Buffer line of the first change. 1 when the file has no changes.
---@param file review.FileDiff
---@param line_count integer
---@return integer
function M.first_line(file, line_count)
  local first = M.segments(file, line_count)[1]
  return first and first.line or 1
end

return M
