# 02 Mental model

> Source of truth: [spec/architecture.md](../../spec/architecture.md) "Patterns", "State", "Messages", "Effects".
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- What is the one picture?
- What is the unit of work? Where is it born, where does it die?
- What is the lifecycle of one unit of work?
- Which parts are pure and which touch the outside?
- What can a reader rely on because of this model?

## The one picture

Everything that happens is a **message**. One pure function turns a message into a new state and a list of
**effects**. The shell runs the effects. Effects produce new messages. That is the whole plugin.

```
  user key ─┐
  jj op ────┤                                                                   ┌──▶ Neovim (buffers, windows, extmarks)
  focus ────┼──▶ Msg ──▶ update(state, msg) ──▶ (state', [Effect]) ──▶ interpreter ──┼──▶ jj CLI (log, diff, file show)
  timer ────┘                   ▲                                                   └──▶ disk (.jj/review/*.json)
                                │                                                           │
                                └──────────── result Msg (StackLoaded, DiffLoaded, …) ◀─────┘
```

This is the Elm Architecture (Model, Update, View) with effects as data (Command pattern) and an interpreter.

## Parts

| Part | Lives in | Pure? | Example |
|---|---|---|---|
| Message | `core/msg.lua` | yes, data | `ToggleRequested{target, now}` |
| State | `core/state.lua` | yes, one table | stack, diffs by commit id, marks by line key, open buffers |
| update | `core/update.lua` + `core/handlers/` | yes | "a toggle → new marks + `SaveMarks` + `RenderDiff`" |
| Effect | `core/effect.lua` | yes, data | `SaveMarks{root, patch}` |
| Interpreter | `shell/effects.lua` | no | runs `jj diff`, writes JSON, asks the diff port to draw |
| View | `view/` | yes | state → lines and highlight specs. Never touches a buffer. |
| Ports | `shell/*.lua` | no | jj, store, explorer, layout, diff, watcher, comment input, ids, clock |

There are 28 message types and 23 effect types. Each has a handler in a dispatch table. A message with no handler
is ignored.

## Lifecycle of one message

```
 born                      update                                    effects                     dies
 ─────                     ──────                                    ───────                     ────
 keymap, autocmd,   ──▶  1. stale? (review closed, or old           ──▶ each effect runs      ──▶ state replaced,
 watcher, timer,            generation) → dropped, no effects            through a port;          effects consumed.
 or an effect result     2. handler by msg.type → new state,             async results come
                            effect list                                  back as new messages
```

**Generation.** Each `Opened` increments `generation`. Every effect that asks jj or the disk carries it. The
result message carries it back. A result from an older open is dropped. There is no cancellation; late answers
are ignored. That is enough.

**Stale.** While the review is closed, every message except `Opened` is dropped.

## Shapes

These two shapes carry the model. A message is a table with a `type` tag and fields. An effect is the same.

```lua
{ type = "ToggleRequested", target = { type = "line", change_id = "kpt…", path = "src/load.rs", line = 12 }, now = "2026-11-07T10:00:00Z" }
{ type = "SaveMarks", generation = 3, root = "/repo", patch = { set = { ["+|src/load.rs|9f2c…|1"] = "2026-…" }, unset = {} } }
```

Note what is in the message and not in core: the clock (`now`), the comment id, the cursor line. Core has no
clock, no id generator, no access to a window. The shell puts those values into the message.

## The layers, seen from the message

```
            ┌──────────────────────── shell (side effects) ────────────────────────┐
 jj CLI ──▶ │  jj   store   watcher   focus   layout   explorer   diff   buffers   │ ──▶ Neovim
            └──────┬──────────────┬───────────────▲──────────────────▲─────────────┘
                   │ text         │ JSON          │ Msg              │ render specs
            ┌──────▼──────────────▼───────────────┴──────────────────┴─────────────┐
            │ parse (text → tables)   core (update, state, rules)   view (state → specs) │
            │                         pure, immutable, no vim.api                       │
            └─────────────────────────────────────────────────────────────────────────┘
```

## What you can rely on

- **A core test is**: build a state, send a message, compare the new state and the effect list. No Neovim window,
  no jj, no disk. Most of the 375 tests are of this kind.
- **Render is an effect.** `update` decides when to redraw. The shell batches: at most one redraw per event-loop
  tick per view. Twenty `DiffLoaded` messages give one redraw.
- **Core never throws.** A failure is a message (`JjFailed`, `StoreFailed`, `CommandFailed`) or a stack status
  (`error`). The shell catches at the port edge and dispatches a message.
- **No hidden clock, id, or randomness in core.** Replaying the same messages gives the same state.
- **Immutable state.** A handler returns a new table. A value you hold never changes under you.

## Not here
- The rules of who may call whom → [03](03-boundaries.md)
- Named patterns with their cost → [04](04-patterns.md)
- The list of all messages and effects → [spec/architecture.md](../../spec/architecture.md) "Messages", "Effects"
