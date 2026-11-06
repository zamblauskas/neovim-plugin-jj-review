-- Handlers: explorer and diff UI.

local file_tree = require("review.core.file_tree")
local effect = require("review.core.effect")
local folds = require("review.core.folds")
local lookup = require("review.core.lookup")
local open_file = require("review.core.open_file")
local messages = require("review.core.msg")
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
  return open_file.show(tbl.with(state, { open_file = { change_id = msg.change_id, path = msg.path } }), rev, file)
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

---@param state review.State
---@param msg review.Msg.FocusChanged
---@return review.State, review.Effect[]
function M.FocusChanged(state, msg)
  if same_file(state.current, msg.file) then
    return state, {}
  end
  local next_state = msg.file and tbl.with(state, { current = msg.file }) or tbl.without(state, "current")
  return next_state, { effect.render_explorer() }
end

--- Show the loaded content only if it is still for the open file.
---@param state review.State
---@param msg review.Msg.ContentLoaded
---@return review.State, review.Effect[]
local function show_if_open(state, msg)
  local open = state.open_file
  if not open or open.path ~= msg.path then
    return state, {}
  end
  local rev = lookup.revision(state, open.change_id)
  local file = rev and rev.commit_id == msg.commit_id and lookup.file(state, rev, msg.path)
  if not (rev and file) then
    return state, {}
  end
  return open_file.show(state, rev, file)
end

---@param state review.State
---@param msg review.Msg.ContentLoaded
---@return review.State, review.Effect[]
function M.ContentLoaded(state, msg)
  local by_path = tbl.with(state.contents[msg.commit_id] or {}, { [msg.path] = msg.lines })
  local next_state = tbl.with(state, { contents = tbl.with(state.contents, { [msg.commit_id] = by_path }) })
  return show_if_open(next_state, msg)
end

return M
