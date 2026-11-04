local assert = require("luassert")
local cursor = require("review.core.explorer_cursor")

local function rev(id)
  return { type = "revision", change_id = id }
end

local function file(id, path)
  return { type = "file", change_id = id, path = path }
end

-- Rows: 4 c, 5 b, 6 b/f, 7 a
local OLD = { [4] = rev("c"), [5] = rev("b"), [6] = file("b", "f"), [7] = rev("a") }

describe("core.explorer_cursor", function()
  it("stays on the same target when rows move", function()
    local new = { [4] = rev("c"), [5] = file("c", "x"), [6] = rev("b"), [7] = file("b", "f"), [8] = rev("a") }
    assert.are.same(7, cursor.row(OLD, 6, new))
  end)

  it("goes to the revision row when the file is gone", function()
    assert.are.same(5, cursor.row(OLD, 6, { [4] = rev("c"), [5] = rev("b"), [6] = rev("a") }))
  end)

  it("goes to the nearest older revision when the revision is gone", function()
    assert.are.same(5, cursor.row(OLD, 6, { [4] = rev("c"), [5] = rev("a") }))
    assert.are.same(4, cursor.row(OLD, 4, { [4] = rev("b"), [5] = rev("a") }))
  end)

  it("goes to the newest revision when no older one is left", function()
    assert.are.same(4, cursor.row(OLD, 7, { [4] = rev("d"), [5] = rev("c") }))
  end)

  it("keeps the row number when the old row had no target", function()
    assert.is_nil(cursor.row(OLD, 1, OLD))
  end)

  it("has no row when nothing is left", function()
    assert.is_nil(cursor.row(OLD, 5, {}))
  end)
end)
