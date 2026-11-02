local assert = require("luassert")
local explorer = require("review.shell.explorer")
local helpers = require("tests.helpers")
local review = require("review")

---@return string[]
local function explorer_lines()
  local buf = explorer.handles().buf
  return buf and vim.api.nvim_buf_get_lines(buf, 0, -1, false) or {}
end

---@param expected string
local function wait_for_line(expected)
  vim.wait(5000, function()
    return vim.tbl_contains(explorer_lines(), expected)
  end, 20)
end

describe("review (end to end)", function()
  local cwd

  before_each(function()
    cwd = vim.fn.getcwd()
    review.setup()
  end)

  after_each(function()
    review.close()
    vim.cmd("silent! only")
    vim.cmd.cd(cwd)
  end)

  it("shows the stack of a repo in the explorer", function()
    local repo = helpers.temp_repo()
    vim.fn.writefile({ "a" }, repo .. "/a.txt")
    helpers.jj(repo, { "describe", "-m", "first change" })
    helpers.jj(repo, { "new" })
    vim.cmd.cd(repo)
    vim.cmd("Review")
    wait_for_line("Stack (1)")
    assert.are.same("revset: (trunk()..@)::", explorer_lines()[2])
    assert.truthy(explorer_lines()[4]:find(": first change$"))
  end)

  it("shows a jj error for a bad revset", function()
    vim.cmd.cd(helpers.temp_repo())
    vim.cmd("Review no_such_bookmark")
    wait_for_line("✖ jj failed")
    assert.are.same("revset: no_such_bookmark", explorer_lines()[2])
  end)

  it("closes with :Review close", function()
    vim.cmd.cd(helpers.temp_repo())
    vim.cmd("Review")
    vim.cmd("Review close")
    assert.is_nil(explorer.handles().win)
  end)
end)
