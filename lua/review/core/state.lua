-- Application state. Immutable: every change returns a new table.

local folds = require("review.core.folds")

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
---@field marks review.Marks            -- by line key
---@field comments review.Comment[]
---@field folds review.Folds           -- explorer: user fold choices by change id
---@field fold_default review.FoldDefault
---@field disk_commit string|false     -- commit whose text is on disk (core/modes.lua)
---@field marks_loaded boolean         -- the store was read at least once
---@field contents table<string, table<string, string[]>>  -- new text lines by commit id, then path
---@field buffers table<string, review.BufferState>  -- review files with a buffer, by file key (core/review_buffers.lua)
---@field show_pending? string          -- key of the file to show when its buffer is ready
---@field current? review.FileKey      -- review file in the last focused window (reported by the shell)
---@field show_removed boolean          -- diff: removed blocks are drawn

--- One review file: a revision at a path.
---@class review.FileKey
---@field change_id string
---@field path string

---@class review.BufferState
---@field file review.FileKey
---@field commit_id? string  -- commit whose text the buffer has; nil until the first PrepareBuffer
---@field mode? review.Mode    -- mode of the buffer
---@field loading? string    -- commit whose content is loading

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
    fold_default = folds.INITIAL,
    marks_loaded = false,
    disk_commit = false,
    contents = {},
    buffers = {},
    show_removed = true,
  }
end

return M
