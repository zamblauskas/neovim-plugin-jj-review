-- Pure text helpers measured in display columns.

local M = {}

---@param text string
---@return integer
function M.width(text)
  return vim.fn.strdisplaywidth(text)
end

--- `text` cut to at most `width` columns. A cut text ends with "…".
---@param text string
---@param width integer
---@return string
function M.truncate(text, width)
  if M.width(text) <= width then
    return text
  end
  local out = ""
  for _, char in ipairs(vim.fn.split(text, "\\zs")) do
    if M.width(out .. char) > width - 1 then
      break
    end
    out = out .. char
  end
  return out .. "…"
end

return M
