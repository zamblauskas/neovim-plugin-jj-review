local assert = require("luassert")
local actions = require("review.core.explorer_actions")
local msg = require("review.core.msg")

local REVISION = { type = "revision", change_id = "r" }
local FILE = { type = "file", change_id = "r", path = "f" }
local COMMENT = { type = "comment", id = "c1" }

describe("core.explorer_actions", function()
  it("enter: folds a revision, opens a file, does nothing on a comment", function()
    assert.are.same(msg.fold_toggled("r"), actions.enter(REVISION))
    assert.are.same(msg.file_opened("r", "f"), actions.enter(FILE))
    assert.is_nil(actions.enter(COMMENT))
  end)

  it("toggle_file: only on a file row", function()
    assert.are.same(
      msg.toggle_requested({ type = "file", change_id = "r", path = "f" }, "T"),
      actions.toggle_file(FILE, "T")
    )
    assert.is_nil(actions.toggle_file(REVISION, "T"))
  end)

  it("delete_comment: only on a comment row", function()
    assert.are.same(msg.comment_deleted("c1"), actions.delete_comment(COMMENT))
    assert.is_nil(actions.delete_comment(FILE))
  end)
end)
