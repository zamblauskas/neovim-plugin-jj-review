local assert = require("luassert")
local app_mod = require("review.app")
local config = require("review.config")
local effects = require("review.shell.effects")
local msg = require("review.core.msg")
local state_mod = require("review.core.state")
local update = require("review.core.update").update

---@param stdout string
---@return review.JjResult
local function ok(stdout)
  return { ok = true, stdout = stdout, stderr = "", args = {} }
end

local function log_line(id, parents)
  return table.concat({ id, id, id, id, parents, "0", "0", "desc " .. id }, "\0") .. "\n"
end

--- Fake ports: JJ answers from fixed data, the explorer records renders.
local function fake_ports()
  local renders = {}
  return {
    renders = renders,
    jj = {
      root = function()
        return ok("/repo\n")
      end,
      op_id = function()
        return ok("op1\n")
      end,
      log = function()
        return ok(log_line("b", "a") .. log_line("a", ""))
      end,
    },
    explorer = {
      open = function() end,
      close = function() end,
      render = function(state)
        table.insert(renders, state)
      end,
    },
  }
end

describe("shell.effects", function()
  it("opens a review and loads the stack through the ports", function()
    local ports = fake_ports()
    local app = app_mod.create(state_mod.initial(config.resolve()), update, effects.new(ports))
    app.dispatch(msg.opened("/repo"))
    vim.wait(1000, function()
      return #ports.renders > 0 and app.state().stack.type == "ok"
    end)
    assert.are.same("ok", app.state().stack.type)
    assert.are.same({ "b", "a" }, {
      app.state().stack.revisions[1].short_id,
      app.state().stack.revisions[2].short_id,
    })
  end)

  it("batches renders in one tick", function()
    local ports = fake_ports()
    local interpret = effects.new(ports)
    local app = {
      state = function()
        return {}
      end,
      dispatch = function() end,
    }
    interpret({ type = "RenderExplorer" }, app)
    interpret({ type = "RenderExplorer" }, app)
    vim.wait(100, function()
      return false
    end)
    assert.are.same(1, #ports.renders)
  end)

  it("turns bad log output into a jj failure", function()
    local result = effects.stack_result(1, ok("garbage\n"))
    assert.are.same("JjFailed", result.type)
  end)
end)
