local assert = require("luassert")
local changes = require("review.core.changes")
local keys = require("review.core.keys")
local navigation = require("review.core.navigation")
local parse = require("review.parse.diff")

-- New text: a B c d e f G h. Segments: block "b" and "B" at 2, block "g" and "G" at 7, "h" at 8.
local FILE = keys.annotate(
  parse.parse("diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1,7 +1,8 @@\n a\n-b\n+B\n c\n d\n e\n f\n-g\n+G\n+h\n")[1]
)
local SEGMENTS = changes.segments(FILE, 8)

---@param text string
---@param kind string
---@return string
local function key_of(text, kind)
  for _, line in ipairs(FILE.hunks[1].lines) do
    if line.text == text and line.kind == kind then
      return assert(line.key)
    end
  end
  error(text)
end

describe("core.navigation", function()
  it("steps to the next or previous candidate line, without wrap", function()
    assert.are.same(5, navigation.step({ 2, 5, 9 }, 2, 1))
    assert.are.same(2, navigation.step({ 2, 5, 9 }, 5, -1))
    assert.is_nil(navigation.step({ 2, 5, 9 }, 9, 1))
    assert.is_nil(navigation.step({}, 1, 1))
  end)

  it("finds the next and previous unreviewed line", function()
    assert.are.same(2, navigation.unreviewed_line(SEGMENTS, {}, 1, 1))
    assert.are.same(7, navigation.unreviewed_line(SEGMENTS, {}, 2, 1))
    assert.are.same(7, navigation.unreviewed_line(SEGMENTS, {}, 8, -1))
  end)

  it("skips reviewed changes", function()
    local marks = { [key_of("g", "-")] = { created = "t" }, [key_of("G", "+")] = { created = "t" } }
    assert.are.same(8, navigation.unreviewed_line(SEGMENTS, marks, 2, 1))
  end)

  it("stays at a line with a reviewed line and an unreviewed block", function()
    local marks = { [key_of("G", "+")] = { created = "t" } }
    assert.are.same(7, navigation.unreviewed_line(SEGMENTS, marks, 2, 1))
  end)

  it("finds the next and previous hunk by its first change", function()
    local two_hunks = keys.annotate(parse.parse(table.concat({
      "diff --git a/f b/f",
      "--- a/f",
      "+++ b/f",
      "@@ -1,2 +1,2 @@",
      " a",
      "-b",
      "+B",
      "@@ -20,2 +20,3 @@",
      " x",
      "+y",
      "+z",
      "",
    }, "\n"))[1])
    local segments = changes.segments(two_hunks, 22)
    assert.are.same(2, navigation.hunk_line(segments, 1, 1))
    assert.are.same(21, navigation.hunk_line(segments, 2, 1))
    assert.are.same(2, navigation.hunk_line(segments, 21, -1))
    assert.is_nil(navigation.hunk_line(segments, 21, 1))
  end)

  it("does not wrap", function()
    assert.is_nil(navigation.unreviewed_line(SEGMENTS, {}, 8, 1))
    assert.is_nil(navigation.unreviewed_line(SEGMENTS, {}, 2, -1))
  end)
end)
