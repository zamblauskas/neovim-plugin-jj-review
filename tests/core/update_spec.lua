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

  it("computes the default fold once, when the last diff and the marks are loaded", function()
    local state = update(opened_state(), msg.root_resolved(1, "/repo"))
    state = update(state, msg.stack_loaded(1, { rev("b", { "a" }), rev("a", {}) }))
    state = update(state, msg.diff_loaded(1, "a", {}))
    state = update(state, msg.diff_loaded(1, "b", {}))
    assert.is_false(state.fold_default.computed)
    state = update(state, msg.store_loaded(1, {}))
    assert.are.same({ computed = true, known = true }, state.fold_default)
    local again = update(state, msg.store_loaded(1, {}))
    assert.are.equal(state.fold_default, again.fold_default)
  end)

  describe("review buffers after a refresh", function()
    local added = {
      status = "added",
      path = "a.txt",
      binary = false,
      hunks = { { old_start = 0, old_count = 0, new_start = 1, new_count = 1, lines = { { kind = "+", text = "x" } } } },
    }
    local other = vim.tbl_extend("force", added, { path = "o.txt" })
    local a_txt = { change_id = "b", path = "a.txt" }
    local o_txt = { change_id = "b", path = "o.txt" }

    --- Revision "b" (commit "b1") with buffers for a.txt and o.txt, both prepared.
    ---@return review.State
    local function prepared()
      local b1 = vim.tbl_extend("force", rev("b", { "a" }), { commit_id = "b1" })
      local state = update(opened_state(), msg.root_resolved(1, "/repo"))
      state = update(state, msg.stack_loaded(1, { b1, rev("a", {}) }))
      state = update(state, msg.diff_loaded(1, "b1", { added, other }))
      state = update(state, msg.diff_loaded(1, "a", {}))
      state = update(state, msg.content_loaded(1, "b1", "o.txt", { "o" }))
      state = update(state, msg.file_opened("b", "o.txt"))
      state = update(state, msg.file_opened("b", "a.txt"))
      return (update(state, msg.content_loaded(1, "b1", "a.txt", { "x" })))
    end

    ---@return review.Revision
    local function rewritten()
      return vim.tbl_extend("force", rev("b", { "a" }), { commit_id = "b2" })
    end

    it("loads and prepares every buffer of a rewritten revision, without showing", function()
      local state = update(prepared(), msg.stack_loaded(1, { rewritten(), rev("a", {}) }))
      local next_state, effects = update(state, msg.diff_loaded(1, "b2", { added, other }))
      assert.are.same({ "RenderExplorer", "LoadContent", "LoadContent" }, types(effects))
      next_state, effects = update(next_state, msg.content_loaded(1, "b2", "a.txt", { "y" }))
      assert.are.same({ effect.prepare_buffer(a_txt, { "y" }, "view", "/repo/a.txt"), effect.render_diff() }, effects)
      assert.are.same("b2", next_state.buffers["b/a.txt"].commit_id)
      assert.are.same("b1", next_state.buffers["b/o.txt"].commit_id)
    end)

    it("does not load the same content twice", function()
      local state = update(prepared(), msg.stack_loaded(1, { rewritten(), rev("a", {}) }))
      state = update(state, msg.diff_loaded(1, "b2", { added, other }))
      local _, effects = update(state, msg.diff_loaded(1, "a", {}))
      assert.are.same({ "RenderExplorer" }, types(effects))
    end)

    it("prepares the real buffer when the revision becomes the working copy (jj edit)", function()
      local b1 = vim.tbl_extend("force", rev("b", { "a" }), { commit_id = "b1", working_copy = true })
      local state, effects = update(prepared(), msg.stack_loaded(1, { b1, rev("a", {}) }))
      assert.are.same("working_copy", state.buffers["b/a.txt"].mode)
      assert.are.same(effect.prepare_buffer(a_txt, { "x" }, "working_copy", "/repo/a.txt"), effects[2])
    end)

    it("waits for the new diff", function()
      local state, effects = update(prepared(), msg.stack_loaded(1, { rewritten(), rev("a", {}) }))
      assert.are.same("b1", state.buffers["b/a.txt"].commit_id)
      assert.are.same({ "RenderExplorer", "LoadDiff" }, types(effects))
    end)

    it("releases every buffer of a revision that is gone", function()
      local state, effects = update(prepared(), msg.stack_loaded(1, { rev("a", {}) }))
      assert.are.same({}, state.buffers)
      assert.are.same({ effect.render_explorer(), effect.release_buffer(a_txt), effect.release_buffer(o_txt) }, effects)
    end)

    it("releases the buffer of a file that is gone from the revision", function()
      local state = update(prepared(), msg.stack_loaded(1, { rewritten(), rev("a", {}) }))
      local next_state, effects = update(state, msg.diff_loaded(1, "b2", { other }))
      assert.is_nil(next_state.buffers["b/a.txt"])
      assert.are.same({ "RenderExplorer", "ReleaseBuffer", "LoadContent" }, types(effects))
    end)

    it("keeps the buffers while the stack is not linear", function()
      local c = vim.tbl_extend("force", rev("c", { "a" }), {})
      local state = update(prepared(), msg.stack_loaded(1, { rewritten(), c, rev("a", {}) }))
      assert.are.same("error", state.stack.type)
      assert.are.same("b1", state.buffers["b/a.txt"].commit_id)
    end)
  end)

  describe("focus on a real file", function()
    local added = {
      status = "added",
      path = "src/a.txt",
      binary = false,
      hunks = { { old_start = 0, old_count = 0, new_start = 1, new_count = 1, lines = { { kind = "+", text = "x" } } } },
    }

    ---@return review.State
    local function working_copy_state()
      local b = vim.tbl_extend("force", rev("b", { "a" }), { working_copy = true })
      local state = update(opened_state(), msg.root_resolved(1, "/repo"))
      state = update(state, msg.stack_loaded(1, { b, rev("a", {}) }))
      state = update(state, msg.diff_loaded(1, "b", { added }))
      return (update(state, msg.content_loaded(1, "b", "src/a.txt", { "x" })))
    end

    it("adopts a file of the working-copy revision and makes it current", function()
      local state, effects = update(working_copy_state(), msg.focus_changed(nil, "/repo/src/a.txt"))
      local file = { change_id = "b", path = "src/a.txt" }
      assert.are.same(file, state.current)
      assert.are.same({
        effect.prepare_buffer(file, { "x" }, "working_copy", "/repo/src/a.txt"),
        effect.render_diff(),
        effect.render_explorer(),
      }, effects)
    end)

    it("does not adopt a file outside the working-copy revision", function()
      local state, effects = update(working_copy_state(), msg.focus_changed(nil, "/repo/other.txt"))
      assert.are.same({}, state.buffers)
      assert.are.same({}, effects)
    end)

    it("does not adopt a file outside the repo", function()
      local state = update(working_copy_state(), msg.focus_changed(nil, "/elsewhere/src/a.txt"))
      assert.are.same({}, state.buffers)
    end)
  end)

  describe("comments", function()
    local added = {
      status = "added",
      path = "a.txt",
      binary = false,
      hunks = { { old_start = 0, old_count = 0, new_start = 1, new_count = 1, lines = { { kind = "+", text = "x" } } } },
    }

    ---@return review.State
    local function ready()
      local state = update(opened_state(), msg.root_resolved(1, "/repo"))
      state = update(state, msg.stack_loaded(1, { rev("a", {}) }))
      state = update(state, msg.diff_loaded(1, "a", { added }))
      return (update(state, msg.content_loaded(1, "a", "a.txt", { "x" })))
    end

    local target = { type = "line", change_id = "a", path = "a.txt", line = 1 }

    it("opens the input with a draft", function()
      local _, effects = update(ready(), msg.comment_requested(target))
      assert.are.same({ "OpenCommentInput" }, types(effects))
      assert.are.same("a.txt:1", effects[1].title)
    end)

    it("adds a submitted comment and saves it", function()
      local _, input = update(ready(), msg.comment_requested(target))
      local state, effects = update(ready(), msg.comment_submitted(input[1].draft, "why?", "c-1", "T"))
      assert.are.same(
        { "c-1", "why?", "T" },
        { state.comments[1].id, state.comments[1].text, state.comments[1].created }
      )
      assert.are.same({ "SaveComments", "RenderDiff", "RenderExplorer" }, types(effects))
    end)

    it("ignores an empty comment", function()
      local _, input = update(ready(), msg.comment_requested(target))
      local _, effects = update(ready(), msg.comment_submitted(input[1].draft, "  \n", "c-1", "T"))
      assert.are.same({}, effects)
    end)

    it("deletes the comment shown at the line", function()
      local _, input = update(ready(), msg.comment_requested(target))
      local state = update(ready(), msg.comment_submitted(input[1].draft, "why?", "c-1", "T"))
      local next_state, effects = update(state, msg.comment_delete_requested("a", "a.txt", 1))
      assert.are.same({}, next_state.comments)
      assert.are.same({ set = nil, add = {}, remove = { "c-1" } }, effects[1].patch)
      local _, none = update(state, msg.comment_delete_requested("a", "a.txt", 2))
      assert.are.same({}, none)
    end)
  end)

  describe("refresh", function()
    ---@return review.State
    local function loaded()
      local state = update(opened_state(), msg.root_resolved(1, "/repo"))
      state = update(state, msg.stack_loaded(1, { rev("b", { "a" }), rev("a", {}) }))
      state = update(state, msg.diff_loaded(1, "a", {}))
      state = update(state, msg.diff_loaded(1, "b", {}))
      return (update(state, msg.content_loaded(1, "b", "f", { "x" })))
    end

    it("drops cached diffs and contents of commits that left the stack", function()
      local state = update(loaded(), msg.stack_loaded(1, { rev("c", { "a" }), rev("a", {}) }))
      assert.are.same({ "a" }, vim.tbl_keys(state.diffs))
      assert.are.same({}, state.contents)
    end)

    it("loads only diffs of new commits", function()
      local _, effects = update(loaded(), msg.stack_loaded(1, { rev("c", { "a" }), rev("a", {}) }))
      assert.are.same({ "RenderExplorer", "LoadDiff" }, types(effects))
      assert.are.same("c", effects[2].commit_id)
    end)

    it("keeps the stack and warns when jj fails after a stack is loaded", function()
      local state = loaded()
      local next_state, effects = update(state, msg.jj_failed(1, "locked\n"))
      assert.are.equal(state.stack, next_state.stack)
      assert.are.same({ effect.notify("warn", "jj failed, the stack is not updated: locked") }, effects)
    end)
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
      assert.are.same("b/a.txt", state.show_pending)
      assert.are.same({ effect.load_content(1, "/repo", "b", "a.txt") }, effects)
    end)

    it("prepares and shows the buffer when the content arrives", function()
      local file = { change_id = "b", path = "a.txt" }
      local state = update(loaded_state(), msg.file_opened("b", "a.txt"))
      local next_state, effects = update(state, msg.content_loaded(1, "b", "a.txt", { "x" }))
      assert.are.same({ ["a.txt"] = { "x" } }, next_state.contents.b)
      assert.is_nil(next_state.show_pending)
      assert.are.same({
        effect.prepare_buffer(file, { "x" }, "view", "/repo/a.txt"),
        effect.show_buffer(file, 1),
        effect.render_diff(),
      }, effects)
    end)

    it("opens a cached file without loading", function()
      local state = update(loaded_state(), msg.content_loaded(1, "b", "a.txt", { "x" }))
      local _, effects = update(state, msg.file_opened("b", "a.txt"))
      assert.are.same({ "PrepareBuffer", "ShowBuffer", "RenderDiff" }, types(effects))
    end)

    it("shows a prepared buffer again without preparing it", function()
      local state = update(loaded_state(), msg.content_loaded(1, "b", "a.txt", { "x" }))
      state = update(state, msg.file_opened("b", "a.txt"))
      local _, effects = update(state, msg.file_opened("b", "a.txt"))
      assert.are.same({ "ShowBuffer" }, types(effects))
    end)

    it("only caches content of a file without a buffer", function()
      local state = update(loaded_state(), msg.file_opened("b", "d.txt"))
      local next_state, effects = update(state, msg.content_loaded(1, "b", "a.txt", { "x" }))
      assert.are.same({ "x" }, next_state.contents.b["a.txt"])
      assert.are.same({}, effects)
    end)

    it("opens a deleted file with one empty line, without loading", function()
      local file = { change_id = "b", path = "d.txt" }
      local _, effects = update(loaded_state(), msg.file_opened("b", "d.txt"))
      assert.are.same({
        effect.prepare_buffer(file, { "" }, "view", "/repo/d.txt"),
        effect.show_buffer(file, 1),
        effect.render_diff(),
      }, effects)
    end)

    it("steps to the next and previous file in explorer order", function()
      local next_state, effects = update(loaded_state(), msg.file_stepped("b", "a.txt", 1))
      assert.are.same("b", next_state.buffers["b/d.txt"].commit_id)
      assert.are.same({ "PrepareBuffer", "ShowBuffer", "RenderDiff" }, types(effects))
      assert.are.same(
        { effect.load_content(1, "/repo", "b", "a.txt") },
        select(2, update(next_state, msg.file_stepped("b", "d.txt", -1)))
      )
    end)

    it("does not step past the first or the last file", function()
      local state = loaded_state()
      local next_state, effects = update(state, msg.file_stepped("b", "d.txt", 1))
      assert.are.equal(state, next_state)
      assert.are.same({}, effects)
    end)

    it("does not step from an unknown file", function()
      local _, effects = update(loaded_state(), msg.file_stepped("b", "gone.txt", 1))
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

  describe("focus", function()
    local file = { change_id = "b", path = "a.txt" }

    it("draws the diff again when a buffer gets a window", function()
      local state, effects = update(opened_state(), msg.buffer_shown(file))
      assert.are.same({ "RenderDiff" }, types(effects))
      assert.is_nil(state.current)
    end)

    it("stores the focused review file and renders the explorer", function()
      local state, effects = update(opened_state(), msg.focus_changed(file))
      assert.are.same(file, state.current)
      assert.are.same({ "RenderExplorer" }, types(effects))
    end)

    it("does nothing when the focused file is the same", function()
      local state = update(opened_state(), msg.focus_changed(file))
      local next_state, effects = update(state, msg.focus_changed({ change_id = "b", path = "a.txt" }))
      assert.are.equal(state, next_state)
      assert.are.same({}, effects)
    end)

    it("clears the current file when another buffer is focused", function()
      local state = update(opened_state(), msg.focus_changed(file))
      local next_state, effects = update(state, msg.focus_changed(nil, "/elsewhere/x.lua"))
      assert.is_nil(next_state.current)
      assert.are.same({ "RenderExplorer" }, types(effects))
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
    assert.are.same({ "ClearStore", "RenderExplorer", "RenderDiff" }, types(effects))
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

  describe("removed blocks", function()
    it("toggles them off and on, and draws the diff", function()
      local hidden, effects = update(opened_state(), msg.removed_toggled())
      assert.is_false(hidden.show_removed)
      assert.are.same({ "RenderDiff" }, types(effects))
      assert.is_true(update(hidden, msg.removed_toggled()).show_removed)
    end)
  end)
end)
