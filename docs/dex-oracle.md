# Dex dual oracle

[Dex](https://github.com/google-research/dex-lang) is a functional, statically
typed array language from Google Research, compiled through LLVM. It is used
here as a second, independent implementation of two computations the
repository already checks. Each side generates the same pseudo-random inputs,
computes the results its own way, and prints one line per result. CI requires
the two outputs to be byte-identical.

## What is compared

| Check | First side (repository code) | Second side (Dex) | Lines per run |
|---|---|---|---|
| Poly64: sum, product and evaluation of two-variable polynomials over Z/2^64 | `src/main/scala/uor/kernel/Poly64.scala` (sorted sparse terms), driven by `dex/scala/Poly64Vectors.scala` | `dex/poly64.dx` (dense coefficient tables, Word64 arithmetic) | 600 (200 cases x add, mul, eval) |
| Determinant (LA-04): Bareiss elimination vs the Leibniz formula | `MP.Matrix.det` in `montrepol_checked/packages/mp-linalg`, driven by `dex/haskell/BareissVectors.hs` | `dex/det.dx` (sum over all permutations of a 6 x 6 embedding, Int64) | 200 |

The two sides share no code. Both use SplitMix64 with seed `0x5eed`, written
separately in each language, and the same drawing rules:

- Poly64 case: for each of the two polynomials, `nterms = 1 + w mod 4`, then for
  each term `e0 = w mod 4`, `e1 = w mod 4`, `coeff = w`; then two evaluation
  points `w`. Duplicate monomials are summed and zero coefficients dropped.
- Determinant case: `n = 1 + w mod 6`, then `n*n` entries in row-major order,
  each `(w mod 41) - 20`.

Output lines:

```
case 0 add 1,3:70d29b6c7d22528d 2,0:1289a69805c125b1 3,3:58a5f17b6c15c659
case 0 mul 3,3:62ad984d77f6747d 4,6:be3416e34e58c105
case 0 eval 8576a4f2cab95600
case 0 n 5 det 755160
```

Terms are `e0,e1:coefficient` in lexicographic order of the exponents, with
16-digit hex coefficients; a zero polynomial prints as `0`.

## Measured agreement

| Comparison | Local run (2026-11-15) | CI, dex-oracle run 5 (commit `9e27e68`) |
|---|---|---|
| Scala Poly64 vs `poly64.dx` | 600 of 600 | 600 of 600 |
| Haskell Bareiss vs `det.dx` | 200 of 200 | 200 of 200 |

CI run: https://github.com/AHMADALIPARR/Sovereign-UOR/actions/runs/43783588614.
In that run the "Build dex" step took 10 min 17 s and the compare step 12 s;
the finished build is cached under the key
`dex-25e2e389b90403ae2f8d67fb6d52f47d23c439ee-jammy-llvm12-v1-done`.

Matrix sizes in the 200 determinant cases: n=1: 33, n=2: 28, n=3: 30, n=4: 33,
n=5: 40, n=6: 36.

Negative controls (temporary copies of the Dex files, not committed):

| Planted change | Lines that then differ |
|---|---|
| `det.dx`: every permutation sign forced to +1 | 165 of 200 |
| `poly64.dx`: each product term increased by 1 | 400 of 600 |

`poly64.dx` runs in about 2 s and `det.dx` in about 1.5 s on the build machine,
including compilation of the program (the prelude is compiled once before).

## Dex details that matter here

- `rem` on `Word64` is a signed remainder in this Dex version: `rem` of
  `0xdc336acab085b9ce` by 4 gives `0xfffffffffffffffe`. `poly64.dx` and
  `det.dx` therefore build an unsigned remainder `urem` from 32-bit halves.
- `.>>.` on `Word64` is a logical shift (`0xffffffff00000000 .>>. 30` gives
  `0x3fffffffc`).
- Dex has no hexadecimal literals and no `Show` instance for `Word64`, so the
  64-bit constants are assembled from two 32-bit halves and hex output is
  formatted by hand.
- Comments are `#`; `'` starts a prose block.

## Building Dex

The last upstream commit is `25e2e389b90403ae2f8d67fb6d52f47d23c439ee`
(2024-01-10). It needs GHC 8.10.7 (stack resolver lts-18.23), LLVM 12 and
clang 12, which Ubuntu 22.04 still packages. The `dex-oracle` workflow builds
it in an `ubuntu:22.04` container:

```
apt-get install llvm-12-dev clang-12 libpng-dev libgmp-dev zlib1g-dev libtinfo-dev pkg-config nodejs npm
git clone https://github.com/google-research/dex-lang && cd dex-lang
git checkout 25e2e389b90403ae2f8d67fb6d52f47d23c439ee
npm install --no-save --prefix /tmp/tsc typescript@4.9.5
/tmp/tsc/node_modules/.bin/tsc --strict --lib es2015,dom static/index.ts
clang++-12 -fPIC -std=c++11 -fno-exceptions -fno-rtti -pthread -DDEX_LIVE -c -emit-llvm src/lib/dexrt.cpp -o src/lib/dexrt.bc
export PATH=/usr/lib/llvm-12/bin:$PATH
stack setup && stack build --fast
```

`static/index.js` and `src/lib/dexrt.bc` are listed in `dex.cabal` as data
files, so the copy step fails without them even though the oracle never uses
the web front end. `dexrt.bc` is read at run time.

## Running

From the repository root, with Dex built in `$DEX` (a dex-lang checkout):

```
scala-cli run --server=false --scala 3.5.2 src/main/scala/uor/kernel dex/scala/Poly64Vectors.scala -- 200 > poly64-scala.txt
ghc -O0 -outputdir /tmp/bv -o /tmp/bv/bareiss-vectors \
  -imontrepol_checked/packages/mp-linalg/src -imontrepol_checked/packages/mp-check/src \
  dex/haskell/BareissVectors.hs
/tmp/bv/bareiss-vectors 200 > det-haskell.txt
(cd $DEX && stack exec dex -- --lib-path lib script $OLDPWD/dex/poly64.dx) | sed -n 's/^> \(case .*\)$/\1/p' > poly64-dex.txt
(cd $DEX && stack exec dex -- --lib-path lib script $OLDPWD/dex/det.dx) | sed -n 's/^> \(case .*\)$/\1/p' > det-dex.txt
cmp poly64-scala.txt poly64-dex.txt && cmp det-haskell.txt det-dex.txt
```

`dex script` echoes the source and prefixes program output with `> `, which
is why the output is filtered.
