local assert = require("luassert")
local word_diff = require("review.core.word_diff")

describe("core.word_diff", function()
  it("splits text into word runs, whitespace runs and single characters", function()
    assert.are.same(
      { "foo_1", "(", "a", ",", "  ", "é", ")" },
      vim.tbl_map(function(token)
        return token.text
      end, word_diff.tokenize("foo_1(a,  é)"))
    )
  end)

  it("returns the byte ranges of the changed tokens on both sides", function()
    local ranges = assert(word_diff.ranges("f(a, b)", "f(a, bb, c)"))
    assert.are.same({ { col = 5, end_col = 6 } }, ranges.old)
    assert.are.same({ { col = 5, end_col = 10 } }, ranges.new)
  end)

  it("returns empty ranges for equal lines and nil for a rewritten line", function()
    assert.are.same({ old = {}, new = {} }, word_diff.ranges("same", "same"))
    assert.is_nil(word_diff.ranges("f(a, b)", "something else entirely"))
  end)
end)
