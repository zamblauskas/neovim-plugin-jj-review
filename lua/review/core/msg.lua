-- Messages: everything that happens is a message to `update`.
-- Results of effects carry the `generation` of the open that asked for them.

local M = {}

---@alias review.Msg
---| review.Msg.Opened
---| review.Msg.Closed
---| review.Msg.Cleared
---| review.Msg.RootResolved
---| review.Msg.OpChecked
---| review.Msg.StackLoaded
---| review.Msg.DiffLoaded
---| review.Msg.JjFailed
---| review.Msg.FoldToggled
---| review.Msg.FileOpened
---| review.Msg.ContentLoaded
---| review.Msg.FileStepped
---| review.Msg.StoreLoaded
---| review.Msg.StoreFailed
---| review.Msg.ToggleRequested
---| review.Msg.UnreviewedStepped

---@class review.Msg.Opened
---@field type "Opened"
---@field cwd string
---@field revset string?

---@class review.Msg.Closed
---@field type "Closed"

--- Delete all marks in the repo (confirmed by the user).
---@class review.Msg.Cleared
---@field type "Cleared"

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

--- Open the file `offset` places after the open file, in the same revision (explorer order).
---@class review.Msg.FileStepped
---@field type "FileStepped"
---@field offset integer

---@class review.Msg.StoreLoaded
---@field type "StoreLoaded"
---@field generation integer
---@field marks review.Marks

---@class review.Msg.StoreFailed
---@field type "StoreFailed"
---@field generation integer
---@field error string

---@class review.Msg.ToggleRequested
---@field type "ToggleRequested"
---@field target review.ToggleTarget
---@field now string  -- ISO 8601 UTC, for new marks

--- Go to the next (`offset` 1) or previous (-1) unreviewed change in the file, from `line`.
---@class review.Msg.UnreviewedStepped
---@field type "UnreviewedStepped"
---@field change_id string
---@field path string
---@field line integer
---@field offset integer

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

---@return review.Msg.Cleared
function M.cleared()
  return { type = "Cleared" }
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

---@param offset integer
---@return review.Msg.FileStepped
function M.file_stepped(offset)
  return { type = "FileStepped", offset = offset }
end

---@return review.Msg.StoreLoaded
function M.store_loaded(generation, marks)
  return { type = "StoreLoaded", generation = generation, marks = marks }
end

---@return review.Msg.StoreFailed
function M.store_failed(generation, error)
  return { type = "StoreFailed", generation = generation, error = error }
end

---@param target review.ToggleTarget
---@param now string
---@return review.Msg.ToggleRequested
function M.toggle_requested(target, now)
  return { type = "ToggleRequested", target = target, now = now }
end

---@return review.Msg.UnreviewedStepped
function M.unreviewed_stepped(change_id, path, line, offset)
  return { type = "UnreviewedStepped", change_id = change_id, path = path, line = line, offset = offset }
end

return M
