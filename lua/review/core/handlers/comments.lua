-- Handlers: write and delete comments.

local comment_drafts = require("review.core.comment_drafts")
local comments = require("review.core.comments")
local effect = require("review.core.effect")
local messages = require("review.core.msg")
local tbl = require("review.lib.tbl")

local M = {}

--- Apply the patch to the state; save it; redraw.
---@param state review.State
---@param patch review.CommentPatch
---@return review.State, review.Effect[]
local function change(state, patch)
  return tbl.with(state, { comments = comments.apply(state.comments, patch) }),
    {
      effect.save_comments(state.generation, assert(state.root, "root not resolved"), patch),
      effect.render_diff(),
      effect.render_explorer(),
    }
end

---@param state review.State
---@param msg review.Msg.CommentRequested
---@return review.State, review.Effect[]
function M.CommentRequested(state, msg)
  local draft, title = comment_drafts.for_target(state, msg.target)
  if not (draft and title) then
    return state, {}
  end
  return state, { effect.open_comment_input(title, draft) }
end

---@param state review.State
---@param msg review.Msg.CommentSubmitted
---@return review.State, review.Effect[]
function M.CommentSubmitted(state, msg)
  if vim.trim(msg.text) == "" then
    return state, {}
  end
  local comment = vim.tbl_extend("force", msg.draft, { id = msg.id, text = msg.text, created = msg.now })
  return change(state, { add = { comment }, remove = {} })
end

---@param state review.State
---@param msg review.Msg.CommentDeleted
---@return review.State, review.Effect[]
function M.CommentDeleted(state, msg)
  return change(state, { add = {}, remove = { msg.id } })
end

---@param state review.State
---@param msg review.Msg.CommentDeleteRequested
---@return review.State, review.Effect[]
function M.CommentDeleteRequested(state, msg)
  local at_line = vim.tbl_filter(function(p)
    return p.line == msg.line
  end, comments.in_file(comments.place(state), msg.change_id, msg.path))
  if #at_line == 0 then
    return state, {}
  end
  return M.CommentDeleted(state, messages.comment_deleted(at_line[1].comment.id))
end

return M
