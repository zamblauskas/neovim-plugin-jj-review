-- JJ port. Reads never snapshot the working copy, so they never create an operation.
-- All functions except `run_cb` must be called inside `async.run`.

local async = require("review.shell.lib.async")

local M = {}

---@class review.JjResult
---@field ok boolean
---@field stdout string
---@field stderr string
---@field args string[]

local GLOBAL_ARGS = { "--ignore-working-copy", "--no-pager", "--color=never" }

---@param args string[]
---@return string[]
local function command(args)
  return vim.list_extend(vim.list_extend({ "jj" }, GLOBAL_ARGS), args)
end

---@param args string[]
---@param obj vim.SystemCompleted
---@return review.JjResult
local function to_result(args, obj)
  return { ok = obj.code == 0, stdout = obj.stdout or "", stderr = obj.stderr or "", args = args }
end

--- Run jj in `cwd`, callback style. `done` runs in the main loop (API calls are safe).
---@param cwd string
---@param args string[]
---@param done fun(result: review.JjResult)
function M.run_cb(cwd, args, done)
  local on_exit = vim.schedule_wrap(function(obj)
    done(to_result(args, obj))
  end)
  local ok, err = pcall(vim.system, command(args), { cwd = cwd, text = true }, on_exit)
  if not ok then
    done({ ok = false, stdout = "", stderr = tostring(err), args = args })
  end
end

---@param cwd string
---@param args string[]
---@return review.JjResult
function M.run(cwd, args)
  return async.await(function(done)
    M.run_cb(cwd, args, done)
  end)
end

---@param cwd string
---@return review.JjResult
function M.root(cwd)
  return M.run(cwd, { "root" })
end

---@param root string
---@return review.JjResult
function M.op_id(root)
  return M.run(root, { "op", "log", "-n1", "--no-graph", "-T", "id" })
end

---@param root string
---@param revset string
---@param template string
---@return review.JjResult
function M.log(root, revset, template)
  return M.run(root, { "log", "-r", revset, "--no-graph", "-T", template })
end

return M
