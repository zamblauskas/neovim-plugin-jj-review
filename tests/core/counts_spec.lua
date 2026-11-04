local assert = require("luassert")
local counts = require("review.core.counts")

---@param line_keys string[]
---@return review.FileDiff
local function file(line_keys)
  local lines = vim.tbl_map(function(key)
    return { kind = "+", text = key, key = key }
  end, line_keys)
  table.insert(lines, { kind = " ", text = "ctx" })
  local hunk = { old_start = 1, old_count = 1, new_start = 1, new_count = 1, lines = lines }
  return { status = "modified", path = "f", binary = false, hunks = { hunk } }
end

---@param id string
---@return review.Revision
local function rev(id)
  return {
    change_id = id,
    short_id = id,
    id_prefix = id,
    commit_id = id,
    parents = {},
    empty = false,
    working_copy = false,
    description = "",
  }
end

local MARKS = { a = { created = "t" }, c = { created = "t" } }

describe("core.counts", function()
  it("counts reviewed and total keys of a file", function()
    assert.are.same({ reviewed = 1, total = 2 }, counts.file(file({ "a", "b" }), MARKS))
  end)

  it("counts a binary file as one", function()
    local binary = { status = "modified", path = "b", binary = true, key = "c", hunks = {} }
    assert.are.same({ reviewed = 1, total = 1 }, counts.file(binary, MARKS))
  end)

  it("sums files and revisions", function()
    local diffs = { r1 = { file({ "a", "b" }) }, r2 = { file({ "c" }), file({ "d" }) } }
    assert.are.same({ reviewed = 2, total = 4 }, counts.stack({ rev("r1"), rev("r2") }, diffs, MARKS))
  end)

  it("has no stack count while a diff is loading", function()
    assert.is_nil(counts.stack({ rev("r1"), rev("r2") }, { r1 = {} }, MARKS))
  end)

  it("is done when all are reviewed, also with no lines", function()
    assert.is_true(counts.is_done({ reviewed = 0, total = 0 }))
    assert.is_false(counts.is_done({ reviewed = 1, total = 2 }))
  end)
end)
