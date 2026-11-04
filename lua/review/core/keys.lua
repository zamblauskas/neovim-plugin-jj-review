-- Line keys: identity of a reviewable line. See spec/data-model.md "Line key".
--   key = side | path | hash(normalize(context)) | occurrence
-- Context: the line, 2 lines above and 2 below, from the same side's text. Lines out of the hunk are at the
-- file edge (the diff has 2 context lines), so they are empty.
-- A line whose normalized text is empty is not reviewable: it gets no key.
-- Comment anchors: every non-blank line in a hunk. Changed lines use their key. Unchanged lines (new side)
-- get "=|path|hash|occurrence"; it is never a review key.

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

--- Hash of each non-blank line of one side, top to bottom: changed lines, or unchanged lines.
---@param hunk review.Hunk
---@param side "+"|"-"
---@param changed boolean
---@return { index: integer, hash: string }[]
local function line_hashes(hunk, side, changed)
  local lines, out = side_lines(hunk, side), {}
  for pos, line in ipairs(lines) do
    if line.changed == changed and line.text ~= "" then
      table.insert(out, { index = line.index, hash = context_hash(lines, pos) })
    end
  end
  return out
end

--- Key kinds: tag, side of the text, changed lines or not.
--- "=" keys are comment anchors of unchanged lines. They have their own occurrence count.
local KINDS = { { "+", "+", true }, { "-", "-", true }, { "=", "+", false } }

---@class review.KeyContext
---@field paths table<string, string>  -- by side
---@field seen table<string, integer>  -- occurrences so far, by "tag|path|hash"

--- Keys of the non-blank lines of one hunk, by line index. Counts occurrences in `ctx.seen`.
---@param hunk review.Hunk
---@param ctx review.KeyContext
---@return table<integer, string>
local function hunk_keys(hunk, ctx)
  local keys = {}
  for _, kind in ipairs(KINDS) do
    local tag, side, changed = kind[1], kind[2], kind[3]
    for _, item in ipairs(line_hashes(hunk, side, changed)) do
      local id = tag .. "|" .. ctx.paths[side] .. "|" .. item.hash
      ctx.seen[id] = (ctx.seen[id] or 0) + 1
      keys[item.index] = id .. "|" .. ctx.seen[id]
    end
  end
  return keys
end

--- Line with its keys: a changed line gets `key` (review) and `anchor`; an unchanged line only `anchor`.
---@param line review.DiffLine
---@param key string?
---@return review.DiffLine
local function keyed_line(line, key)
  if not key then
    return line
  elseif line.kind == " " then
    return tbl.with(line, { anchor = key })
  end
  return tbl.with(line, { key = key, anchor = key })
end

---@param hunk review.Hunk
---@param keys table<integer, string>
---@return review.Hunk
local function with_keys(hunk, keys)
  local lines = {}
  for i, line in ipairs(hunk.lines) do
    lines[i] = keyed_line(line, keys[i])
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
