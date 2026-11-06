-- Review buffers (spec/ux.md "Windows and buffers"). Pure.
-- `state.buffers` holds the review files that have a buffer. `sync` (Reconciler) compares each one with the stack
-- and returns the effects that bring its buffer up to date: load, prepare or release. Then it shows the file
-- that waits to be shown, once its buffer is ready.

local changes = require("review.core.changes")
local effect = require("review.core.effect")
local lookup = require("review.core.lookup")
local modes = require("review.core.modes")
local tbl = require("review.lib.tbl")

local M = {}

---@param file review.FileKey
---@return string
function M.key(file)
  return file.change_id .. "/" .. file.path
end

--- Add the file to the review buffers (no change if it is there). `show`: show it when its buffer is ready.
---@param state review.State
---@param file review.FileKey
---@param show boolean
---@return review.State
function M.request(state, file, show)
  local key = M.key(file)
  local entry = tbl.without(state.buffers[key] or { file = file }, "loading") -- a new request loads again
  local next_state = tbl.with(state, { buffers = tbl.with(state.buffers, { [key] = entry }) })
  return show and tbl.with(next_state, { show_pending = key }) or next_state
end

---@alias review.BufferPlan
---| { kind: "release" }
---| { kind: "wait" }
---| { kind: "ready", rev: review.Revision, file: review.FileDiff, lines: string[] }
---| { kind: "load", rev: review.Revision }
---| { kind: "prepare", rev: review.Revision, file: review.FileDiff, lines: string[], mode: review.Mode }

--- Plan for a file that is in the loaded diff of its revision.
---@param state review.State
---@param entry review.BufferState
---@param rev review.Revision
---@param file review.FileDiff
---@return review.BufferPlan
local function located_plan(state, entry, rev, file)
  local lines, mode = lookup.new_lines(state, rev, file), modes.mode(state, rev, file)
  if not lines then
    return { kind = "load", rev = rev }
  end
  local ready = entry.commit_id == rev.commit_id and entry.mode == mode
  return { kind = ready and "ready" or "prepare", rev = rev, file = file, lines = lines, mode = mode }
end

--- What the buffer of `entry` needs, compared with the stack.
---@param state review.State
---@param entry review.BufferState
---@return review.BufferPlan
local function plan(state, entry)
  local rev = lookup.revision(state, entry.file.change_id)
  if not rev then
    return { kind = "release" }
  elseif not state.diffs[rev.commit_id] then
    return { kind = "wait" }
  end
  local file = lookup.file(state, rev, entry.file.path)
  return file and located_plan(state, entry, rev, file) or { kind = "release" }
end

---@class review.SyncAcc
---@field state review.State
---@field effects review.Effect[]

---@param acc review.SyncAcc
---@param key string
---@param entry review.BufferState?  nil: remove
---@param new_effect review.Effect?
---@return review.SyncAcc
local function step(acc, key, entry, new_effect)
  local buffers = entry and tbl.with(acc.state.buffers, { [key] = entry }) or tbl.without(acc.state.buffers, key)
  local effects = new_effect and vim.list_extend(vim.list_slice(acc.effects), { new_effect }) or acc.effects
  return { state = tbl.with(acc.state, { buffers = buffers }), effects = effects }
end

--- Apply the plan for one entry (Strategy by plan kind).
---@type table<string, fun(acc: review.SyncAcc, key: string, entry: review.BufferState, p: review.BufferPlan): review.SyncAcc>
local APPLY = {
  release = function(acc, key, entry)
    return step(acc, key, nil, effect.release_buffer(entry.file))
  end,
  wait = function(acc)
    return acc
  end,
  ready = function(acc)
    return acc
  end,
  load = function(acc, key, entry, p)
    if entry.loading == p.rev.commit_id then
      return acc
    end
    local state = acc.state
    local load = effect.load_content(state.generation, assert(state.root, "root"), p.rev.commit_id, entry.file.path)
    return step(acc, key, tbl.with(entry, { loading = p.rev.commit_id }), load)
  end,
  prepare = function(acc, key, entry, p)
    local file_path = assert(acc.state.root, "root") .. "/" .. entry.file.path
    local prepared = { file = entry.file, commit_id = p.rev.commit_id, mode = p.mode }
    return step(acc, key, prepared, effect.prepare_buffer(entry.file, p.lines, p.mode, file_path))
  end,
}

--- Show the waiting file if its buffer is ready. Drop the wish if the file is gone.
---@param acc review.SyncAcc
---@return review.SyncAcc
local function show_pending(acc)
  local key, state = acc.state.show_pending, acc.state
  local entry = key and state.buffers[key]
  if not entry then
    return { state = tbl.without(state, "show_pending"), effects = acc.effects }
  end
  local p = plan(state, entry)
  if p.kind ~= "ready" then
    return acc
  end
  local show = effect.show_buffer(entry.file, changes.first_line(p.file, #p.lines))
  return { state = tbl.without(state, "show_pending"), effects = vim.list_extend(vim.list_slice(acc.effects), { show }) }
end

---@param acc review.SyncAcc
---@return review.SyncAcc
local function sync_entries(acc)
  for _, key in ipairs(vim.fn.sort(vim.tbl_keys(acc.state.buffers))) do
    local entry = acc.state.buffers[key]
    local p = plan(acc.state, entry)
    acc = APPLY[p.kind](acc, key, entry, p)
  end
  return acc
end

--- Effects with `RenderDiff` at the end when a buffer was prepared.
---@param effects review.Effect[]
---@return review.Effect[]
local function with_render(effects)
  local prepared = vim.iter(effects):any(function(e)
    return e.type == "PrepareBuffer"
  end)
  return prepared and vim.list_extend(effects, { effect.render_diff() }) or effects
end

--- Bring every review buffer up to date with the stack, then show the waiting file. No change while the stack is
--- not ok.
---@param state review.State
---@return review.State, review.Effect[]
function M.sync(state)
  if state.stack.type ~= "ok" then
    return state, {}
  end
  local acc = show_pending(sync_entries({ state = state, effects = {} }))
  return acc.state, with_render(acc.effects)
end

return M
