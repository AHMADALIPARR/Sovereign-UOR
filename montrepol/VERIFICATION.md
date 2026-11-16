# VERIFICATION

What each command discharges, and the evidence that each can fail.

| Command | Discharges | IDs |
| --- | --- | --- |
| `cabal build all` | Types check; `-Wall -Werror`, so no incomplete patterns or unused bindings | — |
| `cabal test all` | Every `build` claim against its oracle | all 39 |
| `cabal run mp-gate` | R1–R6 over the model, the sources and the build configuration | GT-00 is its clean case |
| `cabal run mp-gate -- mutants` | The tests are not vacuous: each planted defect is caught by a named test | the IDs in `model/mutants.toml` |
| `agda --no-libraries -i formal formal/Everything.agda` | Every `proved` ledger claim | — |
| `./dex/build.sh && ./dex/check.sh` | The DX IDs: Dex quines, run and diffed against themselves | DX-01 – DX-04 |
| `cd liquid && cabal build all` | Every `refined` ledger claim (Liquid Haskell, with Z3) | — |
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
| R6 | An outside dependency; an unbounded boot dependency; an unlisted package; a re-enabled package repository; a source or `.cabal` file without the SPDX header | — |
| Liquid (GT-09) | Liquid sources without their own project; a root project that includes them; a core package depending on `liquidhaskell`; an `assume`d refinement | — |
| Refined (GT-10) | A `refined` claim naming a function with no spec, a module the liquid build does not compile, or a file that is not a core source | — |
| Formal (GT-08) | A `proved` claim citing a missing file or lemma; an ID at `proved`; a `postulate`; a module without `--safe`; a module Everything.agda does not import; an Agda file without the SPDX header | "proves" in a `proved` claim |

The gate's first run over this repository found two real violations: `maximum`
(partial on an empty list) in `MP.Matrix` and in the report executable. Both
were rewritten, not exempted.

## The tests can fail

`model/mutants.toml` holds 34 planted defects: in the code, in the Agda
proofs, in the Liquid Haskell refinements, and in the rules that govern
them. `mp-gate mutants` applies each
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
| Gate: SPDX header check disabled | GT-06 |
| Proof: Strassen C12 stated with `a12 b12` for `a12 b22` | Agda, in `strassen-c12` |
| Proof: `M6` defined with `b22` in place of `b12` | Agda, in the expansion lemma `m₆` |
| Proof: the normaliser forgets to swap signs under negation | Agda, in `sound`, the normaliser's soundness proof |
| Proof: the Kish inequality reversed | Agda, in `kish-lower` |
| Gate: the proved-claim lemma check disabled | GT-08 |
| Hcalc: the refutation checker accepts anything | HC-02, HC-08 |
| Hcalc: Fourier–Motzkin drops strictness when combining | HC-03, HC-05, HC-06 |
| Hcalc: back-substitution takes a strict bound itself | HC-03, HC-05 |
| Hcalc: the Farkas checker allows negative multipliers | HC-04 |
| Hcalc: negating `e ≤ 0` gives `−e ≤ 0` instead of `−e < 0` | HC-05, HC-06 |
| Hcalc: the Tseitin OR gate is missing its upward clauses | HC-05 – HC-08 |
| λ: substitution under a binder forgets to shift | LM-05 |
| Refinements: integer subtyping always succeeds | LM-08, LM-10 |
| Refinements: substitution into types captures | LM-09 |
| Liquid: the size of a variable claimed 0 | Liquid Haskell, in `size` |
| Liquid: `typeOf` recurses on the whole term under a lambda | Liquid Haskell, termination of `typeOf` |
| Liquid: `evaluate` keeps stepping when the fuel is spent | Liquid Haskell, termination of `evaluate` |
| Dex: Strassen C22 with M6 subtracted | DX-03 (quine diff) |
| Dex: the product adds a stray term | DX-01 – DX-03 (quine diff) |
| Dex: Kish comparison made strict | DX-04 (quine diff) |

A Dex mutant counts as caught only if the quine check fails with an expected
`> True` line no longer printed, so a check gave the wrong answer.

A Liquid mutant counts as caught only if the build reports an *error* (not a
warning) located in the mutated file, and does not report `LIQUID: SAFE`.

A proof mutant counts as caught only if Agda rejects it with an error
*located in* the file the mutant names (`File.agda:line,col`); a file merely
appearing in Agda's progress output does not count.

Four holes were found this way and closed, and both are recorded here because
they are exactly what this file exists to catch:

- **LI-01 was vacuous.** With the root-system closure check disabled, every
  test still passed, because every system constructed here really is closed.
  LI-01 now also requires rejection of E8 with a root deleted, a non-reduced
  set and a non-crystallographic set.
- **CK-02 did not test the runner.** It used its own loop. The runner is now a
  pure function, `checkProperty`, and CK-02 calls it.
- **HC-04 never offered a negative multiplier**, so a Farkas checker that
  forgot the sign condition passed. With weights (1, −1), `x ≤ 0` and
  `x − 1 ≤ 0` sum to `1 ≤ 0`, although `x = 0` satisfies both. HC-04 now
  draws multipliers of either sign and includes that forgery.
- **LM-05 only substituted closed terms**, and shifting a closed term changes
  nothing, so dropping the shift under binders passed. LM-05 now works in a
  non-empty context, with open terms.

## What this suite does not establish

- **Only the `proved` rows are proofs**, and only of what their lemmas'
  types state. Agda's kernel is trusted. Everything else is tested: property
  tests sample, and the classification tables and Odlyzko's zeros are
  reproduced (`some-true`), not derived.
- **The proofs are about the mathematics, not the Haskell.** That
  `MP.Matrix.strassenSq` computes exactly the seven products of
  `Strassen.agda` is checked by reading and by LA-03, not mechanically. Where
  a claim is exhaustive (root-system axioms, Weyl orders, the 512 zeros
  against the table, brute-force minimality) its test name says so.
- **Floating point is not interval arithmetic.** ζ, θ and Z are computed in
  `Double`. AN-04 to AN-06 measure agreement with closed forms and a table to
  stated tolerances; they do not bound the error rigorously.
- **Completeness of the zeros** to height 826.91 is Odlyzko's, not checked here
  with Turing's method (ledger: `zeta-zeros-complete`).
- **Hcalc's trusted base** is its Tseitin encoding and its reading of terms
  as linear expressions; models and certificates are checked independently of
  everything else. It decides over ℚ: valid over ℚ implies valid over ℤ, not
  conversely.
- **`refined` results trust Liquid Haskell and Z3.** That is a larger base
  than `proved`, and the two levels are kept apart for that reason.
- **The explicit formula's truncation error** is measured, not bounded
  (ledger: `explicit-formula-truncation`, level `open`).
