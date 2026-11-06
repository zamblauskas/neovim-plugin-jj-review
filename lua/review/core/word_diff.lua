-- Intra-line diff of a removed line and the added line that replaced it. Pure.
-- Tokens: word runs, whitespace runs, single other characters. Myers diff over the token lists.

local M = {}

--- Share of changed tokens above which a line counts as rewritten: it gets no intra-line ranges.
local REWRITTEN = 0.6

---@class review.Token
---@field text string
---@field col integer  -- 0-based byte offset

---@class review.Range
---@field col integer      -- 0-based byte start
---@field end_col integer  -- exclusive

---@class review.LineRanges
---@field old review.Range[]  -- changed ranges of the removed line
---@field new review.Range[]  -- changed ranges of the added line

--- Token at byte position `pos` (1-based): a word run, a whitespace run, or one UTF-8 character.
---@param text string
---@param pos integer
---@return string
local function token_at(text, pos)
  return text:match("^[%w_]+", pos) or text:match("^%s+", pos) or text:match("^[%z\1-\127\194-\244][\128-\191]*", pos)
end

---@param text string
---@return review.Token[]
function M.tokenize(text)
  local out, pos = {}, 1
  while pos <= #text do
    local token = token_at(text, pos)
    table.insert(out, { text = token, col = pos - 1 })
    pos = pos + #token
  end
  return out
end

--- One token per line, for vim.diff.
---@param tokens review.Token[]
---@return string
local function joined(tokens)
  return table.concat(
    vim.tbl_map(function(token)
      return token.text
    end, tokens),
    "\n"
  )
end

--- Byte range of `count` tokens from `start` (1-based).
---@param tokens review.Token[]
---@param start integer
---@param count integer
---@return review.Range
local function range(tokens, start, count)
  local first, last = tokens[start], tokens[start + count - 1]
  return { col = first.col, end_col = last.col + #last.text }
end

--- Ranges of the diff hunks, and the number of changed tokens.
---@param hunks integer[][]  -- { start_a, count_a, start_b, count_b }
---@param a review.Token[]
---@param b review.Token[]
---@return review.LineRanges, integer
local function collect(hunks, a, b)
  local out, changed = { old = {}, new = {} }, 0
  for _, hunk in ipairs(hunks) do
    local start_a, count_a, start_b, count_b = unpack(hunk)
    changed = changed + math.max(count_a, count_b)
    if count_a > 0 then
      table.insert(out.old, range(a, start_a, count_a))
    end
    if count_b > 0 then
      table.insert(out.new, range(b, start_b, count_b))
    end
  end
  return out, changed
end

--- Changed ranges of both lines. Nil when the line is mostly rewritten.
---@param old string
---@param new string
---@return review.LineRanges?
function M.ranges(old, new)
  local a, b = M.tokenize(old), M.tokenize(new)
  local hunks = vim.text.diff(joined(a), joined(b), { result_type = "indices" }) --[[@as integer[][] ]]
  local out, changed = collect(hunks, a, b)
  if changed > REWRITTEN * math.max(#a, #b) then
    return nil
  end
  return out
end

return M
