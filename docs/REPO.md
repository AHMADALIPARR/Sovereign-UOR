# The repository, file by file

This document describes every file in the repository at commit `67948e5`
(2026-11-15), what it does, how the files depend on each other, how to build
and test them, and what was found when they were checked. Line numbers ("line 12", "lines 15-45", or a bare number in parentheses)
refer to the file named in the enclosing heading or paragraph, in that commit. All numbers were measured on
the build machine (GHC 9.10.1, cabal 3.12.1.0, Scala 3.5.2 on Java 21,
Dex at commit `25e2e389`) or read from GitHub Actions logs. The detailed
claim-by-claim audit was kept in `docs/README-audit.md`, which has since been
deleted; this document summarises it where a file is affected.

## 1. Overview

The repository holds four things:

| Part | Language | Files | State |
|---|---|---|---|
| `src/` | Scala 3 | 4 | Compiles; 8 unit tests pass. |
| `montrepol/` | Haskell | 48 | As committed by the author, plus one added file, the corrected zeta table. Does not compile. |
| `montrepol_checked/` | Haskell | 38 | Corrected copy of `montrepol/`. Builds with `-Werror`, 80 tests pass, gate holds, 10 of 10 mutants caught. |
| `dex/` | Dex, Scala, Haskell | 4 | Dual oracle. 600/600 and 200/200 lines agree in CI. |

Around them: three workflows in `.github/workflows/`, documents in `docs/`,
the AGPL text in `LICENSE`, and `README.md`.

The two original trees share no code. The Scala tree implements polynomials
over Z/2^64 and exposes them through a C ABI. The Haskell tree implements
exact linear algebra, root systems, linear recurrences and some analytic
number theory, with a "claim discipline": every claim is registered in TOML
files, tied to a test by an ID, and checked by a gate program. The Dex
programs re-implement one computation from each tree and are compared line
by line with them.

Nothing in the original files was edited. Corrections live beside the
originals: the Haskell tree as `montrepol_checked/`, the zeta oracle as
`montrepol/oracles/zeta-zeros-odlyzko_checked.txt`. The old README
(`docs/README-original.md`) and the old workflows (`docs/workflows-original/`)
were kept too, and have since been deleted.

## 2. Root files

**`README.md`** (103 lines). The overview: what each tree is, the measured
state, the layout, build commands, the document index (including the per-file
document listed in section 9) and the license line. It replaced the original
README, whose verbatim copy in `docs/README-original.md` has since been deleted.

**`LICENSE`** (661 lines). The GNU Affero General Public License version 3,
fetched from gnu.org. It is byte-identical to `montrepol/LICENSE` and ends
with the "How to Apply These Terms" section. The license line in the README
reads "AGPL-3.0-only OR LicenseRef-SnapKitty-Opaque-1.0".

**`.gitignore`** (28 lines). Ignores build output for the Scala side
(`build/`, `target/`, class and jar files, shared libraries, `libuor.*`,
`graal_isolate*`, `*.h`; lines 1-11), editor and OS files (lines 13-17), Metals/Bloop/BSP
directories (lines 19-24) and `.scala-build/` (line 27). `.bsp/` appears
twice (lines 22 and 28), which is harmless. Haskell build output is ignored
by `montrepol/.gitignore` and `montrepol_checked/.gitignore` instead.

## 3. The Scala tree (`src/`)

### 3.1 `src/main/scala/uor/kernel/Poly64.scala` (185 lines)

The core type: `final case class Poly64 private (numVars, exps, coeffs)`
(line 11), a polynomial in `numVars` variables with coefficients in Z/2^64,
stored sparsely as parallel arrays of exponent vectors and `Long`
coefficients, sorted lexicographically by exponent vector with no zero
coefficients (doc comment, lines 8-10). Because the JVM's `Long` arithmetic
wraps modulo 2^64, the bit pattern of every `+` and `*` result is the residue
modulo 2^64; the code relies on this at lines 33 and 67.

Members:

- `+` (lines 15-45): merge of two sorted term lists. Equal monomials are
  added and dropped if the sum is 0 mod 2^64 (lines 32-38). Builds the result
  with the private constructor, so it relies on both inputs being canonical.
  Cost `O((m+n)k)`.
- `*` (lines 48-71): every pairwise product of terms (exponents added,
  coefficients multiplied), then `fromRaw` to sort and merge. With
  `booleanQuota = true` every summed exponent above 1 is clamped to 1
  (line 64), which computes the product in the multilinear quotient
  `x_i^2 = x_i`. The raw term count `termCount * other.termCount` is an `Int`
  (line 50) and overflows past 2^31 − 1.
- `eval` (lines 74-91): sum over terms of coefficient times powers, each power
  by square-and-multiply (lines 82-87), all wrapping; returns `U64`.
  Exponents ≤ 0 act as 0 because of the `while e > 0` loop.
- `toFlatU64` (lines 94-106): flat array, `numVars + 1` longs per term,
  exponents zero-extended from 32 bits (line 102).
- `digestBytes` (lines 109-121): SHA-256 of a big-endian message: tag byte
  `0x04`, `numVars`, `termCount`, then per term each exponent as 32 bits and
  the coefficient as 64 bits (lines 110-120).
- `urn` (lines 123-133): `urn:uor:poly64:` plus the digest in hex.
- `Poly64.zero` (lines 136-137), `Poly64.fromRaw` (lines 140-166: sort an
  index array with `compareUnsigned`, skip zeros, merge equal monomials,
  remove a term whose merged coefficient becomes 0, copy exponent vectors
  defensively), `Poly64.fromFlatU64` (lines 169-185: decode the flat
  layout with `.toInt` narrowing, then `fromRaw`).

Measured behaviour (details and the probe program in
`docs/files/src/main/scala/uor/kernel/Poly64.scala.md`):

- The README example `x_0 + (2^64−1)x_0 + 7x_1^2` canonicalises to `7x_1^2`,
  whose digest is `02a9fb47034782411ec4ce49acee55fa5ab5092da46d928d48adbed5bccb7d49`.
- `==` on two equal polynomials is `false`, even `Poly64.zero(2) ==
  Poly64.zero(2)`, because a case class compares array fields by reference.
- `fromRaw` accepts exponent vectors of the wrong length and negative
  exponents; a polynomial built from a length-1 vector with `numVars = 2`
  makes `digestBytes` throw `ArrayIndexOutOfBoundsException`.
- A flat exponent of 2^31 decodes to −2^31; trailing values that do not fill a
  term are dropped.
- Multiplying two 3-variable polynomials of 938 terms each took about 351 ms
  and gave 55,003 terms; adding them took about 41 µs.

The file compiles without warnings. It contains no placeholders and is
complete.

### 3.2 `src/main/scala/uor/kernel/U64.scala` (8 lines)

`final case class U64(value: Long) extends AnyVal` (line 5), a value class
whose `toString` prints the unsigned decimal value via
`java.lang.Long.toUnsignedString` when the bit pattern is negative (lines 6-8). It is the
return type of `Poly64.eval`. Nothing else.

### 3.3 `src/main/scala/uor/ffi/UorExports.scala` (111 lines)

GraalVM native-image entry points, each a `@scala.annotation.static` method
with `@CEntryPoint(name = ...)` and an `IsolateThread` first argument:

