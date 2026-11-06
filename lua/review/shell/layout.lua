-- Layout port (Facade): the review tab page with the explorer (left) and the diff window (right).
-- The only owner of the tab and diff window handles.

local explorer = require("review.shell.explorer")
local focus = require("review.shell.focus")

local M = {}

---@type { tab: integer?, diff_win: integer? }
local ui = {}

---@return boolean
local function tab_is_valid()
  return ui.tab ~= nil and vim.api.nvim_tabpage_is_valid(ui.tab)
end

--- New tab page. Its first window becomes the diff window. Its empty buffer is wiped when hidden.
local function create_tab()
  vim.cmd.tabnew()
  vim.bo.bufhidden = "wipe"
  ui = { tab = vim.api.nvim_get_current_tabpage(), diff_win = vim.api.nvim_get_current_win() }
end

--- Open the review tab, or go to it if it is open.
---@param app review.App
function M.open(app)
  if tab_is_valid() then
    vim.api.nvim_set_current_tabpage((assert(ui.tab, "review tab")))
  else
    create_tab()
  end
  explorer.open(app)
  focus.start(app, (assert(ui.tab, "review tab")))
end

--- Close the review tab. If it is the only tab, close the explorer only.
function M.close()
  if tab_is_valid() and #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd.tabclose(vim.api.nvim_tabpage_get_number((assert(ui.tab, "review tab"))))
  end
  focus.stop()
  explorer.close()
  ui = {}
end

---@return boolean
local function diff_win_is_valid()
  return ui.diff_win ~= nil
    and vim.api.nvim_win_is_valid(ui.diff_win)
    and vim.api.nvim_win_get_tabpage(ui.diff_win) == ui.tab
end

--- The diff window. If the user closed it, a new one opens on the right of the explorer.
--- Call only while the review tab is open.
---@param buf integer  buffer for a new window
---@return integer
function M.diff_window(buf)
  if not diff_win_is_valid() then
    vim.api.nvim_set_current_tabpage((assert(ui.tab, "review tab")))
    ui.diff_win = vim.api.nvim_open_win(buf, false, { split = "right", win = -1 })
  end
  return assert(ui.diff_win, "diff window")
end

---@return { tab: integer?, diff_win: integer? }
function M.handles()
  return ui
end

return M
