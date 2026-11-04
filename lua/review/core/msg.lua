-- Messages: everything that happens is a message to `update`.
-- Results of effects carry the `generation` of the open that asked for them.

local M = {}

---@alias review.Msg
---| review.Msg.Opened
---| review.Msg.Closed
---| review.Msg.RootResolved
---| review.Msg.OpChecked
---| review.Msg.StackLoaded
---| review.Msg.DiffLoaded
---| review.Msg.JjFailed
---| review.Msg.FoldToggled
---| review.Msg.FileOpened
---| review.Msg.ContentLoaded

---@class review.Msg.Opened
---@field type "Opened"
---@field cwd string
---@field revset string?

---@class review.Msg.Closed
---@field type "Closed"

---@class review.Msg.RootResolved
---@field type "RootResolved"
---@field generation integer
---@field root string

---@class review.Msg.OpChecked
---@field type "OpChecked"
---@field generation integer
---@field op_id string

---@class review.Msg.StackLoaded
---@field type "StackLoaded"
---@field generation integer
---@field revisions review.Revision[]

---@class review.Msg.DiffLoaded
---@field type "DiffLoaded"
---@field generation integer
---@field commit_id string
---@field files review.FileDiff[]

---@class review.Msg.JjFailed
---@field type "JjFailed"
---@field generation integer
---@field stderr string

---@class review.Msg.FoldToggled
---@field type "FoldToggled"
---@field change_id string

---@class review.Msg.FileOpened
---@field type "FileOpened"
---@field change_id string
---@field path string

---@class review.Msg.ContentLoaded
---@field type "ContentLoaded"
---@field generation integer
---@field commit_id string
---@field path string
---@field lines string[]

---@param cwd string
---@param revset string?
---@return review.Msg.Opened
function M.opened(cwd, revset)
  return { type = "Opened", cwd = cwd, revset = revset }
end

---@return review.Msg.Closed
function M.closed()
  return { type = "Closed" }
end

---@return review.Msg.RootResolved
function M.root_resolved(generation, root)
  return { type = "RootResolved", generation = generation, root = root }
end

---@return review.Msg.OpChecked
function M.op_checked(generation, op_id)
  return { type = "OpChecked", generation = generation, op_id = op_id }
end

---@return review.Msg.StackLoaded
function M.stack_loaded(generation, revisions)
  return { type = "StackLoaded", generation = generation, revisions = revisions }
end

---@return review.Msg.DiffLoaded
function M.diff_loaded(generation, commit_id, files)
  return { type = "DiffLoaded", generation = generation, commit_id = commit_id, files = files }
end

---@return review.Msg.JjFailed
function M.jj_failed(generation, stderr)
  return { type = "JjFailed", generation = generation, stderr = stderr }
end

---@param change_id string
---@return review.Msg.FoldToggled
function M.fold_toggled(change_id)
  return { type = "FoldToggled", change_id = change_id }
end

---@param change_id string
---@param path string
---@return review.Msg.FileOpened
function M.file_opened(change_id, path)
  return { type = "FileOpened", change_id = change_id, path = path }
end

---@return review.Msg.ContentLoaded
function M.content_loaded(generation, commit_id, path, lines)
  return { type = "ContentLoaded", generation = generation, commit_id = commit_id, path = path, lines = lines }
end

return M
