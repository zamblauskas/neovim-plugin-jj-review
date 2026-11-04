local assert = require("luassert")
local schedule = require("review.shell.lib.schedule")

describe("shell.lib.schedule.once_per_tick", function()
  it("calls fn once per tick with the first arguments", function()
    local calls = {}
    local wrapped = schedule.once_per_tick(function(value)
      table.insert(calls, value)
    end)
    wrapped("first")
    wrapped("second")
    vim.wait(100, function()
      return #calls > 0
    end, 5)
    assert.are.same({ "first" }, calls)
  end)

  it("calls fn again in a later tick", function()
    local count = 0
    local wrapped = schedule.once_per_tick(function()
      count = count + 1
    end)
    wrapped()
    vim.wait(100, function()
      return count == 1
    end, 5)
    wrapped()
    vim.wait(100, function()
      return count == 2
    end, 5)
    assert.are.same(2, count)
  end)
end)
