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
    assert.are.same("Stack · (trunk()..@)::", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
  end)

  describe("width", function()
    local function counted_app()
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
      return fake_app({ stack = { type = "ok", revisions = { rev } }, diffs = { c1 = {} } })
    end

    ---@return integer
    local function first_line_width()
      local buf = assert(explorer.handles().buf, "buffer")
      return vim.fn.strdisplaywidth(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
    end

    it("aligns counts to the window width, not the configured width", function()
      local app = counted_app()
      explorer.open(app)
      vim.api.nvim_win_set_width(assert(explorer.handles().win, "window"), 25)
      explorer.render(app.state())
      assert.are.same(25, first_line_width())
    end)

    it("renders again when the window is resized", function()
      local app = counted_app()
      explorer.open(app)
      explorer.render(app.state())
      vim.api.nvim_win_set_width(assert(explorer.handles().win, "window"), 22)
      vim.api.nvim_exec_autocmds("WinResized", {})
      assert.are.same(22, first_line_width())
    end)
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
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    assert.are.same({ "FoldToggled" }, app.messages)
  end)

  it("keeps the cursor on its target when rows are added above", function()
    local function rev(id, parents)
      return {
        change_id = id,
        short_id = id,
        id_prefix = id,
        commit_id = id,
        parents = parents,
        empty = false,
        working_copy = false,
        description = "",
      }
    end
    local stack = { type = "ok", revisions = { rev("bbbb", { "aaaa" }), rev("aaaa", {}) } }
    local app = fake_app({ stack = stack })
    explorer.open(app)
    explorer.render(app.state())
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    local more = tbl.with(stack, { revisions = { rev("cccc", { "bbbb" }), unpack(stack.revisions) } })
    explorer.render(tbl.with(app.state(), { stack = more }))
    local line = vim.api.nvim_buf_get_lines(0, vim.fn.line(".") - 1, vim.fn.line("."), false)[1]
    assert.truthy(line:find("aaaa:"))
  end)

  it("opens the help float with ?", function()
    explorer.open(fake_app())
    vim.api.nvim_feedkeys("?", "x", false)
    local win = vim.api.nvim_get_current_win()
    assert.are.same("editor", vim.api.nvim_win_get_config(win).relative)
    assert.are.same("Explorer", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    vim.api.nvim_feedkeys("q", "x", false)
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it("uses the configured explorer keys", function()
    local app = fake_app({ config = require("review.config").resolve({ keymaps = { quit = "Q" } }) })
    explorer.open(app)
    vim.api.nvim_feedkeys("q", "x", false)
    assert.are.same({}, app.messages)
    vim.api.nvim_feedkeys("Q", "x", false)
    assert.are.same({ "Closed" }, app.messages)
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
