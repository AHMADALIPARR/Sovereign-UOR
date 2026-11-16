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

## Adding a capability

In this order, because the order is the discipline:

1. A row in `model/ids.toml`, with its level, its claim and what it is checked
   against.
2. A test tagged with the ID (`unit "XX-00" ...`, `prop "XX-00" ...`) that
   fails without the implementation.
3. The implementation.
4. At least one entry in `model/mutants.toml`: a defect planted in the
   implementation and the IDs that must catch it.
5. `cabal run mp-gate -- write`, then `cabal test all`, `cabal run mp-gate` and
   `cabal run mp-gate -- mutants`.

## Choosing an oracle

A test is only as good as what it compares against. Prefer, in order:

1. An independent algorithm for the same quantity (Leibniz for Bareiss, the
   definition for Strassen, Floyd–Warshall for min-plus powers, brute force for
   Berlekamp–Massey).
2. A theorem that does not depend on the code under test (von Staudt–Clausen,
   `e^psi(x) = lcm(1..x)`, Euler's formula for `zeta(2k)`).
3. A published table, cited in `model/authorities.toml` and committed under
   `oracles/` when it is data.

Never compare a function with itself, and never let a table be an input and
its own check.

## Writing a gate

A gate that cannot fail is worse than no gate, because it reads as evidence.
Before relying on one, plant the defect it exists to catch and confirm it
fires. For the rules that is `mp-gate-test` (GT-01..GT-07). For the
mathematics it is `model/mutants.toml`. A mutant that only breaks the build
does not count as caught.

A gate that reads source must survive reading its own. `MP.Gate.Scan` spells
its forbidden names in halves for that reason; exempting the file would leave a
hole exactly where a defect parked in the gate would sit.

## Comments

Explain *why*, not *what*. A comment earns its place by recording why a
decision went one way when it could plausibly have gone another.
