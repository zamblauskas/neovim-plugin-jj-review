-- Line keys: identity of a reviewable line. See spec/data-model.md "Line key".
--   key = side | path | hash(normalize(context)) | occurrence
-- Context: the line, 2 lines above and 2 below, from the same side's text. Lines out of the hunk are at the
-- file edge (the diff has 2 context lines), so they are empty.
-- A line whose normalized text is empty is not reviewable: it gets no key.

local tbl = require("review.lib.tbl")

local M = {}

local CONTEXT = 2
local ZERO_BLOB = "^0+$"

---@param text string
---@return string
local function normalize(text)
  return (text:gsub("%s", ""))
end

--- Lines of one side of the hunk, with their index in the hunk.
---@param hunk review.Hunk
---@param side "+"|"-"
---@return { text: string, index: integer, changed: boolean }[]
local function side_lines(hunk, side)
  local out = {}
  for i, line in ipairs(hunk.lines) do
    if line.kind == " " or line.kind == side then
      table.insert(out, { text = normalize(line.text), index = i, changed = line.kind == side })
    end
  end
  return out
end

---@param lines { text: string }[]
---@param pos integer
---@return string
local function context_hash(lines, pos)
  local parts = {}
  for p = pos - CONTEXT, pos + CONTEXT do
    table.insert(parts, lines[p] and lines[p].text or "")
  end
  return vim.fn.sha256(table.concat(parts, "\n"))
end

--- Hash of each reviewable line of one side, top to bottom.
---@param hunk review.Hunk
---@param side "+"|"-"
---@return { index: integer, hash: string }[]
local function reviewable_hashes(hunk, side)
  local lines, out = side_lines(hunk, side), {}
  for pos, line in ipairs(lines) do
    if line.changed and line.text ~= "" then
      table.insert(out, { index = line.index, hash = context_hash(lines, pos) })
    end
  end
  return out
end

---@class review.KeyContext
---@field paths table<string, string>  -- by side
---@field seen table<string, integer>  -- occurrences so far, by "side|path|hash"

--- Keys of the reviewable lines of one hunk, by line index. Counts occurrences in `ctx.seen`.
---@param hunk review.Hunk
---@param ctx review.KeyContext
---@return table<integer, string>
local function hunk_keys(hunk, ctx)
  local keys = {}
  for _, side in ipairs({ "+", "-" }) do
    for _, item in ipairs(reviewable_hashes(hunk, side)) do
      local id = side .. "|" .. ctx.paths[side] .. "|" .. item.hash
      ctx.seen[id] = (ctx.seen[id] or 0) + 1
      keys[item.index] = id .. "|" .. ctx.seen[id]
    end
  end
  return keys
end

---@param hunk review.Hunk
---@param keys table<integer, string>
---@return review.Hunk
local function with_keys(hunk, keys)
  local lines = {}
  for i, line in ipairs(hunk.lines) do
    lines[i] = keys[i] and tbl.with(line, { key = keys[i] }) or line
  end
  return tbl.with(hunk, { lines = lines })
end

--- Key of a binary file: path and blob hash of the new content (old content for a deleted file).
---@param file review.FileDiff
---@return string
local function binary_key(file)
  local new_blob = file.new_blob or ""
  local blob = new_blob:match(ZERO_BLOB) and file.old_blob or new_blob
  return "b|" .. file.path .. "|" .. (blob or "")
end

--- Copy of the file diff with a `key` on each reviewable line, or on the file if it is binary.
---@param file review.FileDiff
---@return review.FileDiff
function M.annotate(file)
  if file.binary then
    return tbl.with(file, { key = binary_key(file) })
  end
  local ctx = { paths = { ["+"] = file.path, ["-"] = file.old_path or file.path }, seen = {} }
  return tbl.with(file, {
    hunks = vim.tbl_map(function(hunk)
      return with_keys(hunk, hunk_keys(hunk, ctx))
    end, file.hunks),
  })
end

--- All reviewable keys of the file, top to bottom.
---@param file review.FileDiff
---@return string[]
function M.of_file(file)
  if file.key then
    return { file.key }
  end
  local out = {}
  for _, hunk in ipairs(file.hunks) do
    for _, line in ipairs(hunk.lines) do
      if line.key then
        table.insert(out, line.key)
      end
    end
  end
  return out
end

return M
