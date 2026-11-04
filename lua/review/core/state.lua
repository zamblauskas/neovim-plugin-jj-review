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
---@field diffs table<string, review.FileDiff[]>  -- by commit id
---@field marks table<string, table>   -- by line key (v0.3)
---@field comments table[]             -- (v0.5)
---@field folds review.Folds           -- explorer: user fold choices by change id
---@field contents table<string, table<string, string[]>>  -- new text lines by commit id, then path
---@field open_file? review.OpenFile    -- file in the diff window

---@class review.OpenFile
---@field change_id string
---@field path string

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
    folds = {},
    contents = {},
  }
end

return M
