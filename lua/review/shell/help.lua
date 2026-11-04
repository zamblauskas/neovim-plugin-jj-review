-- Help port: a float with the keymaps. q, <Esc> or ? closes it.

local apply = require("review.shell.apply")
local view = require("review.view.help")

local M = {}

local ns = vim.api.nvim_create_namespace("review.help")

---@param lines string[]
---@return vim.api.keyset.win_config
local function float_config(lines)
  local width = vim.iter(lines):fold(20, function(w, line)
    return math.max(w, vim.fn.strdisplaywidth(line))
  end)
  local height = math.min(#lines, vim.o.lines - 4)
  return {
    relative = "editor",
    width = width + 2,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " review: keymaps ",
  }
end

---@param keymaps review.KeymapConfig
function M.open(keymaps)
  local rendered = view.render(keymaps)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  apply.view(buf, ns, rendered)
  local win = vim.api.nvim_open_win(buf, true, float_config(rendered.lines))
  for _, key in ipairs({ "q", "<Esc>", "?" }) do
    vim.keymap.set("n", key, function()
      vim.api.nvim_win_close(win, true)
    end, { buffer = buf, desc = "Close help" })
  end
end

return M