| Symbol | Line | Arguments | Effect |
|---|---|---|---|
| `uor_d64_transform_inplace` | 18 | `data, len, shift, flip` | `data[i] = (flip ? ~data[i] : data[i]) + shift`, in place (lines 27-37) |
| `uor_strata_histogram` | 40 | `data, len, outCounts65` | zeroes 65 counters, then counts `Long.bitCount` of each word (lines 47-56) |
| `uor_d64_digest` | 60 | `shift, flip, outDigest32` | SHA-256 of `0x03, shift (8 bytes), flip (1 byte)` (lines 66-75) |
| `uor_poly64_canonicalize` | 82 | `numVars, termCount, flatTermsInOut, outDigest32` | decodes, canonicalises, writes the canonical terms back into the same buffer and the digest, returns the new term count (lines 90-110) |

The transform computes an element of the dihedral group of order 2^65 acting
on Z/2^64 (a reflection `x ↦ ~x = −1 − x` optionally followed by a
translation). `len` is narrowed with `.toInt` (lines 28 and 50), so buffers
of 2^31 words or more are not handled. The original README listed three
exports with different argument names (`stride`, `direction`); there are four
(see the audit, section 2). The file is compiled only in the non-blocking
`native-image` job of `ci.yml`, which succeeded in CI run 52; no test calls
these functions.

### 3.4 `src/test/scala/uor/kernel/Poly64Test.scala` (83 lines)

Eight munit tests (`//> using dep org.scalameta::munit::1.0.0`, line 2):
zero polynomial (9-12), addition merging and cancelling (14-26), wrapping
cancellation `1 + (2^64 − 1)` (28-33), flat round trip (35-43),
`booleanQuota` (45-53; `sqB` at line 48 is computed and never used), the
README example (55-64), digest length and URN format (66-74), and `3 + 5x`
at 2 equals 13 (76-82). No test multiplies two multi-term polynomials, pins
a digest value or checks `==`. The Dex oracle covers multi-term products and
evaluation (section 6). All eight pass in CI (job "Scala Compile & Test").

## 4. The original Haskell tree (`montrepol/`)

### 4.1 Layout and project files

`montrepol/cabal.project` (25 lines) lists six packages (lines 7-13), pins
`with-compiler: ghc-9.10.1` (line 15), disables every package repository with
`active-repositories: :none` (line 20), enables tests (line 22) and sets
`-Wall -Wcompat -Wincomplete-uni-patterns -Wincomplete-record-updates
-Wredundant-constraints -Werror` for every package (lines 24-25). Even with
no repository, cabal 3.12 still needs a package index file, so `cabal update`
must be run once before the first build; the original `honesty.yml` did not
do this.

The six `.cabal` files all declare `version: 0.1.0.0` (line 3) and depend on
`base >=4.20 && <4.21` plus boot packages:

| Package | Library depends on | Test suite depends on | Problem |
|---|---|---|---|
| `mp-check` (20 lines) | base | base, mp-check | none |
| `mp-linalg` (21 lines) | base, array | base, mp-check, mp-linalg | none in the cabal file |
| `mp-lie` (19 lines) | base, containers | + mp-check, mp-lie, mp-linalg | library imports `MP.Algebra` and `MP.Matrix` (`RootSystem.hs:17-18`) without `mp-linalg` in its `build-depends` (`mp-lie.cabal:11`) |
| `mp-seq` (19 lines) | base, mp-linalg | + mp-check, mp-seq | none |
| `mp-analytic` (28 lines) | base, array | + mp-check, mp-analytic; an executable depends on base and mp-analytic | library imports `MP.Algebra` (`Bernoulli.hs:8`, `Primes.hs:10`) without `mp-linalg` |
| `mp-gate` (30 lines) | base | executable adds directory, filepath, process | none in the cabal file |

`montrepol/.devcontainer/devcontainer.json` (13 lines, since deleted) used the
`haskell:9.10.1` image and ran `cabal update || true` after creation.
`montrepol/.gitignore` (11 lines) ignores `dist-newstyle/` and similar.

### 4.2 Documents inside the tree

- `montrepol/README.md` (49 lines). Claims "171 checks across 6 packages"
  (line 12), "13 planted defects" (line 14) and "all 39 conformance IDs"
  (line 28). The repository has 51 tagged test lines in the original tests,
  10 mutants, and 34 IDs (plus 3 ledger entries); no run produces 171 because
  nothing compiles. The packages table (lines 19-26) describes "matrices with dimensions in the
  type" (line 22), which `Matrix.hs` does not have, and names Floyd–Warshall
  and OEIS as oracles (lines 22 and 25), which no test uses.
- `montrepol/AGENTS.md` (30 lines, since deleted). Defined rules R1-R6 (lines
  14-21) and the change procedure (lines 25-28).
- `montrepol/VERIFICATION.md` (14 lines). How each rule is enforced (lines
  5-12) and what the honesty workflow does (line 14). R1 there says the gate
  "fails if the committed file differs"; the original `Rules.hs` never reads
  `CONFORMANCE.md`.
- `montrepol/CONFORMANCE.md` (77 lines). The rendered register: 34 ID rows
  under six package headings and 3 ledger rows (lines 69-77). Several rows
  claim more than the original tests check (AN-04 s = 2..8, AN-05 200 random
  t to 1e-9, AN-06 512 zeros to 1e-8, LA-02/03/04 shapes and rings).
- `montrepol/NOTICE` (21 lines), `montrepol/LICENSE` (661 lines, AGPL v3 text),
  `montrepol/LICENSES/UOR-template-Apache-2.0.txt` (176 lines) and
  `UOR-template-MIT.txt` (21 lines): copyright and template notices, kept as
  they are.

### 4.3 The model (`montrepol/model/`)

- `ids.toml` (263 lines): 34 `[[id]]` tables, each with `id`, `package`,
  `level`, `claim`, `oracle` and optionally `authorities`. Prefixes: CK-01..04,
  LA-01..07, LI-01..04, SQ-01..05, AN-01..06, GT-00..07. CK-04 cites
  `steele-2014` (line 41), which `authorities.toml` does not define. Every
  ID is at level `build`.
- `authorities.toml` (51 lines): 8 `[[authority]]` entries (lines 5-51):
  Bourbaki 1968, Humphreys 1972, Massey 1969, Edwards 1974, Odlyzko 1987,
  Strassen 1969, Bareiss 1968, von Staudt–Clausen 1840. Seven agree in
  author, title and year with the well-known published work; the Odlyzko
  entry could not be confirmed because his site was unreachable.
- `ledger.toml` (22 lines): 3 untested claims (Strassen exponent, completeness
  of the zero table up to 826.91, explicit-formula truncation error).
- `mutants.toml` (83 lines): 10 mutants. The original text of 5 of them
  (Weyl orbit, root closure, gate R5 list, gate R3, harness) does not occur in
  the files they name.

### 4.4 The oracle (`montrepol/oracles/zeta-zeros-odlyzko.txt`, 520 lines)

An 8-line header naming Odlyzko's `zeros1` as source (lines 4-6), then 512
rows `index gamma`. Compared with LMFDB rounded to 10 decimals, 426 rows are
wrong: 7 in the last digit, 22 by 1e-10 to 1e-6, 397 by 1e-6 or more. Every
row from 130 to 507 is wrong; rows 188 to 507 (320 rows) end in one of
`8765432109`, `2345678901`, `9876543210`, `1234567891`; rows 135 and 136 are
both `295.8131297355`; 22 values exceed 826.91 (the maximum is
858.1234567891 at row 507) and the sequence decreases at rows 136 and 508.
Rows 1-38, 508-512 and 43 scattered rows agree with LMFDB. Verdict: fabricated in large part.

