local assert = require("luassert")
local config = require("review.config")
local list = require("review.lib.list")
local msg = require("review.core.msg")
local state_mod = require("review.core.state")
local update = require("review.core.update").update

---@param effects review.Effect[]
---@return string[]
local function types(effects)
  return list.pluck(effects, "type")
end

---@return review.State
local function opened_state()
  local state = update(state_mod.initial(config.resolve()), msg.opened("/repo/sub"))
  return state
end

---@param id string
---@param parents string[]
---@return review.Revision
local function rev(id, parents)
  return {
    change_id = id,
    short_id = id,
    id_prefix = id,
    commit_id = id,
    parents = parents,
    empty = false,
    working_copy = false,
    description = "",
  }
end

describe("core.update", function()
  it("opens the explorer and resolves the root", function()
    local state, effects = update(state_mod.initial(config.resolve()), msg.opened("/repo/sub", "@"))
    assert.is_true(state.open)
    assert.are.same(1, state.generation)
    assert.are.same("@", state.revset)
    assert.are.same({ "OpenExplorer", "RenderExplorer", "ResolveRoot" }, types(effects))
  end)

  it("uses the configured revset by default", function()
    assert.are.same("(trunk()..@)::", opened_state().revset)
  end)

  it("checks the operation after the root is found", function()
    local state, effects = update(opened_state(), msg.root_resolved(1, "/repo"))
    assert.are.same("/repo", state.root)
    assert.are.same({ { type = "CheckOp", generation = 1, root = "/repo" } }, effects)
  end)

  it("loads the stack when the operation changed", function()
    local state = update(opened_state(), msg.root_resolved(1, "/repo"))
    local next_state, effects = update(state, msg.op_checked(1, "op1"))
    assert.are.same("op1", next_state.op_id)
    assert.are.same({ "LoadStack" }, types(effects))
  end)

  it("does nothing when the operation did not change", function()
    local state = update(update(opened_state(), msg.root_resolved(1, "/repo")), msg.op_checked(1, "op1"))
    local _, effects = update(state, msg.op_checked(1, "op1"))
    assert.are.same({}, effects)
  end)

  it("builds the stack, renders, and loads the diff of each revision", function()
    local state = update(opened_state(), msg.root_resolved(1, "/repo"))
    local next_state, effects = update(state, msg.stack_loaded(1, { rev("b", { "a" }), rev("a", {}) }))
    assert.are.same("ok", next_state.stack.type)
    assert.are.same(2, #next_state.stack.revisions)
    assert.are.same({
      { type = "RenderExplorer" },
      { type = "LoadDiff", generation = 1, root = "/repo", commit_id = "b" },
      { type = "LoadDiff", generation = 1, root = "/repo", commit_id = "a" },
    }, effects)
  end)

  it("does not load a diff that is in the cache", function()
    local state = update(opened_state(), msg.root_resolved(1, "/repo"))
    state = update(state, msg.diff_loaded(1, "a", {}))
    local _, effects = update(state, msg.stack_loaded(1, { rev("b", { "a" }), rev("a", {}) }))
    assert.are.same({ "RenderExplorer", "LoadDiff" }, types(effects))
    assert.are.same("b", effects[2].commit_id)
  end)

  it("does not load diffs for a stack error", function()
    local state = update(opened_state(), msg.root_resolved(1, "/repo"))
    local _, effects = update(state, msg.stack_loaded(1, { rev("b", { "x" }), rev("c", { "x" }), rev("x", {}) }))
    assert.are.same({ "RenderExplorer" }, types(effects))
  end)

  it("stores a loaded diff by commit id and renders", function()
    local files = { { status = "added", path = "f", binary = false, hunks = {} } }
    local state, effects = update(opened_state(), msg.diff_loaded(1, "a", files))
    assert.are.same(files, state.diffs.a)
    assert.are.same({ "RenderExplorer" }, types(effects))
  end)

  it("shows a jj failure as a stack error", function()
    local state = update(opened_state(), msg.jj_failed(1, "Error: bad revset\n"))
    assert.are.same({ type = "error", reason = "jj_failed", detail = "Error: bad revset" }, state.stack)
  end)

  it("drops results of an older open", function()
    local reopened = update(opened_state(), msg.opened("/repo"))
    local state, effects = update(reopened, msg.root_resolved(1, "/old"))
    assert.is_nil(state.root)
    assert.are.same({}, effects)
  end)

  it("drops results after close", function()
    local closed, effects = update(opened_state(), msg.closed())
    assert.are.same({ "CloseExplorer" }, types(effects))
    local state = update(closed, msg.root_resolved(1, "/repo"))
    assert.is_nil(state.root)
  end)

  it("does not change the old state", function()
    local before = opened_state()
    update(before, msg.root_resolved(1, "/repo"))
    assert.is_nil(before.root)
  end)
end)
