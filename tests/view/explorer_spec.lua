local assert = require("luassert")
local config = require("review.config")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")
local view = require("review.view.explorer")

local WIDTH = 40

---@param state review.State
---@return review.View
local function view_of(state)
  return view.render(state, WIDTH)
end

---@param stack review.Stack
---@return review.State
local function state_with(stack)
  return tbl.with(state_mod.initial(config.resolve()), { stack = stack, revset = "trunk()..@" })
end

---@param id string
---@param description string
---@param working_copy? boolean
---@return review.Revision
local function rev(id, description, working_copy)
  return {
    change_id = id .. "full",
    short_id = id,
    id_prefix = id:sub(1, 1),
    commit_id = id,
    parents = {},
    empty = false,
    working_copy = working_copy or false,
    description = description,
  }
end

--- File diff with one added line whose key is `path`.
---@param status string
---@param path string
---@param fields? table
---@return review.FileDiff
local function file(status, path, fields)
  local hunk = {
    old_start = 0,
    old_count = 0,
    new_start = 1,
    new_count = 1,
    lines = { { kind = "+", text = "x", key = path } },
  }
  return vim.tbl_extend("force", { status = status, path = path, binary = false, hunks = { hunk } }, fields or {})
end

--- Left part of a row, without the right-aligned count.
---@param line string
---@return string
local function left(line)
  return line:match("^(.-)%s+%d+/%d+$") or line
end

