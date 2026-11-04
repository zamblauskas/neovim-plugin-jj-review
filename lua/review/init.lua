-- Entry point: setup(), :Review command, global keymaps. Wires the runtime to the real ports.

local app_mod = require("review.app")
local config_mod = require("review.config")
local effects = require("review.shell.effects")
local highlights = require("review.shell.highlights")
local msg = require("review.core.msg")
local state_mod = require("review.core.state")
local update = require("review.core.update")

local M = {}

---@type review.App?
local app

---@param config review.Config
---@return review.App
local function create_app(config)
  local ports = {
    jj = require("review.shell.jj"),
    explorer = require("review.shell.explorer"),
    layout = require("review.shell.layout"),
    diff = require("review.shell.diff"),
    store = require("review.shell.store"),
    watcher = require("review.shell.watcher"),
  }
  return app_mod.create(
    state_mod.initial(config),
    update.update,
    effects.new(ports, { max_parallel_jj = config.max_parallel_jj })
  )
end

---@param args vim.api.keyset.create_user_command.command_args
local function command(args)
  local subcommands = { close = M.close, clear = M.clear }
  local subcommand = subcommands[args.fargs[1]]
  if subcommand and #args.fargs == 1 then
    subcommand()
  else
    M.open(args.args ~= "" and args.args or nil)
  end
end

---@param keymaps review.KeymapConfig
local function set_keymaps(keymaps)
  if keymaps.open then
    vim.keymap.set("n", keymaps.open, M.open, { desc = "Review stack" })
  end
  if keymaps.close then
    vim.keymap.set("n", keymaps.close, M.close, { desc = "Close review" })
  end
end

---@param opts? table
function M.setup(opts)
  local config = config_mod.resolve(opts)
  app = create_app(config)
  highlights.setup()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = highlights.setup })
  vim.api.nvim_create_user_command(
    "Review",
    command,
    { nargs = "*", desc = "Review a jj stack: [revset] | close | clear" }
  )
  set_keymaps(config.keymaps)
end

--- Open the review for `revset` (default: config revset).
---@param revset? string
function M.open(revset)
  if not app then
    M.setup()
  end
  assert(app, "review: setup failed").dispatch(msg.opened(vim.fn.getcwd(), revset))
end

function M.close()
  if app then
    app.dispatch(msg.closed())
  end
end

--- Delete all marks in the repo of the open review, after confirmation.
function M.clear()
  if not (app and app.state().open and app.state().root) then
    vim.notify("review: open a review first (:Review)", vim.log.levels.WARN)
    return
  end
  if vim.fn.confirm("Delete all review marks in this repo?", "&Yes\n&No", 2) == 1 then
    app.dispatch(msg.cleared())
  end
end

return M
