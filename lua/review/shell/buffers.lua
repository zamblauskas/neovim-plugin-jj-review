-- Review buffers (Strategy by mode). The only owner of the buffers a review shows.
--   view:         scratch buffer `review://<change-id>/<path>`; text set on each open; wiped on release.
--   working_copy: the real file buffer; its text is never changed; on release only the review extmarks and
--                 keymaps are removed.

local diff_keymaps = require("review.shell.diff_keymaps")

local M = {}

M.ns = vim.api.nvim_create_namespace("review.diff")

---@class review.ReviewBuffer
---@field buf integer
---@field mode review.Mode
---@field file review.FileKey
---@field keymaps review.MappedKey[]

---@type table<string, review.ReviewBuffer>  by key
local registry = {}

---@param mode review.Mode
---@param change_id string
---@param path string
---@return string
local function key_of(mode, change_id, path)
  return mode .. ":" .. change_id .. "/" .. path
end

---@param e review.Effect.OpenBuffer
---@return integer
local function create_scratch(e)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "review://" .. e.change_id .. "/" .. e.path)
  local filetype = vim.filetype.match({ filename = e.path, buf = buf })
  if filetype then
    vim.bo[buf].filetype = filetype
  end
  return buf
end

---@param buf integer
---@param lines string[]
local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

---@param e review.Effect.OpenBuffer
---@return integer
local function load_real(e)
  local buf = vim.fn.bufadd((assert(e.file_path, "file path")))
  vim.fn.bufload(buf)
  vim.bo[buf].buflisted = true
  return buf
end

---@class review.BufferKind
---@field create fun(e: review.Effect.OpenBuffer): integer
---@field update fun(buf: integer, e: review.Effect.OpenBuffer)
---@field release fun(entry: review.ReviewBuffer)

---@type table<review.Mode, review.BufferKind>
local KINDS = {
  view = {
    create = create_scratch,
    update = function(buf, e)
      set_lines(buf, e.lines)
    end,
    release = function(entry)
      vim.api.nvim_buf_delete(entry.buf, { force = true })
    end,
  },
  working_copy = {
    create = load_real,
    update = function() end,
    release = function(entry)
      vim.api.nvim_buf_clear_namespace(entry.buf, M.ns, 0, -1)
      diff_keymaps.unset(entry.buf, entry.keymaps)
    end,
  },
}

--- The buffer for the effect, created and registered if needed, with its text updated (view mode).
---@param e review.Effect.OpenBuffer
---@param app review.App
---@return integer
function M.acquire(e, app)
  local key = key_of(e.mode, e.change_id, e.path)
  local entry = registry[key]
  if not (entry and vim.api.nvim_buf_is_valid(entry.buf)) then
    local buf = KINDS[e.mode].create(e)
    local file = { change_id = e.change_id, path = e.path }
    entry = { buf = buf, mode = e.mode, file = file, keymaps = diff_keymaps.set(buf, file, app) }
    registry[key] = entry
  end
  KINDS[e.mode].update(entry.buf, e)
  return entry.buf
end

--- Buffer of a file in a mode, if it is registered and valid.
---@param mode review.Mode
---@param change_id string
---@param path string
---@return integer?
function M.find(mode, change_id, path)
  local entry = registry[key_of(mode, change_id, path)]
  return (entry and vim.api.nvim_buf_is_valid(entry.buf)) and entry.buf or nil
end

--- File of a registered buffer, or nil.
---@param buf integer
---@return review.FileKey?
function M.identify(buf)
  local entry = vim.iter(vim.tbl_values(registry)):find(function(e)
    return e.buf == buf
  end)
  return entry and entry.file
end

--- Release working-copy buffers other than `keep` (they left the review).
---@param keep integer
function M.release_real_except(keep)
  for key, entry in pairs(registry) do
    if entry.mode == "working_copy" and entry.buf ~= keep then
      if vim.api.nvim_buf_is_valid(entry.buf) then
        KINDS.working_copy.release(entry)
      end
      registry[key] = nil
    end
  end
end

--- Release all buffers.
function M.release_all()
  for _, entry in pairs(registry) do
    if vim.api.nvim_buf_is_valid(entry.buf) then
      KINDS[entry.mode].release(entry)
    end
  end
  registry = {}
end

---@return table<string, review.ReviewBuffer>
function M.registry()
  return registry
end

return M
