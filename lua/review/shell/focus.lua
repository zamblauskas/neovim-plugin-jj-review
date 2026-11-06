-- Focus port (Observer): reports what the focused window of the review tab shows, as `FocusChanged`.
-- The explorer and floats are not reported: the last report stays.

local buffers = require("review.shell.buffers")
local explorer = require("review.shell.explorer")
local msg = require("review.core.msg")

local M = {}

local GROUP = "review.focus"

---@type { tab: integer?, app: review.App?, last: string? }
local observed = {}

--- Real file path of `buf` (symlinks resolved, as the jj root), or nil for a buffer without a file
--- (scratch, help, terminal).
---@param buf integer
---@return string?
local function real_path(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].buftype ~= "" or name == "" then
    return nil
  end
  local absolute = vim.fn.fnamemodify(name, ":p")
  return vim.uv.fs_realpath(absolute) or absolute
end

--- The focused window, if it is reported: in the review tab, not the explorer, not a float.
---@return integer?
local function reported_window()
  local win = vim.api.nvim_get_current_win()
  local in_tab = vim.api.nvim_win_get_tabpage(win) == observed.tab
  local is_float = vim.api.nvim_win_get_config(win).relative ~= ""
  return (in_tab and not is_float and win ~= explorer.handles().win) and win or nil
end

--- The message for the buffer of `win`.
---@param win integer
---@return review.Msg.FocusChanged
local function focus_msg(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local file = buffers.identify(buf)
  return msg.focus_changed(file, not file and real_path(buf) or nil)
end

--- Dispatch FocusChanged when the reported window shows something else than at the last report.
local function report()
  local win = observed.app and reported_window()
  if not win then
    return
  end
  local message = focus_msg(win)
  local fingerprint = vim.inspect({ message.file, message.path })
  if fingerprint ~= observed.last then
    observed.last = fingerprint
    assert(observed.app, "app").dispatch(message)
  end
end

--- Start observing `tab`. Reports run on the next tick, after the window and buffer changes are done.
---@param app review.App
---@param tab integer
function M.start(app, tab)
  observed = { tab = tab, app = app }
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = vim.api.nvim_create_augroup(GROUP, { clear = true }),
    callback = function()
      vim.schedule(report)
    end,
  })
end

function M.stop()
  pcall(vim.api.nvim_del_augroup_by_name, GROUP)
  observed = {}
end

return M
