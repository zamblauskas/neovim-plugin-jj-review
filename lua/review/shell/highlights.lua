-- Highlight groups. Linked by default, so color schemes and users can override them.

local color = require("review.lib.color")

local M = {}

--- Reviewed lines: the background of the base group, mixed with the Normal background.
local DIMMED = { ReviewAddedReviewed = "DiffAdd", ReviewRemovedReviewed = "DiffDelete" }
local DIM_ALPHA = 0.5

local LINKS = {
  ReviewHeader = "Title",
  ReviewDim = "Comment",
  ReviewError = "DiagnosticError",
  ReviewChangeId = "Special",
  ReviewChangeIdRest = "Comment",
  ReviewWorkingCopy = "DiagnosticOk",
  ReviewFold = "Comment",
  ReviewAdded = "DiffAdd",
  ReviewRemoved = "DiffDelete",
  ReviewSign = "DiagnosticOk",
  ReviewCount = "Comment",
  ReviewDone = "DiagnosticOk",
  ReviewComment = "DiagnosticInfo",
  ReviewCommentOutdated = "DiagnosticWarn",
  ReviewDirectory = "Directory",
  ReviewStatusAdded = "Added",
  ReviewStatusModified = "Changed",
  ReviewStatusDeleted = "Removed",
  ReviewStatusRenamed = "Special",
  ReviewCurrent = "Visual",
}

--- Dimmed version of `base`. A link to `base` if a background is missing.
---@param base string
---@return vim.api.keyset.highlight
local function dimmed(base)
  local hl = vim.api.nvim_get_hl(0, { name = base, link = false })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  if not (hl.bg and normal.bg) then
    return { link = base, default = true }
  end
  return { fg = hl.fg, bg = color.blend(hl.bg, normal.bg, DIM_ALPHA), default = true }
end

function M.setup()
  for group, target in pairs(LINKS) do
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end
  for group, base in pairs(DIMMED) do
    vim.api.nvim_set_hl(0, group, dimmed(base))
  end
end

return M