`montrepol/oracles/zeta-zeros-odlyzko_checked.txt` (519 lines, 7-line header)
holds the 512 values from https://www.lmfdb.org/zeros/zeta/list?N=1&limit=600,
rounded exactly to 10 decimals with rational arithmetic. Its header states
the source and that Odlyzko's own table could not be reached.

### 4.5 `mp-check`: the test harness (identical in both trees)

`MP/Check/Random.hs` (76 lines) is SplitMix64 (Steele, Lea and Flood, 2014):

- `Seed` (line 19) holds the state and an odd gamma.
- `goldenGamma = 0x9e3779b97f4a7c15` (lines 22-23); `mkSeed` (line 25) starts
  a stream with it.
- `mix64` (lines 28-32) is the MurmurHash3 finaliser (shifts of 33,
  multipliers `0xff51afd7ed558ccd`, `0xc4ceb9fe1a85ec53`), used for gammas.
- `mix64variant13` (lines 34-38) is the output function: shifts 30, 27, 31,
  multipliers `0xbf58476d1ce4e5b9` and `0x94d049bb133111eb`.
- `mixGamma` (lines 42-46) forces a new gamma to be odd and, if it has fewer
  than 24 bit transitions, flips it with `0xaaaaaaaaaaaaaaaa`, as in the paper.
- `nextWord64` (line 48) adds gamma to the state and mixes; `splitSeed`
  (line 51) derives two independent streams; `boundedBelow` (line 60) draws a
  bounded integer.

`MP/Check.hs` (206 lines):

- Generators: `newtype Gen a = Gen (Seed -> (a, Seed))` (line 54) with
  Functor, Applicative and Monad instances (lines 59-67); `integerIn` (69),
  `intIn` (74), `boolG` (77), `elements` (82), `listOfLength` (91),
  `listUpTo` (94), `rationalIn` (98).
- Results: `newtype Result = Result [String]` (line 108), a monoid of failure
  messages (lines 110-112); `pass` (114), `failWith` (117), `assert` (120),
  `.&&.` (128), `===` (131), `=/=` (134), `allOf` (137).
- Tests: `unit` (151), `unitIO` (154), `prop` (158-159, 200 cases), `propN`
  (161) with an explicit count.
- Running: `runSuite` (line 178) takes an optional `--seed N`, default
  `0x5eed` (line 184), prints a pass count or `FAIL [ID]` lines, and exits
  non-zero on failure; `checkProperty` (line 197) runs one property for a
  given number of cases and seed.
- There is no shrinking (comment at line 7).

`test/Main.hs` (33 lines), 5 tests: CK-01 `integerIn` stays inside its
interval (line 14); CK-02 the runner reports a property that fails on one
value in ten (16) and accepts a true one (18); CK-03 `integerIn` reaches every
value of a small range (20); CK-04 the first three outputs for seed 0 are
`0xe220a8397b1dcdaf, 0x6e789e6aa1b965f4, 0x06c45d188009454f` (lines 22-25).
An independent C SplitMix64 written for the audit prints the same three
values, so CK-04 is a check against the reference algorithm. `mp-check` is the
only package of the original tree that compiles.

### 4.6 `mp-linalg` in the original tree

- `MP/Algebra.hs` (110 lines): classes `Semiring` (line 19), `Ring` (25),
  `Field` (30); instances for `Integer` (46), `Rational` (55), `GF2` (75) and
  `MinPlus` (95). `isZero x = x == zero` (lines 34-35) has only a `Semiring`
  constraint, so it needs `Eq` it does not ask for. Line 107 declares
  `instance Eq a => Eq (Maybe a)`, which duplicates the instance in `base` and
  is a compile error.
- `MP/Matrix.hs` (188 lines): `data Matrix a = Matrix Int Int (Array ...)`
  (line 28). The comment at lines 25-27 says the dimensions are phantom
  types; they are run-time `Int`s. `mul` (lines 58-66) is the definition.
  `strassen` (lines 69-100) applies `.+.` and `.-.` to whole matrices
  (lines 87-97), but those are scalar operations, and its `Semiring`
  constraint has no subtraction. `bareiss` (lines 110-123) swaps rows
  (line 119) without negating the result. `eliminate` divides with `recipF`
  (line 144), which a `Ring` does not have. `rank` (lines 149-161) stops at
  the first column with no pivot (line 156), so a matrix whose first column is
  zero has rank 0. `inverse` (lines 164-183) builds the augmented matrix with
  `!!` (line 169).
- `MP/Participation.hs` (19 lines): `participation p = 1 / Σ p_i²`, 0 for an
  empty list or a zero sum (lines 15-19), the inverse participation ratio. It
  is identical in both trees.
- `test/Main.hs` (103 lines): 15 tagged tests at lines 12-26. LA-03 uses only
  cutoff 2 (`strassen 2 a b`, line 69). LA-05 passes when `inverse` returns
  `Nothing` (line 92). LA-06 compares the rank with the nonzero rows of the
  matrix itself (`echelon = id`, line 98). Line 26 uses `%` without importing
  `Data.Ratio` (imports at lines 3-6), and `===` on matrices needs a `Show`
  instance that does not exist.

### 4.7 `mp-lie` in the original tree

`MP/RootSystem.hs` (79 lines): a system is its list of simple roots
(line 22). `roots` (lines 30-37) closes the set under reflection in every
root. `cartan` (lines 48-49) divides by `(a_i, a_i)`. The E8 "simple roots"
(lines 69-77) are seven vectors `e_i − e_{i+1}` and `[-1,-1,0,...]`; they are
all integral, so they lie in the D8 lattice and cannot generate the 240 E8
roots, half of which have half-integer coordinates. `weylOrder`
(lines 52-59) counts the distinct images of the fixed vector `[1..8]` under
one reflection in each root, which is not a group orbit: for A2 the three
reflections give `(2,1,3)`, `(1,3,2)` and `(3,2,1)`, so it returns 3 where the
test (line 21) expects 6. `test/Main.hs` (49 lines): 9 tests at lines 14-22;
LI-02's `generates` (lines 36-41) checks only that the simple roots are among
the roots, which holds by construction.

### 4.8 `mp-seq` in the original tree

`MP/Recurrence.hs` (87 lines): Berlekamp–Massey over any field (line 26),
`generates` (line 60), `runLFSR` (line 68) and `period` (line 80). The
algorithm is right; the corrected copy only adds `Eq` constraints that the
corrected `isZero` requires. `test/Main.hs` (63 lines), 8 tests:
regeneration over GF(2) and Q (lines 11-12), minimality by brute force over
GF(2) (line 13), recovery of a length-l LFSR from 2l terms (line 14), period
31 for x^5+x^2+1 and period 6 for x^4+x^2+1 (lines 15-21), Fibonacci's
connection polynomial 1 − x − x² (line 22) and the zero sequence (line 24).

### 4.9 `mp-analytic` in the original tree

- `MP/Bernoulli.hs` (24 lines): the recurrence sums `C(m,k)·B_k` (line 18)
  instead of `C(m+1,k)·B_k`. For m = 2 that is `1 + 2·(−1/2) = 0`, so B2 = 0.
  Every call recomputes all earlier numbers recursively.
- `MP/Primes.hs` (53 lines): `vonMangoldt` returns `floor (log p)` with the
  comment "placeholder" (line 33); `vonMangoldtExact` (lines 38-45) is used by
  the test but missing from the export list (lines 2-7); `psi` (line 53) sums
  the primes p rather than log p.
