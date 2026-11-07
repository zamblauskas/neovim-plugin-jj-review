# 10 Process

> Source of truth: [spec/roadmap.md](../../spec/roadmap.md) "Development process", [spec/architecture.md](../../spec/architecture.md) "Testing", "Tooling", `Makefile`.
> This page explains and duplicates on purpose. Last checked against revision `woryvuxm`.

## Questions this page answers
- How does a change move from idea to done? Each stage, its artifact, its owner.
- Where do the rules live? Which file decides on a conflict?
- What is the definition of done for one step?
- Which conventions bind every change?
- How is a step reviewed? In which order does a reviewer read?
- Which tools run the checks, and how?

## How a change moves

```
 idea ──▶ feature id ──▶ spec change ──▶ plan of steps ──▶ step 1 ──▶ step 2 ──▶ … ──▶ spec "done"
          F-nn in         rules in        one revision      one jj      one jj              roadmap and
          features.md     data-model,     per step,         revision    revision            features updated
                          stack, ux,      each usable                                       in the last step
                          architecture    on its own
```

| Stage | Artifact | Who |
|---|---|---|
| Idea | one line in `spec/features.md` with an id and a link to the rule section | product owner |
| Rules | the section in `data-model.md`, `stack.md`, `ux.md`, or `architecture.md` that the feature changes | product owner with the implementer |
| Refinement | every open question answered and written into the spec, not into chat | product owner |
| Plan | a list of steps, one concept each, each one a usable increment. `spec/roadmap.md` has the v0 plans. | implementer |
| Step | one jj revision with a description. Tests in the same revision. `make check` green. | implementer |
| Done | roadmap status "done"; spec sections match the code | implementer, then reviewer |

The spec comes first. A behavior that is not in the spec is not implemented. A behavior in the spec that the
code does differently is a bug in one of the two.

Step size, from the log: 67 revisions from the initial spec to now, one concept each. Examples: "Parse jj diff --git output
into file diffs", "Store: marks.json with read-merge-write", "Explorer cursor stays on its target after a redraw".

## Where the rules live

| Kind of rule | File | Decides on a conflict? |
|---|---|---|
| What the plugin does, per feature | `spec/features.md` | ids are stable; other files point to them |
| Data: keys, marks, comments, counts, JSON | `spec/data-model.md` | yes |
| Stack: revset, refresh, rewrites, modes | `spec/stack.md` | yes |
| UI: layout, rows, diff view, keymaps | `spec/ux.md` | yes |
| Structure: layers, modules, messages, effects, flows | `spec/architecture.md` | yes |
| Plan and status per increment | `spec/roadmap.md` | |
| Known refinements with ids | `spec/improvements.md` | |
| Why | `docs/onboarding/` | no; it explains |
| Coding conventions the implementer follows (function size, FP, comments language, VCS) | the implementer's `CLAUDE.md` or equivalent | for style |
| User-facing manual | `README.md` | for the user |

## Definition of done for one step

- [ ] One jj revision. Description: `<Area>: <what, one line>`. Area is `Core`, `Diff`, `Explorer`, `Spec`,
      `Config`, `Store`, `Refresh`, … as in the log.
- [ ] Tests in the same revision, in the mirror file under `tests/`.
- [ ] `make check` green: format (stylua), lint (selene), types (lua-language-server), tests (plenary).
- [ ] The spec section that the step touches is updated in the same revision, or the step is spec-only.
- [ ] Module header comment says what the module is and names its pattern.
- [ ] `jj new` after the step.

## Conventions that bind every change

| Convention | Rule |
|---|---|
| Function size | 15 lines max. A long computation is named steps. |
| Data | Immutable. `tbl.with` returns a new table. No module mutates a value it got. |
| Purity | `core/`, `parse/`, `view/`: no `vim.api`, `vim.uv`, `vim.system`, no buffer, window, file, process. |
| Types | LuaCATS on every public function and shape. Types next to the code that makes them. |
| Patterns | Named with the established name, in the spec and in the module header. |
| Helpers | A helper without a plugin type goes to `lib/` or `shell/lib/`. |
| Comments | ASD-STE100 Simplified Technical English. Short sentences. |
| Tests | `local assert = require("luassert")`. Core tests use plain data. Shell tests use fakes or a temp jj repo. |
| Version control | jj. One revision per step. Descriptions as above. |

## How a step is reviewed

1. The description. One line. Does it name one concept?
2. The spec diff, if any. Is the rule clear without the code?
3. The test names. Do they read as the rule's cases?
4. The module header comments of new or changed modules. Pattern named?
5. The diff, newest to oldest file: `core/` first, then `view/`, then `shell/`.
6. `make check` locally.

This plugin reviews itself: open the stack of steps with `:Review`, mark lines, comment for the implementer.

## Checks and tools

| Check | Tool | Command | Config |
|---|---|---|---|
| Format | stylua | `make format`, `make format-check` | `stylua.toml` |
| Lint | selene | `make lint` | `selene.toml`, `vim.yml` (Neovim and busted globals) |
| Types | lua-language-server | `make typecheck` | `.luarc.check.json` (not `.luarc.json`, which would override the editor's lazydev library) |
| Tests | plenary busted, `nvim --headless` | `make test` | `tests/minimal_init.lua`; 375 `it` blocks |
| All | | `make check` | |

Tools come from `PATH`, else from Mason's bin directory.

| Layer | How it is tested |
|---|---|
| `parse/` | fixture jj output in `tests/fixtures/` → expected tables |
| `core/` | plain state in, message in, state and effect list out. Most tests. |
| `view/` | state → expected lines and extmark specs |
| `shell/` | fake ports, or a temp jj repo made with `jj git init` (`tests/helpers.lua`) |
| end to end | `tests/init_spec.lua` with a real temp repo |

Development load: a lazy.nvim spec with `dir =` this repo.

## Not here
- The product roadmap → [spec/roadmap.md](../../spec/roadmap.md), [spec/features.md](../../spec/features.md) v1, v2
- Install and user keymaps → [README.md](../../README.md)
