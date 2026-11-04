-- Diff port: shows the open file in the diff window and draws its diff. Buffers come from shell/buffers.lua.

local apply = require("review.shell.apply")
local buffers = require("review.shell.buffers")
local comments = require("review.core.comments")
local layout = require("review.shell.layout")
local lookup = require("review.core.lookup")
local view = require("review.view.diff")

local M = {}

--- View of `win` if it shows a review buffer (an older version of the file), else nil.
---@param win integer?
---@return vim.fn.winsaveview.ret?
local function saved_view(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return nil
  end
  local shown = vim.api.nvim_win_get_buf(win)
  local is_review = vim.iter(buffers.registry()):any(function(_, entry)
    return entry.buf == shown
  end)
  return is_review and vim.api.nvim_win_call(win, vim.fn.winsaveview) or nil
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
  local saved = e.keep_view and saved_view(layout.handles().diff_win) or nil
  local buf = buffers.acquire(e, app)
  local win = layout.diff_window(buf)
  vim.api.nvim_win_set_buf(win, buf)
  buffers.release_real_except(buf)
  vim.wo[win][0].signcolumn = "yes:1"
  local line_count = vim.api.nvim_buf_line_count(buf)
  if saved then
    return restore_view(win, saved, line_count)
  end
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { math.min(e.cursor_line, line_count), 0 })
end

--- The open file is gone: an empty buffer in the diff window, then release all review buffers.
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
  local buf = open.mode and buffers.find(open.mode, open.change_id, open.path)
  return buf or nil, rev and lookup.file(state, rev, open.path)
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

--- Draw the diff of the open file. A modified real buffer keeps its marks until it is saved: the diff is of
--- the saved text, and the marks move with the text.
---@param state review.State
function M.render(state)
  local buf, file = open_file(state)
  if not (buf and file) or vim.bo[buf].modified then
    return
  end
  local input = {
    line_count = vim.api.nvim_buf_line_count(buf),
    tabstop = vim.bo[buf].tabstop,
    gutter_width = gutter_width(buf),
    marks = state.marks,
    dim = state.config.dim_reviewed,
    comments = file_comments(state),
    icons = state.config.icons,
  }
  local rendered = view.render(file, input)
  apply.extmarks(buf, buffers.ns, rendered.extmarks)
  set_topfill(buf, rendered.topfill)
end

--- Release all review buffers: wipe scratch buffers; remove marks and keymaps from real buffers.
function M.close()
  buffers.release_all()
end

return M
