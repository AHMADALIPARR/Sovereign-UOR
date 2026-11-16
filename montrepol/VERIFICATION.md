# VERIFICATION

What each command discharges, and the evidence that each can fail.

| Command | Discharges | IDs |
| --- | --- | --- |
| `cabal build all` | Types check; `-Wall -Werror`, so no incomplete patterns or unused bindings | — |
| `cabal test all` | Every `build` claim against its oracle | all 39 |
| `cabal run mp-gate` | R1–R6 over the model, the sources and the build configuration | GT-00 is its clean case |
| `cabal run mp-gate -- mutants` | The tests are not vacuous: each planted defect is caught by a named test | the IDs in `model/mutants.toml` |
| `cabal run mp-analytic-report` | The measured numbers behind the ledger's `open` row. Asserts nothing. | — |

## The gate can fail

`mp-gate-test` plants each class of defect in a synthetic repository that
otherwise passes, and requires the gate to report **exactly** the rule
broken, and no other:

| Rule | Planted defect | Near-misses that must not fire |
| --- | --- | --- |
| R1 | A hand-edited CONFORMANCE.md; a duplicated ID; an unparsable model | — |
| R2 | An `open` ID; "proves" in an `open` claim; `some-true` without an authority; an unknown authority | — |
| R3 | An ID with no test; a test tagged with an unregistered ID | — |
| R4 | A deferral marker; a stub | The same word in a comment and in a string |
| R5 | `head`; `!!`; a missing `-Werror` | A primed name (`head'`), a string, a comment |
| R6 | An outside dependency; an unbounded boot dependency; an unlisted package; a re-enabled package repository | — |

The gate's first run over this repository found two real violations: `maximum`
(partial on an empty list) in `MP.Matrix` and in the report executable. Both
were rewritten, not exempted.

## The tests can fail

`model/mutants.toml` holds 13 planted defects. `mp-gate mutants` applies each
one, runs that package's tests and restores the file. A mutant counts as
caught only if the tests named in its `expect` field fail; one that merely
stops the build counts as missed.

| Planted defect | Caught by |
| --- | --- |
| Strassen: `C22 = M1 − M2 + M3 − M6` | LA-03 |
| Bareiss: row swap without a sign flip | LA-04, LA-05 |
| Kish: 64-bit saturation reintroduced | LA-08 |
| Weyl orbit: reflect only on coordinates ≥ 2 | LI-04, LI-06 |
| Root axioms: closure check disabled | LI-01 |
| Berlekamp–Massey: `2L <= k` changed to `2L < k` | SQ-01, SQ-02, SQ-03, SQ-04 |
| Sieve: crossing off with stride 2i | AN-01, AN-03 |
| Euler–Maclaurin: sign of the `N^-s / 2` term flipped | AN-04, AN-05, AN-06 |
| θ: the `−π/8` term dropped | AN-05 |
| Bernoulli: recurrence index shifted | AN-03, AN-04, AN-05, AN-06 |
| Gate: R5's partial-function list emptied | GT-05 |
| Gate: R3's untested-ID check disabled | GT-03 |
| Harness: property runner stops after the first case | CK-02 |

Two holes were found this way and closed, and both are recorded here because
they are exactly what this file exists to catch:

- **LI-01 was vacuous.** With the root-system closure check disabled, every
  test still passed, because every system constructed here really is closed.
  LI-01 now also requires rejection of E8 with a root deleted, a non-reduced
  set and a non-crystallographic set.
- **CK-02 did not test the runner.** It used its own loop. The runner is now a
  pure function, `checkProperty`, and CK-02 calls it.

## What this suite does not establish

- **Nothing here is a proof.** Property tests sample; the classification
  tables and Odlyzko's zeros are reproduced (`some-true`), not derived. Where
  a claim is exhaustive (root-system axioms, Weyl orders, the 512 zeros
  against the table, brute-force minimality) its test name says so.
- **Floating point is not interval arithmetic.** ζ, θ and Z are computed in
  `Double`. AN-04 to AN-06 measure agreement with closed forms and a table to
  stated tolerances; they do not bound the error rigorously.
- **Completeness of the zeros** to height 826.91 is Odlyzko's, not checked here
  with Turing's method (ledger: `zeta-zeros-complete`).
- **The explicit formula's truncation error** is measured, not bounded
  (ledger: `explicit-formula-truncation`, level `open`).
