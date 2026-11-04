-- Effect interpreter: runs effect descriptions through ports, dispatches result messages.

local async = require("review.shell.lib.async")
local diff = require("review.parse.diff")
local log = require("review.parse.log")
local msg = require("review.core.msg")
local schedule = require("review.shell.lib.schedule")
local semaphore = require("review.shell.lib.semaphore")

local M = {}

---@class review.Ports
---@field jj table           -- review.shell.jj
---@field explorer table     -- review.shell.explorer
---@field layout table       -- review.shell.layout
---@field diff table         -- review.shell.diff
---@field store table        -- review.shell.store
---@field watcher table      -- review.shell.watcher
---@field comment_input table -- review.shell.comment_input
---@field ids table          -- review.shell.ids
---@field clock table        -- review.shell.clock

---@param err string
local function notify_error(err)
  vim.notify("review: " .. err, vim.log.levels.ERROR)
end

---@alias review.AsyncRunner fun(fn: fun(), on_error?: fun(err: string))

--- Handler that runs a JJ query and dispatches the message made from its result.
---@param query fun(e: table): review.JjResult
---@param to_msg fun(e: table, result: review.JjResult): review.Msg
---@param runner? review.AsyncRunner  default: async.run (no limit)
---@return fun(effect: review.Effect, app: review.App)
local function jj_effect(query, to_msg, runner)
  return function(e, app)
    (runner or async.run)(function()
      app.dispatch(to_msg(e, query(e)))
    end, notify_error)
  end
end

--- Result → message with the trimmed stdout, or JjFailed.
---@param ok_msg fun(generation: integer, value: string): review.Msg
---@return fun(e: table, result: review.JjResult): review.Msg
local function trimmed(ok_msg)
  return function(e, result)
    if not result.ok then
      return msg.jj_failed(e.generation, result.stderr)
    end
    return ok_msg(e.generation, vim.trim(result.stdout))
  end
end

--- Message for a `jj diff` result.
---@param e review.Effect.LoadDiff
---@param result review.JjResult
---@return review.Msg
function M.diff_result(e, result)
  if not result.ok then
    return msg.jj_failed(e.generation, result.stderr)
  end
  return msg.diff_loaded(e.generation, e.commit_id, diff.parse(result.stdout))
end

--- Message for a `jj log` result.
---@param e review.Effect.LoadStack
---@param result review.JjResult
---@return review.Msg
function M.stack_result(e, result)
  if not result.ok then
    return msg.jj_failed(e.generation, result.stderr)
  end
  local revisions, bad_line = log.parse(result.stdout)
  if not revisions then
    return msg.jj_failed(e.generation, "unexpected jj log output: " .. tostring(bad_line))
  end
  return msg.stack_loaded(e.generation, revisions)
end

--- Lines of a file content. A final newline does not make an extra empty line.
---@param text string
---@return string[]
local function text_lines(text)
  local lines = vim.split(text, "\n", { plain = true })
  if #lines > 1 and lines[#lines] == "" then
    table.remove(lines)
  end
  return lines
end

--- Message for a `jj file show` result.
---@param e review.Effect.LoadContent
---@param result review.JjResult
---@return review.Msg
function M.content_result(e, result)
  if not result.ok then
    return msg.jj_failed(e.generation, result.stderr)
  end
  return msg.content_loaded(e.generation, e.commit_id, e.path, text_lines(result.stdout))
end

---@param ports review.Ports
---@return table<string, fun(effect: review.Effect, app: review.App)>
local function repo_handlers(ports)
  return {
    ResolveRoot = jj_effect(function(e)
      return ports.jj.root(e.cwd)
    end, trimmed(msg.root_resolved)),
    CheckOp = jj_effect(function(e)
      return ports.jj.op_id(e.root)
    end, trimmed(msg.op_checked)),
    LoadStack = jj_effect(function(e)
      return ports.jj.log(e.root, e.revset, log.TEMPLATE)
    end, M.stack_result),
  }
end

