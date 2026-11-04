local assert = require("luassert")
local text = require("review.lib.text")

describe("lib.text", function()
  it("keeps text that fits", function()
    assert.are.same("abc", text.truncate("abc", 3))
  end)

  it("cuts text with an ellipsis", function()
    assert.are.same("ab…", text.truncate("abcdef", 3))
  end)

  it("measures wide characters by display width", function()
    assert.are.same(2, text.width("✅"))
    assert.are.same("a…", text.truncate("a✅b", 3))
  end)
end)
