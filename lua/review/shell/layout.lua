-- Layout port (Facade): the review tab page with the explorer (left), and the target window for a file.
-- The only owner of the tab handle. There is no special diff window (spec/ux.md "Windows and buffers").

local explorer = require("review.shell.explorer")
local focus = require("review.shell.focus")

local M = {}

---@type { tab: integer? }
local ui = {}

---@return boolean
local function tab_is_valid()
  return ui.tab ~= nil and vim.api.nvim_tabpage_is_valid(ui.tab)
end

--- New tab page. Its empty buffer is wiped when hidden.
local function create_tab()
  vim.cmd.tabnew()
  vim.bo.bufhidden = "wipe"
  ui = { tab = vim.api.nvim_get_current_tabpage() }
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

--- A window that can show a file: in the review tab, not the explorer, not a float.
---@param win integer
---@return boolean
local function can_show(win)
  return vim.api.nvim_win_is_valid(win)
    and vim.api.nvim_win_get_tabpage(win) == ui.tab
    and win ~= explorer.handles().win
    and vim.api.nvim_win_get_config(win).relative == ""
end

--- The window for a file: the current window, else the previous window (`wincmd p`), else a new split on the
--- right. Call only while the review tab is open.
---@param buf integer  buffer for a new window
---@return integer
function M.target_window(buf)
  vim.api.nvim_set_current_tabpage((assert(ui.tab, "review tab")))
  local previous = vim.fn.winnr("#") > 0 and vim.fn.win_getid(vim.fn.winnr("#")) or nil
  local found = vim.iter({ vim.api.nvim_get_current_win(), previous }):find(can_show)
  return found or vim.api.nvim_open_win(buf, false, { split = "right", win = -1 })
end

---@return { tab: integer? }
function M.handles()
  return ui
end

return M
