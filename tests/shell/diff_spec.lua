local assert = require("luassert")
local config = require("review.config")
local diff = require("review.shell.diff")
local effect = require("review.core.effect")
local layout = require("review.shell.layout")
local msg = require("review.core.msg")
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
    table.insert(app.messages, m)
  end
  return app
end

describe("shell.diff", function()
  local app

  before_each(function()
    app = fake_app()
    layout.open(app)
  end)

  after_each(function()
    layout.close()
    diff.close()
    vim.cmd("silent! tabonly")
    vim.cmd("silent! only")
  end)

  it("shows a read-only buffer in the diff window, with the cursor at the line", function()
    diff.open(effect.open_buffer("abc", "src/a.lua", { "one", "two" }, 2), app)
    local win = assert(layout.handles().diff_win)
    local buf = vim.api.nvim_win_get_buf(win)
    assert.are.same(win, vim.api.nvim_get_current_win())
    assert.are.same("review://abc/src/a.lua", vim.api.nvim_buf_get_name(buf))
    assert.are.same({ "one", "two" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.are.same({ false, "nofile", "lua" }, { vim.bo[buf].modifiable, vim.bo[buf].buftype, vim.bo[buf].filetype })
    assert.are.same({ 2, 0 }, vim.api.nvim_win_get_cursor(win))
  end)

  it("reuses the buffer of the same file and updates its lines", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "old" }, 1), app)
    local first = vim.api.nvim_get_current_buf()
    diff.open(effect.open_buffer("abc", "b.txt", { "b" }, 1), app)
    diff.open(effect.open_buffer("abc", "a.txt", { "new" }, 1), app)
    assert.are.same(first, vim.api.nvim_get_current_buf())
    assert.are.same({ "new" }, vim.api.nvim_buf_get_lines(first, 0, -1, false))
  end)

  it("clamps the cursor to the buffer", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "" }, 5), app)
    assert.are.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
  end)

  it("draws the diff of the open file and sets topfill", function()
    local rev = {
      change_id = "abc",
      short_id = "abc",
      id_prefix = "a",
      commit_id = "c1",
      parents = {},
      empty = false,
      working_copy = false,
      description = "",
    }
    local file =
      require("review.parse.diff").parse("diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1,2 +1,2 @@\n-x\n+y\n z\n")[1]
    local state = tbl.with(app.state(), {
      stack = { type = "ok", revisions = { rev } },
      diffs = { c1 = { file } },
      open_file = { change_id = "abc", path = "f" },
    })
    diff.open(effect.open_buffer("abc", "f", { "y", "z" }, 1), app)
    diff.render(state)
    local marks = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })
    assert.are.same(2, #marks)
    assert.are.same(1, vim.fn.winsaveview().topfill)
  end)

  it("dispatches FileStepped on ]R and [R", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "x" }, 1), app)
    vim.api.nvim_feedkeys("]R[R", "x", false)
    assert.are.same({ msg.file_stepped(1), msg.file_stepped(-1) }, app.messages)
  end)

  it("dispatches toggles for the line, the block, the file and a visual range", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "1", "2", "3" }, 2), app)
    vim.api.nvim_feedkeys(
      vim.keycode("<leader>rr<leader>rR<leader>rf") .. "Vj" .. vim.keycode("<leader>rr"),
      "x",
      false
    )
    local got = vim.tbl_map(function(m)
      return m.target
    end, app.messages)
    assert.are.same({
      { type = "line", change_id = "abc", path = "a.txt", line = 2 },
      { type = "block", change_id = "abc", path = "a.txt", line = 2 },
      { type = "file", change_id = "abc", path = "a.txt" },
      { type = "range", change_id = "abc", path = "a.txt", first = 2, last = 3 },
    }, got)
    assert.are.same("n", vim.api.nvim_get_mode().mode)
  end)

  it("dispatches UnreviewedStepped on ]r and [r from the cursor line", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "1", "2", "3" }, 2), app)
    vim.api.nvim_feedkeys("]r[r", "x", false)
    assert.are.same({
      msg.unreviewed_stepped("abc", "a.txt", 2, 1),
      msg.unreviewed_stepped("abc", "a.txt", 2, -1),
    }, app.messages)
  end)

  it("keeps cursor and focus when it shows a new commit of the open file", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "1", "2", "3", "4" }, 1), app)
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(win, { 3, 0 })
    vim.cmd.wincmd("p")
    local other = vim.api.nvim_get_current_win()
    diff.open(effect.open_buffer("abc", "a.txt", { "1", "2", "3", "4", "5" }, 1, true), app)
    assert.are.same(other, vim.api.nvim_get_current_win())
    assert.are.same({ 3, 0 }, vim.api.nvim_win_get_cursor(win))
  end)

  it("clamps a kept cursor to a shorter text", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "1", "2", "3", "4" }, 4), app)
    diff.open(effect.open_buffer("abc", "a.txt", { "1" }, 1, true), app)
    assert.are.same(1, vim.api.nvim_win_get_cursor((assert(layout.handles().diff_win)))[1])
  end)

  it("closes the open file: empty buffer in the diff window, review buffers wiped", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "x" }, 1), app)
    local buf = vim.api.nvim_get_current_buf()
    diff.close_file()
    local win = assert(layout.handles().diff_win)
    assert.is_true(vim.api.nvim_win_is_valid(win))
    assert.is_false(vim.api.nvim_buf_is_valid(buf))
    assert.are.same("", vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)))
  end)

  it("wipes its buffers on close", function()
    diff.open(effect.open_buffer("abc", "a.txt", { "x" }, 1), app)
    local buf = vim.api.nvim_get_current_buf()
    diff.close()
    assert.is_false(vim.api.nvim_buf_is_valid(buf))
  end)
end)
