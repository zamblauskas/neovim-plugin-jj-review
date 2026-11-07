local assert = require("luassert")
local comment_drafts = require("review.core.comment_drafts")
local config = require("review.config")
local keys = require("review.core.keys")
local parse = require("review.parse.diff")
local state_mod = require("review.core.state")
local tbl = require("review.lib.tbl")

-- New text: a B c d e f G h (8 lines). Removed "b" above line 2, "g" above line 7.
local F = keys.annotate(
  parse.parse("diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1,7 +1,8 @@\n a\n-b\n+B\n c\n d\n e\n f\n-g\n+G\n+h\n")[1]
)
local NEW = { "a", "B", "c", "d", "e", "f", "G", "h" }

local REV = {
  change_id = "r",
  short_id = "r",
  id_prefix = "r",
  commit_id = "r1",
  parents = {},
  empty = false,
  working_copy = false,
  description = "add things",
}

local STATE = tbl.with(state_mod.initial(config.resolve()), {
  stack = { type = "ok", revisions = { REV } },
  diffs = { r1 = { F } },
  contents = { r1 = { f = NEW } },
})

---@param fields table
---@return review.CommentDraft?, string?
local function draft(fields)
  return comment_drafts.for_target(STATE, vim.tbl_extend("force", { change_id = "r", path = "f" }, fields))
end

describe("core.comment_drafts", function()
  it("drafts a comment on one line", function()
    local d, title = draft({ type = "line", line = 2 })
    d = assert(d)
    assert.are.same("f:2", title)
    assert.are.same({ type = "line", side = "+", start_line = 2, end_line = 2 }, d.anchor)
    assert.are.same({ F.hunks[1].lines[3].key }, d.keys)
    assert.are.same({ "B", "r", "add things" }, { d.snippet, d.change_id, d.revision_description })
  end)

  it("drafts a comment on a range, with anchors of unchanged lines", function()
    local d, title = draft({ type = "range", first = 2, last = 3 })
    d = assert(d)
    assert.are.same("f:2-3", title)
    assert.are.same("range", d.anchor.type)
    assert.are.same(2, #d.keys)
    assert.are.same("B\nc", d.snippet)
  end)

  it("drafts a comment on the removed block at the line", function()
    local d, title = draft({ type = "block", line = 7 })
    d = assert(d)
    assert.are.same("f:7 (removed)", title)
    assert.are.same({ type = "block", side = "-", start_line = 7, end_line = 7 }, d.anchor)
    assert.are.same({ F.hunks[1].lines[8].key }, d.keys)
    assert.are.same("g", d.snippet)
  end)

  it("drafts a comment on the hunk at the line: its changes only, no context", function()
    local d, title = draft({ type = "hunk", line = 4 })
    d = assert(d)
    assert.are.same("f:2-8", title)
    assert.are.same({ type = "range", side = "+", start_line = 2, end_line = 8 }, d.anchor)
    assert.are.same(5, #d.keys)
    assert.are.same("b\nB\ng\nG\nh", d.snippet)
  end)

  it("has no draft for a hunk target between hunks, or for a file target", function()
    assert.is_nil(draft({ type = "hunk", line = 9 }))
    assert.is_nil(draft({ type = "file" }))
  end)

  it("has no draft for a block target without a block", function()
    assert.is_nil(draft({ type = "block", line = 4 }))
  end)

  it("has no draft before the new text is loaded", function()
    local state = tbl.with(STATE, { contents = {} })
    assert.is_nil(comment_drafts.for_target(state, { type = "line", change_id = "r", path = "f", line = 1 }))
  end)
end)
