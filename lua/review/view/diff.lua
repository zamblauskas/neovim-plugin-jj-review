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
---@field gutter_width integer  -- columns before the text (signs, numbers)
---@field marks review.Marks
---@field dim boolean           -- dim reviewed lines
---@field comments review.Placement[]  -- comments shown in this file
---@field icons review.IconConfig

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

---@class review.SegmentState
---@field reviewed integer
---@field total integer

---@param segment review.Segment
---@param marks review.Marks
---@return review.SegmentState
local function segment_state(segment, marks)
  local keys = changes.keys(segment)
  local reviewed = #vim.tbl_filter(function(key)
    return marks[key] ~= nil
  end, keys)
  return { reviewed = reviewed, total = #keys }
end

---@param state review.SegmentState
---@return boolean
local function is_reviewed(state)
  return state.total > 0 and state.reviewed == state.total
end

--- Gutter text of a removed block: the mark icon when reviewed, "3/4" when partly reviewed, else empty.
---@param state review.SegmentState
---@param icons review.IconConfig
---@return string
local function block_prefix(state, icons)
  if is_reviewed(state) then
    return icons.mark
  elseif state.reviewed > 0 then
    return state.reviewed .. "/" .. state.total
  end
  return ""
end

--- Virtual lines of a removed block. Each line starts with a gutter, so the text aligns with the buffer text.
---@param texts string[]
---@param prefix string  -- gutter text of the first line
---@param group string
---@param input review.DiffViewInput
---@return table[]
local function removed_virt_lines(texts, prefix, group, input)
  return vim
    .iter(ipairs(texts))
    :map(function(i, text)
      local gutter = i == 1 and prefix or ""
      local expanded = expand_tabs(text, input.tabstop)
      local pad = math.max(PAD_WIDTH - vim.fn.strdisplaywidth(expanded), 0)
      local gutter_pad = math.max(input.gutter_width - vim.fn.strdisplaywidth(gutter), 0)
      return { { gutter .. string.rep(" ", gutter_pad), "ReviewSign" }, { expanded .. string.rep(" ", pad), group } }
    end)
    :totable()
end

---@param reviewed boolean
---@param input review.DiffViewInput
---@param base string  -- "ReviewAdded" or "ReviewRemoved"
---@return string
local function line_group(reviewed, input, base)
  return (reviewed and input.dim) and base .. "Reviewed" or base
end

---@param segment review.Segment
---@param input review.DiffViewInput
---@return review.ExtmarkSpec
local function added_mark(segment, input)
  local reviewed = is_reviewed(segment_state(segment, input.marks))
  local opts = { line_hl_group = line_group(reviewed, input, "ReviewAdded") }
  if reviewed then
    opts.sign_text, opts.sign_hl_group = input.icons.mark, "ReviewSign"
  end
  return { row = segment.line - 1, opts = opts }
end

---@param segment review.Segment
---@param input review.DiffViewInput
---@return review.ExtmarkSpec
local function removed_mark(segment, input)
  local state = segment_state(segment, input.marks)
  local texts = vim.tbl_map(function(line)
    return line.text
  end, segment.lines)
  local group = line_group(is_reviewed(state), input, "ReviewRemoved")
  local virt_lines = removed_virt_lines(texts, block_prefix(state, input.icons), group, input)
  return {
    row = segment.line - 1,
    opts = { virt_lines = virt_lines, virt_lines_above = segment.above, virt_lines_leftcol = true },
  }
end

---@param segment review.Segment
---@param input review.DiffViewInput
---@return review.ExtmarkSpec
local function segment_mark(segment, input)
  if segment.type == "added" then
    return added_mark(segment, input)
  end
  return removed_mark(segment, input)
end

--- Prefix and highlight of a comment by its status.
---@param status "found"|"outdated"|"orphaned"  -- an orphaned comment is not shown in a file
---@param icons review.IconConfig
---@return string, string
local function comment_style(status, icons)
  if status == "outdated" then
    return icons.warning .. " outdated: ", "ReviewCommentOutdated"
  end
  return icons.comment .. " ", "ReviewComment"
end

--- Comment as virtual lines below its line. The first line has the prefix; the others are indented to match.
---@param placement review.Placement
---@param input review.DiffViewInput
---@return review.ExtmarkSpec
local function comment_mark(placement, input)
  local prefix, group = comment_style(placement.status, input.icons)
  local indent = string.rep(" ", vim.fn.strdisplaywidth(prefix))
  local gutter = string.rep(" ", input.gutter_width)
  local virt_lines = vim
    .iter(ipairs(vim.split(placement.comment.text, "\n", { plain = true })))
    :map(function(i, text)
      return { { gutter }, { (i == 1 and prefix or indent) .. text, group } }
    end)
    :totable()
  local row = math.max(math.min(assert(placement.line, "placed comment"), input.line_count), 1) - 1
  return { row = row, opts = { virt_lines = virt_lines, virt_lines_leftcol = true } }
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
  vim.list_extend(
    marks,
    vim.tbl_map(function(placement)
      return comment_mark(placement, input)
    end, input.comments)
  )
  return { extmarks = marks, topfill = topfill(marks) }
end

return M
