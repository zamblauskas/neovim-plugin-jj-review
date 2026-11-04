-- Watcher port (Observer): turns outside events into callbacks.
--   - `.jj/repo/op_heads/heads/` changes (a jj command ran), debounced;
--   - Neovim gets focus, or a review buffer gets focus;
--   - a buffer is written (separate callback with its path).

local M = {}

local DEBOUNCE_MS = 200
local GROUP = "review.watcher"

---@type { fs_event: uv.uv_fs_event_t?, timer: uv.uv_timer_t? }
local handles = {}

--- The repo directory. In a secondary workspace `.jj/repo` is a file with a path relative to `.jj/`.
---@param root string
---@return string
function M.repo_dir(root)
  local jj_dir = root .. "/.jj"
  local repo = jj_dir .. "/repo"
  if vim.fn.isdirectory(repo) == 1 then
    return repo
  end
  local target = vim.trim(table.concat(vim.fn.readfile(repo), "\n"))
  local path = vim.startswith(target, "/") and target or (jj_dir .. "/" .. target)
  return vim.fs.normalize(vim.fn.resolve(vim.fn.fnamemodify(path, ":p")))
end

--- Call `callback` once, `DEBOUNCE_MS` after the last call of the returned function.
---@param callback fun()
---@return fun()
local function debounced(callback)
  local timer = assert(vim.uv.new_timer())
  handles.timer = timer
  return function()
    timer:stop()
    timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(callback))
  end
end

---@param dir string
---@param on_change fun()
---@return boolean, string?
local function watch_dir(dir, on_change)
  local fs_event = vim.uv.new_fs_event()
  if not fs_event then
    return false, "cannot create a file watcher"
  end
  local ok, err = fs_event:start(dir, {}, on_change)
  if not ok then
    fs_event:close()
    return false, tostring(err)
  end
  handles.fs_event = fs_event
  return true
end

---@param on_change fun()
---@param on_save fun(path: string)
local function watch_editor(on_change, on_save)
  local group = vim.api.nvim_create_augroup(GROUP, { clear = true })
  vim.api.nvim_create_autocmd("FocusGained", { group = group, callback = on_change })
  vim.api.nvim_create_autocmd("BufEnter", { group = group, pattern = "review://*", callback = on_change })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      on_save(vim.uv.fs_realpath(name) or name)
    end,
  })
end

--- Start watching. Focus checks always work; returns false and a reason if the file watcher does not.
---@param root string
---@param on_change fun()
---@param on_save? fun(path: string)
---@return boolean, string?
function M.start(root, on_change, on_save)
  M.stop()
  local notify = debounced(on_change)
  watch_editor(notify, on_save or function() end)
  local ok, dir = pcall(M.repo_dir, root)
  if not ok then
    return false, tostring(dir)
  end
  return watch_dir(dir .. "/op_heads/heads", notify)
end

function M.stop()
  for _, handle in pairs(handles) do
    if not handle:is_closing() then
      handle:close()
    end
  end
  handles = {}
  pcall(vim.api.nvim_del_augroup_by_name, GROUP)
end

return M
