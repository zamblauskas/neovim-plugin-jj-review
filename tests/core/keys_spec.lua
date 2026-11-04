local assert = require("luassert")
local keys = require("review.core.keys")
local parse = require("review.parse.diff")

---@param body string
---@param header? string
---@return review.FileDiff
local function file(body, header)
  return parse.parse("diff --git a/src/load.rs b/src/load.rs\n" .. (header or "") .. body)[1]
end

---@param lines string[]
---@return string
local function hash(lines)
  return vim.fn.sha256(table.concat(lines, "\n"))
end

-- Example from spec/data-model.md.
local LOAD = table.concat({
  "@@ -10,6 +10,5 @@",
  " fn load() {",
  "-  let a = read();",
  "-  let b = parse(a);",
  "-  log(b);",
  "-  return b;",
  "+  let a = read_all();",
  "+  validate(a);",
  "+  return a;",
  " }",
}, "\n") .. "\n"

---@param f review.FileDiff
---@param text string
---@return string?
local function key_of(f, text)
  for _, line in ipairs(f.hunks[1].lines) do
    if line.text == text then
      return line.key
    end
  end
end

describe("core.keys", function()
  local annotated = keys.annotate(file(LOAD))

  it("keys a removed line by its old-side context", function()
    -- context order: 2 above, the line, 2 below
    local expected = hash({ "fnload(){", "leta=read();", "letb=parse(a);", "log(b);", "returnb;" })
    assert.are.same("-|src/load.rs|" .. expected .. "|1", key_of(annotated, "  let b = parse(a);"))
  end)

  it("keys an added line by its new-side context", function()
    local expected = hash({ "fnload(){", "leta=read_all();", "validate(a);", "returna;", "}" })
    assert.are.same("+|src/load.rs|" .. expected .. "|1", key_of(annotated, "  validate(a);"))
  end)

  it("uses empty lines out of the hunk", function()
    local expected = hash({ "", "", "fnload(){", "leta=read();", "letb=parse(a);" })
    assert.are.same(nil, key_of(annotated, "fn load() {"))
    local f = keys.annotate(file("@@ -1,3 +0,0 @@\n-fn load() {\n-  let a = read();\n-  let b = parse(a);\n"))
    assert.are.same("-|src/load.rs|" .. expected .. "|1", f.hunks[1].lines[1].key)
  end)

  it("ignores whitespace in the context", function()
    local spaced = keys.annotate(file((LOAD:gsub("validate%(a%);", "validate( a );"))))
    assert.are.same(key_of(annotated, "  validate(a);"), key_of(spaced, "  validate( a );"))
  end)

  it("gives the same hash an occurrence index", function()
    local f = keys.annotate(file("@@ -1,0 +1,1 @@\n+x\n@@ -20,0 +20,1 @@\n+x\n"))
    local k1, k2 = assert(f.hunks[1].lines[1].key), f.hunks[2].lines[1].key
    assert.are.same((k1:gsub("|1$", "|2")), k2)
  end)

  it("does not key blank or context lines", function()
    local f = keys.annotate(file("@@ -1,1 +1,3 @@\n a\n+\n+   \n"))
    assert.are.same({}, keys.of_file(f))
  end)

  it("uses the old path for removed lines of a renamed file", function()
    local f = keys.annotate(parse.parse(table.concat({
      "diff --git a/old.rs b/new.rs",
      "rename from old.rs",
      "rename to new.rs",
      "@@ -1,1 +1,1 @@",
      "-a",
      "+b",
    }, "\n"))[1])
    assert.truthy(f.hunks[1].lines[1].key:find("^%-|old%.rs|"))
    assert.truthy(f.hunks[1].lines[2].key:find("^%+|new%.rs|"))
  end)

  it("keys a binary file by its new blob, or its old blob when deleted", function()
    local changed = parse.parse("diff --git a/b b/b\nindex 1111..2222 100644\nBinary files a/b and b/b differ\n")[1]
    local deleted = parse.parse(
      "diff --git a/b b/b\ndeleted file mode 100644\nindex 1111..0000\nBinary files a/b and /dev/null differ\n"
    )[1]
    assert.are.same({ "b|b|2222" }, keys.of_file(keys.annotate(changed)))
    assert.are.same({ "b|b|1111" }, keys.of_file(keys.annotate(deleted)))
  end)

  it("lists all keys of a file top to bottom", function()
    assert.are.same(7, #keys.of_file(annotated))
  end)

  it("does not change the input", function()
    local f = file(LOAD)
    keys.annotate(f)
    assert.is_nil(f.hunks[1].lines[2].key)
  end)
end)
