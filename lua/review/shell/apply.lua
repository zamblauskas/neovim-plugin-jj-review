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
    vim.api.nvim_buf_set_extmark(buf, ns, hl.row, hl.col_start, { end_col = hl.col_end, hl_group = hl.group })
  end
end

return M
