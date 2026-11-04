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
local INITIAL = folds.INITIAL
local ALL_DIFFS = { new = files("n"), mid = files("m"), old = files("o") }

---@param fields table
---@return review.State
local function state_with(fields)
  local base = tbl.with(state_mod.initial(config.resolve()), { stack = { type = "ok", revisions = revisions } })
  return tbl.with(base, vim.tbl_extend("force", { marks_loaded = true }, fields))
end

describe("core.folds", function()
  it("opens only the oldest revision before a default is known", function()
    assert.is_true(folds.is_open({}, INITIAL, revisions, "old"))
    assert.is_false(folds.is_open({}, INITIAL, revisions, "new"))
  end)

  it("computes the default when all diffs and marks are loaded: oldest unreviewed revision", function()
    assert.are.same(INITIAL, folds.update_default(state_with({ diffs = { new = files("n") } })))
    assert.are.same(INITIAL, folds.update_default(state_with({ diffs = ALL_DIFFS, marks_loaded = false })))
    local default = folds.update_default(state_with({ diffs = ALL_DIFFS, marks = { o = { created = "t" } } }))
    assert.are.same({ computed = true, known = true, change_id = "mid" }, default)
    assert.is_true(folds.is_open({}, default, revisions, "mid"))
    assert.is_false(folds.is_open({}, default, revisions, "old"))
  end)

  it("does not compute again for the same stack load", function()
    local default = { computed = true, known = true, change_id = "new" }
    assert.are.equal(default, folds.update_default(state_with({ diffs = ALL_DIFFS, fold_default = default })))
  end)

  it("keeps the old default after a new stack until the new one is computed", function()
    local old = { computed = true, known = true, change_id = "mid" }
    local pending = folds.on_new_stack(old)
    assert.is_false(pending.computed)
    assert.is_true(folds.is_open({}, pending, revisions, "mid"))
    assert.is_false(folds.is_open({}, pending, revisions, "old"))
  end)

  it("opens no revision when all are reviewed", function()
    local diffs = { new = {}, mid = {}, old = {} }
    assert.are.same({ computed = true, known = true }, folds.update_default(state_with({ diffs = diffs })))
  end)

  it("toggles from the default state", function()
    local f = folds.toggle({}, INITIAL, revisions, "old")
    assert.are.same({ old = "closed" }, f)
    assert.is_false(folds.is_open(f, INITIAL, revisions, "old"))
    assert.is_true(folds.is_open(folds.toggle(f, INITIAL, revisions, "new"), INITIAL, revisions, "new"))
  end)

  it("keeps a user choice when the stack changes", function()
    local f = folds.toggle({}, INITIAL, revisions, "mid")
    assert.is_true(folds.is_open(f, INITIAL, { rev("mid") }, "mid"))
  end)

  it("does not change the old fold state", function()
    local before = {}
    folds.toggle(before, INITIAL, revisions, "old")
    assert.are.same({}, before)
  end)
end)
