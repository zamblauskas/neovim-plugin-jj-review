local assert = require("luassert")

describe("test runner", function()
  it("runs specs", function()
    assert.are.same(2, 1 + 1)
  end)
end)
