local assert = require("luassert")
local keys = require("review.core.keys")
local parse = require("review.parse.diff")
local targets = require("review.core.targets")

-- New text: a B c d e f G h (8 lines). Removed "b" above line 2, "g" above line 7.
local FILE = keys.annotate(
  parse.parse("diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1,7 +1,8 @@\n a\n-b\n+B\n c\n d\n e\n f\n-g\n+G\n+h\n")[1]
)

---@param key string
---@return string  side and first hash characters, enough to tell keys apart in a test
local function short(key)
  local side, rest = key:match("^(.)|f|(%x%x%x%x)")
  return side .. rest
end

---@param fields table
---@return string[]
local function keys_of(fields)
  local target = vim.tbl_extend("force", { change_id = "c", path = "f" }, fields)
  return vim.tbl_map(short, targets.keys(FILE, 8, target))
end

---@param text string
---@return string
local function key_of(text)
  for _, line in ipairs(FILE.hunks[1].lines) do
    if line.text == text and line.kind ~= " " then
      return short(line.key)
    end
  end
  error(text)
end

describe("core.targets", function()
  it("selects the added line at the cursor line", function()
    assert.are.same({ key_of("B") }, keys_of({ type = "line", line = 2 }))
  end)

  it("selects nothing on a context line", function()
    assert.are.same({}, keys_of({ type = "line", line = 3 }))
  end)

  it("selects the removed block attached to the line", function()
    assert.are.same({ key_of("g") }, keys_of({ type = "block", line = 7 }))
  end)

  it("selects added lines and attached blocks in a range", function()
    assert.are.same({ key_of("b"), key_of("B") }, keys_of({ type = "range", first = 1, last = 3 }))
  end)

  it("selects all keys of the file", function()
    assert.are.same(5, #keys_of({ type = "file" }))
  end)
end)
