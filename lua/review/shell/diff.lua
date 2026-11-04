-- Diff buffer port: read-only scratch buffers `review://<change-id>/<path>`, shown in the diff window.
-- The only owner of these buffers. A buffer is reused when the same file opens again.

local apply = require("review.shell.apply")
local comments = require("review.core.comments")
local diff_keymaps = require("review.shell.diff_keymaps")
local layout = require("review.shell.layout")
local lookup = require("review.core.lookup")
local view = require("review.view.diff")

local M = {}

local ns = vim.api.nvim_create_namespace("review.diff")

---@type table<string, integer>  buffer by name
local buffers = {}

---@param change_id string
---@param path string
---@return string
local function buffer_name(change_id, path)
  return "review://" .. change_id .. "/" .. path
end

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
---@param app review.App
---@return integer
local function buffer_for(e, app)
  local name = buffer_name(e.change_id, e.path)
  local buf = buffers[name]
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = create_buffer(name, e.path)
    diff_keymaps.set(buf, { change_id = e.change_id, path = e.path }, app)
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

--- View of `win` if it shows `buf`, else nil.
---@param win integer
---@param buf integer
---@return vim.fn.winsaveview.ret?
local function saved_view(win, buf)
  if vim.api.nvim_win_get_buf(win) ~= buf then
    return nil
  end
  return vim.api.nvim_win_call(win, vim.fn.winsaveview)
end

---@param win integer
---@param saved vim.fn.winsaveview.ret
---@param line_count integer
local function restore_view(win, saved, line_count)
  saved.lnum = math.min(saved.lnum, line_count)
  saved.topline = math.min(saved.topline, line_count)
  vim.api.nvim_win_call(win, function()
    vim.fn.winrestview(saved)
  end)
end

--- Show the file in the diff window.
--- New file: focus the window, cursor at `cursor_line`. `keep_view`: keep cursor, scroll and focus.
---@param e review.Effect.OpenBuffer
---@param app review.App
function M.open(e, app)
  local buf = buffer_for(e, app)
  local win = layout.diff_window(buf)
  local saved = e.keep_view and saved_view(win, buf) or nil
  set_lines(buf, e.lines)
  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win][0].signcolumn = "yes:1"
  if saved then
    return restore_view(win, saved, #e.lines)
  end
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { math.min(e.cursor_line, #e.lines), 0 })
end

--- The open file is gone: an empty buffer in the diff window, then wipe all review buffers.
function M.close_file()
  local win = layout.handles().diff_win
  if win and vim.api.nvim_win_is_valid(win) then
    local empty = vim.api.nvim_create_buf(false, true)
    vim.bo[empty].bufhidden = "wipe"
    vim.api.nvim_win_set_buf(win, empty)
  end
  M.close()
end

--- Show virtual lines above line 1 when the window shows the top of the buffer.
---@param buf integer
---@param topfill integer
local function set_topfill(buf, topfill)
  local win = layout.handles().diff_win
  if topfill > 0 and win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
    vim.api.nvim_win_call(win, function()
      if vim.fn.line("w0") == 1 then
        vim.fn.winrestview({ topfill = topfill })
      end
    end)
  end
end

--- Buffer and file diff of the open file, if both exist.
---@param state review.State
---@return integer?, review.FileDiff?
local function open_file(state)
  local open = state.open_file
  if not open then
    return nil, nil
  end
  local rev = lookup.revision(state, open.change_id)
  local buf = buffers[buffer_name(open.change_id, open.path)]
  local valid_buf = (buf and vim.api.nvim_buf_is_valid(buf)) and buf or nil
  return valid_buf, rev and lookup.file(state, rev, open.path)
end

--- Columns before the text in the diff window (signs, numbers, folds). 0 if the window does not show `buf`.
---@param buf integer
---@return integer
local function gutter_width(buf)
  local win = layout.handles().diff_win
  if not (win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf) then
    return 0
  end
  return vim.fn.getwininfo(win)[1].textoff
end

--- Comments shown in the open file.
---@param state review.State
---@return review.Placement[]
local function file_comments(state)
  local open = assert(state.open_file, "open file")
  return comments.in_file(comments.place(state), open.change_id, open.path)
end

--- Draw the diff of the open file.
---@param state review.State
function M.render(state)
  local buf, file = open_file(state)
  if not (buf and file) then
    return
  end
  local input = {
    line_count = vim.api.nvim_buf_line_count(buf),
    tabstop = vim.bo[buf].tabstop,
    gutter_width = gutter_width(buf),
    marks = state.marks,
    dim = state.config.dim_reviewed,
    comments = file_comments(state),
  }
  local rendered = view.render(file, input)
  apply.extmarks(buf, ns, rendered.extmarks)
  set_topfill(buf, rendered.topfill)
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
