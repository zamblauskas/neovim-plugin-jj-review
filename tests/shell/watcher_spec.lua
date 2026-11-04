local assert = require("luassert")
local helpers = require("tests.helpers")
local watcher = require("review.shell.watcher")

describe("shell.watcher", function()
  after_each(function()
    watcher.stop()
  end)

  it("finds the repo dir of the main workspace", function()
    local repo = helpers.temp_repo()
    assert.are.same(repo .. "/.jj/repo", watcher.repo_dir(repo))
  end)

  it("follows .jj/repo of a secondary workspace", function()
    local repo = helpers.temp_repo()
    local ws = vim.fn.fnamemodify(repo, ":h") .. "/" .. vim.fn.fnamemodify(repo, ":t") .. "-ws"
    helpers.jj(repo, { "workspace", "add", ws })
    assert.are.same(repo .. "/.jj/repo", watcher.repo_dir(assert(vim.uv.fs_realpath(ws))))
  end)

  it("calls back once after a jj operation", function()
    local repo = helpers.temp_repo()
    local calls = 0
    assert.is_true(watcher.start(repo, function()
      calls = calls + 1
    end))
    helpers.jj(repo, { "describe", "-m", "x" })
    vim.wait(2000, function()
      return calls > 0
    end, 20)
    vim.wait(400, function()
      return false
    end)
    assert.are.same(1, calls)
  end)

  it("calls back on focus", function()
    local calls = 0
    watcher.start(helpers.temp_repo(), function()
      calls = calls + 1
    end)
    vim.api.nvim_exec_autocmds("FocusGained", {})
    vim.wait(1000, function()
      return calls > 0
    end, 20)
    assert.are.same(1, calls)
  end)

  it("reports a missing repo but still watches focus", function()
    local ok, err = watcher.start(vim.fn.tempname(), function() end)
    assert.is_false(ok)
    assert.is_not_nil(err)
  end)

  it("stops calling back after stop", function()
    local repo = helpers.temp_repo()
    local calls = 0
    watcher.start(repo, function()
      calls = calls + 1
    end)
    watcher.stop()
    helpers.jj(repo, { "describe", "-m", "x" })
    vim.api.nvim_exec_autocmds("FocusGained", {})
    vim.wait(400, function()
      return false
    end)
    assert.are.same(0, calls)
  end)
end)
