local assert = require("luassert")
local list = require("review.lib.list")

describe("lib.list", function()
  it("plucks one field of each item", function()
    assert.are.same({ "a", "b" }, list.pluck({ { id = "a" }, { id = "b" } }, "id"))
  end)

  it("indexes items by one field", function()
    local a, b = { id = "a" }, { id = "b" }
    assert.are.same({ a = a, b = b }, list.index_by({ a, b }, "id"))
  end)
end)
