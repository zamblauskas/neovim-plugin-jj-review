-- Comment drafts: what a comment key points at → anchor, keys, snippet, input title.
-- One draft rule per selection kind (spec/data-model.md "Comments").

local changes = require("review.core.changes")
local comments = require("review.core.comments")
local lookup = require("review.core.lookup")
local targets = require("review.core.targets")

local M = {}

---@param source review.LoadedSource
---@param fields table
---@return review.CommentDraft
local function draft(source, fields)
  return vim.tbl_extend("force", {
    change_id = source.rev.change_id,
    revision_description = source.rev.description,
    path = source.file.path,
  }, fields)
end

--- Anchors of the lines first..last, top to bottom. Lines outside the hunks have none.
---@param file review.FileDiff
---@param first integer
---@param last integer
---@return string[]
local function line_keys(file, first, last)
  local by_line = {}
  for key, line in pairs(comments.new_side_lines(file)) do
    by_line[line] = key
  end
  local out = {}
  for line = first, last do
    table.insert(out, by_line[line])
  end
  return out
end

---@param path string
---@param first integer
---@param last integer
---@return string
local function lines_title(path, first, last)
  return path .. ":" .. first .. (first == last and "" or "-" .. last)
end

--- A comment on buffer lines: unchanged lines are included.
---@param source review.LoadedSource
---@param first integer
---@param last integer
---@return review.CommentDraft, string
local function lines_draft(source, first, last)
  local anchor = { type = first == last and "line" or "range", side = "+", start_line = first, end_line = last }
  local snippet = table.concat(vim.list_slice(source.lines, first, last), "\n")
  local keys = line_keys(source.file, first, last)
  return draft(source, { anchor = anchor, keys = keys, snippet = snippet }), lines_title(source.file.path, first, last)
end

--- Anchor of segments: a block when every segment is removed; else a line or a range over the placed lines.
---@param segments review.Segment[]
---@return review.CommentAnchor
local function segments_anchor(segments)
  local first, last = segments[1].line, segments[#segments].line
  local all_removed = vim.iter(segments):all(function(segment)
    return segment.type == "removed"
  end)
  if all_removed then
    return { type = "block", side = "-", start_line = first, end_line = last }
  end
  return { type = first == last and "line" or "range", side = "+", start_line = first, end_line = last }
end

--- A comment on changes of the diff: removed and added text, top to bottom; keys of the changes only.
---@param source review.LoadedSource
---@param segments review.Segment[]
---@return review.CommentDraft, string
local function segments_draft(source, segments)
  local anchor = segments_anchor(segments)
  local texts = vim
    .iter(segments)
    :map(function(segment)
      return vim.tbl_map(function(line)
        return line.text
      end, segment.lines)
    end)
    :flatten()
    :totable()
  local keys = vim.iter(segments):map(changes.keys):flatten():totable()
  local title = lines_title(source.file.path, anchor.start_line, anchor.end_line)
  return draft(source, { anchor = anchor, keys = keys, snippet = table.concat(texts, "\n") }),
    title .. (anchor.type == "block" and " (removed)" or "")
end

--- Draft and input title for a comment on the target. Nil if the file is unknown, the new text is not loaded,
--- or the target has no selection.
---@param state review.State
---@param target review.Target
---@return review.CommentDraft?, string?
function M.for_target(state, target)
  local source = lookup.source(state, target.change_id, target.path)
  if not (source and source.lines) then
    return nil
  end
  ---@cast source review.LoadedSource
  local selection = targets.select(source.file, #source.lines, target)
  if not selection then
    return nil
  elseif selection.type == "segments" then
    return segments_draft(source, selection.segments)
  end
  return lines_draft(source, selection.first, selection.last)
end

return M
