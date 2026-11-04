-- Build the review stack from the revset result:
-- remove empty revisions, check the rest is linear, order newest first.

local list = require("review.lib.list")

local M = {}

---@alias review.Stack review.StackLoading|review.StackOk|review.StackError

---@class review.StackLoading
---@field type "loading"

---@class review.StackOk
---@field type "ok"
---@field revisions review.Revision[]  -- newest first

---@class review.StackError
---@field type "error"
---@field reason "not_linear"|"merge"|"jj_failed"
---@field revisions? string[]  -- short ids of the problem revisions
---@field detail? string       -- jj stderr

--- Parents inside the kept set. A hidden (empty) parent is replaced by its own effective parents.
---@param rev review.Revision
---@param all table<string, review.Revision>
---@return string[]
local function effective_parents(rev, all)
  local result = {}
  for _, parent_id in ipairs(rev.parents) do
    local parent = all[parent_id]
    if parent and parent.empty then
      vim.list_extend(result, effective_parents(parent, all))
    elseif parent then
      table.insert(result, parent_id)
    end
  end
  return vim.list.unique(result)
end

---@param kept review.Revision[]
---@param all table<string, review.Revision>
---@return table<string, string[]>
local function parent_map(kept, all)
  local map = {}
  for _, rev in ipairs(kept) do
    map[rev.commit_id] = effective_parents(rev, all)
  end
  return map
end

---@param kept review.Revision[]
---@param parents table<string, string[]>
---@return review.Revision[]
local function heads(kept, parents)
  local has_child = {}
  for _, ids in pairs(parents) do
    for _, id in ipairs(ids) do
      has_child[id] = true
    end
  end
  return vim.tbl_filter(function(rev)
    return not has_child[rev.commit_id]
  end, kept)
end

---@param head review.Revision
---@param parents table<string, string[]>
---@param kept_index table<string, review.Revision>
---@return review.Revision[]
local function walk_down(head, parents, kept_index)
  local ordered, current = {}, head
  while current do
    table.insert(ordered, current)
    current = kept_index[(parents[current.commit_id] or {})[1]]
  end
  return ordered
end

---@param kept review.Revision[]
---@param parents table<string, string[]>
---@return review.Revision[]
local function merges(kept, parents)
  return vim.tbl_filter(function(rev)
    return #parents[rev.commit_id] > 1
  end, kept)
end

---@param kept review.Revision[]
---@param parents table<string, string[]>
---@return review.StackOk|review.StackError
local function linear_stack(kept, parents)
  local merge_revs = merges(kept, parents)
  if #merge_revs > 0 then
    return { type = "error", reason = "merge", revisions = list.pluck(merge_revs, "short_id") }
  end
  local head_revs = heads(kept, parents)
  if #head_revs > 1 then
    return { type = "error", reason = "not_linear", revisions = list.pluck(head_revs, "short_id") }
  end
  return { type = "ok", revisions = walk_down(head_revs[1], parents, list.index_by(kept, "commit_id")) }
end

--- Build the stack from the revset result (any order).
---@param revisions review.Revision[]
---@return review.StackOk|review.StackError
function M.build(revisions)
  local kept = vim.tbl_filter(function(rev)
    return not rev.empty
  end, revisions)
  if #kept == 0 then
    return { type = "ok", revisions = {} }
  end
  return linear_stack(kept, parent_map(kept, list.index_by(revisions, "commit_id")))
end

---@param stderr string
---@return review.StackError
function M.jj_failed(stderr)
  return { type = "error", reason = "jj_failed", detail = vim.trim(stderr) }
end

return M
