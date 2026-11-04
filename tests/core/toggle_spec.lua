local assert = require("luassert")
local toggle = require("review.core.toggle")

local NOW = "2026-11-04T10:00:00Z"

describe("core.toggle", function()
  it("marks all keys when one is not marked", function()
    local marks = { a = { created = "old" } }
    local patch = toggle.patch(marks, { "a", "b" }, NOW)
    assert.are.same({ set = { b = { created = NOW } }, unset = {} }, patch)
    assert.are.same({ a = { created = "old" }, b = { created = NOW } }, toggle.apply(marks, patch))
  end)

  it("unmarks all keys when all are marked", function()
    local marks = { a = { created = "old" }, b = { created = "old" }, c = { created = "old" } }
    local patch = toggle.patch(marks, { "a", "b" }, NOW)
    assert.are.same({ set = {}, unset = { "a", "b" } }, patch)
    assert.are.same({ c = { created = "old" } }, toggle.apply(marks, patch))
  end)

  it("gives an empty patch for no keys", function()
    assert.is_true(toggle.is_empty(toggle.patch({}, {}, NOW)))
    assert.is_false(toggle.is_empty(toggle.patch({}, { "a" }, NOW)))
  end)

  it("does not change the marks it gets", function()
    local marks = { a = { created = "old" } }
    toggle.apply(marks, toggle.patch(marks, { "a" }, NOW))
    assert.are.same({ a = { created = "old" } }, marks)
  end)
end)
