-- Diff view: file diff → extmark specs for the buffer with the new text. Pure.
-- Added lines get a whole-line range highlight (not line_hl_group: Neovim 0.12 paints it over every range
-- highlight of the line, whatever the priority). Removed blocks are virtual lines, placed by core/changes.lua.
-- A removed line paired with the added line that replaced it gets its changed tokens highlighted (core/word_diff.lua).

local changes = require("review.core.changes")
local word_diff = require("review.core.word_diff")

local M = {}

--- Virtual lines do not wrap. Padding makes the background cover the window width.
local PAD_WIDTH = 400

---@class review.ExtmarkSpec
---@field row integer   -- 0-based
---@field col? integer  -- 0-based byte column; 0 when nil
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
---@field show_removed boolean  -- draw removed blocks
---@field inline boolean        -- highlight the changed tokens of paired lines
---@field comments review.Placement[]  -- comments shown in this file
---@field icons review.IconConfig

--- Text with tabs expanded, starting at display column `col`; and the display column after it.
---@param text string
---@param tabstop integer
---@param col integer
---@return string, integer
local function expand_tabs(text, tabstop, col)
  local out = {}
  for chunk, tab in text:gmatch("([^\t]*)(\t?)") do
    col = col + vim.fn.strdisplaywidth(chunk)
    local spaces = tab == "" and 0 or tabstop - col % tabstop
    col = col + spaces
    table.insert(out, chunk .. string.rep(" ", spaces))
  end
  return table.concat(out), col
end

---@alias review.InlineRanges table<review.Segment, review.Range[]|review.Range[][]>  -- added: ranges; removed: per line

--- Pair the k-th line of the removed block at `i` with the k-th added line after it, by position.
---@param segments review.Segment[]
---@param i integer
---@param out review.InlineRanges
local function pair_block(segments, i, out)
  local block = segments[i]
  out[block] = {}
  for k, line in ipairs(block.lines) do
    local added = segments[i + k]
    if not (added and added.type == "added" and added.line == block.next_line + k - 1) then
      return
    end
    local ranges = word_diff.ranges(line.text, added.lines[1].text)
    if ranges then
      out[block][k], out[added] = ranges.old, ranges.new
    end
  end
end

--- Changed token ranges by segment. Empty when intra-line highlights are off.
---@param segments review.Segment[]
---@param input review.DiffViewInput
---@return review.InlineRanges
local function inline_ranges(segments, input)
  local out = {}
  for i, segment in ipairs(segments) do
    if input.inline and segment.type == "removed" then
      pair_block(segments, i, out)
    end
  end
  return out
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

--- Where a removed line changes highlight: { byte end (exclusive), group } pairs, left to right.
---@param ranges review.Range[]
---@param group string
---@param length integer
---@return { [1]: integer, [2]: string }[]
local function cuts(ranges, group, length)
  local out = {}
  for _, range in ipairs(ranges) do
    table.insert(out, { range.col, group })
    table.insert(out, { range.end_col, "ReviewRemovedText" })
  end
  table.insert(out, { length, group })
  return out
end

