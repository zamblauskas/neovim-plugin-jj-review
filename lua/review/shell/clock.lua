-- Clock port.

local M = {}

--- Current time, ISO 8601 UTC.
---@return string
function M.now()
  return tostring(os.date("!%Y-%m-%dT%H:%M:%SZ"))
end

return M
