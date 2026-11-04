local assert = require("luassert")
local list = require("review.lib.list")
local stack = require("review.core.stack")

--- Revision with commit id = short id = `id`.
---@param id string
---@param parents string[]
---@param empty? boolean
---@return review.Revision
local function rev(id, parents, empty)
  return {
    change_id = id,
    short_id = id,
    id_prefix = id,
    commit_id = id,
    parents = parents,
    empty = empty or false,
    working_copy = false,
    description = "",
  }
end

---@param result review.StackOk|review.StackError
---@return string[]
local function ids(result)
  return list.pluck(result.revisions, "short_id")
end

describe("core.stack.build", function()
  it("orders a linear stack newest first", function()
    local result = stack.build({ rev("a", { "trunk" }), rev("c", { "b" }), rev("b", { "a" }) })
    assert.are.same("ok", result.type)
    assert.are.same({ "c", "b", "a" }, ids(result))
  end)

  it("hides empty revisions and links across them", function()
    local result = stack.build({ rev("w", { "c" }, true), rev("c", { "e" }), rev("e", { "a" }, true), rev("a", {}) })
    assert.are.same({ "c", "a" }, ids(result))
  end)

  it("ignores an empty sibling (jj new on a middle revision)", function()
    local result = stack.build({ rev("c", { "b" }), rev("w", { "b" }, true), rev("b", { "a" }), rev("a", {}) })
    assert.are.same({ "c", "b", "a" }, ids(result))
  end)

  it("fails when there are two heads", function()
    local result = stack.build({ rev("c", { "a" }), rev("b", { "a" }), rev("a", {}) })
    assert.are.same({ type = "error", reason = "not_linear", revisions = { "c", "b" } }, result)
  end)

  it("fails on a merge inside the stack", function()
    local result = stack.build({ rev("m", { "a", "b" }), rev("a", {}), rev("b", {}) })
    assert.are.same({ type = "error", reason = "merge", revisions = { "m" } }, result)
  end)

  it("accepts a merge with one parent outside the stack", function()
    local result = stack.build({ rev("m", { "a", "trunk" }), rev("a", {}) })
    assert.are.same({ "m", "a" }, ids(result))
  end)

  it("returns an empty stack when all revisions are empty", function()
    assert.are.same({ type = "ok", revisions = {} }, stack.build({ rev("w", {}, true) }))
  end)
end)
