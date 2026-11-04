-- Diff view: file diff → extmark specs for the buffer with the new text. Pure.
-- Added lines get a line highlight. Removed blocks are virtual lines, placed by core/changes.lua.

local changes = require("review.core.changes")

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

---@param segment review.Segment
---@param input review.DiffViewInput
---@return review.ExtmarkSpec
local function segment_mark(segment, input)
  if segment.type == "added" then
    return { row = segment.line - 1, opts = { line_hl_group = "ReviewAdded" } }
  end
  local texts = vim.tbl_map(function(line)
    return line.text
  end, segment.lines)
  return {
    row = segment.line - 1,
    opts = { virt_lines = removed_virt_lines(texts, input.tabstop), virt_lines_above = segment.above },
  }
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
  local marks = vim.tbl_map(function(segment)
    return segment_mark(segment, input)
  end, changes.segments(file, input.line_count))
  return { extmarks = marks, topfill = topfill(marks) }
end

return M
