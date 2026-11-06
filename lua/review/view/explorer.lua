-- Explorer view: state → lines and highlights. Pure.
-- Rows are lists of chunks (view/rows.lua).

local comments = require("review.core.comments")
local counts = require("review.core.counts")
local file_tree = require("review.core.file_tree")
local folds = require("review.core.folds")
local row_lib = require("review.view.rows")
local text_lib = require("review.lib.text")

local M = {}

---@class review.ExplorerEntry
---@field chunks review.Row
---@field icons? review.Row  -- after the left part, never cut (comment icons)
---@field right? review.Row  -- right-aligned (counts)
---@field target? review.ExplorerTarget

local TREE_INDENT = "    "

--- File status → letter and highlight group.
local STATUS = {
  added = { "A", "ReviewStatusAdded" },
  modified = { "M", "ReviewStatusModified" },
  deleted = { "D", "ReviewStatusDeleted" },
  renamed = { "R", "ReviewStatusRenamed" },
  copied = { "C", "ReviewStatusRenamed" },
}

local ERROR_TITLES = {
  not_linear = "Stack is not linear",
  merge = "Stack has a merge revision",
  jj_failed = "jj failed",
}

--- Right part with the count, or nil when there is no count yet.
---@param count review.Count?
---@return review.Row?
local function count_chunks(count)
  if not count then
    return nil
  end
  local group = counts.is_done(count) and "ReviewDone" or "ReviewCount"
  return { { count.reviewed .. "/" .. count.total, group } }
end

--- Comment icon when a comment is shown there, warning icon when one of them is outdated.
---@param placements review.Placement[]
---@param config review.IconConfig
---@return review.Chunk[]
local function comment_icons(placements, config)
  local icons = {}
  if #placements > 0 then
    table.insert(icons, { " " .. config.comment, "ReviewComment" })
  end
  if vim.iter(placements):any(function(p)
    return p.status == "outdated"
  end) then
    table.insert(icons, { " " .. config.warning, "ReviewCommentOutdated" })
  end
  return icons
end

---@class review.ExplorerContext
---@field state review.State
---@field placements review.Placement[]

---@param ctx review.ExplorerContext
---@param change_id string
---@param path? string  -- nil: all files of the revision
---@return review.Placement[]
local function placements_at(ctx, change_id, path)
  return vim.tbl_filter(function(p)
    return p.change_id == change_id and (path == nil or p.path == path)
  end, ctx.placements)
end

---@param count review.Count?
---@param icons review.IconConfig
---@return review.Chunk[]
local function done_icon(count, icons)
  return (count and counts.is_done(count)) and { { icons.reviewed .. " " } } or {}
end

--- The working-copy icon, or blanks of the same width.
---@param rev review.Revision
---@param icons review.IconConfig
---@return review.Chunk
local function working_copy_chunk(rev, icons)
  local icon = rev.working_copy and icons.working_copy or string.rep(" ", text_lib.width(icons.working_copy))
  return { icon .. " ", "ReviewWorkingCopy" }
end

