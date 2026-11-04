local assert = require("luassert")
local config = require("review.config")
local diff = require("review.shell.diff")
local effect = require("review.core.effect")
local layout = require("review.shell.layout")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")

local function fake_app()
  local state = tbl.with(state_mod.initial(config.resolve()), { open = true })
  return {
    state = function()
      return state
    end,
    dispatch = function() end,
  }
end

describe("shell.diff", function()
  before_each(function()
    layout.open(fake_app())
  end)

  after_each(function()
    layout.close()
    diff.close()
    vim.cmd("silent! tabonly")
    vim.cmd("silent! only")
  end)

  it("shows a read-only buffer in the diff window, with the cursor at the line", function()
    diff.open(effect.open_buffer("abc", "src/a.lua", { "one", "two" }, 2))
    local win = assert(layout.handles().diff_win)
    local buf = vim.api.nvim_win_get_buf(win)
    assert.are.same(win, vim.api.nvim_get_current_win())
    assert.are.same("review://abc/src/a.lua", vim.api.nvim_buf_get_name(buf))
    assert.are.same({ "one", "two" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.are.same({ false, "nofile", "lua" }, { vim.bo[buf].modifiable, vim.bo[buf].buftype, vim.bo[buf].filetype })
    assert.are.same({ 2, 0 }, vim.api.nvim_win_get_cursor(win))
  end)

  it("reuses the buffer of the same file and updates its lines", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "old" }, 1))
    local first = vim.api.nvim_get_current_buf()
    diff.open(effect.open_buffer("abc", "b.txt", { "b" }, 1))
    diff.open(effect.open_buffer("abc", "a.txt", { "new" }, 1))
    assert.are.same(first, vim.api.nvim_get_current_buf())
    assert.are.same({ "new" }, vim.api.nvim_buf_get_lines(first, 0, -1, false))
  end)

  it("clamps the cursor to the buffer", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "" }, 5))
    assert.are.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
  end)

  it("wipes its buffers on close", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "x" }, 1))
    local buf = vim.api.nvim_get_current_buf()
    diff.close()
    assert.is_false(vim.api.nvim_buf_is_valid(buf))
  end)
end)
