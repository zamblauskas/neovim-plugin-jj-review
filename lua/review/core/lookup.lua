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

return M
