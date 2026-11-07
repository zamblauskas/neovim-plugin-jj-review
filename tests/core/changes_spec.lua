local assert = require("luassert")
local changes = require("review.core.changes")
local parse = require("review.parse.diff")

---@param body string
---@param header? string
---@return review.FileDiff
local function file(body, header)
  return parse.parse("diff --git a/f b/f\n" .. (header or "") .. "--- a/f\n+++ b/f\n" .. body)[1]
end

--- Compact form: "+line" or "-line^ texts" / "-line_ texts".
---@param segments review.Segment[]
---@return string[]
local function outline(segments)
  return vim.tbl_map(function(s)
    if s.type == "added" then
      return "+" .. s.line
    end
    local texts = vim.tbl_map(function(l)
      return l.text
    end, s.lines)
    return "-" .. s.line .. (s.above and "^ " or "_ ") .. table.concat(texts, ",")
  end, segments)
end

describe("core.changes", function()
  it("places added lines and removed blocks above the next line", function()
    local f = file("@@ -1,7 +1,8 @@\n a\n-b\n+B\n c\n d\n e\n f\n-g\n+G\n+h\n")
    assert.are.same({ "-2^ b", "+2", "-7^ g", "+7", "+8" }, outline(changes.segments(f, 8)))
  end)

  it("groups consecutive removed lines into one block", function()
    assert.are.same({ "-1_ b,c" }, outline(changes.segments(file("@@ -1,3 +1,1 @@\n a\n-b\n-c\n"), 1)))
  end)

  it("puts a block at the end of the file below the last line", function()
    assert.are.same({ "-2_ c" }, outline(changes.segments(file("@@ -1,3 +1,2 @@\n a\n b\n-c\n"), 2)))
  end)

  it("puts a block above line 1", function()
    assert.are.same({ "-1^ x,y" }, outline(changes.segments(file("@@ -1,3 +1,2 @@\n-x\n-y\n a\n b\n"), 2)))
  end)

  it("puts the block of a deleted or emptied file below its one empty line", function()
    local deleted = file("@@ -1,2 +0,0 @@\n-x\n-y\n", "deleted file mode 100644\n")
    assert.are.same({ "-1_ x,y" }, outline(changes.segments(deleted, 1)))
    assert.are.same({ "-1_ keep" }, outline(changes.segments(file("@@ -1,1 +0,0 @@\n-keep\n"), 1)))
  end)

  it("counts lines of a hunk that does not start at line 1", function()
    local f = file("@@ -10,3 +10,3 @@\n a\n-b\n+c\n d\n")
    assert.are.same({ "-11^ b", "+11" }, outline(changes.segments(f, 20)))
  end)

  it("has no segments for a binary file", function()
    assert.are.same({}, changes.segments(parse.parse("diff --git a/b b/b\nBinary files a/b and b/b differ\n")[1], 1))
  end)

  it("finds the first change line, or 1", function()
    assert.are.same(3, changes.first_line(file("@@ -1,3 +1,3 @@\n a\n b\n-c\n+C\n"), 3))
    assert.are.same(1, changes.first_line({ status = "added", path = "f", binary = false, hunks = {} }, 1))
  end)

  it("tags each segment with its hunk index", function()
    local f = file("@@ -1,3 +1,3 @@\n a\n-b\n+B\n c\n@@ -10,3 +10,3 @@\n x\n-y\n+Y\n z\n")
    local hunks = vim.tbl_map(function(s)
      return s.hunk
    end, changes.segments(f, 12))
    assert.are.same({ 1, 1, 2, 2 }, hunks)
  end)

  it("finds the hunk at a line: on its new lines, context included; none between hunks", function()
    local f = file("@@ -1,3 +1,3 @@\n a\n-b\n+B\n c\n@@ -10,3 +10,3 @@\n x\n-y\n+Y\n z\n")
    local segments = changes.segments(f, 12)
    assert.are.same({ 1, 1, 2, nil }, {
      changes.hunk_at(f, segments, 1),
      changes.hunk_at(f, segments, 3),
      changes.hunk_at(f, segments, 10),
      changes.hunk_at(f, segments, 5),
    })
  end)

  it("finds a hunk without new lines on the line its block is placed on", function()
    local f = file("@@ -3,2 +2,0 @@\n-x\n-y\n")
    local segments = changes.segments(f, 5)
    assert.are.same(1, changes.hunk_at(f, segments, 3))
    assert.is_nil(changes.hunk_at(f, segments, 2))
  end)

  it("finds a hunk that removes the end of the file on the last line", function()
    local f = file("@@ -1,3 +1,2 @@\n a\n b\n-c\n")
    assert.are.same(1, changes.hunk_at(f, changes.segments(f, 2), 2))
  end)

  it("lists the segments of a hunk", function()
    local f = file("@@ -1,3 +1,3 @@\n a\n-b\n+B\n c\n@@ -10,3 +10,3 @@\n x\n-y\n+Y\n z\n")
    assert.are.same({ "-11^ y", "+11" }, outline(changes.of_hunk(changes.segments(f, 12), 2)))
  end)

  it("lists the keys of a segment", function()
    local segment = {
      type = "removed",
      line = 1,
      above = true,
      lines = { { kind = "-", text = "", key = "k" }, { kind = "-", text = "" } },
    }
    assert.are.same({ "k" }, changes.keys(segment))
  end)
end)
