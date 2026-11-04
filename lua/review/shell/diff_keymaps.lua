-- Buffer-local keymaps of a diff buffer → messages. A key set to false in the config is not mapped.

local clock = require("review.shell.clock")
local msg = require("review.core.msg")

local M = {}

---@class review.BufferFile
---@field change_id string
---@field path string

local DESCRIPTIONS = {
  toggle = "Toggle reviewed: line",
  toggle_block = "Toggle reviewed: removed block",
  toggle_file = "Toggle reviewed: file",
  next_unreviewed = "Next unreviewed change",
  prev_unreviewed = "Previous unreviewed change",
  next_file = "Next file",
  prev_file = "Previous file",
}

---@param file review.BufferFile
---@param fields table
---@return review.Msg
local function toggle(file, fields)
  local target = vim.tbl_extend("force", { change_id = file.change_id, path = file.path }, fields)
  return msg.toggle_requested(target, clock.now())
end

--- Normal mode toggle actions by config key name.
---@param file review.BufferFile
---@return table<string, fun(): review.Msg>
local function toggle_actions(file)
  return {
    toggle = function()
      return toggle(file, { type = "line", line = vim.fn.line(".") })
    end,
    toggle_block = function()
      return toggle(file, { type = "block", line = vim.fn.line(".") })
    end,
    toggle_file = function()
      return toggle(file, { type = "file" })
    end,
  }
end

--- Navigation actions by config key name.
---@param file review.BufferFile
---@return table<string, fun(): review.Msg>
local function step_actions(file)
  local function unreviewed(offset)
    return function()
      return msg.unreviewed_stepped(file.change_id, file.path, vim.fn.line("."), offset)
    end
  end
  local function other_file(offset)
    return function()
      return msg.file_stepped(offset)
    end
  end
  return {
    next_unreviewed = unreviewed(1),
    prev_unreviewed = unreviewed(-1),
    next_file = other_file(1),
    prev_file = other_file(-1),
  }
end

--- Visual mode toggle: the selected lines. Leaves visual mode.
---@param file review.BufferFile
---@return review.Msg
local function visual_toggle(file)
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  return toggle(file, { type = "range", first = math.min(a, b), last = math.max(a, b) })
end

---@param buf integer
---@param file review.BufferFile
---@param app review.App
function M.set(buf, file, app)
  local keymaps = app.state().config.keymaps
  for name, action in pairs(vim.tbl_extend("error", toggle_actions(file), step_actions(file))) do
    if keymaps[name] then
      vim.keymap.set("n", keymaps[name], function()
        app.dispatch(action())
      end, { buffer = buf, desc = DESCRIPTIONS[name] })
    end
  end
  if keymaps.toggle then
    vim.keymap.set("x", keymaps.toggle, function()
      app.dispatch(visual_toggle(file))
    end, { buffer = buf, desc = "Toggle reviewed: range" })
  end
end

return M