- `MP/Zeta.hs` (41 lines): Euler–Maclaurin adds `half = ½N^−s` (lines 22-24)
  where it must subtract; the Bernoulli term uses `N^(2−s−2k)` (line 30)
  where the formula has `N^(1−s−2k)`; `theta` (line 34) stops at
  `t/2·log(t/2π) − t/2 − π/8`; `hardyZ` (lines 38-41) ignores `t` and calls
  `zeta 20 0.5` ("placeholder", line 40), which `zeta` rejects with `error`
  because s ≤ 1 (line 18).
- `MP/ExplicitFormula.hs` (16 lines): uses three hard-coded zeros
  `[14.13, 21.02, 25.01]` ("placeholder", line 14) and only the cosine part of
  each term (line 15).
- `app/Main.hs` (14 lines): prints B0..B10, the primes up to 50 and
  `zeta 40 2`.
- `test/Main.hs` (24 lines), 6 tests at lines 13-18: AN-01 sieve on [2, 200];
  AN-02 `vonMangoldtExact 8 == Just 2`; AN-03 B2 and B4; AN-04 ζ(2) to 1e-6;
  AN-05 one sample, `hardyZ 14.13`. There is no AN-06 test.

### 4.10 `mp-gate` in the original tree

- `MP/Gate/Toml.hs` (91 lines): a TOML subset reader; `parseTable` (47-55);
  line 50 is a name-shadowing error under `-Werror`; it accepts a lone `[`.
- `MP/Gate/Model.hs` (103 lines): records and parsers for the four TOML
  files.
- `MP/Gate/Scan.hs` (57 lines): `tagOf` (lines 18-24) sees a tag only on a
  line that starts with `prop`, `unit` or `propN`, so it misses every test
  written as a list element (`[ prop ...`, `, prop ...`), which is all of
  them. Line 16 shadows `id`, line 22 uses `head` and `last`, lines 27 and 35
  default types; all are errors under `-Werror`. `isInfixOf` is used at
  lines 30 and 38 but only `isPrefixOf` is imported (line 11). The partial
  names it rejects are listed at line 40.
- `MP/Gate/Rules.hs` (104 lines): `r1`..`r6` at lines 65, 71, 80, 88, 91, 97.
  `r1` never reads `CONFORMANCE.md`; `r5` requires `-Werror` in every `.cabal`
  file (line 94), but the flag is set in `cabal.project`.
- `MP/Gate/Render.hs` (43 lines): renders the model as Markdown.
- `app/Main.hs` (97 lines): commands `check` (default), `write`, `mutants`;
  `main` (20), `write` (33), `check` (42), `loadRepo` (53). Identical in both
  trees.
- `app/Mutants.hs` (66 lines): uses `docArrays` (line 25), `lookupStrings`
  (35) and `lookupString` (36), none of which is defined.
- `test/Main.hs` (57 lines): GT-00..GT-07; line 50 writes
  `SourceFile "x.hs" "x = 1 -- " <> "TODO" True`, which parses as applying the
  string `"TODO"` to `True`.

`cabal build all --keep-going` on the original tree fails in `mp-linalg`,
`mp-lie`, `mp-analytic` and `mp-gate`. Running the corrected gate's rules over
the original tree reports 17 violations: R2 for `steele-2014`, R3 for the
untested `AN-06`, and 15 R5 uses of partial functions (listed in
section 3 of `README-audit.md`, since deleted).

## 5. The corrected Haskell tree (`montrepol_checked/`)

Same layout and package names. Unchanged copies: `.gitignore`,
`cabal.project`, the `.cabal` files of every package except `mp-lie`, the
whole of `mp-check`, `Participation.hs` and the gate's `app/Main.hs`.
`mp-seq` differs only by `Eq` constraints. Everything else was rewritten or
edited. Build and test with

    cd montrepol_checked
    cabal update && cabal build all && cabal test all
    cabal run mp-gate && cabal run mp-gate -- mutants

Result locally and in CI: no warnings; 80 tests pass (mp-check 5, mp-linalg
19, mp-lie 13, mp-seq 8, mp-analytic 12, mp-gate 23); "mp-gate: R1-R6 hold
over 6 packages"; "10 of 10 mutants caught".

### 5.1 `mp-linalg`

- `MP/Algebra.hs` (124 lines): `Semiring` (line 18), fixities `infixl 6 .+.`,
  `infixl 7 .*.`, `infixl 6 .-.` (lines 24-26), `Ring` (28), `Field` (33),
  and a new class `ExactDivision` (39) for the exact division Bareiss needs:
  `quot` for `Integer` (66-67), `/` for `Rational` (81-82), and the identity
  for `GF2` (106-107), where the only nonzero divisor is 1. Division by zero
  returns zero, so every operation is total. `isZero` now requires `Eq`
  (line 43). The duplicate `Eq (Maybe a)` instance is gone.
- `MP/Matrix.hs` (201 lines): dimensions are run-time values, and a matrix is
  zero outside its shape (comment at lines 8-11). `Eq` and `Show` instances
  (lines 35, 38); `entry` (46); `generate` (52); `fromLists` pads short rows
  (59-64); `toLists` (66); `identity` (71); `addM` (74); `subM` (77); `mul`
  (81); `strassen` over `Ring` (88-91), which falls back to `mul` when any
  dimension is below the cutoff or the cutoff is below 2, and otherwise splits
  into zero-padded quadrants (`strassen'`, from line 94; products m1..m7 at
  lines 101-107); `det` by Bareiss with a sign flip per row swap and division
  by the previous pivot (124, comment at 121-123); `findPivot` (141);
  `swapRows` (147); `eliminate` (154); `echelon` (163), which skips columns
  without a pivot; `rank` as the nonzero rows of the echelon form (177);
  Gauss–Jordan `inverse` (182).
- `test/Main.hs` (161 lines), 19 tests at lines 13-32: semiring axioms for
  four types (13-16); associativity, distributivity over same-shape pairs and
  the identity (17-19); Strassen against `mul` for cutoffs 2-5 over Integer,
  Rational and GF2 (20-22); Bareiss against the Leibniz expansion over Integer
  and GF2 for n up to 6, and the pivot-swap matrix with determinant −1
  (23-25); inverse round trip and a singular matrix (26-27); rank against the
  order of the largest nonzero minor, and a matrix with a zero first column
  whose rank is 2 (28-30); participation bounds and the uniform vector
  (31-32).

### 5.2 `mp-lie`

`mp-lie.cabal` adds `mp-linalg` to the library's `build-depends`.
`MP/RootSystem.hs` (119 lines; method in the comment at lines 1-10):
`reflect` (40) returns its argument unchanged for a zero root; `roots` (51)
closes the simple roots under the simple reflections; `cartan` (63-64) and
`cartanEntry` (66-67) give entry (i, j) = 2(a_i, a_j)/(a_j, a_j), Humphreys'
convention (comment at 61-62); `weylOrder` (70) uses orbit–stabilizer,
|W| = |W·w_i| × |W(S \ {i})|, enumerating the orbit of a fundamental weight by
its Dynkin labels (83-85); `system` (100) gives A2, B2, G2 and E8, with E8 in
doubled coordinates so the half-integer roots stay integral (107-108).

`test/Main.hs` (68 lines), 13 tests: root axioms for A2, B2, G2 and E8
(12-15); E8 has 240 roots (16); the simple roots generate A2 and E8 (17-18);
the Cartan matrices of A2, `[[2,-1],[-1,2]]`, and G2, `[[2,-1],[-3,2]]`
(19-22); Weyl orders 6, 8, 12 and 696,729,600 for A2, B2, G2 and E8 (23-26).

