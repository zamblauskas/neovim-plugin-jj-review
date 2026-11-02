-- Plugin configuration: defaults, merge, validation.

local M = {}

---@class review.Config
---@field revset string
---@field explorer_width integer
---@field keymaps review.KeymapConfig

---@class review.KeymapConfig
---@field open string|false
---@field close string|false

---@type review.Config
M.defaults = {
  revset = "(trunk()..@)::",
  explorer_width = 40,
  keymaps = {
    open = "<leader>jvv",
    close = "<leader>jvq",
  },
}

---@param config review.Config
local function validate(config)
  vim.validate("revset", config.revset, "string")
  vim.validate("explorer_width", config.explorer_width, "number")
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
