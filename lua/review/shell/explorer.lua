-- Explorer port: the left split window. Holds the only UI handles (buffer, window).

local actions = require("review.core.explorer_actions")
local apply = require("review.shell.apply")
local clock = require("review.shell.clock")
local explorer_cursor = require("review.core.explorer_cursor")
local msg = require("review.core.msg")
local view = require("review.view.explorer")

local M = {}

local ns = vim.api.nvim_create_namespace("review.explorer")

---@type { buf: integer?, win: integer? }
local ui = {}

--- Row targets of the last render, by 1-based line.
---@type table<integer, review.ExplorerTarget>
local targets = {}

--- Dispatch the message of `action` for the row under the cursor, if any.
---@param app review.App
---@param action fun(target: review.ExplorerTarget): review.Msg?
local function on_cursor_row(app, action)
  local target = targets[vim.api.nvim_win_get_cursor(0)[1]]
  local message = target and action(target)
  if message then
    app.dispatch(message)
  end
end

---@return integer
local function create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "review-explorer"
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_set_name(buf, "review://explorer")
  return buf
end

---@param win integer
local function set_window_options(win)
  local wo = vim.wo[win][0]
  wo.number, wo.relativenumber, wo.signcolumn = false, false, "no"
  wo.winfixwidth, wo.cursorline, wo.wrap = true, true, false
  wo.foldcolumn, wo.spell, wo.list = "0", false, false
end

--- Row actions by config key name.
local ROW_ACTIONS = {
  toggle_file = {
    function(target)
      return actions.toggle_file(target, clock.now())
    end,
    "Toggle reviewed: file",
  },
  delete_comment = { actions.delete_comment, "Delete orphaned comment" },
}

---@param buf integer
---@param app review.App
local function set_row_keymaps(buf, app)
  local keymaps = app.state().config.keymaps
  for name, row_action in pairs(ROW_ACTIONS) do
    if keymaps[name] then
      vim.keymap.set("n", keymaps[name], function()
        on_cursor_row(app, row_action[1])
      end, { buffer = buf, desc = row_action[2] })
    end
  end
end

--- `q` closes the review. `<CR>` runs the enter action of the row. The toggle key toggles a file row.
---@param buf integer
---@param app review.App
local function set_keymaps(buf, app)
  vim.keymap.set("n", "q", function()
    app.dispatch(msg.closed())
  end, { buffer = buf, desc = "Close review" })
  vim.keymap.set("n", "<CR>", function()
    on_cursor_row(app, actions.enter)
  end, { buffer = buf, desc = "Fold revision / open file" })
  set_row_keymaps(buf, app)
end

--- Keymaps. Closing the window (`:q`) closes the review too.
---@param buf integer
---@param win integer
---@param app review.App
local function bind(buf, win, app)
  set_keymaps(buf, app)
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      ui = {} -- the window is closing already; `M.close` must not close it again
      app.dispatch(msg.closed())
    end,
  })
end

---@return boolean
local function is_open()
  return ui.win ~= nil and vim.api.nvim_win_is_valid(ui.win)
end

--- Open the explorer on the left, or focus it if open.
---@param app review.App
function M.open(app)
  if is_open() then
    vim.api.nvim_set_current_win((assert(ui.win, "explorer window")))
    return
  end
  local buf = create_buffer()
  local width = app.state().config.explorer_width
  local win = vim.api.nvim_open_win(buf, true, { split = "left", win = -1, width = width })
  set_window_options(win)
  bind(buf, win, app)
  ui = { buf = buf, win = win }
end

--- Close the explorer. If it is the last window, open an empty window first.
function M.close()
  if is_open() then
    if #vim.api.nvim_tabpage_list_wins(0) == 1 then
      vim.cmd("vnew")
    end
    vim.api.nvim_win_close(assert(ui.win, "explorer window"), true)
  end
  ui = {}
  targets = {}
end

--- Keep the cursor on the same target after a redraw (rule in core/explorer_cursor.lua).
---@param old_targets review.RowTargets
local function follow_target(old_targets)
  if not is_open() then
    return
  end
  local win = assert(ui.win, "explorer window")
  local row = explorer_cursor.row(old_targets, vim.api.nvim_win_get_cursor(win)[1], targets)
  if row then
    vim.api.nvim_win_set_cursor(win, { row, 0 })
  end
end

---@param state review.State
function M.render(state)
  if ui.buf and vim.api.nvim_buf_is_valid(ui.buf) then
    local rendered = view.render(state)
    local old_targets = targets
    apply.view(ui.buf, ns, rendered)
    targets = rendered.targets or {}
    follow_target(old_targets)
  end
end

---@return { buf: integer?, win: integer? }
function M.handles()
  return ui
end

return M
