local assert = require("luassert")
local diff = require("review.parse.diff")

---@return table<string, review.FileDiff>
---@param name string
local function fixture_by_path(name)
  local text = table.concat(vim.fn.readfile("tests/fixtures/" .. name), "\n")
  local by_path = {}
  for _, file in ipairs(diff.parse(text)) do
    by_path[file.path] = file
  end
  return by_path
end

describe("parse.diff", function()
  local files = fixture_by_path("diff_statuses.txt")
  local other = fixture_by_path("diff_paths_and_mode.txt")

  it("parses an added file", function()
    assert.are.same({
      status = "added",
      path = "add.txt",
      binary = false,
      old_blob = "0000000000",
      new_blob = "3e757656cf",
      hunks = {
        { old_start = 0, old_count = 0, new_start = 1, new_count = 1, lines = { { kind = "+", text = "new" } } },
      },
    }, files["add.txt"])
  end)

  it("parses a deleted file", function()
    local file = files["del.txt"]
    assert.are.same("deleted", file.status)
    assert.are.same({ { kind = "-", text = "x" } }, file.hunks[1].lines)
  end)

  it("parses a modified file with context lines", function()
    local file = files["mod.txt"]
    assert.are.same("modified", file.status)
    assert.are.same({ 1, 7, 1, 8 }, {
      file.hunks[1].old_start,
      file.hunks[1].old_count,
      file.hunks[1].new_start,
      file.hunks[1].new_count,
    })
    assert.are.same({ kind = " ", text = "a" }, file.hunks[1].lines[1])
    assert.are.same({ kind = "-", text = "b" }, file.hunks[1].lines[2])
    assert.are.same({ kind = "+", text = "B" }, file.hunks[1].lines[3])
  end)

  it("parses a renamed file", function()
    local file = files["moved.txt"]
    assert.are.same("renamed", file.status)
    assert.are.same("ren.txt", file.old_path)
    assert.are.same(1, #file.hunks)
  end)

  it("parses an emptied file as modified with only removed lines", function()
    local file = files["empty.txt"]
    assert.are.same("modified", file.status)
    assert.are.same({ { kind = "-", text = "keep" } }, file.hunks[1].lines)
  end)

  it("parses an added empty file without hunks", function()
    assert.are.same({
      status = "added",
      path = "newempty.txt",
      binary = false,
      old_blob = "0000000000",
      new_blob = "e69de29bb2",
      hunks = {},
    }, files["newempty.txt"])
  end)

  it("reads the blob hashes of a binary file", function()
    assert.are.same({ "88768efdf7", "3e3315e1b0" }, { files["b.bin"].old_blob, files["b.bin"].new_blob })
  end)

  it("parses binary files", function()
    assert.is_true(files["b.bin"].binary)
    assert.are.same("modified", files["b.bin"].status)
    assert.is_true(other["nb.bin"].binary)
    assert.are.same("added", other["nb.bin"].status)
  end)

  it("flags lines followed by the no-newline marker", function()
    assert.are.same({
      { kind = "-", text = "nonl", no_eol = true },
      { kind = "+", text = "nonl2", no_eol = true },
    }, files["nonl.txt"].hunks[1].lines)
  end)

  it("keeps a whitespace-only change as a file without hunks", function()
    assert.are.same({
      status = "modified",
      path = "ws.txt",
      binary = false,
      old_blob = "aa2c32af38",
      new_blob = "02f5508497",
      hunks = {},
    }, files["ws.txt"])
  end)

  it("parses paths with spaces, quotes and non-ASCII characters", function()
    assert.is_not_nil(other["sp ace b.txt"])
    assert.is_not_nil(other['q"t.txt'])
    assert.is_not_nil(other["ünï.txt"])
  end)

  it("parses a mode change without hunks", function()
    assert.are.same({ status = "modified", path = "mod.txt", binary = false, hunks = {} }, other["mod.txt"])
  end)

  it("returns no files for empty output", function()
    assert.are.same({}, diff.parse(""))
  end)

  it("defaults a missing hunk count to 1", function()
    local file = diff.parse("diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -3 +3 @@\n-x\n+y\n")[1]
    assert.are.same({ 3, 1, 3, 1 }, {
      file.hunks[1].old_start,
      file.hunks[1].old_count,
      file.hunks[1].new_start,
      file.hunks[1].new_count,
    })
  end)
end)
