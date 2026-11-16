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
| `prism-ciris` | The integer kernel's ideas, done correctly: exact Kish k_eff and participation ratio (`mp-linalg`), GF(2) recurrences done properly with Berlekamp–Massey (`mp-seq`), E8 (`mp-lie`) | The ethics, governance and "atlas" prose, the 188 vocabulary files and the `.lex.tex` "proofs": 200 of 223 theorems had no parameters, 196 were `decide` on constants, and no CI step ran Lean. See below for the two defects found in its kernel. |
| `prime-router` | ψ(x), the projection of ψ(x) − x onto zeta zeros, now as the explicit formula with measured error (`mp-analytic`); its zero table, as an oracle | "Hypersphere brain", Λ − π, "hyperbolic deficit", GloVe, the Ollama server. The table file was named `100k` and held 512 rows. |
| `cluster` | Not yet | 22k lines of infrastructure rendering. Porting it means byte-for-byte golden tests against its `generated/`, and it only means something with the hardware. |
| `jsonschema` | Not yet | A fork of an actively maintained upstream. A Haskell validator is a large, separate piece of work, with the official JSON-Schema-Test-Suite as its oracle. |

### Defects found in the prism-ciris kernel

Both were reproduced by compiling the original functions on their own before
anything here was written:

1. `check_integer_kish_keff` used saturating `u64` arithmetic and was described
   as overflow-free. For weights `[2^32, 2^32]`, whose effective size is exactly
   2, it accepted `min_keff = 3` and `min_keff = 1000`. Here the comparison is
   over unbounded integers (LA-08), and a mutant that reintroduces 64-bit
   saturation is caught.
2. `evaluate_gram_ratchet`'s comment said `tr(G)^2 >= 2 ||G||_F^2`, but for a
   2×2 positive semi-definite matrix that holds only when `G` is a multiple of
   the identity, since `(l1 + l2)^2 <= 2 (l1^2 + l2^2)`. The code checked
   `4 tr^2 >= 7 ||G||_F^2` instead. Here the participation ratio
   `tr(G)^2 / tr(G^2)` is shown to lie in `[1, 2]` and to equal 2 exactly for
   scalar matrices (LA-10).

## How claims work

Every claim has one of three levels, and the gate fails if they blur:

- **`some-true`**: reproduced from a cited authority. Not established here.
- **`build`**: constructed here and checked by a test against an oracle.
  Evidence, not proof.
- **`open`**: measured and reported. Never asserted.

Asserting words ("proves", "guarantees", "establishes", ...) may not appear in
a `build` or `open` claim, and the gate checks that. Property tests over random inputs are evidence; they are
not proofs, and this repository does not call them that.

[`AGENTS.md`](AGENTS.md) defines the rules. [`VERIFICATION.md`](VERIFICATION.md)
says what each gate discharges and records the defects planted to show it can
fail.

## Toolchain

GHC 9.10.1 and cabal 3.12.1.0, installed with `ghcup`. `libgmp` is needed to
link. `cabal.project` sets `active-repositories: :none`: a dependency from
outside the compiler cannot even be resolved, and the build needs no network.

## Licence

GNU Affero General Public License v3.0 or later ([`LICENSE`](LICENSE)). Parts
adapted from the UOR Foundation's template keep their MIT / Apache-2.0 notices;
see [`NOTICE`](NOTICE).
