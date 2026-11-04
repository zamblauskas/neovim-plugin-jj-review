-- Handlers: mark lines as reviewed.

local effect = require("review.core.effect")
local lookup = require("review.core.lookup")
local targets = require("review.core.targets")
local tbl = require("review.lib.tbl")
local toggle = require("review.core.toggle")

local M = {}

--- Keys the target points at, in its file. None if the file is unknown.
---@param state review.State
---@param target review.ToggleTarget
---@return string[]
local function target_keys(state, target)
  local rev = lookup.revision(state, target.change_id)
  local file = rev and lookup.file(state, rev, target.path)
  if not (rev and file) then
    return {}
  end
  return targets.keys(file, #(lookup.new_lines(state, rev, file) or { "" }), target)
end

---@param state review.State
---@param msg review.Msg.ToggleRequested
---@return review.State, review.Effect[]
function M.ToggleRequested(state, msg)
  local patch = toggle.patch(state.marks, target_keys(state, msg.target), msg.now)
  if toggle.is_empty(patch) then
    return state, {}
  end
  return tbl.with(state, { marks = toggle.apply(state.marks, patch) }),
    {
      effect.save_marks(state.generation, assert(state.root, "root not resolved"), patch),
      effect.render_diff(),
      effect.render_explorer(),
    }
end

return M
