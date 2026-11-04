-- Highlight groups. Linked by default, so color schemes and users can override them.

local M = {}

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
  ReviewDirectory = "Directory",
  ReviewStatusAdded = "Added",
  ReviewStatusModified = "Changed",
  ReviewStatusDeleted = "Removed",
  ReviewStatusRenamed = "Special",
}

function M.setup()
  for group, target in pairs(LINKS) do
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end
end

return M
