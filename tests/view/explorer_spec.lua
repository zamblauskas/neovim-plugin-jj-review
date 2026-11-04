local assert = require("luassert")
local config = require("review.config")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")
local view = require("review.view.explorer")

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
    local v = view.render(state_with({ type = "loading" }))
    assert.are.same({ "Stack", "revset: trunk()..@", "", "Loading…" }, v.lines)
  end)

  it("shows revisions with the working copy mark", function()
    local stack = { type = "ok", revisions = { rev("uxlm", "final fixes", true), rev("jrgk", "") } }
    local v = view.render(state_with(stack))
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
    local v = view.render(state_with({ type = "ok", revisions = { rev("uxlm", "x", true) } }))
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
    local v = view.render(state)
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
    end, view.render(state).highlights)
    assert.are.same({ { row = 4, col_start = 4, col_end = 6, group = "ReviewStatusAdded" } }, hl)
  end)

  it("hides files of a closed revision", function()
    local state = state_with({ type = "ok", revisions = { rev("uxlm", "x") } })
    state = tbl.with(state, { folds = { uxlmfull = "closed" } })
    assert.are.same(4, #view.render(state).lines)
  end)

  it("maps rows to revision and file targets", function()
    local state = state_with({ type = "ok", revisions = { rev("uxlm", "x") } })
    state = tbl.with(state, { diffs = { uxlm = { file("added", "d/a") } } })
    assert.are.same({
      [4] = { type = "revision", change_id = "uxlmfull" },
      [6] = { type = "file", change_id = "uxlmfull", path = "d/a" },
    }, view.render(state).targets)
  end)

  describe("counts", function()
    local function counted_state(marks)
      local state = state_with({ type = "ok", revisions = { rev("uxlm", "x") } })
      return tbl.with(state, { diffs = { uxlm = { file("added", "a"), file("added", "b") } }, marks = marks })
    end

    it("right-aligns counts to the explorer width", function()
      local v = view.render(counted_state({ a = { created = "t" } }))
      assert.are.same("Stack (1)" .. string.rep(" ", 28) .. "1/2", v.lines[1])
      assert.are.same(40, vim.fn.strdisplaywidth(v.lines[4]))
      assert.truthy(v.lines[4]:find("1/2$"))
      assert.are.same("    ✅ A a" .. string.rep(" ", 27) .. "1/1", v.lines[5])
    end)

    it("marks a done revision", function()
      local v = view.render(counted_state({ a = { created = "t" }, b = { created = "t" } }))
      assert.truthy(v.lines[4]:find("^▾ ✅ "))
    end)

    it("has no stack count while a diff loads", function()
      local state = tbl.with(counted_state({}), { diffs = {} })
      assert.are.same("Stack (1)", view.render(state).lines[1])
    end)

    it("cuts a long name to keep the count", function()
      local state = state_with({ type = "ok", revisions = { rev("uxlm", string.rep("d", 60)) } })
      state = tbl.with(state, { diffs = { uxlm = { file("added", "a") } } })
      local line = view.render(state).lines[4]
      assert.are.same(40, vim.fn.strdisplaywidth(line))
      assert.truthy(line:find("d… 0/1$"))
    end)
  end)

  it("shows an empty stack", function()
    local v = view.render(state_with({ type = "ok", revisions = {} }))
    assert.are.same("Nothing to review", v.lines[4])
  end)

  it("shows a not linear stack with its heads", function()
    local v = view.render(state_with({ type = "error", reason = "not_linear", revisions = { "uxl", "mzo" } }))
    assert.are.same({ "✖ Stack is not linear", "  revisions: uxl, mzo" }, { v.lines[4], v.lines[5] })
  end)

  it("shows jj stderr lines", function()
    local v = view.render(state_with({ type = "error", reason = "jj_failed", detail = "Error: a\nHint: b" }))
    assert.are.same({ "✖ jj failed", "  Error: a", "  Hint: b" }, { v.lines[4], v.lines[5], v.lines[6] })
  end)
end)
