-- Diff buffer port: read-only scratch buffers `review://<change-id>/<path>`, shown in the diff window.
-- The only owner of these buffers. A buffer is reused when the same file opens again.

local layout = require("review.shell.layout")

local M = {}

---@type table<string, integer>  buffer by name
local buffers = {}

---@param name string
---@param path string  for the filetype
---@return integer
local function create_buffer(name, path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].modifiable = false
  local filetype = vim.filetype.match({ filename = path, buf = buf })
  if filetype then
    vim.bo[buf].filetype = filetype
  end
  return buf
end

---@param e review.Effect.OpenBuffer
---@return integer
local function buffer_for(e)
  local name = "review://" .. e.change_id .. "/" .. e.path
  local buf = buffers[name]
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = create_buffer(name, e.path)
    buffers[name] = buf
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

--- Show the file in the diff window and focus it, cursor at `cursor_line`.
---@param e review.Effect.OpenBuffer
function M.open(e)
  local buf = buffer_for(e)
  set_lines(buf, e.lines)
  local win = layout.diff_window(buf)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { math.min(e.cursor_line, #e.lines), 0 })
end

--- Wipe all review buffers.
function M.close()
  for _, buf in pairs(buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  buffers = {}
end

---@return table<string, integer>
function M.buffers()
  return buffers
end

return M
