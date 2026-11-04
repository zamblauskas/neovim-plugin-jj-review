local assert = require("luassert")
local async = require("review.shell.lib.async")
local semaphore = require("review.shell.lib.semaphore")

--- An async task that waits until `release()` is called.
local function gate()
  local waiting = {}
  return {
    wait = function()
      async.await(function(done)
        table.insert(waiting, done)
      end)
    end,
    release = function()
      local released = waiting
      waiting = {}
      for _, done in ipairs(released) do
        done()
      end
    end,
  }
end

describe("shell.lib.semaphore", function()
  it("runs at most `limit` tasks at once", function()
    local run, g, started, finished = semaphore.new(2), gate(), 0, 0
    for _ = 1, 3 do
      run(function()
        started = started + 1
        g.wait()
        finished = finished + 1
      end)
    end
    assert.are.same(2, started)
    g.release()
    assert.are.same({ 3, 2 }, { started, finished })
    g.release()
    assert.are.same(3, finished)
  end)

  it("frees the slot when a task fails", function()
    local run, errors, ran = semaphore.new(1), {}, false
    run(function()
      error("boom")
    end, function(err)
      table.insert(errors, err)
    end)
    run(function()
      ran = true
    end)
    assert.are.same(1, #errors)
    assert.is_true(ran)
  end)
end)
