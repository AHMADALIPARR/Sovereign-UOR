# Sovereign UOR

Two separate code trees in one repository.

| Tree | Language | What is in it |
|------|----------|---------------|
| `src/` | Scala 3 | `Poly64`, a sparse multivariate polynomial type with coefficients in Z/2^64 (wrapping `Long` arithmetic), plus GraalVM `@CEntryPoint` exports in `src/main/scala/uor/ffi/UorExports.scala` |
| `montrepol/` | Haskell (Cabal, GHC 9.10.1) | Six packages: `mp-check`, `mp-linalg`, `mp-lie`, `mp-seq`, `mp-analytic`, `mp-gate`, with a claim register in `montrepol/model/` |

## Current state

These are the things that were checked on 2026-11-15.

- The Scala job in `.github/workflows/ci.yml` compiles `U64.scala` and `Poly64.scala` and runs `Poly64Test`. It passed on GitHub Actions in run 35 (commit 5db9b38).
- `montrepol/` does not compile as committed. `cabal build all` with GHC 9.10.1 stops with errors in `MP/Algebra.hs` (a duplicate `Eq (Maybe a)` instance), `MP/Bernoulli.hs`, `MP/Primes.hs`, `MP/RootSystem.hs`, `MP/Gate/Scan.hs` and `MP/Gate/Toml.hs`. Because of this the `cabal` job in `ci.yml` and the `honesty` workflow fail.
- `montrepol/oracles/zeta-zeros-odlyzko.txt` does not match published values. Compared with the zeros listed by LMFDB, 397 of its 512 rows differ by 1e-6 or more. A corrected table, rounded from LMFDB, is in `montrepol/oracles/zeta-zeros-odlyzko_checked.txt`.

The full list of findings, with file and line references, is in [docs/README-audit.md](docs/README-audit.md). The previous README is kept unchanged in [docs/README-original.md](docs/README-original.md).

## Layout

```
.github/workflows/ci.yml        Scala test, native-image (non-blocking), Cabal build/test/gate
.github/workflows/honesty.yml   mutant replay for montrepol
src/main/scala/uor/kernel/      U64.scala, Poly64.scala
src/main/scala/uor/ffi/         UorExports.scala
src/test/scala/uor/kernel/      Poly64Test.scala (munit)
montrepol/cabal.project         the six packages; active-repositories: :none
montrepol/model/                ids.toml, authorities.toml, ledger.toml, mutants.toml
montrepol/oracles/              zeta zero tables
montrepol/packages/             mp-check, mp-linalg, mp-lie, mp-seq, mp-analytic, mp-gate
docs/                           audit and other documents
```

## Build and test

Scala (needs a JDK and scala-cli):

```bash
scala-cli test --scala 3.5.2 src/main/scala/uor/kernel src/test/scala/uor/kernel/Poly64Test.scala
```

Haskell (GHC 9.10.1, cabal 3.12). As noted above, this currently fails to compile:

```bash
cd montrepol
cabal update
cabal build all
cabal test all
cabal run mp-gate
cabal run mp-gate -- mutants
```

## License

AGPL-3.0-only OR LicenseRef-SnapKitty-Opaque-1.0. The AGPL text is in [LICENSE](LICENSE).
