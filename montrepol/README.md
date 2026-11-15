# montrepol

Exact mathematics in Haskell, with every claim tied to a test that can fail.

This repository consolidates the parts of five earlier repositories that held
real mathematics, and drops the rest. It depends on nothing but GHC: no
Hackage packages, no Rust, no Python. The test harness, pseudorandom generator,
TOML reader and every algorithm are written here.

```
cabal build all          # GHC 9.10.1, cabal 3.12
cabal test all           # 171 checks across 6 packages
cabal run mp-gate        # rules R1-R6 over the model, the sources and the build
cabal run mp-gate -- mutants   # 13 planted defects; each must be caught by a named test
```

## Packages

| Package | What it is | Checked against |
| --- | --- | --- |
| `mp-check` | Test harness: SplitMix64, generators, properties, ID-tagged tests | An independent C SplitMix64; a planted false property |
| `mp-linalg` | Semirings, matrices with dimensions in the type, naive and Strassen products, Bareiss determinant, rank, inverse, participation ratio | Leibniz expansion, the definition of the product, Floyd–Warshall |
| `mp-lie` | Root systems A–G, simple roots, Cartan matrices, Weyl group orders by orbit–stabilizer | The classification tables (Bourbaki, Humphreys) |
| `mp-seq` | Berlekamp–Massey over any field, LFSRs, periods | Brute-force minimality; Massey's 2L theorem |
| `mp-analytic` | Sieve, von Mangoldt, Chebyshev ψ, exact Bernoulli numbers, ζ by Euler–Maclaurin, Riemann–Siegel θ, Hardy Z, zeros, the explicit formula | Trial division, OEIS, lcm(1..x), von Staudt–Clausen, closed forms of ζ, Odlyzko's table |
| `mp-gate` | The gate: R1–R6 over the model, sources and build; mutant replay | Its own planted defects (GT-01..GT-07) |

[`CONFORMANCE.md`](CONFORMANCE.md) lists all 39 conformance IDs and the ledger's
untested claims, by package and honesty level. It is generated from [`model/`](model/), never edited.

## Where it came from

| Repository | Kept | Dropped, and why |
| --- | --- | --- |
| `matmul` | The claim discipline: levels, register, generated conformance, the rules | All of the Rust. There was no matrix multiplication in it; it was an empty template. `mp-linalg` is the matmul. |
| `prism-ciris` | The integer kernel's ideas, done correctly: exact Kish k_eff and participation ratio (`mp-linalg`), GF(2) recurrences done properly with Berlekamp–Massey (`mp-seq`), E8 (`mp-lie`) | The ethics, governance and "atlas" prose, the 188 vocabulary files and the `.lex.tex` "proofs": 200 of 223 files contained no mathematics. |
| `uor` | The honesty of saying what is not shown: open claims stay open | Everything that was not a mathematical claim. |
| `zeta` | The analytic number theory | The Python, the notebooks, the approximate floating-point. |
| `lie` | The root systems | The Sage dependency. |

## Honesty

Every claim is one of three levels:

- **build** — a test can fail. The CI runs it.
- **some-true** — cited to a named authority that exists in the register. Not re-proved here.
- **open** — stated and left untested. The gate forbids asserting language on an open claim.

A mutant that is not caught by the test that names it fails the honesty workflow.
