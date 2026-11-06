-- Lookups in the state: revision by change id, file diff by path.
-- Revision lookup is behind one function, so it can later follow a squashed change (F-33).

local M = {}

---@param state review.State
---@param change_id string
---@return review.Revision?
function M.revision(state, change_id)
  if state.stack.type ~= "ok" then
    return nil
  end
  local revisions = state.stack.revisions ---@type review.Revision[]
  for _, rev in ipairs(revisions) do
    if rev.change_id == change_id then
      return rev
    end
  end
  return nil
end

--- The revision whose text is on disk (core/modes.lua), if it is in the stack.
---@param state review.State
---@return review.Revision?
function M.disk_revision(state)
  if state.stack.type ~= "ok" or not state.disk_commit then
    return nil
  end
  return vim.iter(state.stack.revisions):find(function(rev)
    return rev.commit_id == state.disk_commit
  end)
end

---@param state review.State
---@param rev review.Revision
---@param path string
---@return review.FileDiff?
function M.file(state, rev, path)
  for _, file in ipairs(state.diffs[rev.commit_id] or {}) do
    if file.path == path then
      return file
    end
  end
  return nil
end

--- A deleted file has no new text: the buffer has one empty line.
local DELETED_LINES = { "" }
local BINARY_LINES = { "Binary file" }

--- Lines of the buffer with the new text, when known without jj or in the cache (memoization by commit id).
---@param state review.State
---@param rev review.Revision
---@param file review.FileDiff
---@return string[]?
function M.new_lines(state, rev, file)
  if file.status == "deleted" then
    return DELETED_LINES
  elseif file.binary then
    return BINARY_LINES
  end
  return (state.contents[rev.commit_id] or {})[file.path]
end

return M
