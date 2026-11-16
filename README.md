# Sovereign UOR

Two separate code trees in one repository, plus a corrected copy of the
second one and a Dex program that cross-checks both.

| Tree | Language | What is in it |
|------|----------|---------------|
| `src/` | Scala 3 | `Poly64`, a sparse multivariate polynomial type with coefficients in Z/2^64 (wrapping `Long` arithmetic), plus GraalVM `@CEntryPoint` exports in `src/main/scala/uor/ffi/UorExports.scala` |
| `montrepol/` | Haskell (Cabal, GHC 9.10.1) | Six packages: `mp-check`, `mp-linalg`, `mp-lie`, `mp-seq`, `mp-analytic`, `mp-gate`, with a claim register in `montrepol/model/`. Kept as committed; it does not compile. |
| `montrepol_checked/` | Haskell (Cabal, GHC 9.10.1) | A corrected copy of `montrepol/` that builds, passes its tests and its gate. |
| `dex/` | Dex, Scala, Haskell | A second implementation, in Dex, of Poly64 arithmetic and of the determinant, compared line by line with the Scala kernel and with `montrepol_checked`. |

## Current state

Checked on 2026-11-15.

- Scala: `Poly64Test` (8 tests) passes in CI.
- `montrepol/` does not compile with GHC 9.10.1: a duplicate `Eq (Maybe a)`
  instance, modules imported from `mp-linalg` by packages that do not depend
  on it, and `-Werror` warnings in `mp-gate`. Its mutant-replay driver uses
  names that are not defined. CI still builds it, as an informational job
  that is allowed to fail.
- `montrepol_checked/` builds with no warnings under the same `-Werror`
  flags. 80 tests pass (mp-check 5, mp-linalg 19, mp-lie 13, mp-seq 8,
  mp-analytic 12, mp-gate 23), `mp-gate` reports that R1 to R6 hold over the
  6 packages, and 10 of 10 planted mutants are caught.
- `montrepol/oracles/zeta-zeros-odlyzko.txt` is wrong in 426 of its 512 rows
  compared with LMFDB; 397 rows are off by 1e-6 or more. The corrected table
  is `montrepol/oracles/zeta-zeros-odlyzko_checked.txt`. The zero finder in
  `montrepol_checked` finds exactly 512 zeros on (10, 827] and matches the
  corrected table to within 5.3e-11.
- Dex oracle: 600 of 600 Poly64 lines agree with the Scala kernel and 200 of
  200 determinants agree with `montrepol_checked`, both locally and in CI
  (`dex-oracle` run 5).

The full list of findings, with file and line references, is in
[docs/README-audit.md](docs/README-audit.md). The previous README is kept
unchanged in [docs/README-original.md](docs/README-original.md).

## Layout

```
.github/workflows/ci.yml          Scala test, native image (non-blocking), montrepol_checked build/test/gate,
                                  montrepol build (informational)
.github/workflows/honesty.yml     mutant replay for montrepol_checked
.github/workflows/dex-oracle.yml  Dex dual oracle
src/main/scala/uor/kernel/        U64.scala, Poly64.scala
src/main/scala/uor/ffi/           UorExports.scala
src/test/scala/uor/kernel/        Poly64Test.scala (munit)
montrepol/                        the Haskell tree as committed
montrepol_checked/                the corrected Haskell tree (same layout)
  cabal.project                   the six packages; active-repositories: :none
  model/                          ids.toml, authorities.toml, ledger.toml, mutants.toml
  packages/                       mp-check, mp-linalg, mp-lie, mp-seq, mp-analytic, mp-gate
montrepol/oracles/                zeta zero tables (original and _checked)
dex/                              poly64.dx, det.dx and the two vector generators
docs/                             audit, Dex notes, original README and workflows
LICENSE                           GNU AGPL v3 text
```

## Build and test

Scala (JDK 21 and scala-cli):

```bash
scala-cli test --scala 3.5.2 src/main/scala/uor/kernel src/test/scala/uor/kernel/Poly64Test.scala
```

Haskell, corrected tree (GHC 9.10.1, cabal 3.12):

```bash
cd montrepol_checked
cabal update
cabal build all
cabal test all
cabal run mp-gate
cabal run mp-gate -- mutants
```

The same commands in `montrepol/` stop at `cabal build all`.

Dex oracle: see [docs/dex-oracle.md](docs/dex-oracle.md) for building Dex
(LLVM 12, GHC 8.10.7 through stack) and for the exact commands.

## Documents

| Document | Contents |
|---|---|
| [docs/README-audit.md](docs/README-audit.md) | Every claim of the old README checked against the code; truncation, fabrication, test and mutant audit |
| [docs/dex-oracle.md](docs/dex-oracle.md) | What the Dex programs compute, how they are compared, measured agreement |
| [docs/README-original.md](docs/README-original.md) | The README as it was at commit `5db9b38` |
| [docs/workflows-original/](docs/workflows-original/) | The workflows as they were before the CI fix |

Per-file documents live under `docs/files/`, at the same path as the file
they describe. Written so far:

| File | Document |
|---|---|
| `src/main/scala/uor/kernel/Poly64.scala` | [docs/files/src/main/scala/uor/kernel/Poly64.scala.md](docs/files/src/main/scala/uor/kernel/Poly64.scala.md) |

## License

AGPL-3.0-only OR LicenseRef-SnapKitty-Opaque-1.0. The AGPL text is in [LICENSE](LICENSE).
