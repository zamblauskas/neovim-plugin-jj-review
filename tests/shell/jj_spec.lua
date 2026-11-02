local assert = require("luassert")
local helpers = require("tests.helpers")
local jj = require("review.shell.jj")

describe("jj port", function()
  local repo

  before_each(function()
    repo = helpers.temp_repo()
  end)

  it("finds the repo root", function()
    local result = helpers.run_async(function()
      return jj.root(repo)
    end)
    assert.is_true(result.ok)
    assert.are.same(repo, vim.trim(result.stdout))
  end)

  it("reads the operation id", function()
    local result = helpers.run_async(function()
      return jj.op_id(repo)
    end)
    assert.is_true(result.ok)
    assert.truthy(result.stdout:match("^%x+$"))
  end)

  it("does not snapshot the working copy", function()
    local before = helpers.run_async(function()
      return jj.op_id(repo).stdout
    end)
    vim.fn.writefile({ "new" }, repo .. "/file.txt")
    local after = helpers.run_async(function()
      jj.log(repo, "@", "commit_id")
      return jj.op_id(repo).stdout
    end)
    assert.are.same(before, after)
  end)

  it("returns stderr when the command fails", function()
    local result = helpers.run_async(function()
      return jj.log(repo, "no_such_revision", "commit_id")
    end)
    assert.is_false(result.ok)
    assert.truthy(result.stderr:find("no_such_revision"))
  end)

  it("fails outside a repo", function()
    local result = helpers.run_async(function()
      return jj.root(vim.fn.fnamemodify(repo, ":h"))
    end)
    assert.is_false(result.ok)
  end)
end)
