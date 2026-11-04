-- JJ port. Reads never snapshot the working copy, so they never create an operation.
-- Only `snapshot` and `edit` write (and snapshot): they run without --ignore-working-copy.
-- All functions except `run_cb` must be called inside `async.run`.

local async = require("review.shell.lib.async")

local M = {}

---@class review.JjResult
---@field ok boolean
---@field stdout string
---@field stderr string
---@field args string[]

local GLOBAL_ARGS = { "--no-pager", "--color=never" }
local READ_ARGS = { "--ignore-working-copy" }

---@param args string[]
---@param write boolean
---@return string[]
local function command(args, write)
  local base = vim.list_extend({ "jj" }, GLOBAL_ARGS)
  return vim.list_extend(write and base or vim.list_extend(base, READ_ARGS), args)
end

---@param args string[]
---@param obj vim.SystemCompleted
---@return review.JjResult
local function to_result(args, obj)
  return { ok = obj.code == 0, stdout = obj.stdout or "", stderr = obj.stderr or "", args = args }
end

--- Run jj in `cwd`, callback style. `done` runs in the main loop (API calls are safe).
--- `write`: may snapshot the working copy (no --ignore-working-copy).
---@param cwd string
---@param args string[]
---@param done fun(result: review.JjResult)
---@param write? boolean
function M.run_cb(cwd, args, done, write)
  local on_exit = vim.schedule_wrap(function(obj)
    done(to_result(args, obj))
  end)
  local ok, err = pcall(vim.system, command(args, write or false), { cwd = cwd, text = true }, on_exit)
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

--- Diff of one revision. Whitespace changes are ignored. 2 context lines are enough for line keys.
---@param root string
---@param commit_id string
---@return review.JjResult
function M.diff(root, commit_id)
  return M.run(root, { "diff", "-r", commit_id, "--git", "-w", "--context", "2" })
end

--- Literal root-relative path as a fileset. A bare path is parsed as a fileset expression and fails on `"`.
---@param path string
---@return string
local function root_file(path)
  return 'root-file:"' .. path:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

--- Content of a file in a revision.
---@param root string
---@param commit_id string
---@param path string  root-relative
---@return review.JjResult
function M.file_show(root, commit_id, path)
  return M.run(root, { "file", "show", "-r", commit_id, "--", root_file(path) })
end

--- Run a command that writes (snapshots the working copy).
---@param cwd string
---@param args string[]
---@return review.JjResult
local function run_write(cwd, args)
  return async.await(function(done)
    M.run_cb(cwd, args, done, true)
  end)
end

--- Snapshot the working copy (after a save).
---@param root string
---@return review.JjResult
function M.snapshot(root)
  return run_write(root, { "util", "snapshot" })
end

--- Make the revision the working copy.
---@param root string
---@param change_id string
---@return review.JjResult
function M.edit(root, change_id)
  return run_write(root, { "edit", change_id })
end

return M
