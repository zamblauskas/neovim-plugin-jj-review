-- Explorer view: state → lines and highlights. Pure.
-- A row is a list of chunks { text, hl_group? }. `render` joins chunks and computes byte ranges.

local file_tree = require("review.core.file_tree")
local folds = require("review.core.folds")

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
---@field targets? table<integer, review.ExplorerTarget>  -- by 1-based line

---@class review.ExplorerEntry
---@field chunks review.Row
---@field target? review.ExplorerTarget

local TREE_INDENT = "    "

--- File status → letter and highlight group.
local STATUS = {
  added = { "A", "ReviewStatusAdded" },
  modified = { "M", "ReviewStatusModified" },
  deleted = { "D", "ReviewStatusDeleted" },
  renamed = { "R", "ReviewStatusRenamed" },
  copied = { "C", "ReviewStatusRenamed" },
}

local ERROR_TITLES = {
  not_linear = "Stack is not linear",
  merge = "Stack has a merge revision",
  jj_failed = "jj failed",
}

---@param rev review.Revision
---@param open boolean
---@return review.Row
local function revision_row(rev, open)
  local rest = rev.short_id:sub(#rev.id_prefix + 1)
  local description = rev.description ~= "" and { rev.description } or { "(no description)", "ReviewDim" }
  return {
    { open and "▾ " or "▸ ", "ReviewFold" },
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

--- Entries without a target.
---@param rows review.Row[]
---@return review.ExplorerEntry[]
local function plain(rows)
  return vim.tbl_map(function(row)
    return { chunks = row }
  end, rows)
end

---@param file review.FileDiff
---@return review.Chunk[]
local function file_suffix(file)
  local suffix = {}
  if file.old_path then
    table.insert(suffix, { " ← " .. file.old_path, "ReviewDim" })
  end
  if file.binary then
    table.insert(suffix, { " (binary)", "ReviewDim" })
  end
  return suffix
end

---@param entry review.TreeEntry
---@param change_id string
---@return review.ExplorerEntry
local function tree_entry(entry, change_id)
  local indent = TREE_INDENT .. string.rep("  ", entry.depth)
  if entry.type == "dir" then
    return { chunks = { { indent }, { entry.name, "ReviewDirectory" } } }
  end
  local file = assert(entry.file, "file entry")
  local status = STATUS[file.status]
  local chunks = { { indent }, { status[1] .. " ", status[2] }, { entry.name } }
  return {
    chunks = vim.list_extend(chunks, file_suffix(file)),
    target = { type = "file", change_id = change_id, path = file.path },
  }
end

--- Rows under an open revision: its file tree, or "Loading…" while the diff loads.
---@param state review.State
---@param rev review.Revision
---@return review.ExplorerEntry[]
local function file_entries(state, rev)
  local files = state.diffs[rev.commit_id]
  if not files then
    return plain({ { { TREE_INDENT .. "Loading…", "ReviewDim" } } })
  end
  return vim.tbl_map(function(entry)
    return tree_entry(entry, rev.change_id)
  end, file_tree.build(files))
end

---@param state review.State
---@param revisions review.Revision[]
---@return review.ExplorerEntry[]
local function revision_entries(state, revisions)
  local entries = {}
  for _, rev in ipairs(revisions) do
    local open = folds.is_open(state.folds, revisions, rev.change_id)
    table.insert(
      entries,
      { chunks = revision_row(rev, open), target = { type = "revision", change_id = rev.change_id } }
    )
    if open then
      vim.list_extend(entries, file_entries(state, rev))
    end
  end
  return entries
end

---@param state review.State
---@return review.ExplorerEntry[]
local function body_entries(state)
  local stack = state.stack
  if stack.type == "loading" then
    return plain({ { { "Loading…", "ReviewDim" } } })
  elseif stack.type == "error" then
    return plain(error_rows(stack))
  elseif #stack.revisions == 0 then
    return plain({ { { "Nothing to review", "ReviewDim" } } })
  end
  return revision_entries(state, stack.revisions)
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
  local entries = vim.list_extend(plain(header_rows(state)), body_entries(state))
  local view = { lines = {}, highlights = {}, targets = {} }
  for i, entry in ipairs(entries) do
    local text, highlights = flatten(entry.chunks, i - 1)
    table.insert(view.lines, text)
    vim.list_extend(view.highlights, highlights)
    view.targets[i] = entry.target
  end
  return view
end

return M
