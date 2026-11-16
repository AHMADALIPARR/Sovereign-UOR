# montrepol

Exact mathematics in Haskell, with every claim tied to a test that can fail.

This repository consolidates the parts of five earlier repositories that held
real mathematics, and drops the rest. It depends on nothing but GHC: no
Hackage packages, no Rust, no Python. The test harness, pseudorandom generator,
TOML reader and every algorithm are written here.

```
cabal build all          # GHC 9.10.1, cabal 3.12
cabal test all           # 182 checks across 6 packages
cabal run mp-gate        # rules R1-R6 over the model, the sources and the build
cabal run mp-gate -- mutants   # planted defects in code, proofs and refinements; each must be caught
agda --no-libraries -i formal formal/Everything.agda   # Agda 2.6.3, --safe, no stdlib
```

## Packages

| Package | What it is | Checked against |
| --- | --- | --- |
| `mp-check` | Test harness: SplitMix64, generators, properties, ID-tagged tests | An independent C SplitMix64; a planted false property |
| `mp-linalg` | Semirings, matrices with dimensions in the type, naive and Strassen products, Bareiss determinant, rank, inverse, participation ratio | Leibniz expansion, the definition of the product, Floyd–Warshall |
| `mp-lie` | Root systems A–G, simple roots, Cartan matrices, Weyl group orders by orbit–stabilizer | The classification tables (Bourbaki, Humphreys) |
| `mp-seq` | Berlekamp–Massey over any field, LFSRs, periods | Brute-force minimality; Massey's 2L theorem |
| `mp-analytic` | Sieve, von Mangoldt, Chebyshev ψ, exact Bernoulli numbers, ζ by Euler–Maclaurin, Riemann–Siegel θ, Hardy Z, zeros, the explicit formula | Trial division, OEIS, lcm(1..x), von Staudt–Clausen, closed forms of ζ, Odlyzko's table |
| `mp-hcalc` | Hcalc: a certifying SMT core. DPLL SAT with resolution refutations, Fourier–Motzkin linear arithmetic over ℚ with Farkas certificates, and DPLL(T) over both | Brute-force truth tables, grids of rational points, and independent certificate checkers that must reject forged certificates |
| `mp-lambda` | The simply typed λ-calculus, and refinement types `{v:Int \| φ}` over it whose verification conditions Hcalc decides | Progress, preservation and substitution on random terms; accepted programs are run and their postconditions checked |
| `mp-gate` | The gate: R1–R6 over the model, sources, proofs, the Liquid layer and the build; mutant replay | Its own planted defects (GT-01..GT-10) |

## Hcalc and refinement types

Hcalc is an SMT solver written here, for quantifier-free linear rational
arithmetic with propositional structure. It is small and slow, and it does not
ask to be trusted: every answer carries a certificate.

| Answer | Certificate | Checked by |
| --- | --- | --- |
| SAT | a model | evaluating the formula directly, ignoring the encoding |
| UNSAT (propositional) | a tree-resolution refutation read off the DPLL search | replaying the resolution steps |
| UNSAT (arithmetic) | Farkas multipliers for every learned theory lemma | summing the constraints and checking the contradiction |

The checker trusts the Tseitin encoding and the reading of terms as linear
expressions; HC-07 tests the encoding against truth tables.

`mp-lambda`'s refinement checker sends each subtyping obligation to Hcalc and
accepts it only when the certificate checks. Hcalc decides over ℚ, and a
statement valid over ℚ is valid over ℤ, so acceptance is sound for integer
programs. The converse fails: `x < y ⟹ x + 1 ≤ y` holds over ℤ but is rejected,
with a non-integral counter-model (LM-10).

## Liquid Haskell

`liquid/` is a separate build that compiles core modules a second time with
the Liquid Haskell plugin and Z3. The refinements live in the core sources as
`{-@ … @-}` comments, which GHC ignores, so the core build is unchanged and
still depends on nothing outside GHC. `liquid/` is the one place allowed to use
Hackage and an external solver. The gate enforces that the exemption runs one
way only: the root build may not include `liquid/`, and no core package may
depend on it.

Liquid Haskell checks `MP.Lambda.Simple` as it is in the core:

