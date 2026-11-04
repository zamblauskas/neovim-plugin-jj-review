local assert = require("luassert")
local config = require("review.config")
local modes = require("review.core.modes")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")

---@param id string
---@param fields? table
---@return review.Revision
local function rev(id, fields)
  return vim.tbl_extend("force", {
    change_id = id,
    short_id = id,
    id_prefix = id,
    commit_id = id,
    parents = {},
    empty = false,
    working_copy = false,
    description = "",
  }, fields or {})
end

---@param fields? table
---@return review.FileDiff
local function file(fields)
  return vim.tbl_extend("force", { status = "modified", path = "f", binary = false, hunks = {} }, fields or {})
end

describe("core.modes", function()
  it("finds the commit on disk: @", function()
    assert.are.same("w", modes.disk_commit({ rev("w", { working_copy = true }), rev("a") }))
  end)

  it("finds the commit on disk: @- when @ is empty", function()
    local wc = rev("w", { working_copy = true, empty = true, parents = { "a" } })
    assert.are.same("a", modes.disk_commit({ wc, rev("a") }))
  end)

  it("has no commit on disk when @ is not in the log", function()
    assert.is_false(modes.disk_commit({ rev("a") }))
  end)

  it("uses @ itself when it is an empty merge", function()
    assert.are.same("w", modes.disk_commit({ rev("w", { working_copy = true, empty = true, parents = { "a", "b" } }) }))
  end)

  it("uses working-copy mode for the commit on disk, except deleted and binary files", function()
    local state = tbl.with(state_mod.initial(config.resolve()), { disk_commit = "a" })
    assert.are.same("working_copy", modes.mode(state, rev("a"), file()))
    assert.are.same("view", modes.mode(state, rev("b"), file()))
    assert.are.same("view", modes.mode(state, rev("a"), file({ status = "deleted" })))
    assert.are.same("view", modes.mode(state, rev("a"), file({ binary = true })))
  end)
end)
