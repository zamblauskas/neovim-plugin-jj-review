-- Comment input port: a float window with a multi-line buffer.
-- <C-s> submits (normal and insert mode). q or <Esc> in normal mode cancels.

local M = {}

local WIDTH_RATIO, MIN_WIDTH, HEIGHT = 0.6, 40, 8

---@return vim.api.keyset.win_config
local function float_config(title)
  local width = math.max(math.floor(vim.o.columns * WIDTH_RATIO), MIN_WIDTH)
  return {
    relative = "editor",
    width = math.min(width, vim.o.columns - 4),
    height = HEIGHT,
    row = math.floor((vim.o.lines - HEIGHT) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    footer = " <C-s> save · q cancel ",
    footer_pos = "right",
  }
end

---@param buf integer
---@param win integer
---@param on_submit fun(text: string)
local function set_keymaps(buf, win, on_submit)
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set({ "n", "i" }, "<C-s>", function()
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    vim.cmd.stopinsert()
    close()
    on_submit(text)
  end, { buffer = buf, desc = "Save comment" })
  vim.keymap.set("n", "q", close, { buffer = buf, desc = "Cancel comment" })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, desc = "Cancel comment" })
end

--- Open the input. `on_submit` gets the text; it is not called on cancel.
---@param title string
---@param on_submit fun(text: string)
function M.open(title, on_submit)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  local win = vim.api.nvim_open_win(buf, true, float_config(title))
  vim.wo[win].wrap = true
  set_keymaps(buf, win, on_submit)
  vim.cmd.startinsert()
end

return M
