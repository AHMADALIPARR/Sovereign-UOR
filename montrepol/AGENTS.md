# AGENTS

The standing brief for anyone, human or otherwise, changing this repository.

Read `README.md` for the shape of it, then `VERIFICATION.md` for which gate
discharges what.

## The rules

Every violation `mp-gate` reports names the rule it breaks, so a red gate says
*which promise* failed rather than merely that something is wrong. Nothing else
in the repository defines an `R`-number.

| Rule | What it says | Enforced by |
| --- | --- | --- |
| R1 | The model is the single source. Every claim lives in `model/*.toml`; `CONFORMANCE.md` is generated from it. IDs are unique, well formed and name a real package. | `mp-gate` |
| R2 | Levels are load-bearing. An ID is `build` or `some-true`, never `open`. `some-true` cites an authority that exists. No `build` or `open` claim uses asserting words ("proves", "guarantees", ...). Every authority is cited. | `mp-gate` |
| R3 | Every ID is tagged on a test in its own package, and every test tag is a registered ID. | `mp-gate` |
| R4 | Nothing is deferred: no deferral markers, no stubs. | `mp-gate` |
| R5 | Everything is total: no partial Prelude functions (`head`, `fromJust`, `maximum`, `!!`, `error`, ...), nothing unsafe, warnings are errors. | `mp-gate`, GHC `-Wall -Werror` |
| R6 | Nothing arrives from outside GHC and this repository. Boot packages carry both version bounds; every package directory is in `cabal.project`; no package repository is enabled. | `mp-gate`, `active-repositories: :none` |

## Changing something

1. Edit the model if the claim changes. Never edit `CONFORMANCE.md` by hand.
2. Add or change the test that carries the ID.
3. Run `cabal run mp-gate -- write` and commit the regenerated conformance.
4. If you plant a defect, add it to `model/mutants.toml` and confirm the honesty job catches it.

The gate is the reviewer. A change that leaves the gate red does not land.
