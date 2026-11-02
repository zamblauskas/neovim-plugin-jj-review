local assert = require("luassert")
local helpers = require("tests.helpers")
local log = require("review.parse.log")

describe("parse.log", function()
  it("parses one line per revision", function()
    local line = table.concat({ "kptxwzrq", "kptx", "kp", "abc123", "p1,p2", "0", "1", "add service" }, "\0")
    local revisions = log.parse(line .. "\n")
    assert.are.same({
      {
        change_id = "kptxwzrq",
        short_id = "kptx",
        id_prefix = "kp",
        commit_id = "abc123",
        parents = { "p1", "p2" },
        empty = false,
        working_copy = true,
        description = "add service",
      },
    }, revisions)
  end)

  it("parses a revision without parents and description", function()
    local line = table.concat({ "zzzz", "zzzz", "z", "000", "", "1", "0", "" }, "\0")
    local revisions = assert(log.parse(line))
    assert.are.same({}, revisions[1].parents)
    assert.are.same("", revisions[1].description)
  end)

  it("returns the bad line when fields are missing", function()
    local revisions, bad = log.parse("only\0two\n")
    assert.is_nil(revisions)
    assert.are.same("only\0two", bad)
  end)

  it("matches real jj output", function()
    local repo = helpers.temp_repo()
    helpers.jj(repo, { "describe", "-m", "first line\nsecond line" })
    local revisions = assert(log.parse(helpers.jj(repo, { "log", "-r", "@", "--no-graph", "-T", log.TEMPLATE })))
    assert.are.same("first line", revisions[1].description)
    assert.is_true(revisions[1].working_copy)
    assert.is_true(revisions[1].empty)
  end)
end)
