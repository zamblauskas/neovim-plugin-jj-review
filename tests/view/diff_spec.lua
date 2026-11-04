local assert = require("luassert")
local parse = require("review.parse.diff")
local view = require("review.view.diff")

---@param body string  diff body after the header
---@param status? string  header line for the status
---@return review.FileDiff
local function file(body, status)
  return parse.parse("diff --git a/f b/f\n" .. (status or "") .. "--- a/f\n+++ b/f\n" .. body)[1]
end

--- Compact form of the marks: "+row", "-row^ texts" (above) or "-row_ texts" (below).
---@param rendered review.DiffView
---@return string[]
local function outline(rendered)
  return vim.tbl_map(function(mark)
    if mark.opts.line_hl_group then
      return "+" .. mark.row
    end
    local texts = vim.tbl_map(function(virt_line)
      return vim.trim(virt_line[1][1])
    end, mark.opts.virt_lines)
    return "-" .. mark.row .. (mark.opts.virt_lines_above and "^ " or "_ ") .. table.concat(texts, ",")
  end, rendered.extmarks)
end

local INPUT = { line_count = 8, tabstop = 4 }

describe("view.diff", function()
  it("highlights added lines and puts removed blocks above the next line", function()
    local f = file("@@ -1,7 +1,8 @@\n a\n-b\n+B\n c\n d\n e\n f\n-g\n+G\n+h\n")
    assert.are.same({ "-1^ b", "+1", "-6^ g", "+6", "+7" }, outline(view.render(f, INPUT)))
  end)

  it("groups consecutive removed lines into one block", function()
    local f = file("@@ -1,3 +1,1 @@\n a\n-b\n-c\n")
    assert.are.same({ "-0_ b,c" }, outline(view.render(f, { line_count = 1, tabstop = 4 })))
  end)

  it("puts a block at the end of the file below the last line", function()
    local f = file("@@ -1,3 +1,2 @@\n a\n b\n-c\n")
    assert.are.same({ "-1_ c" }, outline(view.render(f, { line_count = 2, tabstop = 4 })))
  end)

  it("sets topfill for a block above line 1", function()
    local rendered = view.render(file("@@ -1,3 +1,2 @@\n-x\n-y\n a\n b\n"), { line_count = 2, tabstop = 4 })
    assert.are.same({ "-0^ x,y" }, outline(rendered))
    assert.are.same(2, rendered.topfill)
  end)

  it("puts the block of a deleted file below its one empty line", function()
    local f = file("@@ -1,2 +0,0 @@\n-x\n-y\n", "deleted file mode 100644\n")
    local rendered = view.render(f, { line_count = 1, tabstop = 4 })
    assert.are.same({ "-0_ x,y" }, outline(rendered))
    assert.are.same(0, rendered.topfill)
  end)

  it("puts the block of an emptied file below its one empty line", function()
    local f = file("@@ -1,1 +0,0 @@\n-keep\n")
    assert.are.same({ "-0_ keep" }, outline(view.render(f, { line_count = 1, tabstop = 4 })))
  end)

  it("counts lines of a hunk that does not start at line 1", function()
    local f = file("@@ -10,3 +10,3 @@\n a\n-b\n+c\n d\n")
    assert.are.same({ "-10^ b", "+10" }, outline(view.render(f, { line_count = 20, tabstop = 4 })))
  end)

  it("draws nothing for a binary file", function()
    local f = parse.parse("diff --git a/b b/b\nBinary files a/b and b/b differ\n")[1]
    assert.are.same({ extmarks = {}, topfill = 0 }, view.render(f, INPUT))
  end)

  it("expands tabs and pads removed lines with the removed highlight", function()
    local f = file("@@ -1,2 +1,1 @@\n-\tx\n-ab\tc\n a\n")
    local virt_lines = assert(view.render(f, INPUT).extmarks[1].opts.virt_lines)
    assert.are.same("    x", virt_lines[1][1][1]:match("^(.-)%s*$"))
    assert.are.same("ab  c", virt_lines[2][1][1]:match("^(.-)%s*$"))
    assert.are.same("ReviewRemoved", virt_lines[1][1][2])
    assert.are.same(400, vim.fn.strdisplaywidth(virt_lines[1][1][1]))
  end)
end)
