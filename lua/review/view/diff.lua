-- Diff view: file diff → extmark specs for the buffer with the new text. Pure.
-- Added lines get a line highlight. Removed blocks are virtual lines:
--   above the next real line; at the end of the file, below the last line;
--   in a deleted or emptied file (one empty line), below that line.

local M = {}

--- Virtual lines do not wrap. Padding makes the background cover the window width.
local PAD_WIDTH = 400

---@class review.ExtmarkSpec
---@field row integer  -- 0-based
---@field opts vim.api.keyset.set_extmark

---@class review.DiffView
---@field extmarks review.ExtmarkSpec[]
---@field topfill integer  -- virtual lines above the first line

---@class review.DiffViewInput
---@field line_count integer
---@field tabstop integer

---@class review.DiffViewContext: review.DiffViewInput
---@field empty boolean  -- the new text is empty (deleted or emptied file)

---@param text string
---@param tabstop integer
---@return string
local function expand_tabs(text, tabstop)
  local col, out = 0, {}
  for chunk, tab in text:gmatch("([^\t]*)(\t?)") do
    col = col + vim.fn.strdisplaywidth(chunk)
    local spaces = tab == "" and 0 or tabstop - col % tabstop
    col = col + spaces
    table.insert(out, chunk .. string.rep(" ", spaces))
  end
  return table.concat(out)
end

---@param texts string[]
---@param tabstop integer
---@return table[]  virt_lines
local function removed_virt_lines(texts, tabstop)
  return vim.tbl_map(function(text)
    local expanded = expand_tabs(text, tabstop)
    local pad = math.max(PAD_WIDTH - vim.fn.strdisplaywidth(expanded), 0)
    return { { expanded .. string.rep(" ", pad), "ReviewRemoved" } }
  end, texts)
end

--- Row of a removed block, and whether it is above that row. Rules at the top of this file.
---@param next_line integer  -- 1-based new line after the block
---@param ctx review.DiffViewContext
---@return integer, boolean
local function block_position(next_line, ctx)
  if ctx.empty then
    return 0, false
  elseif next_line > ctx.line_count then
    return ctx.line_count - 1, false
  end
  return next_line - 1, true
end

---@alias review.DiffSegment
---| { type: "added", line: integer }
---| { type: "removed", texts: string[], next_line: integer }

--- First new line of the hunk. A hunk without new lines starts after `new_start`.
---@param hunk review.Hunk
---@return integer
local function first_new_line(hunk)
  return hunk.new_count == 0 and hunk.new_start + 1 or hunk.new_start
end

--- Add a removed line to the open block before `line_no`, or start a new block.
---@param out review.DiffSegment[]
---@param text string
---@param line_no integer
local function add_removed(out, text, line_no)
  local last = out[#out]
  if last and last.type == "removed" and last.next_line == line_no then
    table.insert(last.texts, text)
  else
    table.insert(out, { type = "removed", texts = { text }, next_line = line_no })
  end
end

--- Group hunk lines into added lines and removed blocks, with new line numbers.
---@param hunk review.Hunk
---@return review.DiffSegment[]
local function segments(hunk)
  local out, line_no = {}, first_new_line(hunk)
  for _, line in ipairs(hunk.lines) do
    if line.kind == "-" then
      add_removed(out, line.text, line_no)
    else
      if line.kind == "+" then
        table.insert(out, { type = "added", line = line_no })
      end
      line_no = line_no + 1
    end
  end
  return out
end

---@param segment review.DiffSegment
---@param ctx review.DiffViewContext
---@return review.ExtmarkSpec
local function segment_mark(segment, ctx)
  if segment.type == "added" then
    return { row = segment.line - 1, opts = { line_hl_group = "ReviewAdded" } }
  end
  local row, above = block_position(segment.next_line, ctx)
  return { row = row, opts = { virt_lines = removed_virt_lines(segment.texts, ctx.tabstop), virt_lines_above = above } }
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

---@param marks review.ExtmarkSpec[]
---@return integer
local function topfill(marks)
  local count = 0
  for _, mark in ipairs(marks) do
    if mark.row == 0 and mark.opts.virt_lines_above then
      count = count + #mark.opts.virt_lines
    end
  end
  return count
end

---@param file review.FileDiff
---@param input review.DiffViewInput
---@return review.DiffView
function M.render(file, input)
  if file.binary then
    return { extmarks = {}, topfill = 0 }
  end
  local ctx = vim.tbl_extend("force", input, { empty = new_text_empty(file) })
  local marks = {}
  for _, hunk in ipairs(file.hunks) do
    for _, segment in ipairs(segments(hunk)) do
      table.insert(marks, segment_mark(segment, ctx))
    end
  end
  return { extmarks = marks, topfill = topfill(marks) }
end

return M
