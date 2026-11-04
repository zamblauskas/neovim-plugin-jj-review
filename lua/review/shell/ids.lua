-- Id port: new comment ids.

local M = {}

local counter = 0

--- New comment id, for example "c-7f3a09b2". Unique enough for one repo.
---@return string
function M.comment_id()
  counter = counter + 1
  local seed = table.concat({ vim.uv.hrtime(), vim.uv.os_getpid(), counter, math.random() }, ":")
  return "c-" .. vim.fn.sha256(seed):sub(1, 8)
end

return M
