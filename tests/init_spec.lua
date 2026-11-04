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

--- Wait for an explorer line that starts with `prefix`. Returns its 1-based row, or nil.
---@param prefix string
---@return integer?
local function wait_for_row(prefix)
  local row
  vim.wait(5000, function()
    row = vim.iter(ipairs(explorer_lines())):find(function(_, line)
      return vim.startswith(line, prefix)
    end)
    return row ~= nil
  end, 20)
  return row
end

--- Repo with one revision that adds a.txt ("hello"). Opens the review and opens a.txt with <CR>.
---@return string repo
local function open_one_file_review()
  local repo = helpers.temp_repo()
  vim.fn.writefile({ "hello" }, repo .. "/a.txt")
  helpers.jj(repo, { "describe", "-m", "first change" })
  helpers.jj(repo, { "new" })
  vim.cmd.cd(repo)
  vim.cmd("Review")
  vim.api.nvim_win_set_cursor(0, { assert(wait_for_row("    A a.txt"), "file row"), 0 })
  vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
  vim.wait(5000, function()
    return vim.api.nvim_buf_get_name(0):match("a%.txt$") ~= nil
  end, 20)
  return repo
end

describe("review (end to end)", function()
  local cwd

  before_each(function()
    cwd = vim.fn.getcwd()
    review.setup()
  end)

  after_each(function()
    review.close()
    vim.cmd("silent! tabonly")
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
    wait_for_row("Stack (1)")
    assert.are.same("revset: (trunk()..@)::", explorer_lines()[2])
    assert.truthy(explorer_lines()[4]:find(": first change$"))
  end)

  it("shows a jj error for a bad revset", function()
    vim.cmd.cd(helpers.temp_repo())
    vim.cmd("Review no_such_bookmark")
    wait_for_line("✖ jj failed")
    assert.are.same("revset: no_such_bookmark", explorer_lines()[2])
  end)

  it("opens the real file when the revision is on disk (@ empty, revision @-)", function()
    local repo = open_one_file_review()
    assert.are.same(repo .. "/a.txt", vim.api.nvim_buf_get_name(0))
    assert.are.same({ "hello" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.is_true(vim.bo.modifiable)
  end)

  it("opens a scratch buffer for a revision that is not on disk", function()
    local repo = helpers.temp_repo()
    vim.fn.writefile({ "hello" }, repo .. "/a.txt")
    helpers.jj(repo, { "describe", "-m", "first change" })
    helpers.jj(repo, { "new", "-m", "second" })
    vim.fn.writefile({ "x" }, repo .. "/b.txt")
    helpers.jj(repo, { "new" })
    vim.cmd.cd(repo)
    vim.cmd("Review")
    vim.api.nvim_win_set_cursor(0, { assert(wait_for_row("    A a.txt"), "file row"), 0 })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    vim.wait(5000, function()
      return vim.api.nvim_buf_get_name(0):match("a%.txt$") ~= nil
    end, 20)
    assert.truthy(vim.api.nvim_buf_get_name(0):match("^review://%w+/a%.txt$"))
    assert.is_false(vim.bo.modifiable)
  end)

  it("snapshots and refreshes after a save in working-copy mode", function()
    open_one_file_review()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello", "added line" })
    vim.cmd("silent write")
    vim.wait(5000, function()
      return vim.iter(explorer_lines()):any(function(line)
        return line:find("0/2", 1, true) ~= nil
      end)
    end, 20)
    local counts = vim.iter(explorer_lines()):any(function(line)
      return line:find("0/2", 1, true) ~= nil
    end)
    assert.is_true(counts)
  end)

  it("removes review keymaps from the real buffer on close", function()
    open_one_file_review()
    local buf = vim.api.nvim_get_current_buf()
    review.close()
    local has_review_key = vim.iter(vim.api.nvim_buf_get_keymap(buf, "n")):any(function(m)
      return m.desc == "Toggle reviewed: line"
    end)
    assert.is_false(has_review_key)
    assert.is_true(vim.api.nvim_buf_is_valid(buf))
  end)

  it("marks a line as reviewed and writes marks.json", function()
    local repo = open_one_file_review()
    vim.api.nvim_feedkeys(vim.keycode("<leader>rr"), "x", false)
    local data = require("review.shell.store").load(repo)
    assert.are.same(1, vim.tbl_count(assert(data).marks))
  end)

  it("writes a comment to comments.json", function()
    local repo = open_one_file_review()
    vim.api.nvim_feedkeys(vim.keycode("<leader>rc"), "x", false)
    vim.cmd("stopinsert")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "why hello?" })
    local save = vim.iter(vim.api.nvim_buf_get_keymap(0, "n")):find(function(m)
      return m.lhs == "<C-S>"
    end)
    assert(save, "<C-s> mapping").callback()
    local data = assert(require("review.shell.store").load(repo))
    assert.are.same(
      { "why hello?", "a.txt", "hello" },
      { data.comments[1].text, data.comments[1].path, data.comments[1].snippet }
    )
  end)

  it("refreshes when a jj command changes the stack", function()
    local repo = helpers.temp_repo()
    vim.fn.writefile({ "a" }, repo .. "/a.txt")
    helpers.jj(repo, { "describe", "-m", "first change" })
    vim.cmd.cd(repo)
    vim.cmd("Review")
    local function has(text)
      return vim.iter(explorer_lines()):any(function(line)
        return line:find(text, 1, true) ~= nil
      end)
    end
    vim.wait(5000, function()
      return has("first change")
    end, 20)
    helpers.jj(repo, { "describe", "-m", "renamed change" })
    vim.wait(5000, function()
      return has("renamed change")
    end, 20)
    assert.is_true(has("renamed change"))
  end)

  it("closes with :Review close", function()
    vim.cmd.cd(helpers.temp_repo())
    vim.cmd("Review")
    vim.cmd("Review close")
    assert.is_nil(explorer.handles().win)
  end)
end)
