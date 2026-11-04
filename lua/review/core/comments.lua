-- Comments: data, patches, and placement in the stack (spec/data-model.md "Comment lookup").
-- A comment is placed at most once:
--   found:    one of its keys is in a diff of the stack → at the last found line (end of the anchor);
--   outdated: no key found, but its revision is in the stack and has the file → at `start_line`;
--   orphaned: else. Listed in the explorer.
-- A comment made on lines outside the hunks has no keys. It is "found" at `start_line` while its file is there.

local changes = require("review.core.changes")
local counts = require("review.core.counts")
local lookup = require("review.core.lookup")

local M = {}

---@class review.CommentAnchor
---@field type "line"|"range"|"block"
---@field side "+"|"-"
---@field start_line integer
---@field end_line integer

---@class review.CommentDraft
---@field anchor review.CommentAnchor
---@field change_id string
---@field revision_description string
---@field path string
---@field keys string[]
---@field snippet string

---@class review.Comment: review.CommentDraft
---@field id string
---@field text string
---@field created string

---@class review.CommentPatch
---@field add review.Comment[]
---@field remove string[]  -- ids

---@class review.Placement
---@field comment review.Comment
---@field status "found"|"outdated"|"orphaned"
---@field change_id? string  -- found / outdated: revision of the file it is shown in
---@field path? string
---@field line? integer      -- 1-based buffer line; the view clamps it

--- Line count to place blocks when the new text is not loaded: a block at the end stays past the end.
local UNKNOWN_LINE_COUNT = math.huge

--- New comment list with the patch applied: removed ids out, added comments replace the same id or append.
---@param comments review.Comment[]
---@param patch review.CommentPatch
---@return review.Comment[]
function M.apply(comments, patch)
  local gone = {}
  for _, id in ipairs(patch.remove) do
    gone[id] = true
  end
  for _, comment in ipairs(patch.add) do
    gone[comment.id] = true
  end
  local kept = vim.tbl_filter(function(comment)
    return not gone[comment.id]
  end, comments)
  return vim.list_extend(kept, patch.add)
end

---@param out table<string, integer>
---@param hunk review.Hunk
local function add_new_side_anchors(out, hunk)
  local line_no = hunk.new_count == 0 and hunk.new_start + 1 or hunk.new_start
  for _, line in ipairs(hunk.lines) do
    if line.kind ~= "-" then
      if line.anchor then
        out[line.anchor] = line_no
      end
      line_no = line_no + 1
    end
  end
end

--- Buffer line of each anchor key of the file. Removed lines are at the line their block attaches to.
---@param file review.FileDiff
---@param line_count integer
---@return table<string, integer>
function M.anchor_lines(file, line_count)
  local out = {}
  for _, hunk in ipairs(file.hunks) do
    add_new_side_anchors(out, hunk)
  end
  for _, segment in ipairs(changes.segments(file, line_count)) do
    if segment.type == "removed" then
      for _, key in ipairs(changes.keys(segment)) do
        out[key] = segment.line
      end
    end
  end
  return out
end

--- Lines in the buffer with the new text, or UNKNOWN_LINE_COUNT when it is not loaded.
---@param state review.State
---@param rev review.Revision
---@param file review.FileDiff
---@return integer
local function line_count(state, rev, file)
  local lines = lookup.new_lines(state, rev, file)
  return lines and #lines or UNKNOWN_LINE_COUNT
end

---@class review.FileAnchors
---@field rev review.Revision
---@field file review.FileDiff
---@field lines table<string, integer>

--- Anchor lines of every file in the stack.
---@param state review.State
---@param revisions review.Revision[]
---@return review.FileAnchors[]
local function stack_anchors(state, revisions)
  local out = {}
  for _, rev in ipairs(revisions) do
    for _, file in ipairs(state.diffs[rev.commit_id] or {}) do
      table.insert(out, { rev = rev, file = file, lines = M.anchor_lines(file, line_count(state, rev, file)) })
    end
  end
  return out
end

--- Last line of the comment's keys in the file, or nil if no key is there.
---@param comment review.Comment
---@param anchors review.FileAnchors
---@return integer?
local function found_line(comment, anchors)
  local found = vim
    .iter(comment.keys)
    :map(function(key)
      return anchors.lines[key]
    end)
    :totable()
  return #found > 0 and math.max(unpack(found)) or nil
end

---@param comment review.Comment
---@param all review.FileAnchors[]
---@return review.Placement?
local function find(comment, all)
  for _, anchors in ipairs(all) do
    local line = found_line(comment, anchors)
    if line then
      return {
        comment = comment,
        status = "found",
        change_id = anchors.rev.change_id,
        path = anchors.file.path,
        line = line,
      }
    end
  end
  return nil
end

---@param state review.State
---@param comment review.Comment
---@return review.Placement
local function by_line_number(state, comment)
  local rev = lookup.revision(state, comment.change_id)
  if not (rev and lookup.file(state, rev, comment.path)) then
    return { comment = comment, status = "orphaned" }
  end
  local status = #comment.keys == 0 and "found" or "outdated"
  return {
    comment = comment,
    status = status,
    change_id = rev.change_id,
    path = comment.path,
    line = comment.anchor.start_line,
  }
end

--- Placement of every comment. Empty while the stack is not ok or a diff is loading.
---@param state review.State
---@return review.Placement[]
function M.place(state)
  if state.stack.type ~= "ok" or not counts.stack(state.stack.revisions, state.diffs, {}) then
    return {}
  end
  local all = stack_anchors(state, state.stack.revisions)
  return vim.tbl_map(function(comment)
    return find(comment, all) or by_line_number(state, comment)
  end, state.comments)
end

--- Placements shown in one file.
---@param placements review.Placement[]
---@param change_id string
---@param path string
---@return review.Placement[]
function M.in_file(placements, change_id, path)
  return vim.tbl_filter(function(p)
    return p.change_id == change_id and p.path == path
  end, placements)
end

return M
