-- Diff port: prepares, shows and releases review buffers, and draws the diff on every one of them.
-- Buffers come from shell/buffers.lua; the target window from shell/layout.lua.

local apply = require("review.shell.apply")
local buffers = require("review.shell.buffers")
local comments = require("review.core.comments")
local layout = require("review.shell.layout")
local lookup = require("review.core.lookup")
local view = require("review.view.diff")

local M = {}

---@param e review.Effect.PrepareBuffer
---@param app review.App
function M.prepare(e, app)
  buffers.prepare(e, app)
end

--- Show the buffer in the target window and focus it. The first show puts the cursor at `cursor_line`.
---@param e review.Effect.ShowBuffer
function M.show(e)
  local buf = buffers.find(e.file)
  if not buf then
    return
  end
  local win = layout.target_window(buf)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(win)
  if buffers.first_show(e.file) then
    vim.api.nvim_win_set_cursor(win, { math.min(e.cursor_line, vim.api.nvim_buf_line_count(buf)), 0 })
  end
end

---@param e review.Effect.ReleaseBuffer
function M.release(e)
  buffers.release(e.file)
end

--- Columns before the text (signs, numbers, folds) in the first window that shows `buf`. 0 if none does.
---@param buf integer
---@return integer
local function gutter_width(buf)
  local win = vim.fn.win_findbuf(buf)[1]
  return win and vim.fn.getwininfo(win)[1].textoff or 0
end

--- Sign column on, and virtual lines above line 1 in each window that shows the top of the buffer.
---@param buf integer
---@param topfill integer
local function set_windows(buf, topfill)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win][0].signcolumn = "yes:1"
    vim.api.nvim_win_call(win, function()
      if topfill > 0 and vim.fn.line("w0") == 1 then
        vim.fn.winrestview({ topfill = topfill })
      end
    end)
  end
end

--- Buffer and file diff of a review file whose buffer has the text of the current commit.
---@param state review.State
---@param entry review.BufferState
---@return integer?, review.FileDiff?
local function current_buffer(state, entry)
  local rev = lookup.revision(state, entry.file.change_id)
  if not (rev and rev.commit_id == entry.commit_id) then
    return nil, nil
  end
  return buffers.find(entry.file), lookup.file(state, rev, entry.file.path)
end

--- Draw the diff of one review file. A modified real buffer keeps its marks until it is saved: the diff is of the
--- saved text, and the marks move with the text.
---@param state review.State
---@param entry review.BufferState
---@param placements review.Placement[]
local function render_file(state, entry, placements)
  local buf, file = current_buffer(state, entry)
  if not (buf and file) or vim.bo[buf].modified then
    return
  end
  local rendered = view.render(file, {
    line_count = vim.api.nvim_buf_line_count(buf),
    tabstop = vim.bo[buf].tabstop,
    gutter_width = gutter_width(buf),
    marks = state.marks,
    dim = state.config.dim_reviewed,
    comments = comments.in_file(placements, entry.file.change_id, entry.file.path),
    icons = state.config.icons,
  })
  apply.extmarks(buf, buffers.ns, rendered.extmarks)
  set_windows(buf, rendered.topfill)
end

--- Draw the diff of every review buffer.
---@param state review.State
function M.render(state)
  local placements = comments.place(state)
  for _, entry in pairs(state.buffers) do
    render_file(state, entry, placements)
  end
end

--- Release all review buffers: wipe scratch buffers; remove marks and keymaps from real buffers.
function M.close()
  buffers.release_all()
end

return M
