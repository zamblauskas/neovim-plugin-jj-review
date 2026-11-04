local assert = require("luassert")
local folds = require("review.core.folds")

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

describe("core.folds", function()
  local revisions = { rev("new"), rev("mid"), rev("old") }

  it("opens only the oldest revision by default", function()
    assert.is_true(folds.is_open({}, revisions, "old"))
    assert.is_false(folds.is_open({}, revisions, "new"))
  end)

  it("toggles from the default state", function()
    local f = folds.toggle({}, revisions, "old")
    assert.are.same({ old = "closed" }, f)
    assert.is_false(folds.is_open(f, revisions, "old"))
    assert.is_true(folds.is_open(folds.toggle(f, revisions, "new"), revisions, "new"))
  end)

  it("keeps a user choice when the stack changes", function()
    local f = folds.toggle({}, revisions, "mid")
    assert.is_true(folds.is_open(f, { rev("mid") }, "mid"))
  end)

  it("does not change the old fold state", function()
    local before = {}
    folds.toggle(before, revisions, "old")
    assert.are.same({}, before)
  end)
end)
