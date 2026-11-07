local assert = require("luassert")
local config = require("review.config")

describe("config", function()
  it("uses the defaults", function()
    assert.are.same(config.defaults, config.resolve())
  end)

  it("merges user options over the defaults", function()
    local c = config.resolve({ explorer_width = 50, keymaps = { toggle = "<leader>x" }, icons = { mark = "+" } })
    assert.are.same({ 50, "<leader>x", "<leader>rR", "+", "✓" }, {
      c.explorer_width,
      c.keymaps.toggle,
      c.keymaps.toggle_block,
      c.icons.mark,
      c.icons.reviewed,
    })
  end)

  it("accepts false to not map a key", function()
    assert.is_false(config.resolve({ keymaps = { help = false } }).keymaps.help)
  end)

  it("rejects unknown option names", function()
    assert.has_error(function()
      config.resolve({ explorer_widht = 50 })
    end, "review: unknown option 'explorer_widht'")
    assert.has_error(function()
      config.resolve({ keymaps = { toggel = "x" } })
    end, "review: unknown option 'keymaps.toggel'")
    assert.has_error(function()
      config.resolve({ icons = { done = "x" } })
    end, "review: unknown option 'icons.done'")
  end)

  it("rejects invalid values", function()
    for _, opts in ipairs({
      { keymaps = { toggle = true } },
      { explorer_width = 0 },
      { max_parallel_jj = 1.5 },
      { icons = { mark = 1 } },
      { dim_reviewed = "yes" },
    }) do
      assert.has_error(function()
        config.resolve(opts)
      end)
    end
  end)
end)
