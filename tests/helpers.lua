-- Shared test helpers.

local async = require("review.shell.async")

local M = {}

--- Run `fn` inside async.run and wait until it ends. Returns its return values.
---@param fn fun(): ...
---@return ...
function M.run_async(fn)
  local result, failure
  async.run(function()
    result = vim.F.pack_len(fn())
  end, function(err)
    failure = err
  end)
  vim.wait(10000, function()
    return result ~= nil or failure ~= nil
  end, 10)
  assert(failure == nil, failure)
  assert(result ~= nil, "async test timed out")
  return vim.F.unpack_len(result)
end

--- Create an empty JJ repo in a temp dir. Returns its real path.
---@return string
function M.temp_repo()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local obj = vim.system({ "jj", "git", "init" }, { cwd = dir, text = true }):wait()
  assert(obj.code == 0, obj.stderr)
  return assert(vim.uv.fs_realpath(dir))
end

--- Run a jj command in `dir` synchronously (test setup only).
---@param dir string
---@param args string[]
---@return string stdout
function M.jj(dir, args)
  local obj = vim.system(vim.list_extend({ "jj" }, args), { cwd = dir, text = true }):wait()
  assert(obj.code == 0, obj.stderr)
  return obj.stdout
end

return M
