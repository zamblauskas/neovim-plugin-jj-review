-- Explorer view: state → lines and highlights. Pure.
-- A row is a list of chunks { text, hl_group? }. `render` joins chunks and computes byte ranges.

local M = {}

---@alias review.Chunk { [1]: string, [2]: string? }
---@alias review.Row review.Chunk[]

---@class review.Highlight
---@field row integer       -- 0-based
---@field col_start integer -- byte
---@field col_end integer   -- byte, exclusive
---@field group string

---@class review.View
---@field lines string[]
---@field highlights review.Highlight[]

local ERROR_TITLES = {
  not_linear = "Stack is not linear",
  merge = "Stack has a merge revision",
  jj_failed = "jj failed",
}

---@param rev review.Revision
---@return review.Row
local function revision_row(rev)
  local rest = rev.short_id:sub(#rev.id_prefix + 1)
  local description = rev.description ~= "" and { rev.description } or { "(no description)", "ReviewDim" }
  return {
    { rev.working_copy and "◆ " or "  ", "ReviewWorkingCopy" },
    { rev.id_prefix, "ReviewChangeId" },
    { rest, "ReviewChangeIdRest" },
    { ": " },
    description,
  }
end

---@param state review.State
---@return review.Row[]
local function header_rows(state)
  local count = state.stack.type == "ok" and (" (" .. #state.stack.revisions .. ")") or ""
  return {
    { { "Stack" .. count, "ReviewHeader" } },
    { { "revset: " .. state.revset, "ReviewDim" } },
    {},
  }
end

---@param stack review.StackError
---@return review.Row[]
local function error_rows(stack)
  local rows = { { { "✖ " .. ERROR_TITLES[stack.reason], "ReviewError" } } }
  if stack.revisions then
    table.insert(rows, { { "  revisions: " .. table.concat(stack.revisions, ", ") } })
  end
  for _, line in ipairs(vim.split(stack.detail or "", "\n", { trimempty = true })) do
    table.insert(rows, { { "  " .. line, "ReviewDim" } })
  end
  return rows
end

---@param stack review.Stack
---@return review.Row[]
local function body_rows(stack)
  if stack.type == "loading" then
    return { { { "Loading…", "ReviewDim" } } }
  elseif stack.type == "error" then
    return error_rows(stack)
  elseif #stack.revisions == 0 then
    return { { { "Nothing to review", "ReviewDim" } } }
  end
  return vim.tbl_map(revision_row, stack.revisions)
end

---@param row review.Row
---@param index integer 0-based row
---@return string, review.Highlight[]
local function flatten(row, index)
  local text, highlights = "", {}
  for _, chunk in ipairs(row) do
    if chunk[2] then
      table.insert(highlights, { row = index, col_start = #text, col_end = #text + #chunk[1], group = chunk[2] })
    end
    text = text .. chunk[1]
  end
  return text, highlights
end

---@param state review.State
---@return review.View
function M.render(state)
  local rows = vim.list_extend(header_rows(state), body_rows(state.stack))
  local view = { lines = {}, highlights = {} }
  for i, row in ipairs(rows) do
    local text, highlights = flatten(row, i - 1)
    table.insert(view.lines, text)
    vim.list_extend(view.highlights, highlights)
  end
  return view
end

return M
