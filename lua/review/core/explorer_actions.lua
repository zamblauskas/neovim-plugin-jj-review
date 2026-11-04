-- Explorer actions: (action, row target) → message. One dispatcher for all explorer row actions.

local msg = require("review.core.msg")

local M = {}

---@alias review.ExplorerTarget review.ExplorerTarget.Revision|review.ExplorerTarget.File|review.ExplorerTarget.Comment

---@class review.ExplorerTarget.Comment
---@field type "comment"
---@field id string

---@class review.ExplorerTarget.Revision
---@field type "revision"
---@field change_id string

---@class review.ExplorerTarget.File
---@field type "file"
---@field change_id string
---@field path string

--- `<CR>`: fold / unfold a revision, open a file. Comment rows: no action.
---@param target review.ExplorerTarget
---@return review.Msg?
function M.enter(target)
  if target.type == "revision" then
    return msg.fold_toggled(target.change_id)
  elseif target.type == "file" then
    return msg.file_opened(target.change_id, target.path)
  end
  return nil
end

--- Delete an orphaned comment row. Other rows: no action.
---@param target review.ExplorerTarget
---@return review.Msg?
function M.delete_comment(target)
  return target.type == "comment" and msg.comment_deleted(target.id) or nil
end

--- Toggle reviewed: the file under the cursor. Other rows: no action.
---@param target review.ExplorerTarget
---@param now string
---@return review.Msg?
function M.toggle_file(target, now)
  if target.type ~= "file" then
    return nil
  end
  return msg.toggle_requested({ type = "file", change_id = target.change_id, path = target.path }, now)
end

--- `jj edit`: the revision of a revision or file row. Comment rows: no action.
---@param target review.ExplorerTarget
---@return review.Msg?
function M.edit(target)
  return target.type ~= "comment" and msg.edit_requested(target.change_id) or nil
end

return M
