local assert = require("luassert")
local apply = require("review.shell.apply")

describe("shell.apply", function()
  local buf, ns

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    ns = vim.api.nvim_create_namespace("review.test")
  end)

  after_each(function()
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  ---@return vim.api.keyset.extmark_details[]
  local function details()
    return vim.tbl_map(function(m)
      return { row = m[2], col = m[3], hl_group = m[4].hl_group, line_hl_group = m[4].line_hl_group }
    end, vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true }))
  end

  it("sets the lines and a highlight per byte range", function()
    apply.view(buf, ns, { lines = { "ab" }, highlights = { { row = 0, col_start = 1, col_end = 2, group = "G" } } })
    assert.are.same({ "ab" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.are.same({ { row = 0, col = 1, hl_group = "G" } }, details())
  end)

  it("highlights a whole line", function()
    local hl = { row = 1, col_start = 0, col_end = 0, group = "G", line = true }
    apply.view(buf, ns, { lines = { "a", "b" }, highlights = { hl } })
    assert.are.same({ { row = 1, col = 0, line_hl_group = "G" } }, details())
  end)
end)
