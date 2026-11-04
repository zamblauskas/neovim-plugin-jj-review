local assert = require("luassert")
local comments = require("review.core.comments")
local config = require("review.config")
local keys = require("review.core.keys")
local parse = require("review.parse.diff")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")

-- New text: a B c d e f G h (8 lines). Removed "b" above line 2, "g" above line 7.
local BODY = "@@ -1,7 +1,8 @@\n a\n-b\n+B\n c\n d\n e\n f\n-g\n+G\n+h\n"

---@param path string
---@return review.FileDiff
local function file(path)
  return keys.annotate(parse.parse("diff --git a/" .. path .. " b/" .. path .. "\n" .. BODY)[1])
end

---@param id string
---@param parents string[]
---@return review.Revision
local function rev(id, parents)
  return {
    change_id = id,
    short_id = id,
    id_prefix = id,
    commit_id = id .. "1",
    parents = parents,
    empty = false,
    working_copy = false,
    description = "",
  }
end

---@param f review.FileDiff
---@param text string
---@param kind string
---@return string
local function anchor_of(f, text, kind)
  for _, line in ipairs(f.hunks[1].lines) do
    if line.text == text and line.kind == kind then
      return assert(line.anchor)
    end
  end
  error(text)
end

---@param fields table
---@return review.Comment
local function comment(fields)
  return vim.tbl_extend("force", {
    id = "c1",
    anchor = { type = "line", side = "+", start_line = 3, end_line = 3 },
    change_id = "b",
    revision_description = "",
    path = "f",
    keys = {},
    snippet = "",
    text = "hi",
    created = "t",
  }, fields)
end

local F = file("f")

---@param list review.Comment[]
---@return review.State
local function state_with(list)
  local base = state_mod.initial(config.resolve())
  return tbl.with(base, {
    stack = { type = "ok", revisions = { rev("b", { "a1" }), rev("a", {}) } },
    diffs = { b1 = { F }, a1 = {} },
    comments = list,
  })
end

describe("core.comments", function()
  it("gives unchanged lines an anchor that is not a review key", function()
    local c = F.hunks[1].lines[4]
    assert.are.same(" ", c.kind)
    assert.is_nil(c.key)
    assert.truthy(c.anchor:find("^=|f|"))
    assert.are.same(F.hunks[1].lines[3].key, F.hunks[1].lines[3].anchor)
  end)

  it("maps anchors to buffer lines; removed lines to their block line", function()
    local lines = comments.anchor_lines(F, 8)
    assert.are.same(3, lines[anchor_of(F, "c", " ")])
    assert.are.same(2, lines[anchor_of(F, "B", "+")])
    assert.are.same(7, lines[anchor_of(F, "g", "-")])
  end)

  it("places a comment at the last found line of its keys", function()
    local keys_ = { anchor_of(F, "B", "+"), anchor_of(F, "c", " ") }
    local placed = comments.place(state_with({ comment({ keys = keys_ }) }))
    assert.are.same({ "found", "b", "f", 3 }, { placed[1].status, placed[1].change_id, placed[1].path, placed[1].line })
  end)

  it("finds a comment in another revision (squash)", function()
    local c = comment({ change_id = "gone", keys = { anchor_of(F, "G", "+") } })
    local placed = comments.place(state_with({ c }))[1]
    assert.are.same({ "found", "b", 7 }, { placed.status, placed.change_id, placed.line })
  end)

  it("is outdated when no key is found but its revision has the file", function()
    local placed = comments.place(state_with({ comment({ keys = { "+|f|nope|1" } }) }))[1]
    assert.are.same({ "outdated", 3 }, { placed.status, placed.line })
  end)

  it("is orphaned when no key is found and its revision or file is gone", function()
    assert.are.same("orphaned", comments.place(state_with({ comment({ keys = { "x" }, change_id = "z" }) }))[1].status)
    assert.are.same("orphaned", comments.place(state_with({ comment({ keys = { "x" }, path = "other" }) }))[1].status)
  end)

  it("shows a comment without keys at its line while the file is there", function()
    assert.are.same("found", comments.place(state_with({ comment({}) }))[1].status)
  end)

  it("places nothing while a diff loads", function()
    local state = tbl.with(state_with({ comment({}) }), { diffs = { b1 = { F } } })
    assert.are.same({}, comments.place(state))
  end)

  it("applies a patch: remove, replace by id, append", function()
    local a, b = comment({ id = "a" }), comment({ id = "b" })
    local b2, c = comment({ id = "b", text = "new" }), comment({ id = "c" })
    local out = comments.apply({ a, b }, { add = { b2, c }, remove = { "a" } })
    assert.are.same({ b2, c }, out)
  end)

  it("filters placements of one file", function()
    local placed = comments.place(state_with({ comment({}), comment({ id = "c2", path = "other" }) }))
    assert.are.same(1, #comments.in_file(placed, "b", "f"))
  end)
end)
