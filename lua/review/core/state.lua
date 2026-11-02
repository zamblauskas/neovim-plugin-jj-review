-- Application state. Immutable: every change returns a new table.

local M = {}

---@class review.State
---@field config review.Config
---@field open boolean
---@field generation integer          -- increments on each open; results of older opens are dropped
---@field cwd string?
---@field root string?
---@field revset string
---@field op_id string?
---@field stack review.Stack
---@field diffs table<string, table>   -- by commit id (v0.2)
---@field marks table<string, table>   -- by line key (v0.3)
---@field comments table[]             -- (v0.5)

---@param config review.Config
---@return review.State
function M.initial(config)
  return {
    config = config,
    open = false,
    generation = 0,
    revset = config.revset,
    stack = { type = "loading" },
    diffs = {},
    marks = {},
    comments = {},
  }
end

return M
