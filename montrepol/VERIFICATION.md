# VERIFICATION

How each rule is discharged.

| Rule | Mechanism | What a failure means |
| --- | --- | --- |
| R1 | `mp-gate` regenerates `CONFORMANCE.md` from `model/` and fails if the committed file differs, or if an ID is duplicated, malformed or names a missing package. | The model and the published register disagree. |
| R2 | The same gate checks that every `some-true` cites a registered authority, that no asserting word appears on a `build` or `open` claim, and that every authority is cited at least once. | A claim is stronger than its evidence. |
| R3 | Every ID must appear as a tag on a test in the package it names; every tag must be a registered ID. | A claim has no test, or a test claims something unregistered. |
| R4 | The scanner rejects deferral markers (`TODO`, `FIXME`, `XXX`, `HACK`, `stub`, `not implemented`) outside comments and strings. | Something was left for later. |
| R5 | The scanner rejects the partial Prelude functions and operators, and the cabal file requires `-Werror`. | A function can fail at runtime on a legal input. |
| R6 | `cabal.project` sets `active-repositories: :none`; the gate checks that every package is listed and that boot packages have both bounds. | A dependency can arrive from outside the repository. |

The honesty workflow applies every mutant in `model/mutants.toml`, requires that the named tests fail, and requires that the working tree is clean afterwards. A mutant that is not caught means a test can no longer fail.