### 5.3 `mp-seq`

`MP/Recurrence.hs` (87 lines): `berlekampMassey` (26), `generates` (60),
`runLFSR` (68), `period` (80), with `Eq` constraints added. The test file
(63 lines) adds `Eq a` to `regenerates` (line 33). Same 8 tests as the
original.

### 5.4 `mp-analytic`

- `MP/Bernoulli.hs` (35 lines): a memoised list `bernoullis` (line 14) built
  with `C(m+1,k)` (line 20); `bernoulli` (25) indexes it; `choose` (32).
- `MP/Primes.hs` (52 lines): `primesUpTo` (17) sieves with `accumArray`
  (line 21); `vonMangoldt :: Int -> Maybe Int` (33) returns the prime p when
  n = p^k, so Λ(n) = log p is represented exactly; `psiExp` (48) is
  exp(ψ(x)) as an exact integer; `psi` (51) is its logarithm.
- `MP/Zeta.hs` (89 lines): `zeta` (21) for real s > 1, NaN otherwise
  (comment 19-20); `zetaC` (27) for complex s with N = 20 + ⌈t/π⌉ (line 30);
  `eulerMaclaurin` (35) with the formula in the comment at lines 33-34 and
  `correctionTerms` (44); `theta` (59) by its asymptotic expansion, stated
  accurate to about 1e-12 for t ≥ 10 (57-58); `rotated` (66) is
  e^{iθ(t)}ζ(½+it); `hardyZ` (70) its real part; `zerosUpTo` (75) scans for
  sign changes with step h and bisects each to width eps.
- `MP/ExplicitFormula.hs` (16 lines): `explicitPsi x gammas` (12) takes the
  zero ordinates as an argument and computes
  `x − Σ 2√x(½cos(γ log x) + γ sin(γ log x))/(¼ + γ²) − log 2π − ½log(1 − x⁻²)`
  (lines 9 and 15-16); the summand is 2 Re(x^ρ/ρ) for ρ = ½ + iγ.
- `test/Main.hs` (78 lines), 12 tests: AN-01 sieve against trial division on
  [2, 2000] (17); AN-02 support of Λ on n ≤ 1000, Λ(8) = log 2, and
  exp(ψ(x)) = lcm(1..x) for x ≤ 300 (18-22); AN-03 B2, B4, odd numbers vanish
  up to B61, von Staudt–Clausen denominators for B2..B60 (23-28); AN-04
  ζ(2k) against the closed form for k = 1..4 to 1e-12 (29-30); AN-05 the
  imaginary part of `rotated t` below 1e-9 for t in [10, 800] (31); AN-06 the
  table has 512 rows, and `zerosUpTo 10 827 0.05 1e-11` matches it to 1e-8
  (32-34). The table is read at line 14 from
  `../../../montrepol/oracles/zeta-zeros-odlyzko_checked.txt`.

Measured: the zero finder returns 512 zeros on (10, 827]; the largest
difference from the checked table is 5.3e-11; 408 of them differ from the
original table by 1e-8 or more, the largest by 37.78.

### 5.5 `mp-gate`

- `MP/Gate/Toml.hs` (130 lines): the subset is described at lines 1-4;
  anything else is a parse error. `parseToml` (25) merges repeated
  `[[name]]` sections in order (45); `tablesNamed` (54), `lookupString` (58),
  `lookupStrings` (63); string escapes in `parseString` (92); comments outside
  strings removed by `stripComment` (118).
- `MP/Gate/Model.hs` (109 lines): `IdRow` (15), `Authority` (25), `Mutant`
  (31), `LedgerEntry` (41), `Model` (50); `loadModel` (63); one parser per
  file (71, 81, 88, 98).
- `MP/Gate/Scan.hs` (122 lines): `tagsIn` (20) takes the first string literal
  after `unit`, `unitIO`, `prop` or `propN` used as a function, wherever it is
  on the line; `deferrals` (39) and `partials` (46) match whole words on code
  with comments and string literals blanked (`blankComments` 78, `codeOnly`
  102), so primed names do not match. The marker and partial-name lists
  (lines 42 and 49) are assembled from halves so the scanner does not flag
  its own file (comment at 4-5).
- `MP/Gate/Rules.hs` (155 lines): `checkRepo` (47); R1 (61): unique,
  well-formed IDs naming real packages, and the committed `CONFORMANCE.md`
  equal to the rendering; R2 (75): levels are load-bearing; R3 (90): every ID
  tagged in its own package, every tag registered; R4 (98): no deferral
  markers; R5 (102): no partial functions, and `-Werror` in `cabal.project`
  or every `.cabal` file; R6 (110): only boot packages (`bootPackages`, 134)
  with both bounds, every package listed, no package repository.
- `MP/Gate/Render.hs` (46 lines): `renderConformance` (11).
- `app/Mutants.hs` (55 lines): `runMutants` (13) prints "N of M mutants
  caught" (21); `runOne` (24) reports `STALE` unless the planted text occurs
  exactly once (30), applies it with `replaceOnce` (43), runs the named test
  suite, and counts the mutant as caught only if the suite exits non-zero and
  prints `FAIL [ID]` for every expected ID (38-39); the file is restored
  afterwards.
- `test/Main.hs` (91 lines), 23 tests GT-00..GT-07 at lines 20-47, including
  near-misses: markers inside strings and comments, primed names. Test
  fixtures contain the strings `"CK-01"` and `"CK-02"`, which are data, not
  tags.

### 5.6 Model and conformance

- `model/ids.toml` (263 lines): the same 34 IDs, claims narrowed to what the
  tests check (section 5.7).
- `model/authorities.toml` (63 lines): adds `steele-2014` (line 36) and
  `lmfdb-zeros` (42) to the original eight.
- `model/ledger.toml` (22 lines): the zero-table entry's evidence (line 15)
  names the `_checked` file and says the original does not match published
  values.
- `model/mutants.toml` (84 lines): 10 mutants (section 5.8).
- `CONFORMANCE.md` (77 lines): regenerated by `cabal run mp-gate -- write`;
  R1 fails if it differs from the model.

### 5.7 The conformance register, ID by ID

Claims from `montrepol_checked/model/ids.toml`, shortened; test lines are in
`montrepol_checked/packages/<package>/test/Main.hs`. All IDs are at level
`build`.

