local assert = require("luassert")
local config = require("review.config")
local diff = require("review.shell.diff")
local effect = require("review.core.effect")
local explorer = require("review.shell.explorer")
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

---@param change_id string
---@param path string
---@return review.FileKey
local function key(change_id, path)
  return { change_id = change_id, path = path }
end

describe("shell.diff", function()
  local app

  --- Prepare and show a view-mode buffer.
  ---@param file review.FileKey
  ---@param lines string[]
  ---@param cursor_line integer
  local function open(file, lines, cursor_line)
    diff.prepare(effect.prepare_buffer(file, lines, "view", "/repo/" .. file.path), app)
    diff.show(effect.show_buffer(file, cursor_line))
  end

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

  it("shows a read-only buffer in the previous window and focuses it, with the cursor at the line", function()
    open(key("abc", "src/a.lua"), { "one", "two" }, 2)
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    assert.are_not.equal(explorer.handles().win, win)
    assert.are.same("review://abc/src/a.lua", vim.api.nvim_buf_get_name(buf))
    assert.are.same({ "one", "two" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.are.same({ false, "nofile", "lua" }, { vim.bo[buf].modifiable, vim.bo[buf].buftype, vim.bo[buf].filetype })
    assert.are.same({ 2, 0 }, vim.api.nvim_win_get_cursor(win))
  end)

  it("reuses the buffer of the same file and updates its lines", function()
    open(key("abc", "a.txt"), { "old" }, 1)
    local first = vim.api.nvim_get_current_buf()
    open(key("abc", "b.txt"), { "b" }, 1)
    open(key("abc", "a.txt"), { "new" }, 1)
    assert.are.same(first, vim.api.nvim_get_current_buf())
    assert.are.same({ "new" }, vim.api.nvim_buf_get_lines(first, 0, -1, false))
  end)

  it("clamps the cursor to the buffer", function()
    open(key("abc", "a.txt"), { "" }, 5)
    assert.are.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
  end)

  it("draws the diff of a review buffer and sets topfill", function()
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
      buffers = { ["abc/f"] = { file = key("abc", "f"), commit_id = "c1", mode = "view" } },
    })
    open(key("abc", "f"), { "y", "z" }, 1)
    diff.render(state)
    local marks = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })
    assert.are.same(2, #marks)
    assert.are.same(1, vim.fn.winsaveview().topfill)
  end)

  it("dispatches FileStepped on ]R and [R", function()
    open(key("abc", "a.txt"), { "x" }, 1)
    vim.api.nvim_feedkeys("]R[R", "x", false)
    assert.are.same({ msg.file_stepped("abc", "a.txt", 1), msg.file_stepped("abc", "a.txt", -1) }, app.messages)
  end)

  it("dispatches toggles for the line, the block, the file and a visual range", function()
    open(key("abc", "a.txt"), { "1", "2", "3" }, 2)
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
    open(key("abc", "a.txt"), { "1", "2", "3" }, 2)
    vim.api.nvim_feedkeys("]r[r", "x", false)
    assert.are.same({
      msg.unreviewed_stepped("abc", "a.txt", 2, 1),
      msg.unreviewed_stepped("abc", "a.txt", 2, -1),
    }, app.messages)
  end)

  it("keeps cursor and focus when it prepares a new text of a shown buffer", function()
    open(key("abc", "a.txt"), { "1", "2", "3", "4" }, 1)
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(win, { 3, 0 })
    vim.cmd.wincmd("p")
    local other = vim.api.nvim_get_current_win()
    diff.prepare(effect.prepare_buffer(key("abc", "a.txt"), { "1", "2", "3", "4", "5" }, "view", "/repo/a.txt"), app)
    assert.are.same(other, vim.api.nvim_get_current_win())
    assert.are.same({ 3, 0 }, vim.api.nvim_win_get_cursor(win))
  end)

  it("clamps a kept cursor to a shorter text", function()
    open(key("abc", "a.txt"), { "1", "2", "3", "4" }, 4)
    diff.prepare(effect.prepare_buffer(key("abc", "a.txt"), { "1" }, "view", "/repo/a.txt"), app)
    assert.are.same(1, vim.api.nvim_win_get_cursor(0)[1])
  end)

  it("sets the cursor only on the first show", function()
    open(key("abc", "a.txt"), { "1", "2", "3" }, 2)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    open(key("abc", "b.txt"), { "b" }, 1)
    diff.show(effect.show_buffer(key("abc", "a.txt"), 2))
    assert.are.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
  end)

  it("keeps the buffer, its lines and keymaps after another file is shown (<C-o> works)", function()
    open(key("abc", "a.txt"), { "a" }, 1)
    local first = vim.api.nvim_get_current_buf()
    open(key("abc", "b.txt"), { "b" }, 1)
    vim.api.nvim_set_current_buf(first)
    assert.are.same({ "a" }, vim.api.nvim_buf_get_lines(first, 0, -1, false))
    vim.api.nvim_feedkeys(vim.keycode("<leader>rf"), "x", false)
    assert.are.same("ToggleRequested", app.messages[1].type)
  end)

  it("opens a split when no window can show the file", function()
    vim.api.nvim_set_current_win(explorer.handles().win --[[@as integer]])
    vim.cmd.only()
    open(key("abc", "a.txt"), { "a" }, 1)
    assert.are.same(2, #vim.api.nvim_tabpage_list_wins(0))
    assert.are_not.equal(explorer.handles().win, vim.api.nvim_get_current_win())
  end)

  it("releases a scratch buffer: its windows get an empty buffer", function()
    open(key("abc", "a.txt"), { "x" }, 1)
    local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    diff.release(effect.release_buffer(key("abc", "a.txt")))
    assert.is_true(vim.api.nvim_win_is_valid(win))
    assert.is_false(vim.api.nvim_buf_is_valid(buf))
    assert.are.same("", vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)))
  end)

  it("dispatches comment messages", function()
    open(key("abc", "a.txt"), { "1", "2", "3" }, 2)
    vim.api.nvim_feedkeys(
      vim.keycode("<leader>rc<leader>rC<leader>rx") .. "Vj" .. vim.keycode("<leader>rc"),
      "x",
      false
    )
    local base = { change_id = "abc", path = "a.txt" }
    assert.are.same({
      msg.comment_requested(vim.tbl_extend("force", base, { type = "line", line = 2 })),
      msg.comment_requested(vim.tbl_extend("force", base, { type = "block", line = 2 })),
      msg.comment_delete_requested("abc", "a.txt", 2),
      msg.comment_requested(vim.tbl_extend("force", base, { type = "range", first = 2, last = 3 })),
    }, app.messages)
  end)

  it("wipes its buffers on close", function()
    open(key("abc", "a.txt"), { "x" }, 1)
    local buf = vim.api.nvim_get_current_buf()
    diff.close()
    assert.is_false(vim.api.nvim_buf_is_valid(buf))
  end)
end)
