local assert = require("luassert")
local config = require("review.config")
local effect = require("review.core.effect")
local keys = require("review.core.keys")
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
    assert.are.same({ "OpenTab", "RenderExplorer", "ResolveRoot" }, types(effects))
  end)

  it("uses the configured revset by default", function()
    assert.are.same("(trunk()..@)::", opened_state().revset)
  end)

  it("checks the operation after the root is found", function()
    local state, effects = update(opened_state(), msg.root_resolved(1, "/repo"))
    assert.are.same("/repo", state.root)
    assert.are.same(
      { effect.load_store(1, "/repo"), effect.check_op(1, "/repo"), effect.start_watcher(1, "/repo") },
      effects
    )
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

  it("computes the default fold once, when the last diff loads", function()
    local state = update(opened_state(), msg.root_resolved(1, "/repo"))
    state = update(state, msg.stack_loaded(1, { rev("b", { "a" }), rev("a", {}) }))
    state = update(state, msg.diff_loaded(1, "a", {}))
    assert.is_false(state.fold_default.ready)
    state = update(state, msg.diff_loaded(1, "b", {}))
    assert.are.same({ ready = true }, state.fold_default)
    local again = update(state, msg.diff_loaded(1, "b", {}))
    assert.are.equal(state.fold_default, again.fold_default)
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

  it("toggles a revision fold and renders", function()
    local state = update(
      update(opened_state(), msg.root_resolved(1, "/repo")),
      msg.stack_loaded(1, { rev("b", { "a" }), rev("a", {}) })
    )
    local next_state, effects = update(state, msg.fold_toggled("b"))
    assert.are.same({ b = "open" }, next_state.folds)
    assert.are.same({ "RenderExplorer" }, types(effects))
  end)

  describe("opening a file", function()
    local added = {
      status = "added",
      path = "a.txt",
      binary = false,
      hunks = { { old_start = 0, old_count = 0, new_start = 1, new_count = 1, lines = { { kind = "+", text = "x" } } } },
    }
    local deleted = { status = "deleted", path = "d.txt", binary = false, hunks = {} }

    ---@return review.State
    local function loaded_state()
      local state = update(opened_state(), msg.root_resolved(1, "/repo"))
      state = update(state, msg.stack_loaded(1, { rev("b", { "a" }), rev("a", {}) }))
      return (update(state, msg.diff_loaded(1, "b", { added, deleted })))
    end

    it("loads the content when it is not in the cache", function()
      local state, effects = update(loaded_state(), msg.file_opened("b", "a.txt"))
      assert.are.same({ change_id = "b", path = "a.txt" }, state.open_file)
      assert.are.same({ effect.load_content(1, "/repo", "b", "a.txt") }, effects)
    end)

    it("opens the buffer when the content arrives", function()
      local state = update(loaded_state(), msg.file_opened("b", "a.txt"))
      local next_state, effects = update(state, msg.content_loaded(1, "b", "a.txt", { "x" }))
      assert.are.same({ ["a.txt"] = { "x" } }, next_state.contents.b)
      assert.are.same({ effect.open_buffer("b", "a.txt", { "x" }, 1), effect.render_diff() }, effects)
    end)

    it("opens a cached file without loading", function()
      local state = update(loaded_state(), msg.content_loaded(1, "b", "a.txt", { "x" }))
      local _, effects = update(state, msg.file_opened("b", "a.txt"))
      assert.are.same({ "OpenBuffer", "RenderDiff" }, types(effects))
    end)

    it("only caches content of a file that is not open any more", function()
      local state = update(loaded_state(), msg.file_opened("b", "d.txt"))
      local next_state, effects = update(state, msg.content_loaded(1, "b", "a.txt", { "x" }))
      assert.are.same({ "x" }, next_state.contents.b["a.txt"])
      assert.are.same({}, effects)
    end)

    it("opens a deleted file with one empty line, without loading", function()
      local _, effects = update(loaded_state(), msg.file_opened("b", "d.txt"))
      assert.are.same({ effect.open_buffer("b", "d.txt", { "" }, 1), effect.render_diff() }, effects)
    end)

    it("steps to the next and previous file in explorer order", function()
      local state = update(loaded_state(), msg.file_opened("b", "a.txt"))
      local next_state, effects = update(state, msg.file_stepped(1))
      assert.are.same({ change_id = "b", path = "d.txt" }, next_state.open_file)
      assert.are.same({ "OpenBuffer", "RenderDiff" }, types(effects))
      assert.are.same("a.txt", update(next_state, msg.file_stepped(-1)).open_file.path)
    end)

    it("does not step past the first or the last file", function()
      local state = update(loaded_state(), msg.file_opened("b", "d.txt"))
      local next_state, effects = update(state, msg.file_stepped(1))
      assert.are.equal(state, next_state)
      assert.are.same({}, effects)
    end)

    it("does not step without an open file", function()
      local _, effects = update(loaded_state(), msg.file_stepped(1))
      assert.are.same({}, effects)
    end)

    it("toggles the file and saves the patch", function()
      local state =
        update(loaded_state(), msg.toggle_requested({ type = "file", change_id = "b", path = "a.txt" }, "T"))
      local key = keys.annotate(added).hunks[1].lines[1].key
      assert.are.same({ [key] = { created = "T" } }, state.marks)
      local _, effects =
        update(loaded_state(), msg.toggle_requested({ type = "file", change_id = "b", path = "a.txt" }, "T"))
      assert.are.same({ "SaveMarks", "RenderDiff", "RenderExplorer" }, types(effects))
      assert.are.same({ set = { [key] = { created = "T" } }, unset = {} }, effects[1].patch)
    end)

    it("unmarks on a second toggle", function()
      local toggle_msg = msg.toggle_requested({ type = "line", change_id = "b", path = "a.txt", line = 1 }, "T")
      local state = update(update(loaded_state(), msg.content_loaded(1, "b", "a.txt", { "x" })), toggle_msg)
      assert.are.same({}, update(state, toggle_msg).marks)
    end)

    it("does nothing when the target has no keys", function()
      local toggle_msg = msg.toggle_requested({ type = "line", change_id = "b", path = "a.txt", line = 9 }, "T")
      local state = loaded_state()
      local next_state, effects = update(state, toggle_msg)
      assert.are.equal(state, next_state)
      assert.are.same({}, effects)
    end)

    it("moves the cursor to the next unreviewed change", function()
      local state = update(loaded_state(), msg.content_loaded(1, "b", "a.txt", { "x" }))
      local _, effects = update(state, msg.unreviewed_stepped("b", "a.txt", 1, -1))
      assert.are.same({}, effects)
      local _, back = update(state, msg.unreviewed_stepped("b", "a.txt", 2, -1))
      assert.are.same({ effect.move_cursor(1) }, back)
    end)

    it("ignores an unknown file", function()
      local state = loaded_state()
      local next_state, effects = update(state, msg.file_opened("b", "nope"))
      assert.are.equal(state, next_state)
      assert.are.same({}, effects)
    end)
  end)

  it("keeps loaded marks and renders", function()
    local marks = { k = { created = "t" } }
    local state, effects = update(opened_state(), msg.store_loaded(1, marks))
    assert.are.same(marks, state.marks)
    assert.are.same({ "RenderExplorer", "RenderDiff" }, types(effects))
  end)

  it("shows a store error", function()
    local _, effects = update(opened_state(), msg.store_failed(1, "bad"))
    assert.are.same({ effect.notify("error", "bad") }, effects)
  end)

  it("clears all marks", function()
    local state = update(opened_state(), msg.root_resolved(1, "/repo"))
    state = update(state, msg.store_loaded(1, { k = { created = "t" } }))
    local next_state, effects = update(state, msg.cleared())
    assert.are.same({}, next_state.marks)
    assert.are.same({ "ClearMarks", "RenderExplorer", "RenderDiff" }, types(effects))
  end)

  it("checks the operation and the store on refresh", function()
    local state = update(opened_state(), msg.root_resolved(1, "/repo"))
    local _, effects = update(state, msg.refresh_requested(1))
    assert.are.same({ effect.check_op(1, "/repo"), effect.load_store(1, "/repo") }, effects)
  end)

  it("drops results of an older open", function()
    local reopened = update(opened_state(), msg.opened("/repo"))
    local state, effects = update(reopened, msg.root_resolved(1, "/old"))
    assert.is_nil(state.root)
    assert.are.same({}, effects)
  end)

  it("drops results after close", function()
    local closed, effects = update(opened_state(), msg.closed())
    assert.are.same({ "StopWatcher", "CloseTab" }, types(effects))
    local state = update(closed, msg.root_resolved(1, "/repo"))
    assert.is_nil(state.root)
  end)

  it("does not change the old state", function()
    local before = opened_state()
    update(before, msg.root_resolved(1, "/repo"))
    assert.is_nil(before.root)
  end)
end)
