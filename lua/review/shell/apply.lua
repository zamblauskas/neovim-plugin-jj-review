-- Apply a view (lines + highlights) to a buffer. Full redraw.

local M = {}

---@param buf integer
---@param ns integer
---@param view review.View
function M.view(buf, ns, view)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, view.lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, hl in ipairs(view.highlights) do
    local opts = hl.line and { line_hl_group = hl.group } or { end_col = hl.col_end, hl_group = hl.group }
    vim.api.nvim_buf_set_extmark(buf, ns, hl.row, hl.line and 0 or hl.col_start, opts)
  end
end

--- Replace all extmarks of `ns` in `buf` (full redraw). Marks start at column 0.
---@param buf integer
---@param ns integer
---@param specs review.ExtmarkSpec[]
function M.extmarks(buf, ns, specs)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, spec in ipairs(specs) do
    vim.api.nvim_buf_set_extmark(buf, ns, spec.row, 0, spec.opts)
  end
end

return M
