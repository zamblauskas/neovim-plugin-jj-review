-- Pure list helpers. No dependency on core or shell.

local M = {}

--- Value of field `key` of each item, in order.
---@param items table[]
---@param key string
---@return any[]
function M.pluck(items, key)
  return vim.tbl_map(function(item)
    return item[key]
  end, items)
end

--- Map from the value of field `key` to the item. A later item with the same key wins.
---@generic T: table
---@param items T[]
---@param key string
---@return table<any, T>
function M.index_by(items, key)
  local index = {}
  for _, item in ipairs(items) do
    index[item[key]] = item
  end
  return index
end

return M
