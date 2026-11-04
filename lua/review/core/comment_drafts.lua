-- Comment drafts: what a comment key points at → anchor, keys, snippet, input title.

local changes = require("review.core.changes")
local comments = require("review.core.comments")
local lookup = require("review.core.lookup")

local M = {}

---@alias review.CommentTarget
---| { type: "line", change_id: string, path: string, line: integer }
---| { type: "range", change_id: string, path: string, first: integer, last: integer }
---| { type: "block", change_id: string, path: string, line: integer }

---@class review.DraftSource
---@field rev review.Revision
---@field file review.FileDiff
---@field lines string[]  -- new text

---@param source review.DraftSource
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

---@param source review.DraftSource
---@param first integer
---@param last integer
---@return review.CommentDraft, string
local function lines_draft(source, first, last)
  local anchor = { type = first == last and "line" or "range", side = "+", start_line = first, end_line = last }
  local snippet = table.concat(vim.list_slice(source.lines, first, last), "\n")
  local title = source.file.path .. ":" .. first .. (first == last and "" or "-" .. last)
  return draft(source, { anchor = anchor, keys = line_keys(source.file, first, last), snippet = snippet }), title
end

---@param source review.DraftSource
---@param line integer
---@return review.CommentDraft?, string?
local function block_draft(source, line)
  local blocks = vim.tbl_filter(function(segment)
    return segment.type == "removed" and segment.line == line
  end, changes.segments(source.file, #source.lines))
  if #blocks == 0 then
    return nil
  end
  local removed = vim
    .iter(blocks)
    :map(function(b)
      return b.lines
    end)
    :flatten()
    :totable()
  local snippet = table.concat(
    vim.tbl_map(function(l)
      return l.text
    end, removed),
    "\n"
  )
  local keys = vim.iter(blocks):map(changes.keys):flatten():totable()
  local anchor = { type = "block", side = "-", start_line = line, end_line = line }
  return draft(source, { anchor = anchor, keys = keys, snippet = snippet }),
    source.file.path .. ":" .. line .. " (removed)"
end

--- Draft and input title for a comment on the target. Nil if the file is unknown or there is no block.
---@param state review.State
---@param target review.CommentTarget
---@return review.CommentDraft?, string?
function M.for_target(state, target)
  local rev = lookup.revision(state, target.change_id)
  local file = rev and lookup.file(state, rev, target.path)
  local lines = rev and file and lookup.new_lines(state, rev, file)
  if not (rev and file and lines) then
    return nil
  end
  local source = { rev = rev, file = file, lines = lines }
  if target.type == "block" then
    return block_draft(source, target.line)
  end
  return lines_draft(source, target.first or target.line, target.last or target.line)
end

return M
