local assert = require("luassert")
local config = require("review.config")
local explorer = require("review.shell.explorer")
local layout = require("review.shell.layout")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")

--- Fake app that records dispatched messages.
local function fake_app()
  local state = tbl.with(state_mod.initial(config.resolve()), { open = true })
  local app = { messages = {} }
  function app.state()
    return state
  end
  function app.dispatch(m)
    table.insert(app.messages, m.type)
  end
  return app
end

describe("shell.layout", function()
  after_each(function()
    layout.close()
    vim.cmd("silent! tabonly")
    vim.cmd("silent! only")
  end)

  it("opens a new tab with the explorer on the left and one window on the right", function()
    local first_tab = vim.api.nvim_get_current_tabpage()
    layout.open(fake_app())
    local tab = assert(layout.handles().tab, "tab")
    local wins = vim.api.nvim_tabpage_list_wins(tab)
    assert.are_not.equal(first_tab, tab)
    assert.are.same({ 2, explorer.handles().win }, { #wins, wins[1] })
  end)

  it("goes to the open tab on a second open", function()
    local app = fake_app()
    layout.open(app)
    local tab = layout.handles().tab
    vim.cmd.tabprevious()
    layout.open(app)
    assert.are.same(2, #vim.api.nvim_list_tabpages())
    assert.are.same(tab, vim.api.nvim_get_current_tabpage())
  end)

  it("closes the tab", function()
    layout.open(fake_app())
    layout.close()
    assert.are.same(1, #vim.api.nvim_list_tabpages())
    assert.is_nil(explorer.handles().win)
  end)

  it("closes only the explorer when the review tab is the only tab", function()
    layout.open(fake_app())
    vim.cmd("tabonly")
    layout.close()
    assert.is_nil(explorer.handles().win)
    assert.are.same(1, #vim.api.nvim_tabpage_list_wins(0))
  end)

  it("dispatches Closed when the user closes the tab", function()
    local app = fake_app()
    layout.open(app)
    vim.cmd("tabclose")
    assert.are.same({ "Closed" }, app.messages)
  end)

  describe("target window", function()
    local function buf()
      return vim.api.nvim_create_buf(false, true)
    end

    it("is the current window when it is not the explorer", function()
      layout.open(fake_app())
      vim.cmd.wincmd("l")
      assert.are.same(vim.api.nvim_get_current_win(), layout.target_window(buf()))
    end)

    it("is the previous window when the explorer is focused", function()
      layout.open(fake_app())
      vim.cmd.wincmd("l")
      vim.cmd.split()
      local previous = vim.api.nvim_get_current_win()
      vim.api.nvim_set_current_win(explorer.handles().win --[[@as integer]])
      assert.are.same(previous, layout.target_window(buf()))
    end)

    it("is a new split when the explorer is the only window", function()
      layout.open(fake_app())
      vim.cmd.only()
      local win = layout.target_window(buf())
      assert.are.same({ explorer.handles().win, win }, vim.api.nvim_tabpage_list_wins(0))
    end)

    it("is in the review tab when another tab is focused", function()
      layout.open(fake_app())
      local tab = layout.handles().tab
      vim.cmd.tabnew()
      local win = layout.target_window(buf())
      assert.are.same(tab, vim.api.nvim_win_get_tabpage(win))
    end)
  end)
end)
