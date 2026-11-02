-- Messages: everything that happens is a message to `update`.
-- Results of effects carry the `generation` of the open that asked for them.

local M = {}

---@alias review.Msg
---| review.Msg.Opened
---| review.Msg.Closed
---| review.Msg.RootResolved
---| review.Msg.OpChecked
---| review.Msg.StackLoaded
---| review.Msg.JjFailed

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

---@class review.Msg.JjFailed
---@field type "JjFailed"
---@field generation integer
---@field stderr string

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

---@return review.Msg.JjFailed
function M.jj_failed(generation, stderr)
  return { type = "JjFailed", generation = generation, stderr = stderr }
end

return M
