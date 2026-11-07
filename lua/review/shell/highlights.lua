-- Highlight groups. Linked by default, so color schemes and users can override them.

local color = require("review.lib.color")

local M = {}

--- Weaker versions of DiffAdd / DiffDelete: the background mixed with the Normal background, `alpha` of the base.
--- Reviewed: reviewed lines. File: every line of a new or deleted file is a change, so the wall is lighter.
local DIMMED = {
  ReviewAddedReviewed = { base = "DiffAdd", alpha = 0.5 },
  ReviewRemovedReviewed = { base = "DiffDelete", alpha = 0.5 },
  ReviewAddedFile = { base = "DiffAdd", alpha = 0.25 },
  ReviewRemovedFile = { base = "DiffDelete", alpha = 0.25 },
  ReviewAddedFileReviewed = { base = "DiffAdd", alpha = 0.1 },
  ReviewRemovedFileReviewed = { base = "DiffDelete", alpha = 0.1 },
}

--- Changed tokens of a paired line: the background of the base group, mixed with the foreground of the accent group.
local TEXT = {
  ReviewAddedText = { base = "DiffAdd", accent = "Added" },
  ReviewRemovedText = { base = "DiffDelete", accent = "Removed" },
}
local TEXT_ALPHA = 0.5

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
  ReviewGuide = "Comment",
  ReviewStatusAdded = "Added",
  ReviewStatusModified = "Changed",
  ReviewStatusDeleted = "Removed",
  ReviewStatusRenamed = "Special",
  ReviewCurrent = "Visual",
}

--- Dimmed version of `base`. A link to `base` if a background is missing.
---@param base string
---@param alpha number
---@return vim.api.keyset.highlight
local function dimmed(base, alpha)
  local hl = vim.api.nvim_get_hl(0, { name = base, link = false })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  if not (hl.bg and normal.bg) then
    return { link = base, default = true }
  end
  return { fg = hl.fg, bg = color.blend(hl.bg, normal.bg, alpha), default = true }
end

--- Stronger version of `base`. A link to `DiffText` if a color is missing.
---@param base string
---@param accent string
---@return vim.api.keyset.highlight
local function stronger(base, accent)
  local hl = vim.api.nvim_get_hl(0, { name = base, link = false })
  local fg = vim.api.nvim_get_hl(0, { name = accent, link = false }).fg
  if not (hl.bg and fg) then
    return { link = "DiffText", default = true }
  end
  return { fg = hl.fg, bg = color.blend(fg, hl.bg, TEXT_ALPHA), default = true }
end

function M.setup()
  for group, target in pairs(LINKS) do
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end
  for group, spec in pairs(DIMMED) do
    vim.api.nvim_set_hl(0, group, dimmed(spec.base, spec.alpha))
  end
  for group, spec in pairs(TEXT) do
    vim.api.nvim_set_hl(0, group, stronger(spec.base, spec.accent))
  end
end

return M
