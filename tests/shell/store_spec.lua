local assert = require("luassert")
local store = require("review.shell.store")

---@param root string
---@param text string
local function write(root, text)
  vim.fn.mkdir(root .. "/.jj/review", "p")
  vim.fn.writefile(vim.split(text, "\n"), store.marks_path(root))
end

---@param root string
---@return review.Marks?
local function marks_of(root)
  local data = store.load(root)
  return data and data.marks
end

describe("shell.store", function()
  local root

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
  end)

  it("has no marks without a file", function()
    assert.are.same({}, marks_of(root))
  end)

  it("writes a patch and reads it back", function()
    assert.is_true(store.save_marks(root, { set = { a = { created = "t" } }, unset = {} }))
    assert.are.same({ a = { created = "t" } }, marks_of(root))
    assert.are.same(1, vim.json.decode(table.concat(vim.fn.readfile(store.marks_path(root)), "\n")).version)
  end)

  it("merges with marks written by someone else", function()
    write(root, '{"version": 1, "marks": {"other": {"created": "x"}, "gone": {"created": "x"}}}')
    store.save_marks(root, { set = { mine = { created = "t" } }, unset = { "gone" } })
    assert.are.same({ other = { created = "x" }, mine = { created = "t" } }, marks_of(root))
  end)

  it("writes an empty marks object", function()
    write(root, '{"version": 1, "marks": {"a": {"created": "x"}}}')
    store.save_marks(root, { set = {}, unset = { "a" } })
    assert.truthy(table.concat(vim.fn.readfile(store.marks_path(root)), "\n"):find('"marks": {}', 1, true))
  end)

  it("does not write a file with an unknown version", function()
    write(root, '{"version": 2, "marks": {}}')
    local ok, err = store.save_marks(root, { set = { a = { created = "t" } }, unset = {} })
    assert.is_false(ok)
    assert.truthy(assert(err):find("unknown version"))
    assert.are.same('{"version": 2, "marks": {}}', vim.fn.readfile(store.marks_path(root))[1])
  end)

  it("fails to load invalid JSON", function()
    write(root, "{not json")
    local data, err = store.load(root)
    assert.is_nil(data)
    assert.truthy(assert(err):find("not valid JSON"))
  end)

  it("clears all marks", function()
    store.save_marks(root, { set = { a = { created = "t" } }, unset = {} })
    assert.is_true(store.clear(root))
    assert.are.same({}, marks_of(root))
  end)

  it("does not clear a file with an unknown version", function()
    write(root, '{"version": 2, "marks": {}}')
    assert.is_false(store.clear(root))
  end)

  it("writes a comment patch and reads it back", function()
    local c = { id = "c1", text = "hi" }
    ---@diagnostic disable-next-line: missing-fields
    assert.is_true(store.save_comments(root, { add = { c }, remove = {} }))
    assert.are.same({ c }, assert(store.load(root)).comments)
    store.save_comments(root, { add = {}, remove = { "c1" } })
    assert.are.same({}, assert(store.load(root)).comments)
    assert.truthy(table.concat(vim.fn.readfile(store.comments_path(root)), "\n"):find('"comments": []', 1, true))
  end)

  it("clears marks and comments", function()
    store.save_marks(root, { set = { a = { created = "t" } }, unset = {} })
    ---@diagnostic disable-next-line: missing-fields
    store.save_comments(root, { add = { { id = "c1" } }, remove = {} })
    assert.is_true(store.clear(root))
    assert.are.same({ marks = {}, comments = {} }, store.load(root))
  end)
end)
