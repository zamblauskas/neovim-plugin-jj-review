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

--- Copy of `t` without `key` (shallow). `t` is not changed.
---@generic T: table
---@param t T
---@param key any
---@return T
function M.without(t, key)
  local out = vim.tbl_extend("force", {}, t)
  out[key] = nil
  return out
end

return M
