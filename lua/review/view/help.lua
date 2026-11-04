-- Help view: configured keymaps → lines and highlights. Pure. Unmapped keys are left out.

local keymap_docs = require("review.core.keymap_docs")
local rows = require("review.view.rows")
local text_lib = require("review.lib.text")

local M = {}

---@param section review.KeymapDocSection
---@param keymaps review.KeymapConfig
---@return { [1]: string, [2]: string }[]  -- key, description
local function mapped(section, keymaps)
  return vim
    .iter(section.keys)
    :filter(function(k)
      return keymaps[k[1]] ~= false and keymaps[k[1]] ~= nil
    end)
    :map(function(k)
      return { keymaps[k[1]], k[2] }
    end)
    :totable()
end

---@param section review.KeymapDocSection
---@param keymaps review.KeymapConfig
---@param key_width integer
---@return review.Row[]
local function section_rows(section, keymaps, key_width)
  local out = { { { section.title, "ReviewHeader" } } }
  for _, k in ipairs(mapped(section, keymaps)) do
    local pad = string.rep(" ", key_width - text_lib.width(k[1]))
    table.insert(out, { { "  " }, { k[1], "ReviewChangeId" }, { pad .. "  " .. k[2] } })
  end
  table.insert(out, {})
  return out
end

---@param keymaps review.KeymapConfig
---@return integer
local function widest_key(keymaps)
  local width = 0
  for _, key in pairs(keymaps) do
    width = key and math.max(width, text_lib.width(key)) or width
  end
  return width
end

---@param keymaps review.KeymapConfig
---@return review.View
function M.render(keymaps)
  local out, key_width = {}, widest_key(keymaps)
  for _, section in ipairs(keymap_docs.SECTIONS) do
    vim.list_extend(out, section_rows(section, keymaps, key_width))
  end
  table.remove(out)
  return rows.render(out)
end

return M