describe("view.explorer", function()
  it("shows loading", function()
    local v = view_of(state_with({ type = "loading" }))
    assert.are.same({ "Stack", "revset: trunk()..@", "", "Loading…" }, v.lines)
  end)

  it("shows revisions with the working copy mark", function()
    local stack = { type = "ok", revisions = { rev("uxlm", "final fixes", true), rev("jrgk", "") } }
    local v = view_of(state_with(stack))
    assert.are.same({
      "Stack (2)",
      "revset: trunk()..@",
      "",
      "▸ ◆ uxlm: final fixes",
      "▾   jrgk: (no description)",
      "    Loading…",
    }, v.lines)
  end)

  it("highlights the id prefix by byte range", function()
    local v = view_of(state_with({ type = "ok", revisions = { rev("uxlm", "x", true) } }))
    local id_hl = vim.tbl_filter(function(h)
      return h.group == "ReviewChangeId"
    end, v.highlights)[1]
    -- "▾ " and "◆ " are 4 bytes each
    assert.are.same({ row = 3, col_start = 8, col_end = 9, group = "ReviewChangeId" }, id_hl)
  end)

  it("shows the file tree of an open revision with status letters", function()
    local state = state_with({ type = "ok", revisions = { rev("uxlm", "x") } })
    state = tbl.with(state, {
      diffs = {
        uxlm = {
          file("added", "src/app/a.ts"),
          file("renamed", "b.ts", { old_path = "old/b.ts" }),
          file("deleted", "c.bin", { binary = true, hunks = {}, key = "c.bin" }),
        },
      },
    })
    local v = view_of(state)
    assert.are.same(
      { "    src/app/", "      A a.ts", "    R b.ts ← old/b.ts", "    D c.bin (binary)" },
      vim.tbl_map(left, vim.list_slice(v.lines, 5))
    )
  end)

  it("colors the status letter", function()
    local state = state_with({ type = "ok", revisions = { rev("uxlm", "x") } })
    state = tbl.with(state, { diffs = { uxlm = { file("added", "a") } } })
    local hl = vim.tbl_filter(function(h)
      return h.group == "ReviewStatusAdded"
    end, view_of(state).highlights)
    assert.are.same({ { row = 4, col_start = 4, col_end = 6, group = "ReviewStatusAdded" } }, hl)
  end)

  it("hides files of a closed revision", function()
    local state = state_with({ type = "ok", revisions = { rev("uxlm", "x") } })
    state = tbl.with(state, { folds = { uxlmfull = "closed" } })
    assert.are.same(4, #view_of(state).lines)
  end)

  it("maps rows to revision and file targets", function()
    local state = state_with({ type = "ok", revisions = { rev("uxlm", "x") } })
    state = tbl.with(state, { diffs = { uxlm = { file("added", "d/a") } } })
    assert.are.same({
      [4] = { type = "revision", change_id = "uxlmfull" },
      [6] = { type = "file", change_id = "uxlmfull", path = "d/a" },
    }, view_of(state).targets)
  end)

  describe("counts", function()
    local function counted_state(marks)
      local state = state_with({ type = "ok", revisions = { rev("uxlm", "x") } })
      return tbl.with(state, { diffs = { uxlm = { file("added", "a"), file("added", "b") } }, marks = marks })
    end

    it("right-aligns counts to the given width", function()
      local v = view_of(counted_state({ a = { created = "t" } }))
      assert.are.same("Stack (1)" .. string.rep(" ", 28) .. "1/2", v.lines[1])
      assert.are.same(40, vim.fn.strdisplaywidth(v.lines[4]))
      assert.truthy(v.lines[4]:find("1/2$"))
      assert.are.same("    ✅ A a" .. string.rep(" ", 27) .. "1/1", v.lines[5])
    end)

    it("marks a done revision", function()
      local v = view_of(counted_state({ a = { created = "t" }, b = { created = "t" } }))
      assert.truthy(v.lines[4]:find("^▾ ✅ "))
    end)

    it("has no stack count while a diff loads", function()
      local state = tbl.with(counted_state({}), { diffs = {} })
      assert.are.same("Stack (1)", view_of(state).lines[1])
    end)

    it("cuts a long name to keep the count", function()
      local state = state_with({ type = "ok", revisions = { rev("uxlm", string.rep("d", 60)) } })
      state = tbl.with(state, { diffs = { uxlm = { file("added", "a") } } })
      local line = view_of(state).lines[4]
      assert.are.same(40, vim.fn.strdisplaywidth(line))
      assert.truthy(line:find("d… 0/1$"))
    end)
  end)

  describe("comments", function()
    ---@param fields table
    ---@return review.Comment
    local function comment(fields)
      return vim.tbl_extend("force", {
        id = "c1",
        anchor = { type = "line", side = "+", start_line = 1, end_line = 1 },
        change_id = "uxlmfull",
        revision_description = "",
        path = "a",
        keys = {},
        snippet = "",
        text = "why\nsecond line",
        created = "t",
      }, fields)
    end

    ---@param list review.Comment[]
    ---@return review.View
    local function render(list)
      local state = state_with({ type = "ok", revisions = { rev("uxlm", "x") } })
      return view_of(tbl.with(state, { diffs = { uxlm = { file("added", "a") } }, comments = list }))
    end

    it("shows 💬 after the name, with the count aligned at the end", function()
      local v = render({ comment({}) })
      assert.truthy(v.lines[4]:find("x 💬 +0/1$"))
      assert.truthy(v.lines[5]:find("A a 💬 +0/1$"))
      assert.are.same(WIDTH, vim.fn.strdisplaywidth(v.lines[5]))
    end)

    it("shows ⚠ for an outdated comment", function()
      local v = render({ comment({ keys = { "+|a|gone|1" } }) })
      assert.truthy(v.lines[5]:find("A a 💬 ⚠ +0/1$"))
    end)

    it("cuts a long name but keeps 💬 and the count", function()
      local state = state_with({ type = "ok", revisions = { rev("uxlm", string.rep("d", 60)) } })
      local v = view_of(tbl.with(state, { diffs = { uxlm = { file("added", "a") } }, comments = { comment({}) } }))
      assert.are.same(WIDTH, vim.fn.strdisplaywidth(v.lines[4]))
      assert.truthy(v.lines[4]:find("d… 💬 0/1$"))
    end)

    it("lists orphaned comments at the bottom with a target", function()
      local v = render({
        comment({
          change_id = "gone",
          keys = { "x" },
          path = "old.txt",
          anchor = { type = "line", side = "+", start_line = 42, end_line = 42 },
        }),
      })
      assert.are.same({ "", "Orphaned comments (1)", '  ⚠ old.txt:42 "why"' }, vim.list_slice(v.lines, 6))
      assert.are.same({ type = "comment", id = "c1" }, v.targets[8])
    end)

    it("has no orphan section without orphans", function()
      assert.are.same(5, #render({}).lines)
    end)
  end)

  it("uses the configured icons, with blanks of the same width", function()
    local state = state_with({ type = "ok", revisions = { rev("uxlm", "x", true), rev("jrgk", "y") } })
    local icons = vim.tbl_extend("force", state.config.icons, { working_copy = "WC" })
    state = tbl.with(state, { config = tbl.with(state.config, { icons = icons }) })
    local lines = view_of(state).lines
    assert.are.same({ "▸ WC uxlm: x", "▾    jrgk: y" }, { lines[4], lines[5] })
  end)

  it("shows an empty stack", function()
    local v = view_of(state_with({ type = "ok", revisions = {} }))
    assert.are.same("Nothing to review", v.lines[4])
  end)

  it("shows a not linear stack with its heads", function()
    local v = view_of(state_with({ type = "error", reason = "not_linear", revisions = { "uxl", "mzo" } }))
    assert.are.same({ "✖ Stack is not linear", "  revisions: uxl, mzo" }, { v.lines[4], v.lines[5] })
  end)

  it("shows jj stderr lines", function()
    local v = view_of(state_with({ type = "error", reason = "jj_failed", detail = "Error: a\nHint: b" }))
    assert.are.same({ "✖ jj failed", "  Error: a", "  Hint: b" }, { v.lines[4], v.lines[5], v.lines[6] })
  end)
end)
