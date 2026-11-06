-- Rows of chunks → buffer lines and highlights. Pure. Shared by the explorer and help views.
-- A row is a list of chunks { text, hl_group? }.

local M = {}

---@alias review.Chunk { [1]: string, [2]: string? }
---@alias review.Row review.Chunk[]

---@class review.Highlight
---@field row integer       -- 0-based
---@field col_start integer -- byte
---@field col_end integer   -- byte, exclusive
---@field group string
---@field line? boolean     -- the whole line, to the window edge (col_start and col_end are not used)

---@class review.View
---@field lines string[]
---@field highlights review.Highlight[]
---@field targets? table<integer, review.ExplorerTarget>  -- by 1-based line

--- Join the chunks of a row; highlights by byte range.
---@param row review.Row
---@param index integer 0-based row
---@return string, review.Highlight[]
function M.flatten(row, index)
  local text, highlights = "", {}
  for _, chunk in ipairs(row) do
    if chunk[2] then
      table.insert(highlights, { row = index, col_start = #text, col_end = #text + #chunk[1], group = chunk[2] })
    end
    text = text .. chunk[1]
  end
  return text, highlights
end

---@param rows review.Row[]
---@return review.View
function M.render(rows)
  local view = { lines = {}, highlights = {} }
  for i, row in ipairs(rows) do
    local text, highlights = M.flatten(row, i - 1)
    table.insert(view.lines, text)
    vim.list_extend(view.highlights, highlights)
  end
  return view
end

return M
