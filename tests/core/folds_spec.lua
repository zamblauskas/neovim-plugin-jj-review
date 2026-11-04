local assert = require("luassert")
local config = require("review.config")
local folds = require("review.core.folds")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")

---@param id string
---@return review.Revision
local function rev(id)
  return {
    change_id = id,
    short_id = id,
    id_prefix = id,
    commit_id = id,
    parents = {},
    empty = false,
    working_copy = false,
    description = "",
  }
end

---@param key string
---@return review.FileDiff[]
local function files(key)
  local hunk =
    { old_start = 0, old_count = 0, new_start = 1, new_count = 1, lines = { { kind = "+", text = "x", key = key } } }
  return { { status = "added", path = "f", binary = false, hunks = { hunk } } }
end

local revisions = { rev("new"), rev("mid"), rev("old") }
local PENDING = folds.PENDING

---@param fields table
---@return review.State
local function state_with(fields)
  local base = tbl.with(state_mod.initial(config.resolve()), { stack = { type = "ok", revisions = revisions } })
  return tbl.with(base, fields)
end

describe("core.folds", function()
  it("opens only the oldest revision while the default is pending", function()
    assert.is_true(folds.is_open({}, PENDING, revisions, "old"))
    assert.is_false(folds.is_open({}, PENDING, revisions, "new"))
  end)

  it("computes the default when all diffs are loaded: oldest revision with unreviewed lines", function()
    local diffs = { new = files("n"), mid = files("m"), old = files("o") }
    assert.are.same(PENDING, folds.default_for(state_with({ diffs = { new = files("n") } })))
    local default = folds.default_for(state_with({ diffs = diffs, marks = { o = { created = "t" } } }))
    assert.are.same({ ready = true, change_id = "mid" }, default)
    assert.is_true(folds.is_open({}, default, revisions, "mid"))
    assert.is_false(folds.is_open({}, default, revisions, "old"))
  end)

  it("opens no revision when all are reviewed", function()
    local diffs = { new = {}, mid = {}, old = {} }
    assert.are.same({ ready = true }, folds.default_for(state_with({ diffs = diffs })))
  end)

  it("toggles from the default state", function()
    local f = folds.toggle({}, PENDING, revisions, "old")
    assert.are.same({ old = "closed" }, f)
    assert.is_false(folds.is_open(f, PENDING, revisions, "old"))
    assert.is_true(folds.is_open(folds.toggle(f, PENDING, revisions, "new"), PENDING, revisions, "new"))
  end)

  it("keeps a user choice when the stack changes", function()
    local f = folds.toggle({}, PENDING, revisions, "mid")
    assert.is_true(folds.is_open(f, PENDING, { rev("mid") }, "mid"))
  end)

  it("does not change the old fold state", function()
    local before = {}
    folds.toggle(before, PENDING, revisions, "old")
    assert.are.same({}, before)
  end)
end)
