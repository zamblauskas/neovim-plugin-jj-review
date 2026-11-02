local assert = require("luassert")
local tbl = require("review.lib.tbl")

describe("lib.tbl.with", function()
  it("returns a copy with the changes applied", function()
    assert.are.same({ a = 1, b = 3, c = 4 }, tbl.with({ a = 1, b = 2 }, { b = 3, c = 4 }))
  end)

  it("does not change the original table", function()
    local original = { a = 1 }
    tbl.with(original, { a = 2 })
    assert.are.same({ a = 1 }, original)
  end)
end)
