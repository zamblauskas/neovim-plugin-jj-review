-- Buffer-local keymaps of a diff buffer → messages. A key set to false in the config is not mapped.

local clock = require("review.shell.clock")
local keymap_docs = require("review.core.keymap_docs")
local msg = require("review.core.msg")

local M = {}

---@param file review.FileKey
---@param fields table
---@return review.Target
local function target(file, fields)
  return vim.tbl_extend("force", { change_id = file.change_id, path = file.path }, fields)
end

--- Action that sends the target of `type` at the cursor line through `send`.
---@param file review.FileKey
---@param type "line"|"block"|"hunk"
---@param send fun(target: review.Target): review.Msg
---@return fun(): review.Msg
local function at_cursor(file, type, send)
  return function()
    return send(target(file, { type = type, line = vim.fn.line(".") }))
  end
end

---@param t review.Target
---@return review.Msg
local function toggle_now(t)
  return msg.toggle_requested(t, clock.now())
end

--- Normal mode toggle actions by config key name.
---@param file review.FileKey
---@return table<string, fun(): review.Msg>
local function toggle_actions(file)
  return {
    toggle = at_cursor(file, "line", toggle_now),
    toggle_block = at_cursor(file, "block", toggle_now),
    toggle_hunk = at_cursor(file, "hunk", toggle_now),
    toggle_file = function()
      return toggle_now(target(file, { type = "file" }))
    end,
  }
end

--- Comment actions by config key name.
---@param file review.FileKey
---@return table<string, fun(): review.Msg>
local function comment_actions(file)
  return {
    comment = at_cursor(file, "line", msg.comment_requested),
    comment_block = at_cursor(file, "block", msg.comment_requested),
    comment_hunk = at_cursor(file, "hunk", msg.comment_requested),
    delete_comment = function()
      return msg.comment_delete_requested(file.change_id, file.path, vim.fn.line("."))
    end,
  }
end

--- Navigation actions by config key name.
---@param file review.FileKey
---@return table<string, fun(): review.Msg>
local function step_actions(file)
  local function stepped(unit, offset)
    return function()
      return msg.stepped(unit, file.change_id, file.path, vim.fn.line("."), offset)
    end
  end
  local function other_file(offset)
    return function()
      return msg.file_stepped(file.change_id, file.path, offset)
    end
  end
  return {
    next_unreviewed = stepped("unreviewed", 1),
    prev_unreviewed = stepped("unreviewed", -1),
    next_hunk = stepped("hunk", 1),
    prev_hunk = stepped("hunk", -1),
    next_file = other_file(1),
    prev_file = other_file(-1),
  }
end

--- View actions by config key name.
---@return table<string, fun(): review.Msg>
local function view_actions()
  return { toggle_removed = msg.removed_toggled }
end

--- The selected line range as target fields. Leaves visual mode.
---@param file review.FileKey
---@return review.Target
local function visual_range(file)
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  return target(file, { type = "range", first = math.min(a, b), last = math.max(a, b) })
end

--- Visual mode actions by config key name.
---@param file review.FileKey
---@return table<string, fun(): review.Msg>
local function visual_actions(file)
  return {
    toggle = function()
      return toggle_now(visual_range(file))
    end,
    comment = function()
      return msg.comment_requested(visual_range(file))
    end,
  }
end

---@alias review.MappedKey { [1]: string, [2]: string }  -- mode, lhs

---@param buf integer
---@param mode string
---@param actions table<string, fun(): review.Msg>
---@param app review.App
---@return review.MappedKey[]
local function map_all(buf, mode, actions, app)
  local keymaps, mapped = app.state().config.keymaps, {}
  for name, action in pairs(actions) do
    if keymaps[name] then
      vim.keymap.set(mode, keymaps[name], function()
        app.dispatch(action())
      end, { buffer = buf, desc = keymap_docs.describe("Diff buffer", name) })
      table.insert(mapped, { mode, keymaps[name] })
    end
  end
  return mapped
end

--- Set the review keymaps on `buf`. Returns them, so they can be deleted.
---@param buf integer
---@param file review.FileKey
---@param app review.App
---@return review.MappedKey[]
function M.set(buf, file, app)
  local normal =
    vim.tbl_extend("error", toggle_actions(file), comment_actions(file), step_actions(file), view_actions())
  return vim.list_extend(map_all(buf, "n", normal, app), map_all(buf, "x", visual_actions(file), app))
end

--- Delete keymaps set by `M.set`.
---@param buf integer
---@param mapped review.MappedKey[]
function M.unset(buf, mapped)
  for _, key in ipairs(mapped) do
    pcall(vim.keymap.del, key[1], key[2], { buffer = buf })
  end
end

return M
