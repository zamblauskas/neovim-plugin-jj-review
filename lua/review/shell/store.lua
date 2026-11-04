-- Store port: review state in `<root>/.jj/review/marks.json`. JJ never snapshots `.jj/`.
-- Each save reads the file again, applies the patch, and writes with write-to-temp + rename (atomic).
-- A file with an unknown version is never written.

local toggle = require("review.core.toggle")

local M = {}

local VERSION = 1

---@param root string
---@return string
function M.marks_path(root)
  return root .. "/.jj/review/marks.json"
end

--- File content, or nil if the file does not exist.
---@param path string
---@return string?
local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local text = fd:read("*a")
  fd:close()
  return text
end

--- Marks from the file content. No file → no marks.
---@param text string?
---@return review.Marks?, string?
local function decode(text)
  if text == nil then
    return {}
  end
  local ok, doc = pcall(vim.json.decode, text)
  if not ok or type(doc) ~= "table" then
    return nil, "marks.json is not valid JSON"
  elseif doc.version ~= VERSION then
    return nil, "marks.json has an unknown version (" .. tostring(doc.version) .. "): not written"
  end
  return type(doc.marks) == "table" and doc.marks or {}
end

---@param marks review.Marks
---@return string
local function encode(marks)
  local doc = { version = VERSION, marks = next(marks) and marks or vim.empty_dict() }
  return vim.json.encode(doc, { indent = "  ", sort_keys = true }) .. "\n"
end

---@param path string
---@param text string
---@return boolean, string?
local function write_atomic(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local tmp = path .. ".tmp." .. vim.uv.os_getpid()
  local fd, open_err = io.open(tmp, "w")
  if not fd then
    return false, open_err
  end
  fd:write(text)
  fd:close()
  local ok, rename_err = vim.uv.fs_rename(tmp, path)
  return ok == true, rename_err
end

---@param root string
---@return review.Marks?, string?
function M.load_marks(root)
  return decode(read_file(M.marks_path(root)))
end

--- Read the file again, apply the patch, write. Errors if the file cannot be read or has an unknown version.
---@param root string
---@param patch review.MarkPatch
---@return boolean, string?
function M.save_marks(root, patch)
  local path = M.marks_path(root)
  local marks, err = decode(read_file(path))
  if not marks then
    return false, err
  end
  return write_atomic(path, encode(toggle.apply(marks, patch)))
end

return M
