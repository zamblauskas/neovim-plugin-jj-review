-- Handlers: explorer and diff UI.

local file_tree = require("review.core.file_tree")
local effect = require("review.core.effect")
local folds = require("review.core.folds")
local lookup = require("review.core.lookup")
local modes = require("review.core.modes")
local messages = require("review.core.msg")
local review_buffers = require("review.core.review_buffers")
local tbl = require("review.lib.tbl")

local M = {}

---@param state review.State
---@return review.Revision[]
local function revisions(state)
  return state.stack.type == "ok" and state.stack.revisions or {}
end

---@param state review.State
---@param msg review.Msg.FoldToggled
---@return review.State, review.Effect[]
function M.FoldToggled(state, msg)
  local next_folds = folds.toggle(state.folds, state.fold_default, revisions(state), msg.change_id)
  return tbl.with(state, { folds = next_folds }), { effect.render_explorer() }
end

---@param state review.State
---@param msg review.Msg.FileOpened
---@return review.State, review.Effect[]
function M.FileOpened(state, msg)
  local rev = lookup.revision(state, msg.change_id)
  local file = rev and lookup.file(state, rev, msg.path)
  if not rev or not file then
    return state, {}
  end
  return review_buffers.sync(review_buffers.request(state, { change_id = msg.change_id, path = msg.path }, true))
end

--- Path `offset` places after `path` in the revision, in explorer order. Nil past either end.
---@param state review.State
---@param rev review.Revision
---@param path string
---@param offset integer
---@return string?
local function stepped_path(state, rev, path, offset)
  local paths = file_tree.paths(state.diffs[rev.commit_id] or {})
  local index = vim.iter(ipairs(paths)):find(function(_, p)
    return p == path
  end)
  return index and paths[index + offset]
end

---@param state review.State
---@param msg review.Msg.FileStepped
---@return review.State, review.Effect[]
function M.FileStepped(state, msg)
  local rev = lookup.revision(state, msg.change_id)
  local path = rev and stepped_path(state, rev, msg.path, msg.offset)
  if not (rev and path) then
    return state, {}
  end
  return M.FileOpened(state, messages.file_opened(rev.change_id, path))
end

---@param a review.FileKey?
---@param b review.FileKey?
---@return boolean
local function same_file(a, b)
  return (a and a.change_id .. "/" .. a.path) == (b and b.change_id .. "/" .. b.path)
end

--- The file of the working-copy revision at the absolute `path`, if it is shown in working-copy mode.
---@param state review.State
---@param path string
---@return review.FileKey?
local function working_copy_file(state, path)
  local root, rev = state.root, lookup.disk_revision(state)
  if not (root and rev and vim.startswith(path, root .. "/")) then
    return nil
  end
  local relative = path:sub(#root + 2)
  local file = lookup.file(state, rev, relative)
  return (file and modes.mode(state, rev, file) == "working_copy") and { change_id = rev.change_id, path = relative }
    or nil
end

--- A real file of the working-copy revision becomes a review buffer (opened by `gd`, `:e`).
---@param state review.State
---@param file review.FileKey
---@return review.State, review.Effect[]
local function adopt(state, file)
  return review_buffers.sync(review_buffers.request(state, file, false))
end

---@param state review.State
---@param file review.FileKey?
---@return review.State, review.Effect[]
local function with_current(state, file)
  if same_file(state.current, file) then
    return state, {}
  end
  return file and tbl.with(state, { current = file }) or tbl.without(state, "current"), { effect.render_explorer() }
end

---@param state review.State
---@param msg review.Msg.FocusChanged
---@return review.State, review.Effect[]
function M.FocusChanged(state, msg)
  local adopted = not msg.file and msg.path and working_copy_file(state, msg.path)
  if not adopted then
    return with_current(state, msg.file)
  end
  local next_state, effects = adopt(state, adopted)
  local final_state, current_effects = with_current(next_state, adopted)
  return final_state, vim.list_extend(effects, current_effects)
end

---@param state review.State
---@param msg review.Msg.ContentLoaded
---@return review.State, review.Effect[]
function M.ContentLoaded(state, msg)
  local by_path = tbl.with(state.contents[msg.commit_id] or {}, { [msg.path] = msg.lines })
  local next_state = tbl.with(state, { contents = tbl.with(state.contents, { [msg.commit_id] = by_path }) })
  return review_buffers.sync(next_state)
end

return M
