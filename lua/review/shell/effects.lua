-- Effect interpreter: runs effect descriptions through ports, dispatches result messages.

local async = require("review.shell.async")
local log = require("review.parse.log")
local msg = require("review.core.msg")

local M = {}

---@class review.Ports
---@field jj table           -- review.shell.jj
---@field explorer table     -- review.shell.explorer

--- Call `render(state)` at most once per event-loop tick.
---@param render fun(state: review.State)
---@return fun(effect: review.Effect, app: review.App)
local function batched(render)
  local pending = false
  return function(_, app)
    if pending then
      return
    end
    pending = true
    vim.schedule(function()
      pending = false
      render(app.state())
    end)
  end
end

--- Handler that runs a JJ query and dispatches the message made from its result.
---@param query fun(e: table): review.JjResult
---@param to_msg fun(generation: integer, result: review.JjResult): review.Msg
---@return fun(effect: review.Effect, app: review.App)
local function jj_effect(query, to_msg)
  return function(e, app)
    async.run(function()
      app.dispatch(to_msg(e.generation, query(e)))
    end)
  end
end

--- Result → message with the trimmed stdout, or JjFailed.
---@param ok_msg fun(generation: integer, value: string): review.Msg
---@return fun(generation: integer, result: review.JjResult): review.Msg
local function trimmed(ok_msg)
  return function(generation, result)
    if not result.ok then
      return msg.jj_failed(generation, result.stderr)
    end
    return ok_msg(generation, vim.trim(result.stdout))
  end
end

--- Message for a `jj log` result.
---@param generation integer
---@param result review.JjResult
---@return review.Msg
function M.stack_result(generation, result)
  if not result.ok then
    return msg.jj_failed(generation, result.stderr)
  end
  local revisions, bad_line = log.parse(result.stdout)
  if not revisions then
    return msg.jj_failed(generation, "unexpected jj log output: " .. tostring(bad_line))
  end
  return msg.stack_loaded(generation, revisions)
end

---@param ports review.Ports
---@return table<string, fun(effect: review.Effect, app: review.App)>
local function jj_handlers(ports)
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
---@return table<string, fun(effect: review.Effect, app: review.App)>
local function ui_handlers(ports)
  return {
    OpenExplorer = function(_, app)
      ports.explorer.open(app)
    end,
    CloseExplorer = function()
      ports.explorer.close()
    end,
    RenderExplorer = batched(function(state)
      ports.explorer.render(state)
    end),
  }
end

--- Build the interpreter for the given ports.
---@param ports review.Ports
---@return review.Interpreter
function M.new(ports)
  local handlers = vim.tbl_extend("error", jj_handlers(ports), ui_handlers(ports))
  return function(effect, app)
    handlers[effect.type](effect, app)
  end
end

return M
