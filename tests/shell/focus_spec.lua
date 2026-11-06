local assert = require("luassert")
local config = require("review.config")
local diff = require("review.shell.diff")
local effect = require("review.core.effect")
local explorer = require("review.shell.explorer")
local layout = require("review.shell.layout")
local msg = require("review.core.msg")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")

--- Fake app that records FocusChanged messages.
local function fake_app()
  local state = tbl.with(state_mod.initial(config.resolve()), { open = true })
  local app = { messages = {}, shown = {} }
  function app.state()
    return state
  end
  function app.dispatch(m)
    if m.type == "FocusChanged" then
      table.insert(app.messages, m)
    elseif m.type == "BufferShown" then
      table.insert(app.shown, m)
    end
  end
  return app
end

--- Wait for the scheduled reports.
local function settle()
  vim.wait(20, function()
    return false
  end)
end

describe("shell.focus", function()
  local app

  local function open_file()
    local file = { change_id = "abc", path = "a.txt" }
    diff.prepare(effect.prepare_buffer(file, { "x" }, "view", "/repo/a.txt"), app)
    diff.show(effect.show_buffer(file, 1))
  end

  before_each(function()
    app = fake_app()
    layout.open(app)
    settle()
    app.messages = {}
  end)

  after_each(function()
    layout.close()
    diff.close()
    vim.cmd("silent! tabonly")
    vim.cmd("silent! only")
  end)

  it("reports a review buffer that gets a window", function()
    open_file()
    settle()
    assert.are.same({ msg.buffer_shown({ change_id = "abc", path = "a.txt" }) }, app.shown)
  end)

  it("reports a review buffer in the focused window", function()
    open_file()
    settle()
    assert.are.same({ msg.focus_changed({ change_id = "abc", path = "a.txt" }) }, app.messages)
  end)

  it("reports a real file that is not a review buffer by its path", function()
    local path = vim.fn.tempname()
    vim.fn.writefile({ "x" }, path)
    vim.cmd.wincmd("l")
    vim.cmd.edit(path)
    settle()
    assert.are.same({ msg.focus_changed(nil, vim.uv.fs_realpath(path)) }, app.messages)
  end)

  it("does not report the explorer, and does not repeat a report", function()
    open_file()
    settle()
    vim.api.nvim_set_current_win(explorer.handles().win --[[@as integer]])
    settle()
    vim.cmd.wincmd("p")
    settle()
    assert.are.same(1, #app.messages)
  end)

  it("does not report other tabs", function()
    vim.cmd.tabnew()
    vim.cmd.edit(vim.fn.tempname())
    settle()
    assert.are.same({}, app.messages)
  end)
end)
