-- Parse `jj diff --git` output into file diffs.
-- jj does not quote paths. Without a rename or copy, `diff --git a/P b/P` has two equal halves.

local M = {}

---@alias review.FileStatus "added"|"modified"|"deleted"|"renamed"|"copied"

---@class review.DiffLine
---@field kind " "|"+"|"-"
---@field text string
---@field no_eol? true  -- "\ No newline at end of file" follows this line

---@class review.Hunk
---@field old_start integer
---@field old_count integer
---@field new_start integer
---@field new_count integer
---@field lines review.DiffLine[]

---@class review.FileDiff
---@field status review.FileStatus
---@field path string        -- new path (old path for a deleted file)
---@field old_path? string   -- renamed or copied only
---@field binary boolean
---@field hunks review.Hunk[]

local FILE_START = "diff --git "

--- Header line prefix → header field. A field gets the rest of the line as value.
local HEADER_FIELDS = {
  ["new file mode "] = "new_file",
  ["deleted file mode "] = "deleted_file",
  ["rename from "] = "rename_from",
  ["rename to "] = "rename_to",
  ["copy from "] = "copy_from",
  ["copy to "] = "copy_to",
  ["Binary files "] = "binary",
}

---@param line string
---@param prefix string
---@return boolean
local function starts_with(line, prefix)
  return line:sub(1, #prefix) == prefix
end

--- Split lines into one list per file. Lines before the first file header are dropped.
---@param lines string[]
---@return string[][]
local function split_files(lines)
  local files = {}
  for _, line in ipairs(lines) do
    if starts_with(line, FILE_START) then
      table.insert(files, {})
    end
    if #files > 0 then
      table.insert(files[#files], line)
    end
  end
  return files
end

--- Path from `diff --git a/P b/P` (both halves equal).
---@param first_line string
---@return string
local function header_path(first_line)
  local rest = first_line:sub(#FILE_START + 1)
  return rest:sub(3, (#rest - 1) / 2)
end

--- Header fields found in the header lines.
---@param header_lines string[]
---@return table<string, string>
local function header_fields(header_lines)
  local fields = {}
  for _, line in ipairs(header_lines) do
    for prefix, field in pairs(HEADER_FIELDS) do
      if starts_with(line, prefix) then
        fields[field] = line:sub(#prefix + 1)
      end
    end
  end
  return fields
end

---@param fields table<string, string>
---@return review.FileStatus
local function status_of(fields)
  if fields.new_file then
    return "added"
  elseif fields.deleted_file then
    return "deleted"
  elseif fields.rename_to then
    return "renamed"
  elseif fields.copy_to then
    return "copied"
  end
  return "modified"
end

---@param header_lines string[]
---@return review.FileDiff
local function parse_header(header_lines)
  local fields = header_fields(header_lines)
  return {
    status = status_of(fields),
    path = fields.rename_to or fields.copy_to or header_path(header_lines[1]),
    old_path = fields.rename_from or fields.copy_from,
    binary = fields.binary ~= nil,
    hunks = {},
  }
end

---@param line string
---@return review.Hunk?
local function parse_hunk_header(line)
  local old_start, old_count, new_start, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
  if not old_start then
    return nil
  end
  return {
    old_start = tonumber(old_start),
    old_count = tonumber(old_count) or 1,
    new_start = tonumber(new_start),
    new_count = tonumber(new_count) or 1,
    lines = {},
  }
end

--- Add one body line to the hunk. The no-newline marker flags the line before it.
---@param hunk review.Hunk
---@param line string
local function add_hunk_line(hunk, line)
  if starts_with(line, "\\") then
    local last = hunk.lines[#hunk.lines]
    if last then
      last.no_eol = true
    end
    return
  end
  table.insert(hunk.lines, { kind = line:sub(1, 1), text = line:sub(2) })
end

---@param body_lines string[]
---@return review.Hunk[]
local function parse_hunks(body_lines)
  local hunks = {}
  for _, line in ipairs(body_lines) do
    local hunk = parse_hunk_header(line)
    if hunk then
      table.insert(hunks, hunk)
    elseif #hunks > 0 then
      add_hunk_line(hunks[#hunks], line)
    end
  end
  return hunks
end

---@param file_lines string[]
---@return review.FileDiff
local function parse_file(file_lines)
  local first_hunk = #file_lines + 1
  for i, line in ipairs(file_lines) do
    if starts_with(line, "@@ ") then
      first_hunk = i
      break
    end
  end
  local file = parse_header(vim.list_slice(file_lines, 1, first_hunk - 1))
  file.hunks = parse_hunks(vim.list_slice(file_lines, first_hunk))
  return file
end

--- Parse the output of `jj diff --git`. Files are in jj order.
---@param stdout string
---@return review.FileDiff[]
function M.parse(stdout)
  local lines = vim.split(stdout, "\n", { plain = true, trimempty = true })
  return vim.tbl_map(parse_file, split_files(lines))
end

return M
