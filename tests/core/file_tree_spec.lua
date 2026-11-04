local assert = require("luassert")
local file_tree = require("review.core.file_tree")

---@param path string
---@return review.FileDiff
local function file(path)
  return { status = "modified", path = path, binary = false, hunks = {} }
end

---@param entries review.TreeEntry[]
---@return string[]
local function outline(entries)
  return vim.tbl_map(function(entry)
    return string.rep("  ", entry.depth) .. entry.name
  end, entries)
end

describe("core.file_tree", function()
  it("puts directories first, then files, sorted by name", function()
    local entries = file_tree.build({ file("z.lua"), file("lib/b.lua"), file("a.lua"), file("lib/a.lua") })
    assert.are.same({ "lib/", "  a.lua", "  b.lua", "a.lua", "z.lua" }, outline(entries))
  end)

  it("joins a directory with its only subdirectory", function()
    local entries = file_tree.build({ file("src/app/service/a.ts"), file("src/app/service/b.ts") })
    assert.are.same({ "src/app/service/", "  a.ts", "  b.ts" }, outline(entries))
  end)

  it("does not join a directory that has files", function()
    local entries = file_tree.build({ file("src/x.ts"), file("src/app/a.ts") })
    assert.are.same({ "src/", "  app/", "    a.ts", "  x.ts" }, outline(entries))
  end)

  it("keeps the file diff in file entries", function()
    local f = file("a.lua")
    assert.are.equal(f, file_tree.build({ f })[1].file)
  end)

  it("lists paths in display order", function()
    assert.are.same({ "lib/a.lua", "a.lua" }, file_tree.paths({ file("a.lua"), file("lib/a.lua") }))
  end)
end)
