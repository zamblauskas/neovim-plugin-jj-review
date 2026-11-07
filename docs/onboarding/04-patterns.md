# 04 Patterns

> Source of truth: [spec/architecture.md](../../spec/architecture.md) "Patterns".
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- Which named patterns are in use?
- Where is each one?
- Why was each one chosen, and what does it cost?
- Which patterns are not used, that a reader may expect? Why?

## Patterns in use

| Pattern | Where | Why | Cost |
|---|---|---|---|
| Functional Core, Imperative Shell | `core/`, `parse/`, `view/` pure; `shell/` has every side effect | Rules are testable with plain data. Neovim and jj are at the edge. | Every outside value (clock, id, cursor line) must be carried into a message. |
| Elm Architecture (Model, Update, View) | `app.lua`, `core/update.lua`, `view/` | One state. One function changes it. Views are functions of state. Easy to reason about a refresh. | Each new behavior needs a message, a handler, often an effect. More files than a direct call. |
| Command (effects as data) | `core/effect.lua` | `update` returns descriptions. A test compares effect lists. No mocks. | The shell must interpret every effect type. |
| Interpreter | `shell/effects.lua` | One place runs effects through ports and turns results into messages. | A missing handler fails silently (see [09](09-limits.md) B2). |
| Ports and Adapters | `shell/jj.lua`, `store.lua`, `clock.lua`, `ids.lua`, … passed as a table to the interpreter | The shell talks to jj, disk, and clock through a port. Tests pass fakes. | Ports are module tables, not instances. One review per process. |
| Observer | `shell/watcher.lua`, `shell/focus.lua` | Outside events (jj operation, focus, save, window change) become messages. Core never polls. | An observer that fires inside a dispatch makes `dispatch` re-entrant ([09](09-limits.md) A2). |
| Dispatch table (Strategy by tag) | `update` picks a handler by `msg.type`; the interpreter by `effect.type`; targets by target type; buffers by mode; navigation by unit | No `if` chain. Adding a type is adding a key. | A typo in a tag is a silent no-op. |
| Memoization by immutable id | `state.diffs` and `state.contents` keyed by commit id | A commit id never changes content. A refresh fetches only new commits. | Entries for commits not in the stack must be dropped by hand on each stack load. |
| Tagged union (sum type) | Messages, effects, stack status (`loading` / `ok` / `error`), explorer row targets, selections | The type checker knows which fields exist per tag. Handlers are exhaustive by table key. | LuaCATS unions are advisory. Nothing forces a handler to exist. |
| Coroutine async/await | `shell/lib/async.lua` | A jj call reads as a list of steps. No callback pyramid. | Every port function must be called inside `async.run`. A sync failure path resumes at once ([09](09-limits.md) A2). |
| Semaphore | `shell/lib/semaphore.lua` | At most `max_parallel_jj` diff calls at once. A 40-revision stack does not fork 40 processes. | None worth noting. |
| Read-merge-write + atomic rename | `shell/store.lua` | The agent may read the file while we write. We write temp, then rename. We read again before each write and apply a patch, so an unmark is not undone by a stale copy. | No lock between two Neovim instances ([09](09-limits.md) B5). |
| Reconciler | `core/review_buffers.lua` | After each stack, diff, or content change, every open buffer gets a plan: release, wait, load, prepare, ready. The plan is data. | The call to `sync` is by hand in 5 handlers ([09](09-limits.md) A1). |
| Facade | `shell/layout.lua` | One module hides tab, explorer, focus start and stop, target window. | None worth noting. |

## One paragraph per pattern a reader may not know

**Elm Architecture.** A program is one state value, one `update(state, msg)` function that returns a new state
and a list of effects, and a `view(state)` function. Nothing else holds state. Here, `app.lua` is the runtime
loop, `core/handlers/` is `update` split by message group, and `view/` is `view`. Render is an effect, so
`update` decides when the screen changes.

**Reconciler.** A function that compares what is (the buffers that exist, with the commit their text came from)
with what should be (the stack right now) and emits the minimal commands to close the gap. React's DOM
reconciler is the famous one. Here it decides per open file: keep, load text, prepare a new buffer, or release.

**Read-merge-write.** Instead of "write my copy", do "read the file again, apply my change to what is there,
write". The change is a patch `{set, unset}`, not a full copy. Two writers that each apply a patch keep both
changes. Atomic rename makes a reader see either the old file or the new, never half.

**Ports and Adapters (Hexagonal).** The core defines what it needs (a jj port: "give me the log for this
revset"). An adapter implements it for the real world (`vim.system`). Tests implement it with a table of canned
answers. Here the adapters are the modules in `shell/`, passed to the interpreter as one `ports` table.

## Patterns not used on purpose

| Pattern | Why not |
|---|---|
| Object-oriented classes with methods and `self` | Immutable data and pure functions test better. The only "objects" are port modules. |
| Event emitter / pub-sub inside the plugin | One message loop is enough. A second channel would hide ordering. |
| Central `types.lua` | Types live next to the code that makes them. Less churn, no god file. |
| Dependency on a UI library (nui.nvim, plenary at runtime) | No runtime dependencies. The plugin draws with extmarks and splits only. |
| Diff engine in Lua | jj already diffs. `jj diff --git -w --context 2` gives all that a line key needs. |

## Not here
- The decision records behind the big choices → [08](08-decisions.md)
- Which module embodies which pattern, one by one → [11](11-map.md)