---@param ports review.Ports
---@param opts review.InterpreterOpts
---@return table<string, fun(effect: review.Effect, app: review.App)>
local function revision_handlers(ports, opts)
  return {
    LoadDiff = jj_effect(function(e)
      return ports.jj.diff(e.root, e.commit_id)
    end, M.diff_result, semaphore.new(opts.max_parallel_jj)),
    LoadContent = jj_effect(function(e)
      return ports.jj.file_show(e.root, e.commit_id, e.path)
    end, M.content_result),
  }
end

local NOTIFY_LEVELS = { info = vim.log.levels.INFO, warn = vim.log.levels.WARN, error = vim.log.levels.ERROR }

--- Dispatch on the next tick, so a result never runs inside the dispatch that asked for it.
---@param app review.App
---@param message review.Msg
local function dispatch_later(app, message)
  vim.schedule(function()
    app.dispatch(message)
  end)
end

--- Handler for a store write. A failure becomes StoreFailed.
---@param write fun(e: table): boolean, string?
---@return fun(effect: review.Effect, app: review.App)
local function store_write(write)
  return function(e, app)
    local ok, err = write(e)
    if not ok then
      dispatch_later(app, msg.store_failed(e.generation, "store: " .. tostring(err)))
    end
  end
end

---@param ports review.Ports
---@return table<string, fun(effect: review.Effect, app: review.App)>
local function store_handlers(ports)
  return {
    LoadStore = function(e, app)
      local data, err = ports.store.load(e.root)
      local message = data and msg.store_loaded(e.generation, data.marks, data.comments)
      dispatch_later(app, message or msg.store_failed(e.generation, tostring(err)))
    end,
    SaveMarks = store_write(function(e)
      return ports.store.save_marks(e.root, e.patch)
    end),
    ClearStore = store_write(function(e)
      return ports.store.clear(e.root)
    end),
    SaveComments = store_write(function(e)
      return ports.store.save_comments(e.root, e.patch)
    end),
  }
end

---@param ports review.Ports
---@return table<string, fun(effect: review.Effect, app: review.App)>
local function watcher_handlers(ports)
  return {
    StartWatcher = function(e, app)
      local ok, err = ports.watcher.start(e.root, function()
        app.dispatch(msg.refresh_requested(e.generation))
      end)
      if not ok then
        vim.notify("review: no auto-refresh on jj changes, only on focus: " .. tostring(err), vim.log.levels.WARN)
      end
    end,
    StopWatcher = function()
      ports.watcher.stop()
    end,
    Notify = function(e)
      vim.notify("review: " .. e.text, NOTIFY_LEVELS[e.level])
    end,
  }
end

---@param ports review.Ports
---@return table<string, fun(effect: review.Effect, app: review.App)>
local function tab_handlers(ports)
  return {
    OpenTab = function(_, app)
      ports.layout.open(app)
    end,
    CloseTab = function()
      ports.layout.close()
      ports.diff.close()
    end,
    RenderExplorer = schedule.once_per_tick(function(_, app)
      ports.explorer.render(app.state())
    end),
  }
end

---@param ports review.Ports
---@return table<string, fun(effect: review.Effect, app: review.App)>
local function diff_handlers(ports)
  return {
    OpenBuffer = function(e, app)
      ports.diff.open(e, app)
    end,
    CloseDiff = function()
      ports.diff.close_file()
    end,
    OpenCommentInput = function(e, app)
      ports.comment_input.open(e.title, function(text)
        app.dispatch(msg.comment_submitted(e.draft, text, ports.ids.comment_id(), ports.clock.now()))
      end)
    end,
    MoveCursor = function(e)
      vim.api.nvim_win_set_cursor(0, { e.line, 0 })
    end,
    RenderDiff = schedule.once_per_tick(function(_, app)
      ports.diff.render(app.state())
    end),
  }
end

---@class review.InterpreterOpts
---@field max_parallel_jj integer

--- Build the interpreter for the given ports.
---@param ports review.Ports
---@param opts? review.InterpreterOpts
---@return review.Interpreter
function M.new(ports, opts)
  local handlers = vim.tbl_extend(
    "error",
    repo_handlers(ports),
    revision_handlers(ports, opts or { max_parallel_jj = 4 }),
    store_handlers(ports),
    watcher_handlers(ports),
    tab_handlers(ports),
    diff_handlers(ports)
  )
  return function(effect, app)
    handlers[effect.type](effect, app)
  end
end

return M
