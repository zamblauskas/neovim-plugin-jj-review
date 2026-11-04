-- Scheduling helpers on the Neovim event loop.

local M = {}

--- Wrap `fn` so that many calls in one event-loop tick cause one call of `fn` on the next tick.
--- That call gets the arguments of the first call in the tick.
---@param fn fun(...)
---@return fun(...)
function M.once_per_tick(fn)
  local pending = false
  return function(...)
    if pending then
      return
    end
    pending = true
    local args = vim.F.pack_len(...)
    vim.schedule(function()
      pending = false
      fn(vim.F.unpack_len(args))
    end)
  end
end

return M
