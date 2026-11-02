-- Pure table helpers. No dependency on core or shell.

local M = {}

--- Copy of `t` with `changes` applied (shallow). `t` is not changed.
--- A `nil` value in `changes` cannot clear a field: Lua tables do not hold `nil`.
---@generic T: table
---@param t T
---@param changes table
---@return T
function M.with(t, changes)
  return vim.tbl_extend("force", t, changes)
end

return M
