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

describe("view.explorer", function()
  it("shows loading", function()
    local v = view.render(state_with({ type = "loading" }))
    assert.are.same({ "Stack", "revset: trunk()..@", "", "Loading…" }, v.lines)
  end)

  it("shows revisions with the working copy mark", function()
    local stack = { type = "ok", revisions = { rev("uxlm", "final fixes", true), rev("jrgk", "") } }
    local v = view.render(state_with(stack))
    assert.are.same(
      { "Stack (2)", "revset: trunk()..@", "", "◆ uxlm: final fixes", "  jrgk: (no description)" },
      v.lines
    )
  end)

  it("highlights the id prefix by byte range", function()
    local v = view.render(state_with({ type = "ok", revisions = { rev("uxlm", "x", true) } }))
    local id_hl = vim.tbl_filter(function(h)
      return h.group == "ReviewChangeId"
    end, v.highlights)[1]
    -- "◆ " is 4 bytes
    assert.are.same({ row = 3, col_start = 4, col_end = 5, group = "ReviewChangeId" }, id_hl)
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
