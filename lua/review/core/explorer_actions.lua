-- Explorer actions: (action, row target) → message. One dispatcher for all explorer row actions.

local msg = require("review.core.msg")

local M = {}

---@alias review.ExplorerTarget review.ExplorerTarget.Revision|review.ExplorerTarget.File

---@class review.ExplorerTarget.Revision
---@field type "revision"
---@field change_id string

---@class review.ExplorerTarget.File
---@field type "file"
---@field change_id string
---@field path string

--- `<CR>`: fold / unfold a revision, open a file.
---@param target review.ExplorerTarget
---@return review.Msg
function M.enter(target)
  if target.type == "revision" then
    return msg.fold_toggled(target.change_id)
  end
  return msg.file_opened(target.change_id, target.path)
end

return M
