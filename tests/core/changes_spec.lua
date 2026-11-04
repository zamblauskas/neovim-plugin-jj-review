local assert = require("luassert")
local changes = require("review.core.changes")

---@param new_start integer
---@param kinds string  one character per line
---@return review.FileDiff
local function file(new_start, kinds)
  local lines = {}
  for kind in kinds:gmatch(".") do
    table.insert(lines, { kind = kind, text = "" })
  end
  local hunk = { old_start = 1, old_count = 0, new_start = new_start, new_count = 0, lines = lines }
  return { status = "modified", path = "f", binary = false, hunks = { hunk } }
end

describe("core.changes.first_line", function()
  it("finds the first added line after context", function()
    assert.are.same(12, changes.first_line(file(10, "  +")))
  end)

  it("uses the line a removed block attaches to", function()
    assert.are.same(11, changes.first_line(file(10, " - ")))
  end)

  it("is at least 1 for a deleted or emptied file", function()
    assert.are.same(1, changes.first_line(file(0, "-")))
  end)

  it("is 1 without hunks", function()
    assert.are.same(1, changes.first_line({ status = "added", path = "f", binary = false, hunks = {} }))
  end)
end)
