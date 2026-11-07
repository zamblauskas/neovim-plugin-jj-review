# Onboarding

> For an engineer who must understand this plugin without reading its code.
> Every page is self-contained and duplicates the spec on purpose. The spec (`spec/`) decides on a conflict.
> Every page says which revision it was last checked against. Audit with `/onboarding-docs audit`.

## Who

- A product owner who writes feature specs for this plugin and must know what the design allows.
- A person who directs implementation (by people or by agents) and reviews each step.

## Reading paths

| Path | Time | Read |
|---|---|---|
| Elevator | 30 min | 01, 02 |
| Design review | half day | + 03, 04, 05, 08 |
| Full | one day | all, then `spec/` in the order: data-model, stack, architecture, ux, features |

After the Full path you can answer:
- Why does a mark survive `jj squash`, but not a rename of the file? (06, 08)
- What runs when the agent runs `jj squash` in another terminal, step by step? (05, 07)
- Which modules may call the Neovim API, and why only those? (03, 07)
- Why can two Neovim instances on one repo lose a mark? (06, 09)

## Map

| Page | Answers |
|---|---|
| [01 Problem](01-problem.md) | What it does, for whom, the core loop, the four invariants everything serves |
| [02 Mental model](02-mental-model.md) | One picture. A message and its lifecycle |
| [03 Boundaries](03-boundaries.md) | core / parse / view / lib / shell. Who may call whom. Who owns which handle |
| [04 Patterns](04-patterns.md) | 13 named patterns: where, why, cost |
| [05 Walkthroughs](05-walkthroughs.md) | Open; toggle a line; the agent rewrites the stack; edit in working-copy mode |
| [06 Data](06-data.md) | Line keys, marks, comments, counts, the two JSON files, what survives what |
| [07 Edges](07-edges.md) | Every touching point with Neovim, jj, and the file system |
| [08 Decisions](08-decisions.md) | 12 decisions: what, instead of, because, cost |
| [09 Limits](09-limits.md) | By design, hidden invariants, open hazards |
| [10 Process](10-process.md) | Spec → steps → one revision per step → `make check` |
| [11 Map](11-map.md) | Every module in one sentence |
| [12 Glossary](12-glossary.md) | Terms, and terms we do not use |

## Conventions

- Header per page: source of truth, "Last checked against revision". Audit: `/onboarding-docs audit`.
- "Not here" at the end of each page: what you may look for on that page and where it is.
- Feature ids (`F-01` …) are in `spec/features.md`. Improvement ids (`A1`, `B3` …) are in `spec/improvements.md`.
