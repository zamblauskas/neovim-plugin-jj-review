-- Coroutine async/await. Async code reads as a list of steps:
--   async.run(function() local result = jj.op_id(root) ... end)

local M = {}

---@type table<thread, fun(...)>
local resumers = setmetatable({}, { __mode = "k" })

---@param err string
local function report(err)
  vim.notify("review: " .. err, vim.log.levels.ERROR)
end

--- Run `fn` in a new coroutine. `on_error` gets the traceback if `fn` fails.
---@param fn fun()
---@param on_error? fun(err: string)
function M.run(fn, on_error)
  local co = coroutine.create(fn)
  local function step(...)
    local ok, err = coroutine.resume(co, ...)
    if not ok then
      (on_error or report)(debug.traceback(co, err))
    end
  end
  resumers[co] = step
  step()
end

--- Wait for a callback-style operation. `start` gets a `done` callback.
--- The arguments of `done` become the return values. `done` can be called synchronously.
---@param start fun(done: fun(...))
---@return ...
function M.await(start)
  local step = resumers[coroutine.running()]
  assert(step, "async.await called outside async.run")
  local sync_result, waiting = nil, false
  start(function(...)
    if waiting then
      step(...)
    else
      sync_result = vim.F.pack_len(...)
    end
  end)
  if sync_result then
    return vim.F.unpack_len(sync_result)
  end
  waiting = true
  return coroutine.yield()
end

return M
