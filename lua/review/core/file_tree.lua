-- File tree of one revision: files grouped by directory, in display order.
-- Directories come first, then files, each sorted by name.
-- A directory with one subdirectory and no files is joined with it (`src/app/service/`).
-- The explorer and file navigation (`]R`) both use this order.

local M = {}

---@class review.TreeEntry
---@field type "dir"|"file"
---@field depth integer         -- 0 at the revision level
---@field name string           -- dir: joined path with a trailing "/"; file: base name
---@field file? review.FileDiff -- file only

---@class review.TreeNode
---@field dirs table<string, review.TreeNode>
---@field files { name: string, file: review.FileDiff }[]

---@return review.TreeNode
local function new_node()
  return { dirs = {}, files = {} }
end

---@param root review.TreeNode
---@param file review.FileDiff
local function insert(root, file)
  local parts = vim.split(file.path, "/", { plain = true })
  local node = root
  for i = 1, #parts - 1 do
    node.dirs[parts[i]] = node.dirs[parts[i]] or new_node()
    node = node.dirs[parts[i]]
  end
  table.insert(node.files, { name = parts[#parts], file = file })
end

--- Join a directory with its only subdirectory while it has no files.
---@param name string
---@param node review.TreeNode
---@return string, review.TreeNode
local function compact(name, node)
  local child_names = vim.tbl_keys(node.dirs)
  if #node.files == 0 and #child_names == 1 then
    return compact(name .. "/" .. child_names[1], node.dirs[child_names[1]])
  end
  return name, node
end

local flatten

---@param node review.TreeNode
---@param depth integer
---@param out review.TreeEntry[]
local function flatten_dirs(node, depth, out)
  local dir_names = vim.tbl_keys(node.dirs)
  table.sort(dir_names)
  for _, dir_name in ipairs(dir_names) do
    local name, inner = compact(dir_name, node.dirs[dir_name])
    table.insert(out, { type = "dir", depth = depth, name = name .. "/" })
    flatten(inner, depth + 1, out)
  end
end

---@param node review.TreeNode
---@param depth integer
---@param out review.TreeEntry[]
local function flatten_files(node, depth, out)
  local files = vim.list_slice(node.files)
  table.sort(files, function(a, b)
    return a.name < b.name
  end)
  for _, f in ipairs(files) do
    table.insert(out, { type = "file", depth = depth, name = f.name, file = f.file })
  end
end

---@param node review.TreeNode
---@param depth integer
---@param out review.TreeEntry[]
---@return review.TreeEntry[]
flatten = function(node, depth, out)
  flatten_dirs(node, depth, out)
  flatten_files(node, depth, out)
  return out
end

--- Tree entries of the files, in display order.
---@param files review.FileDiff[]
---@return review.TreeEntry[]
function M.build(files)
  local root = new_node()
  for _, file in ipairs(files) do
    insert(root, file)
  end
  return flatten(root, 0, {})
end

--- Paths of the files, in display order.
---@param files review.FileDiff[]
---@return string[]
function M.paths(files)
  local file_entries = vim.tbl_filter(function(entry)
    return entry.type == "file"
  end, M.build(files))
  return vim.tbl_map(function(entry)
    return entry.file.path
  end, file_entries)
end

return M
