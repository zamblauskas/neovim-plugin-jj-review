local assert = require("luassert")
local config = require("review.config")
local explorer = require("review.shell.explorer")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")

--- Fake app that records dispatched messages.
---@param changes? table  state fields
local function fake_app(changes)
  local state = tbl.with(state_mod.initial(config.resolve({ explorer_width = 30 })), { open = true })
  state = tbl.with(state, changes or {})
  local app = { messages = {} }
  function app.state()
    return state
  end
  function app.dispatch(m)
    table.insert(app.messages, m.type)
  end
  return app
end

describe("shell.explorer", function()
  after_each(function()
    explorer.close()
    vim.cmd("silent! only")
  end)

  it("opens a left split with the configured width", function()
    explorer.open(fake_app())
    local win = assert(explorer.handles().win, "window")
    assert.are.same(30, vim.api.nvim_win_get_width(win))
    assert.are.same(win, vim.api.nvim_tabpage_list_wins(0)[1])
  end)

  it("renders the state", function()
    local app = fake_app()
    explorer.open(app)
    explorer.render(app.state())
    local buf = assert(explorer.handles().buf, "buffer")
    assert.are.same("Stack", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
  end)

  it("dispatches Closed on q", function()
    local app = fake_app()
    explorer.open(app)
    vim.api.nvim_feedkeys("q", "x", false)
    assert.are.same({ "Closed" }, app.messages)
  end)

  it("dispatches FoldToggled on <CR> on a revision row", function()
    local rev = {
      change_id = "abcd",
      short_id = "abcd",
      id_prefix = "a",
      commit_id = "c1",
      parents = {},
      empty = false,
      working_copy = false,
      description = "",
    }
    local app = fake_app({ stack = { type = "ok", revisions = { rev } } })
    explorer.open(app)
    explorer.render(app.state())
    vim.api.nvim_win_set_cursor(0, { 4, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    assert.are.same({ "FoldToggled" }, app.messages)
  end)

  it("dispatches Closed once when the window is closed by the user", function()
    local app = fake_app()
    explorer.open(app)
    vim.cmd("close")
    explorer.close()
    assert.are.same({ "Closed" }, app.messages)
  end)

  it("closes the window", function()
    explorer.open(fake_app())
    local win = assert(explorer.handles().win, "window")
    explorer.close()
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)
end)
