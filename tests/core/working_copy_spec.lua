local assert = require("luassert")
local config = require("review.config")
local effect = require("review.core.effect")
local msg = require("review.core.msg")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")
local update = require("review.core.update").update

---@return review.State
local function state()
  return tbl.with(state_mod.initial(config.resolve()), { open = true, generation = 1, root = "/repo" })
end

describe("core working copy handlers", function()
  it("snapshots after a file of the repo is saved", function()
    local _, effects = update(state(), msg.file_saved(1, "/repo/src/a.lua"))
    assert.are.same({ effect.snapshot("/repo") }, effects)
  end)

  it("ignores files outside the repo and inside .jj", function()
    assert.are.same({}, select(2, update(state(), msg.file_saved(1, "/other/a.lua"))))
    assert.are.same({}, select(2, update(state(), msg.file_saved(1, "/repository/a.lua"))))
    assert.are.same({}, select(2, update(state(), msg.file_saved(1, "/repo/.jj/review/marks.json"))))
  end)

  it("snapshots on request", function()
    local _, effects = update(state(), msg.snapshot_requested())
    assert.are.same({ effect.snapshot("/repo") }, effects)
  end)

  it("snapshots nothing without a root", function()
    local no_root = tbl.with(state_mod.initial(config.resolve()), { open = true, generation = 1 })
    assert.are.same({}, select(2, update(no_root, msg.snapshot_requested())))
  end)

  it("runs jj edit", function()
    local _, effects = update(state(), msg.edit_requested("kxyz"))
    assert.are.same({ effect.jj_edit("/repo", "kxyz") }, effects)
  end)

  it("warns when a command fails", function()
    local _, effects = update(state(), msg.command_failed("jj failed: immutable"))
    assert.are.same({ effect.notify("warn", "jj failed: immutable") }, effects)
  end)
end)
