-- Parse `jj log` output made with `M.TEMPLATE`. The template and the parser must change together.

local M = {}

local SEP = "\0"

---@class review.Revision
---@field change_id string
---@field short_id string      -- shortest unique prefix, at least 4 characters
---@field id_prefix string     -- shortest unique prefix (for highlight)
---@field commit_id string
---@field parents string[]     -- parent commit ids
---@field empty boolean
---@field working_copy boolean
---@field description string   -- first line

M.TEMPLATE = table.concat({
  "change_id",
  "change_id.shortest(4)",
  "change_id.shortest(4).prefix()",
  "commit_id",
  'parents.map(|p| p.commit_id()).join(",")',
  'if(empty, "1", "0")',
  'if(current_working_copy, "1", "0")',
  "description.first_line()",
}, ' ++ "\\0" ++ ') .. ' ++ "\\n"'

local FIELD_COUNT = 8

---@param line string
---@return review.Revision?
local function parse_line(line)
  local f = vim.split(line, SEP, { plain = true })
  if #f ~= FIELD_COUNT then
    return nil
  end
  return {
    change_id = f[1],
    short_id = f[2],
    id_prefix = f[3],
    commit_id = f[4],
    parents = vim.split(f[5], ",", { plain = true, trimempty = true }),
    empty = f[6] == "1",
    working_copy = f[7] == "1",
    description = f[8],
  }
end

--- Parse log output. Returns nil and the bad line if a line does not match the template.
---@param stdout string
---@return review.Revision[]?, string?
function M.parse(stdout)
  local lines = vim.split(stdout, "\n", { plain = true, trimempty = true })
  local revisions = vim.tbl_map(parse_line, lines)
  for i, line in ipairs(lines) do
    if revisions[i] == nil then
      return nil, line
    end
  end
  return revisions
end

return M
