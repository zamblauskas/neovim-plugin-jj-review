-- Counting semaphore: run at most `limit` async tasks at once. Later tasks wait in a queue (FIFO).

local async = require("review.shell.lib.async")

local M = {}

---@class review.lib.SemaphoreTask
---@field fn fun()
---@field on_error? fun(err: string)

---@class review.lib.Semaphore
---@field limit integer
---@field active integer
---@field queue review.lib.SemaphoreTask[]
local Semaphore = {}
Semaphore.__index = Semaphore

---@param task review.lib.SemaphoreTask
function Semaphore:start(task)
  self.active = self.active + 1
  async.run(function()
    task.fn()
    self:finish()
  end, function(err)
    self:finish();
    (task.on_error or error)(err)
  end)
end

function Semaphore:finish()
  self.active = self.active - 1
  local next_task = table.remove(self.queue, 1)
  if next_task then
    self:start(next_task)
  end
end

---@param task review.lib.SemaphoreTask
function Semaphore:submit(task)
  if self.active < self.limit then
    self:start(task)
  else
    table.insert(self.queue, task)
  end
end

--- Make a runner with the same signature as `async.run`, limited to `limit` tasks at once.
---@param limit integer
---@return fun(fn: fun(), on_error?: fun(err: string))
function M.new(limit)
  local semaphore = setmetatable({ limit = limit, active = 0, queue = {} }, Semaphore)
  return function(fn, on_error)
    semaphore:submit({ fn = fn, on_error = on_error })
  end
end

return M