| ID | Claim | Test lines |
|---|---|---|
| CK-01 | `integerIn lo hi` stays in [lo, hi] | 14 |
| CK-02 | the runner reports a property false on one value in ten, accepts a true one | 16, 18 |
| CK-03 | `integerIn` reaches every value of a small range | 20 |
| CK-04 | the stream matches published SplitMix64 | 22 |
| LA-01 | Integer, Rational, GF2, MinPlus are semirings | 13-16 |
| LA-02 | product associative, distributive, identity is a unit | 17-19 |
| LA-03 | Strassen equals the definition, cutoffs 2-5, three rings | 20-22 |
| LA-04 | Bareiss equals Leibniz over Integer and GF2 | 23-25 |
| LA-05 | inverse multiplies back; singular has none | 26-27 |
| LA-06 | rank equals nonzero rows of the echelon form | 28-29 |
| LA-07 | participation ratio in [1, n]; uniform gives n | 31-32 |
| LI-01 | A2, B2, G2, E8 satisfy the root axioms | 12-16 |
| LI-02 | simple roots generate the system | 17-18 |
| LI-03 | Cartan matrices have the published entries | 19, 21 |
| LI-04 | Weyl orders equal the published orders | 23-26 |
| SQ-01 | Berlekamp–Massey's polynomial regenerates the sequence | 11-12 |
| SQ-02 | its length is minimal | 13 |
| SQ-03 | a length-l LFSR is recovered from 2l terms | 14 |
| SQ-04 | primitive polynomials have maximal period, others not | 15, 19 |
| SQ-05 | Fibonacci's connection polynomial; zero sequence has complexity 0 | 22, 24 |
| AN-01 | the sieve gives the primes | 17 |
| AN-02 | von Mangoldt and ψ match their definitions | 18, 20, 21 |
| AN-03 | Bernoulli numbers: closed forms, von Staudt–Clausen | 23-27 |
| AN-04 | ζ by Euler–Maclaurin matches the closed forms | 29 |
| AN-05 | e^{iθ(t)}ζ(½+it) is real to 1e-9 on [10, 800] | 31 |
| AN-06 | the zeros on (10, 827] are the 512 tabulated, to 1e-8 | 32-33 |
| GT-00 | a clean repository has no violations | 20 |
| GT-01 | R1 fires on an edited register, duplicate ID, bad model | 21-23 |
| GT-02 | R2 fires on open IDs, asserting words, missing or unknown authorities | 24-27 |
| GT-03 | R3 fires on untested IDs and unregistered tags | 28-29 |
| GT-04 | R4 fires on markers, not in comments or strings | 30-32 |
| GT-05 | R5 fires on partial functions and operators and missing `-Werror` | 34-37 |
| GT-06 | R6 fires on outside dependencies, missing bounds, unlisted packages, repositories | 39-42 |
| GT-07 | the TOML reader parses the subset and rejects the rest | 44, 47 |

### 5.8 The mutants

From `montrepol_checked/model/mutants.toml`; each must make the named test
fail. CI honesty run 32 printed `CAUGHT` for all ten.

| Line | Mutant | File | Expected failure |
|---|---|---|---|
| 7 | Weyl order: orbit sizes added instead of multiplied | `mp-lie/src/MP/RootSystem.hs` | LI-04 |
| 15 | Root closure stops after the simple roots | `mp-lie/src/MP/RootSystem.hs` | LI-01 |
| 23 | Berlekamp–Massey length update off by one | `mp-seq/src/MP/Recurrence.hs` | SQ-01, SQ-02 |
| 31 | Sieve crosses off with stride 2i | `mp-analytic/src/MP/Primes.hs` | AN-01 |
| 39 | Euler–Maclaurin: sign of the N^−s/2 term flipped | `mp-analytic/src/MP/Zeta.hs` | AN-04 |
| 47 | theta: −π/8 dropped | `mp-analytic/src/MP/Zeta.hs` | AN-05 |
| 55 | Bernoulli: C(m, k) instead of C(m+1, k) | `mp-analytic/src/MP/Bernoulli.hs` | AN-03 |
| 63 | Gate: R5 partial-function list emptied | `mp-gate/src/MP/Gate/Scan.hs` | GT-05 |
| 71 | Gate: R3 untested-ID check disabled | `mp-gate/src/MP/Gate/Rules.hs` | GT-03 |
| 79 | Harness: property runner stops after case 0 | `mp-check/src/MP/Check.hs` | CK-02 |

Two of these, the Euler–Maclaurin sign and the Bernoulli binomial, plant
back defects that the original code actually had (section 4.9). A transposed-Cartan mutant was tried and dropped
because it is equivalent: transposing the Cartan matrix does not change the
Weyl order.

## 6. The Dex dual oracle (`dex/`)