- `size` is at least 1.
- `typeOf`, `shift`, `subst` and `step` terminate.
- `evaluate` terminates because its fuel decreases.
- Every pattern match in the module is total.

GHC checks none of these. This is the `refined` level: it trusts Liquid
Haskell 0.9.10.1.2 and Z3 4.8.12, a larger trusted base than Agda's kernel,
and it is kept apart from `proved` for that reason.

```
cd liquid && cabal update && cabal build all    # needs z3 on PATH
```

## Dex

`dex/` holds [Dex](https://github.com/google-research/dex-lang) code: integer
matrices typed by their index sets, the same seven Strassen products, and the
exact Kish comparison. Each check is compared with a hand-computed value or
an independent computation. The files are quines: Dex runs them, and the
output must equal the file, so every `>` line is an assertion. Checks are
tagged `# check DX-01` and registered like any other ID.

Dex's last commit (January 2024) needs LLVM 12, GHC 8.10.7 and a pinned
`llvm-hs`. Ubuntu 24.04 does not package LLVM 12, so `dex/build.sh` installs
Ubuntu 22.04's packages of it, fetches Dex and `llvm-hs` by git at pinned
commits, and builds them into `dex/.toolchain`.

```
./dex/build.sh && ./dex/check.sh
```

## Proofs

`formal/` holds Agda proofs, checked under `--safe --without-K` with no
standard library: equality, naturals, vectors and the algebra are defined
there from nothing.

| Ledger key | What is proved | Where |
| --- | --- | --- |
| `strassen-identities` | Strassen's seven products give the four entries of the 2×2 product, in any abelian group with a two-sided distributive product: no associativity, commutativity or unit assumed. Matrices over a ring are such a structure (standard, not proved here), so this covers blocks | `formal/Montrepol/Strassen.agda` |
| `abelian-solver-sound` | The abelian-group normaliser the Strassen proof uses is sound in every model, so its `refl` steps are trustworthy | `formal/Montrepol/Solver.agda` |
| `kish-lower-bound` | Σ wᵢ² ≤ (Σ wᵢ)² for all natural weights, so k_eff ≥ 1 | `formal/Montrepol/Kish.agda` |

What is *not* proved is recorded too. That `MP.Matrix.strassenSq` uses exactly
these products is checked by reading and by the LA-03 tests, not mechanically.
The Kish upper bound (Cauchy–Schwarz) is tested, not proved.

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

Every claim has one of five levels, and the gate fails if they blur:

- **`some-true`**: reproduced from a cited authority. Not established here.
- **`build`**: constructed here and checked by a test against an oracle.
  Evidence, not proof.
- **`open`**: measured and reported. Never asserted.
- **`proved`**: machine-checked by Agda under `--safe`. The ledger names the
  file and the lemmas; the gate checks they exist, that the file is `--safe`
  with no escape hatches, and that `formal/Everything.agda` imports it so CI
  checks it.
- **`refined`**: checked by Liquid Haskell, trusting it and Z3. The ledger
  names a core source and functions; the gate checks each has a spec and that
  the liquid build compiles the module.

Asserting words ("proves", "guarantees", "establishes", ...) may not appear in
a `build` or `open` claim, and the gate checks that. Property tests over random
inputs are evidence; they are not proofs, and this repository calls a claim
proved only when Agda has checked it.

[`VERIFICATION.md`](VERIFICATION.md) lists the rules R1-R6, says what each
gate discharges and records the defects planted to show it can
fail.

## Toolchain

GHC 9.10.1 and cabal 3.12.1.0, installed with `ghcup`. `libgmp` is needed to
link. Agda 2.6.3 (Ubuntu 24.04's `agda-bin`) for the proofs; run it under a
UTF-8 locale, since its messages print the proofs' Unicode. `cabal.project` sets `active-repositories: :none`: a dependency from
outside the compiler cannot even be resolved, and the build needs no network.

## Licence

GNU Affero General Public License v3.0 or later ([`LICENSE`](LICENSE)). Parts
adapted from the UOR Foundation's template keep their MIT / Apache-2.0 notices;
see [`NOTICE`](NOTICE). Every Haskell source carries
`SPDX-License-Identifier: AGPL-3.0-or-later` on its first line (`.cabal` files
on their second, after `cabal-version`), and the gate fails a file that does
not (R6).
