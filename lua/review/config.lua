-- Plugin configuration: defaults, merge, validation.

local M = {}

---@class review.Config
---@field revset string
---@field explorer_width integer
---@field max_parallel_jj integer
---@field dim_reviewed boolean
---@field inline_diff boolean
---@field keymaps review.KeymapConfig
---@field icons review.IconConfig

--- A key set to false is not mapped.
---@class review.KeymapConfig
---@field open string|false            -- global: :Review
---@field close string|false           -- global: :Review close
---@field enter string|false           -- explorer: fold a revision, open a file
---@field quit string|false            -- explorer: close the review
---@field help string|false            -- explorer: show the keymaps
---@field edit string|false            -- explorer: make the revision under the cursor the working copy
---@field toggle string|false          -- diff buffer: line or visual range
---@field toggle_block string|false    -- diff buffer: removed block at the cursor line
---@field toggle_hunk string|false     -- diff buffer: hunk at the cursor line
---@field toggle_file string|false     -- diff buffer and explorer: file
---@field comment string|false         -- diff buffer: comment on the line or visual range
---@field comment_block string|false   -- diff buffer: comment on the removed block at the cursor line
---@field comment_hunk string|false    -- diff buffer: comment on the hunk at the cursor line
---@field delete_comment string|false  -- diff buffer: comment at the cursor line; explorer: orphaned comment
---@field next_unreviewed string|false -- diff buffer: next unreviewed change in the file
---@field prev_unreviewed string|false -- diff buffer: previous unreviewed change in the file
---@field next_hunk string|false       -- diff buffer: next hunk in the file
---@field prev_hunk string|false       -- diff buffer: previous hunk in the file
---@field next_file string|false       -- diff buffer: next file in the revision
---@field prev_file string|false       -- diff buffer: previous file in the revision
---@field toggle_removed string|false  -- diff buffer: show or hide the removed blocks

---@class review.IconConfig
---@field reviewed string      -- explorer: file or revision fully reviewed
---@field comment string       -- explorer and diff: comment
---@field warning string       -- explorer and diff: outdated or orphaned comment
---@field working_copy string  -- explorer: revision is @
---@field mark string          -- diff: reviewed line (sign) and reviewed block

---@type review.Config
M.defaults = {
  revset = "(trunk()..@)::",
  explorer_width = 40,
  max_parallel_jj = 4,
  dim_reviewed = true,
  inline_diff = true,
  keymaps = {
    open = "<leader>jvv",
    close = "<leader>jvq",
    enter = "<CR>",
    quit = "q",
    help = "?",
    edit = "<leader>re",
    toggle = "<leader>rr",
    toggle_block = "<leader>rR",
    toggle_hunk = "<leader>rh",
    toggle_file = "<leader>rf",
    comment = "<leader>rc",
    comment_block = "<leader>rC",
    comment_hunk = "<leader>rH",
    delete_comment = "<leader>rx",
    next_unreviewed = "]r",
    prev_unreviewed = "[r",
    next_hunk = "]h",
    prev_hunk = "[h",
    next_file = "]R",
    prev_file = "[R",
    toggle_removed = "<leader>r-",
  },
  icons = {
    reviewed = "✓",
    comment = "●",
    warning = "▲",
    working_copy = "◆",
    mark = "✓",
  },
}

--- Error on option names that do not exist (typos).
---@param given table
---@param known table
---@param prefix string
local function reject_unknown(given, known, prefix)
  for name in pairs(given) do
    if known[name] == nil then
      error(("review: unknown option '%s%s'"):format(prefix, name), 0)
    end
  end
end

---@param name string
---@param value any
local function validate_positive_integer(name, value)
  vim.validate(name, value, function(v)
    return type(v) == "number" and v >= 1 and v == math.floor(v)
  end, "positive integer")
end

---@param config review.Config
local function validate(config)
  vim.validate("revset", config.revset, "string")
  validate_positive_integer("explorer_width", config.explorer_width)
  validate_positive_integer("max_parallel_jj", config.max_parallel_jj)
  vim.validate("dim_reviewed", config.dim_reviewed, "boolean")
  vim.validate("inline_diff", config.inline_diff, "boolean")
  for name, key in pairs(config.keymaps) do
    vim.validate("keymaps." .. name, key, function(v)
      return type(v) == "string" or v == false
    end, "string or false")
  end
  for name, icon in pairs(config.icons) do
    vim.validate("icons." .. name, icon, "string")
  end
end

--- Merge user options over the defaults. Errors on unknown names and invalid values.
---@param opts? table
---@return review.Config
function M.resolve(opts)
  opts = opts or {}
  reject_unknown(opts, M.defaults, "")
  reject_unknown(opts.keymaps or {}, M.defaults.keymaps, "keymaps.")
  reject_unknown(opts.icons or {}, M.defaults.icons, "icons.")
  local config = vim.tbl_deep_extend("force", M.defaults, opts)
  validate(config)
  return config
end

return M
