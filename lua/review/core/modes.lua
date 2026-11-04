-- Modes (spec/stack.md "Modes"): where the text of an open file comes from.
--   working_copy: the revision's text is on disk (it is @, or @ is empty and it is @-) → the real file buffer;
--   view: a read-only scratch buffer. A deleted or binary file always uses view mode.

local M = {}

---@alias review.Mode "view"|"working_copy"

--- Commit whose text is on disk, from the raw log (before empty revisions are removed). False if none.
---@param revisions review.Revision[]
---@return string|false
function M.disk_commit(revisions)
  local wc = vim.iter(revisions):find(function(rev)
    return rev.working_copy
  end)
  if not wc then
    return false
  elseif wc.empty and #wc.parents == 1 then
    return wc.parents[1]
  end
  return wc.commit_id
end

---@param state review.State
---@param rev review.Revision
---@param file review.FileDiff
---@return review.Mode
function M.mode(state, rev, file)
  local on_disk = state.disk_commit == rev.commit_id
  return (on_disk and file.status ~= "deleted" and not file.binary) and "working_copy" or "view"
end

return M
