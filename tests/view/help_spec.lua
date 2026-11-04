local assert = require("luassert")
local config = require("review.config")
local view = require("review.view.help")

describe("view.help", function()
  it("lists the keys by section with aligned descriptions", function()
    local lines = view.render(config.defaults.keymaps).lines
    assert.are.same("Explorer", lines[1])
    assert.are.same("  <CR>         Fold revision / open file", lines[2])
    assert.truthy(vim.tbl_contains(lines, "Diff buffer"))
    assert.truthy(vim.tbl_contains(lines, "  <leader>rr   Toggle reviewed: line, or visual range"))
    assert.are.same("  <leader>jvq  Close review (:Review close)", lines[#lines])
  end)

  it("leaves out unmapped keys and shows changed keys", function()
    local keymaps = config.resolve({ keymaps = { edit = false, help = "g?" } }).keymaps
    local lines = view.render(keymaps).lines
    local joined = table.concat(lines, "\n")
    assert.is_nil(joined:find("jj edit", 1, true))
    assert.truthy(joined:find("g?", 1, true))
  end)

  it("highlights section titles and keys", function()
    local highlights = view.render(config.defaults.keymaps).highlights
    assert.are.same({ row = 0, col_start = 0, col_end = 8, group = "ReviewHeader" }, highlights[1])
    assert.are.same({ row = 1, col_start = 2, col_end = 6, group = "ReviewChangeId" }, highlights[2])
  end)
end)
