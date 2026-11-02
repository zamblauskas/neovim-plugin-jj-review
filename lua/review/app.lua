-- Runtime (Elm Architecture): holds the current state, runs update, hands effects to the interpreter.

local M = {}

---@class review.App
---@field state fun(): review.State
---@field dispatch fun(msg: review.Msg)

---@alias review.Interpreter fun(effect: review.Effect, app: review.App)

---@param initial review.State
---@param update fun(state: review.State, msg: review.Msg): review.State, review.Effect[]
---@param interpret review.Interpreter
---@return review.App
function M.create(initial, update, interpret)
  local state = initial
  local app = {}
  function app.state()
    return state
  end
  function app.dispatch(msg)
    local effects
    state, effects = update(state, msg)
    for _, e in ipairs(effects) do
      interpret(e, app)
    end
  end
  return app
end

return M
