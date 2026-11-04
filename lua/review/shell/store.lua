-- Store port: review state in `<root>/.jj/review/` (marks.json, comments.json). JJ never snapshots `.jj/`.
-- Each write reads the file again, applies the change, and writes with write-to-temp + rename (atomic).
-- A file with an unknown version is never written.

local comments = require("review.core.comments")
local toggle = require("review.core.toggle")

local M = {}

local VERSION = 1

---@class review.StoreDoc
---@field file string
---@field field string        -- field of the document that holds the data
---@field empty fun(): table  -- empty data (an object for marks, a list for comments)

---@type review.StoreDoc
local MARKS = { file = "marks.json", field = "marks", empty = vim.empty_dict }
---@type review.StoreDoc
local COMMENTS = {
  file = "comments.json",
  field = "comments",
  empty = function()
    return {}
  end,
}

---@param root string
---@param doc review.StoreDoc
---@return string
local function path_of(root, doc)
  return root .. "/.jj/review/" .. doc.file
end

---@param root string
---@return string
function M.marks_path(root)
  return path_of(root, MARKS)
end

---@param root string
---@return string
function M.comments_path(root)
  return path_of(root, COMMENTS)
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

--- Data from the file content. No file → empty data.
---@param doc review.StoreDoc
---@param text string?
---@return table?, string?
local function decode(doc, text)
  if text == nil then
    return doc.empty()
  end
  local ok, value = pcall(vim.json.decode, text)
  if not ok or type(value) ~= "table" then
    return nil, doc.file .. " is not valid JSON"
  elseif value.version ~= VERSION then
    return nil, doc.file .. " has an unknown version (" .. tostring(value.version) .. "): not written"
  end
  return type(value[doc.field]) == "table" and value[doc.field] or doc.empty()
end

---@param doc review.StoreDoc
---@param data table
---@return string
local function encode(doc, data)
  local value = { version = VERSION, [doc.field] = next(data) and data or doc.empty() }
  return vim.json.encode(value, { indent = "  ", sort_keys = true }) .. "\n"
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

--- Read the file again, change the data, write (read-merge-write).
---@param root string
---@param doc review.StoreDoc
---@param change fun(data: table): table
---@return boolean, string?
local function update(root, doc, change)
  local path = path_of(root, doc)
  local data, err = decode(doc, read_file(path))
  if not data then
    return false, err
  end
  return write_atomic(path, encode(doc, change(data)))
end

---@class review.StoreData
---@field marks review.Marks
---@field comments review.Comment[]

---@param root string
---@return review.StoreData?, string?
function M.load(root)
  local marks, marks_err = decode(MARKS, read_file(path_of(root, MARKS)))
  local list, comments_err = decode(COMMENTS, read_file(path_of(root, COMMENTS)))
  if not (marks and list) then
    return nil, marks_err or comments_err
  end
  return { marks = marks, comments = list }
end

---@param root string
---@param patch review.MarkPatch
---@return boolean, string?
function M.save_marks(root, patch)
  return update(root, MARKS, function(marks)
    return toggle.apply(marks, patch)
  end)
end

---@param root string
---@param patch review.CommentPatch
---@return boolean, string?
function M.save_comments(root, patch)
  return update(root, COMMENTS, function(list)
    return comments.apply(list, patch)
  end)
end

--- Delete all marks and comments. A file with an unknown version is not changed.
---@param root string
---@return boolean, string?
function M.clear(root)
  local function empty(doc)
    return function()
      return doc.empty()
    end
  end
  local ok, err = update(root, MARKS, empty(MARKS))
  local ok_comments, err_comments = update(root, COMMENTS, empty(COMMENTS))
  return ok and ok_comments, err or err_comments
end

return M
