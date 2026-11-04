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

  it("opens a new tab with the explorer on the left and the diff window on the right", function()
    local first_tab = vim.api.nvim_get_current_tabpage()
    layout.open(fake_app())
    local tab = assert(layout.handles().tab, "tab")
    assert.are_not.equal(first_tab, tab)
    assert.are.same({ explorer.handles().win, layout.handles().diff_win }, vim.api.nvim_tabpage_list_wins(tab))
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

  it("opens a new diff window when the user closed it", function()
    layout.open(fake_app())
    local old = assert(layout.handles().diff_win, "diff window")
    vim.api.nvim_win_close(old, true)
    local win = layout.diff_window(vim.api.nvim_create_buf(false, true))
    assert.are_not.equal(old, win)
    assert.are.same({ explorer.handles().win, win }, vim.api.nvim_tabpage_list_wins(0))
  end)
end)
