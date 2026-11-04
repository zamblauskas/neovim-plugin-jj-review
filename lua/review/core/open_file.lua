-- The file in the diff window: show it, and follow it when the stack changes.

local changes = require("review.core.changes")
local effect = require("review.core.effect")
local lookup = require("review.core.lookup")
local modes = require("review.core.modes")
local tbl = require("review.lib.tbl")

local M = {}

--- Show the file: open the buffer, or load the content first.
--- The text is always loaded: core needs it in both modes (line counts, drafts).
--- When the window already shows an older version of the file (commit or mode), the view is kept.
---@param state review.State
---@param rev review.Revision
---@param file review.FileDiff
---@return review.State, review.Effect[]
function M.show(state, rev, file)
  local lines = lookup.new_lines(state, rev, file)
  if not lines then
    return state,
      { effect.load_content(state.generation, assert(state.root, "root not resolved"), rev.commit_id, file.path) }
  end
  local open = assert(state.open_file, "open file")
  local mode = modes.mode(state, rev, file)
  local opts = { keep_view = open.commit_id ~= nil, mode = mode, file_path = state.root .. "/" .. file.path }
  local buffer = effect.open_buffer(rev.change_id, file.path, lines, changes.first_line(file, #lines), opts)
  return tbl.with(state, { open_file = tbl.with(open, { commit_id = rev.commit_id, mode = mode }) }),
    { buffer, effect.render_diff() }
end

---@param state review.State
---@return review.State, review.Effect[]
local function close(state)
  return tbl.without(state, "open_file"), { effect.close_diff(), effect.render_explorer() }
end

--- After a stack or diff change: show a rewritten open file again, or close it if it is gone.
--- No change while the stack is not ok, the new diff is loading, or the first content is loading.
---@param state review.State
---@return review.State, review.Effect[]
function M.follow(state)
  local open = state.open_file
  if not open or not open.commit_id or state.stack.type ~= "ok" then
    return state, {}
  end
  local rev = lookup.revision(state, open.change_id)
  if not rev then
    return close(state)
  end
  if not state.diffs[rev.commit_id] then
    return state, {}
  end
  local file = lookup.file(state, rev, open.path)
  if not file then
    return close(state)
  elseif rev.commit_id == open.commit_id and modes.mode(state, rev, file) == open.mode then
    return state, {}
  end
  return M.show(state, rev, file)
end

return M
