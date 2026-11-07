-- Handlers: mark lines as reviewed.

local effect = require("review.core.effect")
local changes = require("review.core.changes")
local lookup = require("review.core.lookup")
local navigation = require("review.core.navigation")
local targets = require("review.core.targets")
local tbl = require("review.lib.tbl")
local toggle = require("review.core.toggle")

local M = {}

--- Keys the target points at, in its file. None if the file is unknown.
---@param state review.State
---@param target review.Target
---@return string[]
local function target_keys(state, target)
  local source = lookup.source(state, target.change_id, target.path)
  if not source then
    return {}
  end
  return targets.keys(source.file, #(source.lines or { "" }), target)
end

--- Line finder per step unit (Strategy): the segments of the file and the state → the line to go to.
---@type table<review.StepUnit, fun(segments: review.Segment[], state: review.State, msg: review.Msg.Stepped): integer?>
local STEPPERS = {
  unreviewed = function(segments, state, msg)
    return navigation.unreviewed_line(segments, state.marks, msg.line, msg.offset)
  end,
}

---@param state review.State
---@param msg review.Msg.Stepped
---@return review.State, review.Effect[]
function M.Stepped(state, msg)
  local source = lookup.source(state, msg.change_id, msg.path)
  if not (source and source.lines) then
    return state, {}
  end
  local segments = changes.segments(source.file, #source.lines)
  local line = STEPPERS[msg.unit](segments, state, msg)
  return state, line and { effect.move_cursor(line) } or {}
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
