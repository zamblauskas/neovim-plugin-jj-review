local assert = require("luassert")
local config = require("review.config")
local keys = require("review.core.keys")
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
    if mark.opts.hl_eol then
      return "+" .. mark.row
    elseif mark.opts.hl_group then
      return ("~%d:%d-%d"):format(mark.row, mark.col, mark.opts.end_col)
    end
    local texts = vim.tbl_map(function(virt_line)
      return vim.trim(table.concat(vim.tbl_map(function(chunk)
        return chunk[2] == "ReviewRemovedText" and "[" .. chunk[1] .. "]" or chunk[1]
      end, vim.list_slice(virt_line, 2))))
    end, mark.opts.virt_lines)
    return "-" .. mark.row .. (mark.opts.virt_lines_above and "^ " or "_ ") .. table.concat(texts, ",")
  end, rendered.extmarks)
end

---@param fields? table
---@return review.DiffViewInput
local function input(fields)
  return vim.tbl_extend("force", {
    line_count = 8,
    status = "modified",
    tabstop = 4,
    gutter_width = 3,
    marks = {},
    dim = true,
    show_removed = true,
    inline = true,
    comments = {},
    icons = config.defaults.icons,
  }, fields or {})
end

local INPUT = input()

describe("view.diff", function()
  it("highlights the changed tokens of a removed line and the added line that replaced it", function()
    local f = file("@@ -1,2 +1,2 @@\n-f(a, b)\n+f(a, c)\n x\n")
    assert.are.same({ "-0^ f(a, [b])", "+0", "~0:5-6" }, outline(view.render(f, INPUT)))
  end)

  it("pairs block lines with added lines by position and leaves the rest plain", function()
    local f = file("@@ -1,3 +1,2 @@\n-f(a)\n-g(b)\n+f(c)\n x\n")
    assert.are.same({ "-0^ f([a]),g(b)", "+0", "~0:2-3" }, outline(view.render(f, INPUT)))
  end)

  it("shows no tokens for a rewritten line, a dimmed reviewed line, or when inline is off", function()
    local f = file("@@ -1,2 +1,2 @@\n-f(a, b)\n+totally(other)\n x\n")
    assert.are.same({ "-0^ f(a, b)", "+0" }, outline(view.render(f, INPUT)))
    f = file("@@ -1,2 +1,2 @@\n-f(a, b)\n+f(a, b, c)\n x\n")
    assert.are.same({ "-0^ f(a, b)", "+0" }, outline(view.render(f, input({ inline = false }))))
    f = keys.annotate(f)
    local marks = {}
    for _, key in ipairs(keys.of_file(f)) do
      marks[key] = { created = "t" }
    end
    assert.are.same({ "-0^ f(a, b)", "+0" }, outline(view.render(f, input({ marks = marks }))))
  end)

  it("highlights added lines and draws removed blocks with their placement", function()
    local f = file("@@ -1,7 +1,8 @@\n a\n-b\n+B\n c\n d\n e\n f\n-g\n+G\n+h\n")
    assert.are.same({ "-1^ b", "+1", "-6^ g", "+6", "+7" }, outline(view.render(f, INPUT)))
  end)

  it("highlights an added line as a whole-line range, so token ranges can paint over it", function()
    local f = file("@@ -1,1 +1,2 @@\n a\n+b\n")
    local mark = view.render(f, input({ line_count = 2 })).extmarks[1]
    assert.are.same({ row = 1, end_row = 2, end_col = 0, hl_eol = true }, {
      row = mark.row,
      end_row = mark.opts.end_row,
      end_col = mark.opts.end_col,
      hl_eol = mark.opts.hl_eol,
    })
  end)

  it("uses the lighter File groups in a new file and a deleted file", function()
    local f = keys.annotate(file("@@ -0,0 +1,2 @@\n+a\n+b\n", "new file mode 100644\n"))
    local marks = view.render(f, input({ line_count = 2, status = "added" })).extmarks
    assert.are.same("ReviewAddedFile", marks[1].opts.hl_group)
    local reviewed = { [keys.of_file(f)[1]] = { created = "t" } }
    marks = view.render(f, input({ line_count = 2, status = "added", marks = reviewed })).extmarks
    assert.are.same(
      { "ReviewAddedFileReviewed", "ReviewAddedFile" },
      { marks[1].opts.hl_group, marks[2].opts.hl_group }
    )
    f = file("@@ -1,2 +0,0 @@\n-a\n-b\n", "deleted file mode 100644\n")
    marks = view.render(f, input({ line_count = 1, status = "deleted" })).extmarks
    assert.are.same("ReviewRemovedFile", marks[1].opts.virt_lines[1][2][2])
  end)

  it("draws no removed blocks when they are hidden", function()
    local f = file("@@ -1,7 +1,8 @@\n a\n-b\n+B\n c\n d\n e\n f\n-g\n+G\n+h\n")
    local rendered = view.render(f, input({ show_removed = false }))
    assert.are.same({ "+1", "+6", "+7" }, outline(rendered))
    assert.are.same(0, rendered.topfill)
  end)

  it("sets topfill for a block above line 1", function()
    local rendered = view.render(file("@@ -1,3 +1,2 @@\n-x\n-y\n a\n b\n"), input({ line_count = 2 }))
    assert.are.same({ "-0^ x,y" }, outline(rendered))
    assert.are.same(2, rendered.topfill)
  end)

  it("does not count blocks below line 1 in topfill", function()
    local f = file("@@ -1,2 +0,0 @@\n-x\n-y\n", "deleted file mode 100644\n")
    assert.are.same(0, view.render(f, input({ line_count = 1 })).topfill)
  end)

  it("draws nothing for a binary file", function()
    local f = parse.parse("diff --git a/b b/b\nBinary files a/b and b/b differ\n")[1]
    assert.are.same({ extmarks = {}, topfill = 0 }, view.render(f, INPUT))
  end)

  it("expands tabs and pads removed lines with the removed highlight", function()
    local f = file("@@ -1,2 +1,1 @@\n-\tx\n-ab\tc\n a\n")
    local virt_lines = assert(view.render(f, INPUT).extmarks[1].opts.virt_lines)
    assert.are.same("   ", virt_lines[1][1][1])
    assert.are.same("    x", virt_lines[1][2][1]:match("^(.-)%s*$"))
    assert.are.same("ab  c", virt_lines[2][2][1]:match("^(.-)%s*$"))
    assert.are.same({ "ReviewRemoved", "ReviewRemoved" }, { virt_lines[1][2][2], virt_lines[1][3][2] })
    assert.are.same(400, vim.fn.strdisplaywidth(virt_lines[1][2][1] .. virt_lines[1][3][1]))
  end)

  describe("review state", function()
    local f = keys.annotate(file("@@ -1,4 +1,2 @@\n-x\n-y\n+a\n b\n"))
    local x, y, a = f.hunks[1].lines[1].key, f.hunks[1].lines[2].key, f.hunks[1].lines[3].key

    ---@param marks review.Marks
    ---@param dim? boolean
    ---@return review.ExtmarkSpec[]
    local function render(marks, dim)
      return view.render(f, input({ line_count = 2, marks = marks, dim = dim ~= false })).extmarks
    end

    it("draws a reviewed added line with a sign and the dim group", function()
      local added = render({ [a] = { created = "t" } })[2].opts
      assert.are.same(
        { "✓", "ReviewSign", "ReviewAddedReviewed" },
        { added.sign_text, added.sign_hl_group, added.hl_group }
      )
    end)

    it("keeps the normal group when dim is off", function()
      assert.are.same("ReviewAdded", render({ [a] = { created = "t" } }, false)[2].opts.hl_group)
    end)

    it("shows the block state in the gutter of its first line", function()
      local function gutter(marks)
        local virt_lines = assert(render(marks)[1].opts.virt_lines)
        return { vim.trim(virt_lines[1][1][1]), vim.trim(virt_lines[2][1][1]), virt_lines[1][2][2] }
      end
      assert.are.same({ "", "", "ReviewRemoved" }, gutter({}))
      assert.are.same({ "1/2", "", "ReviewRemoved" }, gutter({ [x] = { created = "t" } }))
      assert.are.same(
        { "✓", "", "ReviewRemovedReviewed" },
        gutter({ [x] = { created = "t" }, [y] = { created = "t" } })
      )
    end)

    it("starts block lines at the left edge", function()
      assert.is_true(render({})[1].opts.virt_lines_leftcol)
    end)
  end)

  describe("comments", function()
    local f = file("@@ -1,1 +1,2 @@\n a\n+b\n")

    ---@param status "found"|"outdated"
    ---@param line integer
    ---@return review.Placement
    local function placement(status, line)
      ---@diagnostic disable-next-line: missing-fields
      return { comment = { text = "why\nhere" }, status = status, change_id = "c", path = "f", line = line }
    end

    it("draws a comment below its line with the gutter and the prefix", function()
      local mark = view.render(f, input({ line_count = 2, comments = { placement("found", 2) } })).extmarks[2]
      assert.are.same(1, mark.row)
      assert.is_true(mark.opts.virt_lines_leftcol)
      assert.is_falsy(mark.opts.virt_lines_above)
      assert.are.same({
        { { "   " }, { "💬 why", "ReviewComment" } },
        { { "   " }, { "   here", "ReviewComment" } },
      }, mark.opts.virt_lines)
    end)

    it("draws an outdated comment with its own style, clamped to the buffer", function()
      local mark = view.render(f, input({ line_count = 2, comments = { placement("outdated", 9) } })).extmarks[2]
      assert.are.same(1, mark.row)
      assert.are.same({ "⚠ outdated: why", "ReviewCommentOutdated" }, assert(mark.opts.virt_lines)[1][2])
    end)
  end)
end)