---@param rev review.Revision
---@param open boolean
---@param count review.Count?
---@param icons review.IconConfig
---@return review.Row
local function revision_row(rev, open, count, icons)
  local rest = rev.short_id:sub(#rev.id_prefix + 1)
  local description = rev.description ~= "" and { rev.description } or { "(no description)", "ReviewDim" }
  return vim.list_extend({ { open and "▾ " or "▸ ", "ReviewFold" }, unpack(done_icon(count, icons)) }, {
    working_copy_chunk(rev, icons),
    { rev.id_prefix, "ReviewChangeId" },
    { rest, "ReviewChangeIdRest" },
    { ": " },
    description,
  })
end

---@param state review.State
---@return review.Count?
local function stack_count(state)
  return state.stack.type == "ok" and counts.stack(state.stack.revisions, state.diffs, state.marks) or nil
end

---@param state review.State
---@return review.ExplorerEntry[]
local function header_entries(state)
  local size = state.stack.type == "ok" and (" (" .. #state.stack.revisions .. ")") or ""
  return {
    { chunks = { { "Stack" .. size, "ReviewHeader" } }, right = count_chunks(stack_count(state)) },
    { chunks = { { "revset: " .. state.revset, "ReviewDim" } } },
    { chunks = {} },
  }
end

---@param stack review.StackError
---@return review.Row[]
local function error_rows(stack)
  local rows = { { { "✖ " .. ERROR_TITLES[stack.reason], "ReviewError" } } }
  if stack.revisions then
    table.insert(rows, { { "  revisions: " .. table.concat(stack.revisions, ", ") } })
  end
  for _, line in ipairs(vim.split(stack.detail or "", "\n", { trimempty = true })) do
    table.insert(rows, { { "  " .. line, "ReviewDim" } })
  end
  return rows
end

--- Entries without a target.
---@param rows review.Row[]
---@return review.ExplorerEntry[]
local function plain(rows)
  return vim.tbl_map(function(row)
    return { chunks = row }
  end, rows)
end

---@param file review.FileDiff
---@return review.Chunk[]
local function file_suffix(file)
  local suffix = {}
  if file.old_path then
    table.insert(suffix, { " ← " .. file.old_path, "ReviewDim" })
  end
  if file.binary then
    table.insert(suffix, { " (binary)", "ReviewDim" })
  end
  return suffix
end

---@param entry review.TreeEntry
---@param change_id string
---@param ctx review.ExplorerContext
---@return review.ExplorerEntry
local function tree_entry(entry, change_id, ctx)
  local indent = TREE_INDENT .. string.rep("  ", entry.depth)
  if entry.type == "dir" then
    return { chunks = { { indent }, { entry.name, "ReviewDirectory" } } }
  end
  local file = assert(entry.file, "file entry")
  local status, count = STATUS[file.status], counts.file(file, ctx.state.marks)
  local chunks = { { indent }, unpack(done_icon(count, ctx.state.config.icons)) }
  vim.list_extend(chunks, { { status[1] .. " ", status[2] }, { entry.name } })
  return {
    chunks = vim.list_extend(chunks, file_suffix(file)),
    icons = comment_icons(placements_at(ctx, change_id, file.path), ctx.state.config.icons),
    right = count_chunks(count),
    target = { type = "file", change_id = change_id, path = file.path },
  }
end

--- Rows under an open revision: its file tree, or "Loading…" while the diff loads.
---@param ctx review.ExplorerContext
---@param rev review.Revision
---@return review.ExplorerEntry[]
local function file_entries(ctx, rev)
  local files = ctx.state.diffs[rev.commit_id]
  if not files then
    return plain({ { { TREE_INDENT .. "Loading…", "ReviewDim" } } })
  end
  return vim.tbl_map(function(entry)
    return tree_entry(entry, rev.change_id, ctx)
  end, file_tree.build(files))
end

---@param ctx review.ExplorerContext
---@param revisions review.Revision[]
---@return review.ExplorerEntry[]
local function revision_entries(ctx, revisions)
  local entries, state = {}, ctx.state
  for _, rev in ipairs(revisions) do
    local open = folds.is_open(state.folds, state.fold_default, revisions, rev.change_id)
    local files = state.diffs[rev.commit_id]
    local count = files and counts.files(files, state.marks)
    table.insert(entries, {
      chunks = revision_row(rev, open, count, state.config.icons),
      icons = comment_icons(placements_at(ctx, rev.change_id), state.config.icons),
      right = count_chunks(count),
      target = { type = "revision", change_id = rev.change_id },
    })
    if open then
      vim.list_extend(entries, file_entries(ctx, rev))
    end
  end
  return entries
end

---@param placement review.Placement
---@param icons review.IconConfig
---@return review.ExplorerEntry
local function orphan_entry(placement, icons)
  local c = placement.comment
  local first_line = vim.split(c.text, "\n", { plain = true })[1]
  local where = c.path .. ":" .. c.anchor.start_line
  return {
    chunks = {
      { "  " .. icons.warning .. " ", "ReviewCommentOutdated" },
      { where .. " " },
      { '"' .. first_line .. '"', "ReviewDim" },
    },
    target = { type = "comment", id = c.id },
  }
end

--- "Orphaned comments" section. Empty when there are none.
---@param placements review.Placement[]
---@param icons review.IconConfig
---@return review.ExplorerEntry[]
local function orphan_entries(placements, icons)
  local orphans = vim.tbl_filter(function(p)
    return p.status == "orphaned"
  end, placements)
  if #orphans == 0 then
    return {}
  end
  local header = { { chunks = {} }, { chunks = { { "Orphaned comments (" .. #orphans .. ")", "ReviewHeader" } } } }
  return vim.list_extend(
    header,
    vim.tbl_map(function(p)
      return orphan_entry(p, icons)
    end, orphans)
  )
end

---@param ctx review.ExplorerContext
---@return review.ExplorerEntry[]
local function body_entries(ctx)
  local stack = ctx.state.stack
  if stack.type == "loading" then
    return plain({ { { "Loading…", "ReviewDim" } } })
  elseif stack.type == "error" then
    return plain(error_rows(stack))
  elseif #stack.revisions == 0 then
    return plain({ { { "Nothing to review", "ReviewDim" } } })
  end
  return vim.list_extend(revision_entries(ctx, stack.revisions), orphan_entries(ctx.placements, ctx.state.config.icons))
end

---@param chunks review.Chunk[]
---@return string
local function chunks_text(chunks)
  return table.concat(vim.tbl_map(function(chunk)
    return chunk[1]
  end, chunks))
end

--- Chunks cut to at most `width` columns.
---@param chunks review.Chunk[]
---@param width integer
---@return review.Chunk[]
local function truncate_chunks(chunks, width)
  local out, used = {}, 0
  for _, chunk in ipairs(chunks) do
    local chunk_width = text_lib.width(chunk[1])
    if used + chunk_width > width then
      table.insert(out, { text_lib.truncate(chunk[1], width - used), chunk[2] })
      return out
    end
    table.insert(out, chunk)
    used = used + chunk_width
  end
  return out
end

---@param chunks review.Chunk[]
---@return integer
local function chunks_width(chunks)
  return text_lib.width(chunks_text(chunks))
end

--- Left chunks cut to leave room for the icons and the right part, then the icons.
---@param entry review.ExplorerEntry
---@param width integer
---@return review.Row
local function fit_left(entry, width)
  local icons, right = entry.icons or {}, entry.right or {}
  local room = width - chunks_width(icons) - chunks_width(right) - (#right > 0 and 1 or 0)
  return vim.list_extend(truncate_chunks(entry.chunks, room), icons)
end

--- Row chunks with the right part aligned to `width`. The left part is cut if it is too long; icons stay.
---@param entry review.ExplorerEntry
---@param width integer
---@return review.Row
local function fit(entry, width)
  if not entry.right and not entry.icons then
    return entry.chunks
  end
  local left = fit_left(entry, width)
  if not entry.right then
    return left
  end
  local pad = math.max(width - chunks_width(left) - chunks_width(entry.right), 1)
  return vim.list_extend(vim.list_extend(left, { { string.rep(" ", pad) } }), entry.right)
end

---@param state review.State
---@param width integer  -- text columns of the explorer window
---@return review.View
function M.render(state, width)
  local ctx = { state = state, placements = comments.place(state) }
  local entries = vim.list_extend(header_entries(state), body_entries(ctx))
  local view = { lines = {}, highlights = {}, targets = {} }
  for i, entry in ipairs(entries) do
    local text, highlights = row_lib.flatten(fit(entry, width), i - 1)
    table.insert(view.lines, text)
    vim.list_extend(view.highlights, highlights)
    view.targets[i] = entry.target
  end
  return view
end

return M