[Dex](https://github.com/google-research/dex-lang) is Google Research's
typed functional array language, compiled through LLVM. Each check has a
repository side and a Dex side; both draw the same inputs from SplitMix64
with seed `0x5eed`, written separately in each language, and print one line
per result. CI requires identical output. Full notes: `docs/dex-oracle.md`.

**`dex/scala/Poly64Vectors.scala`** (49 lines). Repository side for Poly64.
Its own SplitMix64 (lines 12-18); `small(k)` uses
`Long.remainderUnsigned` (line 19). `randomPoly` (lines 21-31): `1 + w mod 4`
terms, exponents `w mod 4` in each of two variables, full 64-bit
coefficients, built with `Poly64.fromRaw`. For each case (default 200,
line 40) it prints `p + q`, `p * q` and `(p * q).eval(x)` at two drawn points
(lines 43-48), terms as `e0,e1:hex` (lines 35-37).

**`dex/poly64.dx`** (113 lines). Dex side for Poly64:

- `w64` (line 17) builds 64-bit constants from two 32-bit halves; this Dex
  version has no hex literals.
- `urem` (lines 19-23) computes an unsigned remainder from 32-bit halves,
  because `rem` on `Word64` is signed here (prose at line 11): `rem` of
  `0xdc336acab085b9ce` by 4 gives `0xfffffffffffffffe`. `urem` agreed with C
  on 15 test values; plain `rem` gave −1, −8 and −33 on the large ones.
- `gamma` (25), `mix` (30), and `draw k = mix(seed + (k+1)·gamma)` (36),
  which gives output number k directly, so no generator state is threaded
  through the arithmetic.
- `hex_digit`, `hex16`, `term`, `terms` (42-54) format terms by hand.
- `poly_at` (70) builds a dense 4×4 coefficient table by summing the drawn
  terms into their cells, which merges repeated monomials; `poly_add` (82);
  `poly_mul` (84), the convolution into a 7×7 table; `power` (90) and
  `poly_eval` (93).
- The driver (from line 97) threads only the draw position through
  `with_state` (line 100).

Measured on the 200 cases: 3,833 draws; among the 400 input polynomials, 1,
2, 3 and 4 drawn terms occur 99, 89, 114 and 98 times; 54 had a repeated
monomial (55 merged terms); sums have 2 to 8 terms; products 1 to 16 terms,
with exponents up to 6 in each variable; no result is zero. Run time 1.8 to
2.1 s over three local runs, including compilation.

**`dex/haskell/BareissVectors.hs`** (50 lines). Repository side for the
determinant: n = 1 + w mod 6 (line 30), n² entries `(w mod 41) − 20`
(lines 36-46) drawn with `MP.Check.Random`, determinant by
`montrepol_checked`'s `MP.Matrix.det` (line 33). Built directly with `ghc`
and include paths into `mp-linalg` and `mp-check` (comment at lines 6-9).

**`dex/det.dx`** (84 lines). Dex side for the determinant: the same
SplitMix64 and `urem`; `mat_at` (45) embeds the n×n matrix in a 6×6 `Int64`
matrix with an identity block (lines 48-56); `leibniz` (62) sums over all
6^6 = 46,656 maps from Fin 6 to Fin 6 (`pow6`, line 58), keeps the bijections
(65) and multiplies each product by the sign from its inversion count
(69-72). Run time 1.26 to 1.36 s over three local runs.

Agreement: 600 of 600 Poly64 lines and 200 of 200 determinants, locally and
in dex-oracle run 5. Matrix sizes 1 to 6 occur 33, 28, 30, 33, 40 and 36
times. Negative controls on temporary copies: forcing every permutation sign
to +1 changes 165 of 200 lines; adding 1 to every product term changes 400
of 600.

## 7. Workflows

**`.github/workflows/ci.yml`** (180 lines), on pushes and pull requests to
`main`:

| Job | Lines | What it does |
|---|---|---|
| `scala-test` | 22-47 | installs scala-cli (32-36), compiles the kernel (38-41), runs `Poly64Test` (43-47) |
| `native-image` | 52-102 | GraalVM `native-image --shared` for `libuor` (79-87); `continue-on-error` (57), and the command ends in `|| echo` (87) |
| `cabal` | 108-135 | in `montrepol_checked` (114); cache key on the project, `.cabal` and `.hs` files (126); `cabal update`, build, test, `mp-gate` (129-135) |
| `cabal-original` | 141-158 | the same in `montrepol/` (148) with `--keep-going` (158); `continue-on-error` (145) |
| `status` | 163-180 | needs `scala-test` and `cabal` (166) and fails unless both succeeded (174-175) |

**`.github/workflows/honesty.yml`** (39 lines): in `montrepol_checked`,
`cabal update`, build, `cabal run mp-gate -- mutants`, then
`git diff --exit-code` to prove every mutant was reverted (lines 35-39).

**`.github/workflows/dex-oracle.yml`** (170 lines): path filters at lines 9
and 17, so it runs only when `dex/`, the workflow, the Scala kernel, or
`montrepol_checked`'s `mp-linalg` or `mp-check` change. Job `vectors`
(line 36) produces the Scala and Haskell outputs and uploads them as
`oracle-vectors` (70). Job `dex` (75) runs in an `ubuntu:22.04` container
(80), where LLVM 12 is still packaged (85-92), with
`STACK_ROOT=/opt/stack-root` because stack refuses a home directory owned by
another user (82-83). It clones dex-lang at the pinned commit (95-97),
compiles `static/index.ts` with TypeScript 4.9.5 (119-120) and the runtime
with clang++-12 (121), builds with stack (123-124), saves a finished build
under a `...-done` key (111, 133) and a failed or cancelled one under a key
with the run id (140), runs both `.dx` files (145-148), and diffs the outputs
(160). The first full build took 10 min 17 s in run 5.

The originals were kept as `docs/workflows-original/ci.yml.txt` (162 lines)
and `honesty.yml.txt` (34 lines), since deleted. The old Cabal job built `montrepol/`
directly, and the old honesty job ran the mutant replay that does not
compile.

## 8. How the parts depend on each other

    Poly64.scala <- U64.scala
    Poly64.scala <- UorExports.scala            (C ABI, native image)
    Poly64.scala <- Poly64Test.scala            (munit)
    Poly64.scala <- dex/scala/Poly64Vectors.scala  ==diff==  dex/poly64.dx

    montrepol_checked:
      mp-check <- (test suites of all packages), BareissVectors.hs
      mp-linalg <- mp-lie, mp-seq, BareissVectors.hs  ==diff==  dex/det.dx
      (the corrected mp-analytic no longer imports MP.Algebra, so the
       unchanged mp-analytic.cabal is now complete)
      mp-analytic test -> montrepol/oracles/zeta-zeros-odlyzko_checked.txt
      mp-gate -> model/*.toml, packages/*, cabal.project, CONFORMANCE.md

The original `montrepol/` is built only by the informational CI job. Nothing
outside it reads `montrepol/oracles/zeta-zeros-odlyzko.txt`.

## 9. Documents in `docs/`

| File | Lines | Content |
|---|---|---|
| `dex-oracle.md` | 113 | The Dex oracle: what is compared, measured agreement, Dex quirks, build and run commands |
| `REPO.md` | — | This document |
| `files/src/main/scala/uor/kernel/Poly64.scala.md` | 926 | Detailed walkthrough of `Poly64.scala` (7,527 words), written before the per-file plan was dropped |

## 10. Build, run and test commands

    # Scala
    scala-cli test --scala 3.5.2 src/main/scala/uor/kernel src/test/scala/uor/kernel/Poly64Test.scala

    # Haskell, corrected tree
    cd montrepol_checked && cabal update && cabal build all && cabal test all
    cabal run mp-gate && cabal run mp-gate -- mutants

    # Dex oracle vectors (repository side)
    scala-cli run --server=false --scala 3.5.2 src/main/scala/uor/kernel dex/scala/Poly64Vectors.scala -- 200
    ghc -O0 -outputdir /tmp/bv -o /tmp/bv/bareiss-vectors \
      -imontrepol_checked/packages/mp-linalg/src -imontrepol_checked/packages/mp-check/src \
      dex/haskell/BareissVectors.hs && /tmp/bv/bareiss-vectors 200

    # Dex side, from a built dex-lang checkout (see docs/dex-oracle.md)
    stack exec dex -- --lib-path lib script dex/poly64.dx | sed -n 's/^> \(case .*\)$/\1/p'

## 11. Open gaps

- `montrepol/` itself still does not compile; the fixes exist only in
  `montrepol_checked/`.
- `Poly64` equality is by reference, its arrays are public and mutable, and
  `fromRaw` does not validate its input.
- Nothing tests `UorExports.scala` beyond building the native image.
- The Dex oracle covers two-variable Poly64 add/mul/eval and determinants up
  to 6×6; it does not cover `booleanQuota`, digests, the flat encoding, or
  any of `mp-lie`, `mp-seq` or `mp-analytic`.
- Odlyzko's own table and the Odlyzko authority entry remain unverified
  because his site could not be reached.

## Appendix: every file

All 106 files at commit `67948e5`, with line counts (`wc -l`) and the
section of this document that describes them. In `montrepol_checked/`, a
file marked "same" is byte-identical to its counterpart in `montrepol/`.

| File | Lines | Section |
|---|---|---|
| `.github/workflows/ci.yml` | 180 | 7 |
| `.github/workflows/dex-oracle.yml` | 170 | 7 |
| `.github/workflows/honesty.yml` | 39 | 7 |
| `.gitignore` | 28 | 2 |
| `LICENSE` | 661 | 2 |
| `README.md` | 103 | 2 |
| `dex/det.dx` | 84 | 6 |
| `dex/haskell/BareissVectors.hs` | 50 | 6 |
| `dex/poly64.dx` | 113 | 6 |
| `dex/scala/Poly64Vectors.scala` | 49 | 6 |
| `docs/README-audit.md` (since deleted) | 262 | 9 |
| `docs/README-original.md` (since deleted) | 287 | 9 |
| `docs/dex-oracle.md` | 113 | 9 |
| `docs/files/src/main/scala/uor/kernel/Poly64.scala.md` | 926 | 9 |
| `docs/workflows-original/ci.yml.txt` (since deleted) | 162 | 9 |
| `docs/workflows-original/honesty.yml.txt` (since deleted) | 34 | 9 |
| `montrepol/.devcontainer/devcontainer.json` (since deleted) | 13 | 4.1 |
| `montrepol/.gitignore` | 11 | 4.1 |
| `montrepol/AGENTS.md` (since deleted) | 30 | 4.2 |
| `montrepol/CONFORMANCE.md` | 77 | 4.2 |
| `montrepol/LICENSE` | 661 | 4.2 |
| `montrepol/LICENSES/UOR-template-Apache-2.0.txt` | 176 | 4.2 |
| `montrepol/LICENSES/UOR-template-MIT.txt` | 21 | 4.2 |
| `montrepol/NOTICE` | 21 | 4.2 |
| `montrepol/README.md` | 49 | 4.2 |
| `montrepol/VERIFICATION.md` | 14 | 4.2 |
| `montrepol/cabal.project` | 25 | 4.1 |
| `montrepol/model/authorities.toml` | 51 | 4.3 |
| `montrepol/model/ids.toml` | 263 | 4.3 |
| `montrepol/model/ledger.toml` | 22 | 4.3 |
| `montrepol/model/mutants.toml` | 83 | 4.3 |
| `montrepol/oracles/zeta-zeros-odlyzko.txt` | 520 | 4.4 |
| `montrepol/oracles/zeta-zeros-odlyzko_checked.txt` | 519 | 4.4 |
| `montrepol/packages/mp-analytic/app/Main.hs` | 14 | 4.9 |
| `montrepol/packages/mp-analytic/mp-analytic.cabal` | 28 | 4.1 |
| `montrepol/packages/mp-analytic/src/MP/Bernoulli.hs` | 24 | 4.9 |
| `montrepol/packages/mp-analytic/src/MP/ExplicitFormula.hs` | 16 | 4.9 |
| `montrepol/packages/mp-analytic/src/MP/Primes.hs` | 53 | 4.9 |
| `montrepol/packages/mp-analytic/src/MP/Zeta.hs` | 41 | 4.9 |
| `montrepol/packages/mp-analytic/test/Main.hs` | 24 | 4.9 |
| `montrepol/packages/mp-check/mp-check.cabal` | 20 | 4.1 |
| `montrepol/packages/mp-check/src/MP/Check.hs` | 206 | 4.5 |
| `montrepol/packages/mp-check/src/MP/Check/Random.hs` | 76 | 4.5 |
| `montrepol/packages/mp-check/test/Main.hs` | 33 | 4.5 |
| `montrepol/packages/mp-gate/app/Main.hs` | 97 | 4.10 |
| `montrepol/packages/mp-gate/app/Mutants.hs` | 66 | 4.10 |
| `montrepol/packages/mp-gate/mp-gate.cabal` | 30 | 4.1 |
| `montrepol/packages/mp-gate/src/MP/Gate/Model.hs` | 103 | 4.10 |
| `montrepol/packages/mp-gate/src/MP/Gate/Render.hs` | 43 | 4.10 |
| `montrepol/packages/mp-gate/src/MP/Gate/Rules.hs` | 104 | 4.10 |
| `montrepol/packages/mp-gate/src/MP/Gate/Scan.hs` | 57 | 4.10 |
| `montrepol/packages/mp-gate/src/MP/Gate/Toml.hs` | 91 | 4.10 |
| `montrepol/packages/mp-gate/test/Main.hs` | 57 | 4.10 |
| `montrepol/packages/mp-lie/mp-lie.cabal` | 19 | 4.1 |
| `montrepol/packages/mp-lie/src/MP/RootSystem.hs` | 79 | 4.7 |
| `montrepol/packages/mp-lie/test/Main.hs` | 49 | 4.7 |
| `montrepol/packages/mp-linalg/mp-linalg.cabal` | 21 | 4.1 |
| `montrepol/packages/mp-linalg/src/MP/Algebra.hs` | 110 | 4.6 |
| `montrepol/packages/mp-linalg/src/MP/Matrix.hs` | 188 | 4.6 |
| `montrepol/packages/mp-linalg/src/MP/Participation.hs` | 19 | 4.6 |
| `montrepol/packages/mp-linalg/test/Main.hs` | 103 | 4.6 |
| `montrepol/packages/mp-seq/mp-seq.cabal` | 19 | 4.1 |
| `montrepol/packages/mp-seq/src/MP/Recurrence.hs` | 87 | 4.8 |
| `montrepol/packages/mp-seq/test/Main.hs` | 63 | 4.8 |
| `montrepol_checked/.gitignore` | 11 | 5, same |
| `montrepol_checked/CONFORMANCE.md` | 77 | 5.6 |
| `montrepol_checked/cabal.project` | 25 | 5, same |
| `montrepol_checked/model/authorities.toml` | 63 | 5.6 |
| `montrepol_checked/model/ids.toml` | 263 | 5.6 |
| `montrepol_checked/model/ledger.toml` | 22 | 5.6 |
| `montrepol_checked/model/mutants.toml` | 84 | 5.6 |
| `montrepol_checked/packages/mp-analytic/app/Main.hs` | 14 | 5.4 |
| `montrepol_checked/packages/mp-analytic/mp-analytic.cabal` | 28 | 5.4, same |
| `montrepol_checked/packages/mp-analytic/src/MP/Bernoulli.hs` | 35 | 5.4 |
| `montrepol_checked/packages/mp-analytic/src/MP/ExplicitFormula.hs` | 16 | 5.4 |
| `montrepol_checked/packages/mp-analytic/src/MP/Primes.hs` | 52 | 5.4 |
| `montrepol_checked/packages/mp-analytic/src/MP/Zeta.hs` | 89 | 5.4 |
| `montrepol_checked/packages/mp-analytic/test/Main.hs` | 78 | 5.4 |
| `montrepol_checked/packages/mp-check/mp-check.cabal` | 20 | 4.5, 5, same |
| `montrepol_checked/packages/mp-check/src/MP/Check.hs` | 206 | 4.5, 5, same |
| `montrepol_checked/packages/mp-check/src/MP/Check/Random.hs` | 76 | 4.5, 5, same |
| `montrepol_checked/packages/mp-check/test/Main.hs` | 33 | 4.5, 5, same |
| `montrepol_checked/packages/mp-gate/app/Main.hs` | 97 | 5.5, same |
| `montrepol_checked/packages/mp-gate/app/Mutants.hs` | 55 | 5.5 |
| `montrepol_checked/packages/mp-gate/mp-gate.cabal` | 30 | 5.5, same |
| `montrepol_checked/packages/mp-gate/src/MP/Gate/Model.hs` | 109 | 5.5 |
| `montrepol_checked/packages/mp-gate/src/MP/Gate/Render.hs` | 46 | 5.5 |
| `montrepol_checked/packages/mp-gate/src/MP/Gate/Rules.hs` | 155 | 5.5 |
| `montrepol_checked/packages/mp-gate/src/MP/Gate/Scan.hs` | 122 | 5.5 |
| `montrepol_checked/packages/mp-gate/src/MP/Gate/Toml.hs` | 130 | 5.5 |
| `montrepol_checked/packages/mp-gate/test/Main.hs` | 91 | 5.5 |
| `montrepol_checked/packages/mp-lie/mp-lie.cabal` | 19 | 5.2 |
| `montrepol_checked/packages/mp-lie/src/MP/RootSystem.hs` | 119 | 5.2 |
| `montrepol_checked/packages/mp-lie/test/Main.hs` | 68 | 5.2 |
| `montrepol_checked/packages/mp-linalg/mp-linalg.cabal` | 21 | 5.1, same |
| `montrepol_checked/packages/mp-linalg/src/MP/Algebra.hs` | 124 | 5.1 |
| `montrepol_checked/packages/mp-linalg/src/MP/Matrix.hs` | 201 | 5.1 |
| `montrepol_checked/packages/mp-linalg/src/MP/Participation.hs` | 19 | 5.1, same |
| `montrepol_checked/packages/mp-linalg/test/Main.hs` | 161 | 5.1 |
| `montrepol_checked/packages/mp-seq/mp-seq.cabal` | 19 | 5.3, same |
| `montrepol_checked/packages/mp-seq/src/MP/Recurrence.hs` | 87 | 5.3 |
| `montrepol_checked/packages/mp-seq/test/Main.hs` | 63 | 5.3 |
| `src/main/scala/uor/ffi/UorExports.scala` | 111 | 3.3 |
| `src/main/scala/uor/kernel/Poly64.scala` | 185 | 3.1 |
| `src/main/scala/uor/kernel/U64.scala` | 8 | 3.2 |
| `src/test/scala/uor/kernel/Poly64Test.scala` | 83 | 3.4 |