--- Chunks of a removed line: text inside the ranges in `ReviewRemovedText`, the rest in `group`, then padding.
---@param text string
---@param ranges review.Range[]
---@param group string
---@param tabstop integer
---@return table[]
local function line_chunks(text, ranges, group, tabstop)
  local chunks, pos, col = {}, 0, 0
  for _, cut in ipairs(cuts(ranges, group, #text)) do
    local stop, chunk_group = cut[1], cut[2]
    if stop > pos then
      local expanded
      expanded, col = expand_tabs(text:sub(pos + 1, stop), tabstop, col)
      table.insert(chunks, { expanded, chunk_group })
      pos = stop
    end
  end
  table.insert(chunks, { string.rep(" ", math.max(PAD_WIDTH - col, 0)), group })
  return chunks
end

--- Virtual lines of a removed block. Each line starts with a gutter, so the text aligns with the buffer text.
---@param texts string[]
---@param ranges review.Range[][]  -- by line index
---@param prefix string  -- gutter text of the first line
---@param group string
---@param input review.DiffViewInput
---@return table[]
local function removed_virt_lines(texts, ranges, prefix, group, input)
  return vim
    .iter(ipairs(texts))
    :map(function(i, text)
      local gutter = i == 1 and prefix or ""
      local gutter_pad = math.max(input.gutter_width - vim.fn.strdisplaywidth(gutter), 0)
      local chunks = line_chunks(text, ranges[i] or {}, group, input.tabstop)
      return vim.list_extend({ { gutter .. string.rep(" ", gutter_pad), "ReviewSign" } }, chunks)
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

--- A dimmed reviewed segment shows no changed tokens.
---@param reviewed boolean
---@param input review.DiffViewInput
---@return boolean
local function show_inline(reviewed, input)
  return not (reviewed and input.dim)
end

--- Extmarks of the changed tokens of an added line.
---@param row integer
---@param ranges review.Range[]
---@return review.ExtmarkSpec[]
local function added_text_marks(row, ranges)
  return vim.tbl_map(function(range)
    return { row = row, col = range.col, opts = { end_col = range.end_col, hl_group = "ReviewAddedText" } }
  end, ranges)
end

--- Priority of the line highlight: below the token highlights (default priority), and below syntax.
local LINE_PRIORITY = 50

---@param segment review.Segment
---@param input review.DiffViewInput
---@param ranges review.Range[]
---@return review.ExtmarkSpec[]
local function added_marks(segment, input, ranges)
  local reviewed = is_reviewed(segment_state(segment, input.marks))
  local row = segment.line - 1
  local opts = {
    end_row = row + 1,
    end_col = 0,
    hl_eol = true,
    hl_group = line_group(reviewed, input, "ReviewAdded"),
    priority = LINE_PRIORITY,
  }
  if reviewed then
    opts.sign_text, opts.sign_hl_group = input.icons.mark, "ReviewSign"
  end
  return vim.list_extend(
    { { row = row, opts = opts } },
    show_inline(reviewed, input) and added_text_marks(row, ranges) or {}
  )
end

---@param segment review.Segment
---@param input review.DiffViewInput
---@param ranges review.Range[][]
---@return review.ExtmarkSpec
local function removed_mark(segment, input, ranges)
  local state = segment_state(segment, input.marks)
  local texts = vim.tbl_map(function(line)
    return line.text
  end, segment.lines)
  local reviewed = is_reviewed(state)
  local group = line_group(reviewed, input, "ReviewRemoved")
  local shown = show_inline(reviewed, input) and ranges or {}
  local virt_lines = removed_virt_lines(texts, shown, block_prefix(state, input.icons), group, input)
  return {
    row = segment.line - 1,
    opts = { virt_lines = virt_lines, virt_lines_above = segment.above, virt_lines_leftcol = true },
  }
end

--- None for a removed block when removed blocks are hidden.
---@param segment review.Segment
---@param input review.DiffViewInput
---@param inline review.InlineRanges
---@return review.ExtmarkSpec[]
local function segment_marks(segment, input, inline)
  if segment.type == "added" then
    return added_marks(segment, input, inline[segment] or {})
  elseif not input.show_removed then
    return {}
  end
  return { removed_mark(segment, input, inline[segment] or {}) }
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
  local segments = changes.segments(file, input.line_count)
  local inline = inline_ranges(segments, input)
  local marks = vim
    .iter(segments)
    :map(function(segment)
      return segment_marks(segment, input, inline)
    end)
    :flatten()
    :totable()
  vim.list_extend(
    marks,
    vim.tbl_map(function(placement)
      return comment_mark(placement, input)
    end, input.comments)
  )
  return { extmarks = marks, topfill = topfill(marks) }
end

return M
