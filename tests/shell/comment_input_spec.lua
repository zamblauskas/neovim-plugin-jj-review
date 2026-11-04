local assert = require("luassert")
local comment_input = require("review.shell.comment_input")

describe("shell.comment_input", function()
  after_each(function()
    vim.cmd("stopinsert")
    vim.cmd("silent! only")
  end)

  it("submits the text with <C-s> and closes", function()
    local got
    comment_input.open("f:1", function(text)
      got = text
    end)
    local win = vim.api.nvim_get_current_win()
    assert.are.same("editor", vim.api.nvim_win_get_config(win).relative)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "why", "here?" })
    vim.cmd("stopinsert")
    local save = vim.iter(vim.api.nvim_buf_get_keymap(0, "n")):find(function(m)
      return m.lhs == "<C-S>"
    end)
    assert(save, "<C-s> mapping").callback()
    assert.are.same("why\nhere?", got)
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it("cancels with q without a submit", function()
    local called = false
    comment_input.open("f:1", function()
      called = true
    end)
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_feedkeys(vim.keycode("<Esc>") .. "q", "x", false)
    assert.is_false(called)
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)
end)
