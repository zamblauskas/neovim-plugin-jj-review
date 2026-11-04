-- Plugin configuration: defaults, merge, validation.

local M = {}

---@class review.Config
---@field revset string
---@field explorer_width integer
---@field max_parallel_jj integer
---@field dim_reviewed boolean
---@field keymaps review.KeymapConfig

---@class review.KeymapConfig
---@field open string|false
---@field close string|false
---@field toggle string|false        -- diff buffer: line or visual range
---@field toggle_block string|false  -- diff buffer: removed block at the cursor line
---@field toggle_file string|false   -- diff buffer and explorer: file
---@field comment string|false         -- diff buffer: comment on the line or visual range
---@field comment_block string|false   -- diff buffer: comment on the removed block at the cursor line
---@field delete_comment string|false  -- diff buffer: comment at the cursor line; explorer: orphaned comment
---@field next_unreviewed string|false  -- diff buffer: next unreviewed change in the file
---@field prev_unreviewed string|false  -- diff buffer: previous unreviewed change in the file
---@field next_file string|false  -- diff buffer: next file in the revision
---@field prev_file string|false  -- diff buffer: previous file in the revision

---@type review.Config
M.defaults = {
  revset = "(trunk()..@)::",
  explorer_width = 40,
  max_parallel_jj = 4,
  dim_reviewed = true,
  keymaps = {
    open = "<leader>jvv",
    close = "<leader>jvq",
    toggle = "<leader>rr",
    toggle_block = "<leader>rR",
    toggle_file = "<leader>rf",
    comment = "<leader>rc",
    comment_block = "<leader>rC",
    delete_comment = "<leader>rx",
    next_unreviewed = "]r",
    prev_unreviewed = "[r",
    next_file = "]R",
    prev_file = "[R",
  },
}

---@param config review.Config
local function validate(config)
  vim.validate("revset", config.revset, "string")
  vim.validate("explorer_width", config.explorer_width, "number")
  vim.validate("max_parallel_jj", config.max_parallel_jj, "number")
  vim.validate("dim_reviewed", config.dim_reviewed, "boolean")
  vim.validate("keymaps", config.keymaps, "table")
  for name, key in pairs(config.keymaps) do
    vim.validate("keymaps." .. name, key, { "string", "boolean" })
  end
end

--- Merge user options over the defaults. Errors on invalid values.
---@param opts? table
---@return review.Config
function M.resolve(opts)
  local config = vim.tbl_deep_extend("force", M.defaults, opts or {})
  validate(config)
  return config
end

return M
