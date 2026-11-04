-- Pure color helpers. Colors are integers 0xRRGGBB.

local M = {}

---@param color integer
---@param shift integer
---@return integer
local function channel(color, shift)
  return math.floor(color / 2 ^ shift) % 256
end

--- Mix of `a` and `b`: `alpha` of `a`, the rest of `b`.
---@param a integer
---@param b integer
---@param alpha number  0..1
---@return integer
function M.blend(a, b, alpha)
  local out = 0
  for _, shift in ipairs({ 16, 8, 0 }) do
    local mixed = math.floor(channel(a, shift) * alpha + channel(b, shift) * (1 - alpha) + 0.5)
    out = out + mixed * 2 ^ shift
  end
  return out
end

return M
