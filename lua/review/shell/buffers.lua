-- Review buffers (Strategy by mode). The only owner of the buffers a review shows. One buffer per file key.
--   view:         scratch buffer `review://<change-id>/<path>`; text set on each prepare; wiped on release
--                 (its windows get an empty buffer).
--   working_copy: the real file buffer; its text is never changed; on release only the review extmarks and
--                 keymaps are removed. It stays in its windows.
-- A buffer keeps its marks and keymaps in every window until it is released (spec/ux.md "Windows and buffers").

local diff_keymaps = require("review.shell.diff_keymaps")
local review_buffers = require("review.core.review_buffers")

local M = {}

M.ns = vim.api.nvim_create_namespace("review.diff")

---@class review.ReviewBuffer
---@field buf integer
---@field mode review.Mode
---@field file review.FileKey
---@field keymaps review.MappedKey[]
---@field shown boolean  -- shown at least once (the first show sets the cursor)

---@type table<string, review.ReviewBuffer>  by file key
local registry = {}

---@param e review.Effect.PrepareBuffer
---@return integer
local function create_scratch(e)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "review://" .. e.file.change_id .. "/" .. e.file.path)
  local filetype = vim.filetype.match({ filename = e.file.path, buf = buf })
  if filetype then
    vim.bo[buf].filetype = filetype
  end
  return buf
end

--- Run `fn`, then restore the view of every window that shows `buf` (clamped to the new line count).
---@param buf integer
---@param fn fun()
local function keeping_views(buf, fn)
  local saved = vim.tbl_map(function(win)
    return { win = win, view = vim.api.nvim_win_call(win, vim.fn.winsaveview) }
  end, vim.fn.win_findbuf(buf))
  fn()
  local line_count = vim.api.nvim_buf_line_count(buf)
  for _, s in ipairs(saved) do
    s.view.lnum, s.view.topline = math.min(s.view.lnum, line_count), math.min(s.view.topline, line_count)
    vim.api.nvim_win_call(s.win, function()
      vim.fn.winrestview(s.view)
    end)
  end
end

---@param buf integer
---@param lines string[]
local function set_lines(buf, lines)
  keeping_views(buf, function()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end)
end

---@param e review.Effect.PrepareBuffer
---@return integer
local function load_real(e)
  local buf = vim.fn.bufadd(e.file_path)
  vim.fn.bufload(buf)
  vim.bo[buf].buflisted = true
  return buf
end

--- Put an empty buffer in every window that shows `buf`.
---@param buf integer
local function empty_windows(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    local empty = vim.api.nvim_create_buf(false, true)
    vim.bo[empty].bufhidden = "wipe"
    vim.api.nvim_win_set_buf(win, empty)
  end
end

---@class review.BufferKind
---@field create fun(e: review.Effect.PrepareBuffer): integer
---@field update fun(buf: integer, e: review.Effect.PrepareBuffer)
---@field release fun(entry: review.ReviewBuffer)

---@type table<review.Mode, review.BufferKind>
local KINDS = {
  view = {
    create = create_scratch,
    update = function(buf, e)
      set_lines(buf, e.lines)
    end,
    release = function(entry)
      empty_windows(entry.buf)
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

---@param entry review.ReviewBuffer?
---@return boolean
local function is_valid(entry)
  return entry ~= nil and vim.api.nvim_buf_is_valid(entry.buf)
end

---@param entry review.ReviewBuffer?
local function release_entry(entry)
  if entry and is_valid(entry) then
    KINDS[entry.mode].release(entry)
  end
end

--- Windows that showed the buffer of the old mode show `buf`, with their view.
---@param old review.ReviewBuffer
---@param buf integer
local function take_windows(old, buf)
  for _, win in ipairs(vim.fn.win_findbuf(old.buf)) do
    local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_call(win, function()
      vim.fn.winrestview(view)
    end)
  end
end

--- A new buffer for the file. It replaces the buffer of the old mode in its windows.
---@param e review.Effect.PrepareBuffer
---@param old review.ReviewBuffer?
---@param app review.App
---@return review.ReviewBuffer
local function create_entry(e, old, app)
  local buf = KINDS[e.mode].create(e)
  local entry = { buf = buf, mode = e.mode, file = e.file, keymaps = diff_keymaps.set(buf, e.file, app), shown = false }
  if old and is_valid(old) then
    entry.shown = old.shown
    take_windows(old, buf)
  end
  release_entry(old)
  return entry
end

--- Create or update the buffer of the file. A mode change makes a new buffer.
---@param e review.Effect.PrepareBuffer
---@param app review.App
---@return integer
function M.prepare(e, app)
  local key = review_buffers.key(e.file)
  local entry = registry[key]
  if not (is_valid(entry) and entry.mode == e.mode) then
    entry = create_entry(e, entry, app)
    registry[key] = entry
  end
  KINDS[e.mode].update(entry.buf, e)
  return entry.buf
end

--- Buffer of the file, if it is registered and valid.
---@param file review.FileKey
---@return integer?
function M.find(file)
  local entry = registry[review_buffers.key(file)]
  return is_valid(entry) and entry.buf or nil
end

--- True the first time it is called for the file (the first show).
---@param file review.FileKey
---@return boolean
function M.first_show(file)
  local entry = registry[review_buffers.key(file)]
  local first = entry ~= nil and not entry.shown
  if first then
    entry.shown = true
  end
  return first
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

--- Release the buffer of the file.
---@param file review.FileKey
function M.release(file)
  local key = review_buffers.key(file)
  release_entry(registry[key])
  registry[key] = nil
end

--- Release all buffers.
function M.release_all()
  for _, entry in pairs(registry) do
    release_entry(entry)
  end
  registry = {}
end

return M
