-- Key descriptions by section. One source for keymap `desc` and the help view.

local M = {}

---@class review.KeymapDocSection
---@field title string
---@field keys { [1]: string, [2]: string }[]  -- config key name, description

---@type review.KeymapDocSection[]
M.SECTIONS = {
  {
    title = "Explorer",
    keys = {
      { "enter", "Fold revision / open file" },
      { "toggle_file", "Toggle reviewed: file" },
      { "edit", "Make the revision the working copy (jj edit)" },
      { "delete_comment", "Delete orphaned comment" },
      { "help", "Show this help" },
      { "quit", "Close review" },
    },
  },
  {
    title = "Diff buffer",
    keys = {
      { "toggle", "Toggle reviewed: line, or visual range" },
      { "toggle_block", "Toggle reviewed: removed block at the line" },
      { "toggle_file", "Toggle reviewed: file" },
      { "comment", "Comment: line, or visual range" },
      { "comment_block", "Comment: removed block at the line" },
      { "delete_comment", "Delete comment at the line" },
      { "next_unreviewed", "Next unreviewed change" },
      { "prev_unreviewed", "Previous unreviewed change" },
      { "next_file", "Next file in the revision" },
      { "prev_file", "Previous file in the revision" },
    },
  },
  {
    title = "Global",
    keys = {
      { "open", "Open review (:Review)" },
      { "close", "Close review (:Review close)" },
    },
  },
}

--- Description of a key in a section.
---@param title string
---@param name string
---@return string
function M.describe(title, name)
  local section = assert(
    vim.iter(M.SECTIONS):find(function(s)
      return s.title == title
    end),
    "keymap section"
  )
  local key = vim.iter(section.keys):find(function(k)
    return k[1] == name
  end)
  return key and key[2] or name
end

return M
