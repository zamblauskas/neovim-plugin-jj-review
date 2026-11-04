local assert = require("luassert")
local store = require("review.shell.store")

---@param root string
---@param text string
local function write(root, text)
  vim.fn.mkdir(root .. "/.jj/review", "p")
  vim.fn.writefile(vim.split(text, "\n"), store.marks_path(root))
end

describe("shell.store", function()
  local root

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
  end)

  it("has no marks without a file", function()
    assert.are.same({}, store.load_marks(root))
  end)

  it("writes a patch and reads it back", function()
    assert.is_true(store.save_marks(root, { set = { a = { created = "t" } }, unset = {} }))
    assert.are.same({ a = { created = "t" } }, store.load_marks(root))
    assert.are.same(1, vim.json.decode(table.concat(vim.fn.readfile(store.marks_path(root)), "\n")).version)
  end)

  it("merges with marks written by someone else", function()
    write(root, '{"version": 1, "marks": {"other": {"created": "x"}, "gone": {"created": "x"}}}')
    store.save_marks(root, { set = { mine = { created = "t" } }, unset = { "gone" } })
    assert.are.same({ other = { created = "x" }, mine = { created = "t" } }, store.load_marks(root))
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
    local marks, err = store.load_marks(root)
    assert.is_nil(marks)
    assert.truthy(assert(err):find("not valid JSON"))
  end)
end)
