# Sovereign UOR

[![CI](https://github.com/AHMADALIPARR/Sovereign-UOR/actions/workflows/ci.yml/badge.svg)](https://github.com/AHMADALIPARR/Sovereign-UOR/actions/workflows/ci.yml)
[![honesty](https://github.com/AHMADALIPARR/Sovereign-UOR/actions/workflows/honesty.yml/badge.svg)](https://github.com/AHMADALIPARR/Sovereign-UOR/actions/workflows/honesty.yml)
[![dex-oracle](https://github.com/AHMADALIPARR/Sovereign-UOR/actions/workflows/dex-oracle.yml/badge.svg)](https://github.com/AHMADALIPARR/Sovereign-UOR/actions/workflows/dex-oracle.yml)

This README describes everything in the repository at commit `ee9176b`
(2026-11-15). Line numbers ("line 12", "lines 15-45", or a bare number in
parentheses) refer to the file named in the heading or sentence around them.
Every number was measured on the build machine (GHC 9.10.1, cabal 3.12.1.0,
Scala 3.5.2 on Java 21, Dex at commit `25e2e389`) or read from a GitHub
Actions log. Nothing is estimated.

## 1. What is here

| Directory | Language | Files | State at `ee9176b` |
|---|---|---|---|
| `src/` | Scala 3 | 4 | `Poly64`, polynomials over Z/2^64, with a C ABI. Compiles; 8 unit tests pass. |
| `montrepol/` | Haskell | 50 | The author's monorepo, restored from his own zip in commits `6c15b61`..`ee9176b`, plus one file added earlier (`oracles/zeta-zeros-odlyzko_checked.txt`). Builds with `-Werror`; 171 tests pass; the gate holds; 13 of 13 mutants are caught. |
| `montrepol_checked/` | Haskell | 38 | A corrected copy of an earlier, fabricated `montrepol/`. It builds and passes its own 80 tests, but it is **not** derived from the real code. See section 2. |
| `dex/` | Dex, Scala, Haskell | 4 | A second implementation, in Dex, of Poly64 arithmetic and of the determinant. The Poly64 half checks `src/`; the determinant half checks `montrepol_checked/`, not the restored tree. |
| `.github/workflows/` | YAML | 3 | `ci.yml`, `honesty.yml`, `dex-oracle.yml`. All green on `ee9176b`. |
| `docs/` | Markdown, text | 7 | Audit, file-by-file notes, Dex notes, the README and workflows as they were before. Several are now stale (section 2). |

The root also holds `LICENSE` (the AGPL v3 text, 661 lines), `.gitignore`
(28 lines) and this file. The license line is at the end.

The Scala and Haskell trees share no code. The Scala tree is a small kernel
for sparse polynomials over Z/2^64, exported through GraalVM native-image.
The Haskell tree, `montrepol`, is exact mathematics (linear algebra over
semirings, root systems, linear recurrences, primes, Bernoulli numbers, the
zeta function and its zeros) under a claim discipline: every claim is a row
in a TOML register, each row is tied to tagged tests, a gate program checks
six rules, and planted defects ("mutants") show that the tests can fail.

### Measured state of the restored `montrepol/`

Run on the build machine in a clean checkout of `ee9176b`, each step under
`nohup` with `-j1`, output tee'd to a log and the exit code saved:

| Command | Exit code | Result |
|---|---|---|
| `cabal update` | 0 | index fetched (the project has no repositories, but cabal 3.12 still wants an index file) |
| `cabal build all -j1` | 0 | all six packages, test suites and executables build; 0 warnings under `-Werror` |
| `cabal test all -j1 --test-show-details=direct` | 0 | 171 tests pass, 0 fail: mp-analytic 10, mp-check 5, mp-gate 23, mp-lie 106, mp-linalg 19, mp-seq 8 |
| `cabal run -j1 mp-gate` | 0 | `mp-gate: R1-R6 hold over 6 packages` |
| `cabal run -j1 mp-gate -- mutants` | 0 | `13 of 13 mutants caught`; `git status` clean afterwards |
| `cabal run mp-gate -- write` then `git diff --exit-code CONFORMANCE.md` | 0, 0 | the committed register is exactly what the model generates |
| `cabal run mp-analytic-report` | 0 | 512 zeros found on (10, 827]; error table identical to `model/ledger.toml:28`; 2.4 s wall time |

All tests ran with the default seed `0x5eed` (printed as `seed 24301`). The
numbers the montrepol README states, 171 checks (`montrepol/README.md:12`),
13 planted defects (`:14`) and 39 conformance IDs (`:28`), all match what the
code produces.

## 2. Read this first: what is stale

Until commit `6c15b61`, `montrepol/` on GitHub was not the author's code. It
was a shorter, fabricated version with 34 IDs, 10 mutants, a broken build
and a zeta table that was mostly wrong. Commits `6c15b61` to `ee9176b` (nine
commits, 2026-11-15 18:09-18:10 PST) replaced 33 files and added
`montrepol/.github/workflows/ci.yml` and `honesty.yml`; a fresh clone matches
the author's zip byte for byte on all 49 files. The other 14 were already
identical and did not change: `.gitignore`, `LICENSE`, `cabal.project`, the
six `.cabal` files, `MP/Check/Random.hs`, the `mp-check` tests, the gate's
`app/Main.hs`, and the source and tests of `mp-seq`.

Several things in this repository were built from the fabricated version.
They are left as they are, unedited, and listed here so nobody relies on
them:

| File or directory | Built from | What is stale |
|---|---|---|
| `montrepol_checked/` (38 files) | the fabricated `montrepol/` | Everything except the files that happen to equal the real ones (`.gitignore`, `cabal.project`, `MP/Check/Random.hs`, the mp-check tests, the gate's `app/Main.hs`, and the `.cabal` files of mp-analytic, mp-check, mp-gate, mp-linalg, mp-seq). Its code, 34-ID model, 10 mutants and `CONFORMANCE.md` describe fixes to code that was never the author's. It still builds and passes its own tests. |
| `montrepol_checked/model/ledger.toml:15` | the fabricated oracle | Says the original zeta table "does not match published values". The restored table matches them exactly (section 4.8). |
| `montrepol/oracles/zeta-zeros-odlyzko_checked.txt` | LMFDB | Not wrong, but now redundant: its 512 data rows are byte-identical to the restored `zeta-zeros-odlyzko.txt`. Only `montrepol_checked` reads it. |
| `dex/haskell/BareissVectors.hs` | `montrepol_checked` | Imports the untyped `MP.Matrix` of `montrepol_checked`. Compiled against the restored `mp-linalg` it fails at line 33: `fromLists` now returns `Maybe (Matrix m n a)`. So the Dex determinant check covers `montrepol_checked`, not the author's Bareiss. |
| `.github/workflows/dex-oracle.yml:13-14, 21-22, 60-65` | `montrepol_checked` | Path filters and the determinant step point at `montrepol_checked`. |
| `.github/workflows/ci.yml:105-106, 138-139` | the fabricated tree | Comments say `montrepol/` "does not compile" and is "expected to fail". On `ee9176b` the job built it successfully (CI run 71). |
| `.github/workflows/honesty.yml` | `montrepol_checked` | Replays `montrepol_checked`'s 10 mutants, not the author's 13. |
| `docs/README-audit.md` | the fabricated tree | Every finding about `montrepol/` (build failures, 426 wrong zeta rows, "171", "39", "13" called unproduced, wrong tests, missing names) describes the fabricated files. Its Scala findings (section 2 on `UorExports`) still hold. |
| `docs/REPO.md` | the fabricated tree | Sections 4, 5, 8 and the `montrepol` rows of its appendix. Its Scala, Dex-Poly64 and workflow sections still hold. |
| `docs/dex-oracle.md` | `montrepol_checked` | Accurate about what it measured, but the determinant side is `montrepol_checked`'s code. |

Not stale: `src/`, `dex/poly64.dx`, `dex/scala/Poly64Vectors.scala`,
`dex/det.dx` (it implements Leibniz on its own), `LICENSE`,
`docs/README-original.md` (a verbatim historical copy),
`docs/workflows-original/`, and
`docs/files/src/main/scala/uor/kernel/Poly64.scala.md`.

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
(see `docs/README-audit.md`, section 2, whose Scala findings still hold). The file is compiled only in the non-blocking
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

## 4. The Haskell monorepo (`montrepol/`)

Restored from the author's zip. Everything in this section was re-read at
`ee9176b`; nothing is carried over from earlier notes.

### 4.1 Project files

- `cabal.project` (25 lines): six packages (lines 7-13), `with-compiler:
  ghc-9.10.1` (15), `active-repositories: :none` (20), `tests: True` (22), and
  `-Wall -Wcompat -Wincomplete-uni-patterns -Wincomplete-record-updates
  -Wredundant-constraints -Werror` for every package (24-25). No dependency
  can come from Hackage; the build needs only GHC's boot libraries.
- Six `.cabal` files, all `version: 0.1.0.0`, all `base >=4.20 && <4.21`.
  `mp-check` (20 lines) depends on base only. `mp-linalg` (21) adds `array`.
  `mp-lie` (19) adds `containers`, and its test suite also `mp-linalg` (line 18). `mp-seq` (19) depends on
  `mp-linalg`. `mp-analytic` (28) adds `array` and defines the executable
  `mp-analytic-report`. `mp-gate` (30) has a library on base only and an
  executable adding `directory`, `filepath` and `process`.
- `.gitignore` (11 lines) ignores `dist-newstyle/` and editor files.
- `.devcontainer/devcontainer.json` (17 lines): Ubuntu 24.04 base image, the
  Haskell VS Code extension, and a `postCreateCommand` that installs
  `libgmp-dev` and GHC 9.10.1 with cabal 3.12.1.0 through ghcup (line 16).

### 4.2 The author's own documents

- `README.md` (85 lines). The commands and their counts (lines 10-15), a
  package table (19-26), where the code came from (31-39: five earlier
  repositories, `matmul`, `prism-ciris`, `prime-router`, `cluster`,
  `jsonschema`, and what was kept or dropped from each), two defects found in
  the `prism-ciris` kernel (41-56), the three honesty levels (58-73), the
  toolchain (75-79) and the licence (81-85). The two defects: a Kish
  effective-size check using saturating 64-bit arithmetic, which for weights
  `[2^32, 2^32]` accepted `min_keff = 3` (46-50), now LA-08; and a comment
  claiming `tr(G)^2 >= 2 ||G||_F^2` for 2x2 PSD matrices, which holds only for
  multiples of the identity (51-56), now LA-10. Both tests pass.
- `AGENTS.md` (67 lines). Rules R1-R6 (14-21), the order for adding a
  capability (23-35: register row, failing test, implementation, mutant,
  regenerate), how to choose an oracle (37-50: an independent algorithm,
  then a theorem, then a published table; never a function against itself),
  and why the scanner spells forbidden names in halves (60-62).
- `VERIFICATION.md` (77 lines). What each command discharges (5-11), the
  planted rule violations the gate's own tests use (13-26), two real
  violations the gate found on its first run (`maximum` in `MP.Matrix` and in
  the report, 28-30), the 13 mutants with the IDs that catch them (32-53),
  two holes the mutants exposed and how they were closed (LI-01 was vacuous,
  CK-02 did not call the runner; 55-63), and what the suite does not
  establish (65-77: no proofs, floating point is not interval arithmetic,
  completeness of the zeros is Odlyzko's, the explicit-formula error is
  measured, not bounded). The "caught by" column (39-53) lists more IDs than
  `model/mutants.toml` requires; the replay output in section 4.10 shows those
  extra IDs do fail too.
- `CONFORMANCE.md` (109 lines), generated by `cabal run mp-gate -- write`
  from `model/`: the three levels, a register of 39 IDs, the ledger and the
  12 authorities. Regenerating it changes nothing.
- `NOTICE` (26 lines), `LICENSE` (661 lines, AGPL v3 text),
  `LICENSES/UOR-template-MIT.txt` (21) and `UOR-template-Apache-2.0.txt`
  (176): copyright, the "or later" grant, and the template notices for the
  parts of the claim discipline adapted from UOR-Foundation/template.
- `.github/workflows/ci.yml` (32 lines) and `honesty.yml` (29 lines): the
  author's own workflows. `ci.yml` runs `cabal build all`, `cabal test all`,
  `cabal run mp-gate` and `mp-gate -- write && git diff --exit-code
  CONFORMANCE.md` (27-32); `honesty.yml` builds, runs `mp-gate -- mutants` and
  `git diff --exit-code` (26-29). GitHub only runs workflows under the
  repository root's `.github/`, so these two do not run here as committed;
  neither runs `cabal update` first. Section 7 says which of these steps the
  root workflows cover.

### 4.3 The model (`model/`)

- `ids.toml` (301 lines): 39 `[[id]]` rows, all at level `build`: CK-01..04,
  LA-01..10, LI-01..06, SQ-01..05, AN-01..06, GT-00..07. Each row names its
  package, claim, oracle and, where relevant, authorities.
- `authorities.toml` (52 lines): 12 entries (lines 6-51): Steele, Lea and
  Flood 2014 (SplitMix64); Strassen 1969; Bareiss 1968; Kish 1965;
  Humphreys 1990; Bourbaki, Lie groups ch. 4-6; Massey 1969; Lidl and
  Niederreiter 1997; OEIS A006880; Ireland and Rosen 1990; Edwards 1974;
  Odlyzko's `zeros1`.
- `ledger.toml` (29 lines): three claims with no test. `strassen-exponent`
  (12-14, `some-true`), `zeta-zeros-complete` (19-21, `some-true`: the
  table's completeness to 826.91 is Odlyzko's, not checked here), and
  `explicit-formula-truncation` (26-28, `open`), whose statement records
  max |err|/sqrt(x) of 0.529, 0.317, 0.199 and 0.112 for M = 0, 10, 100 and
  512 zeros. `mp-analytic-report` reproduces exactly these values (section
  4.9).
- `mutants.toml` (112 lines): 13 mutants (section 4.10).

The register, with the test lines in `packages/<package>/test/Main.hs`
that carry each tag. All 39 rows are at level `build`.

| ID | Claim (from `model/ids.toml`) | Test lines |
|---|---|---|
| CK-01 | integerIn lo hi yields values in the closed interval [lo, hi]. | 14 |
| CK-02 | The property runner reports a property that fails on one value in ten, and accepts a true one. | 16-18 |
| CK-03 | integerIn reaches every value of a small range. | 20 |
| CK-04 | The SplitMix64 stream matches the published algorithm. | 22 |
| LA-01 | Integer, Rational, GF2 and MinPlus satisfy the semiring axioms. | 18-21 |
| LA-02 | Matrix multiplication is associative, distributes over addition and has the identity as unit. | 22 |
| LA-03 | Strassen multiplication equals the definition of the product, for every cutoff, over Integer, Rational and GF2. | 23-25 |
| LA-04 | The Bareiss determinant equals the Leibniz expansion over Integer and GF2. | 26-28 |
| LA-05 | det(AB) = det(A) det(B) and det(A^T) = det(A). | 30 |
| LA-06 | Over Q the inverse exists exactly when det is non-zero and is a two-sided inverse; rank A = rank A^T, and rank is full exactly when det is non-zero. | 31-32 |
| LA-07 | Powers of a min-plus adjacency matrix give all-pairs shortest path lengths. | 33 |
| LA-08 | Kish's effective sample size is the participation ratio of diag(w), lies in [1, number of non-zero weights], and is exact: [2^32, 2^32] has k_eff = 2 and is rejected against 3. | 34-35 |
| LA-09 | For non-zero A, 1 <= PR(A^T A) <= rank(A^T A), and tr(G^2) is the squared Frobenius norm of symmetric G. | 40 |
| LA-10 | For 2x2 symmetric G, tr(G^2) = tr(G)^2 - 2 det G; for PSD G, PR(G) lies in [1, 2] and equals 2 exactly when G is a multiple of the identity. | 41 |
| LI-01 | The constructed A1-A6, B2-B6, D4-D7, G2, F4, E6, E7 and E8 satisfy the axioms of a reduced crystallographic root system. | 39-46 |
| LI-02 | Each system has the tabulated number of roots, and the extracted simple roots number the rank. | 49 |
| LI-03 | Every positive root is a non-negative integral combination of the extracted simple roots. | 53 |
| LI-04 | The Weyl group order computed by orbit-stabilizer from the Cartan matrix matches the table, from A1 to E8 = 696729600. | 57 |
| LI-05 | The determinant of each computed Cartan matrix matches the table. | 61 |
| LI-06 | For E8: \|W\| is the product of the degrees, the positive roots number the sum of (d_i - 1), \|Phi\| = rank times the Coxeter number 30, the root lattice is even and unimodular, and \|W\| does not depend on how the nodes are labelled. | 65-75 |
| SQ-01 | The Berlekamp-Massey connection polynomial generates the input sequence, over GF(2) and over Q. | 11-12 |
| SQ-02 | Berlekamp-Massey returns the least length: no shorter LFSR generates the sequence. | 13 |
| SQ-03 | From 2l terms of a length-l LFSR sequence, Berlekamp-Massey recovers a recurrence that predicts the rest. | 14 |
| SQ-04 | x^5 + x^2 + 1 gives period 31 and linear complexity 5; x^4 + x^2 + 1 = (x^2 + x + 1)^2 gives period 6, not 15. | 15-19 |
| SQ-05 | The Fibonacci numbers have connection polynomial 1 - x - x^2, and the zero sequence has linear complexity 0. | 22-24 |
| AN-01 | The sieve agrees with trial division, and pi(10^k) for k = 1..6 matches the published counts. | 15-17 |
| AN-02 | The product of p over prime powers p^k <= x equals lcm(1..x), so exp psi(x) = lcm(1..x); psi(x) matches log lcm(1..x) to 1e-12. | 19-21 |
| AN-03 | The exact Bernoulli numbers match the classical values and satisfy von Staudt-Clausen up to B_80. | 27-30 |
| AN-04 | Euler-Maclaurin zeta matches zeta(2), zeta(4), zeta(0), zeta(-1), zeta(1/2) and Euler's formula for zeta(2k), k <= 10, to 1e-12. | 35-43 |
| AN-05 | exp(i theta(t)) zeta(1/2 + it) is real to 1e-9 for t in [10, 800]. | 48 |
| AN-06 | The zeros of Z(t) located on (10, 827] are exactly the 512 tabulated zeros, each to 1e-8. | 52 |
| GT-00 | A repository that keeps the rules produces no violations. | 20 |
| GT-01 | R1 fires on a hand-edited CONFORMANCE.md, a duplicated ID and an unparsable model, and on nothing else. | 21-25 |
| GT-02 | R2 fires on an open ID, an asserting word in an open claim, some-true with no authority and a citation of an unknown authority. | 27-33 |
| GT-03 | R3 fires on an ID with no test and on a test tagged with an unregistered ID. | 35-37 |
| GT-04 | R4 fires on a deferral marker and on a stub, and not on the same word in a comment or a string. | 39-43 |
| GT-05 | R5 fires on a partial function, a partial operator and a missing -Werror, and not on primed names, strings or comments. | 45-51 |
| GT-06 | R6 fires on an outside dependency, an unbounded boot dependency, an unlisted package and a re-enabled package repository. | 53-59 |
| GT-07 | The TOML reader parses the subset the model uses and rejects what it cannot read. | 61-68 |

### 4.4 `mp-check`: the harness

`MP/Check/Random.hs` (76 lines) is SplitMix64: `Seed` (line 19), the golden
gamma `0x9e3779b97f4a7c15` (22-23), `mix64` (28), the output mix
`mix64variant13` with multipliers `0xbf58476d1ce4e5b9` and
`0x94d049bb133111eb` (34-38), `mixGamma` (42), `nextWord64` (48),
`splitSeed` (51), `boundedBelow` (60).

`MP/Check.hs` (212 lines): generators (`newtype Gen`, line 54; `integerIn`
69, `intIn` 74, `boolG` 77, `elements` 82, `listOfLength` 91, `listUpTo` 94,
`rationalIn` 98), results (`newtype Result`, 108; `pass`, `failWith`,
`assert`, `allOf`, 114-137), tests (`data Test`, 148; `unit` 151, `unitIO`
154, `prop` 158 with 200 cases, `propN` 161), the pure property runner
`checkProperty` (178), and `runSuite` (196), which prints `ok [ID] name` or
`FAIL [ID] ...`, takes `--seed N` and defaults to `0x5eed`. There is no
shrinking; a failure prints the seed and case number (comment at lines 7-9).

`test/Main.hs` (33 lines), 5 tests: CK-01 bounds (14), CK-02 the runner
rejects a property false on one value in ten and accepts a true one (16-18),
CK-03 coverage of a small range (20), CK-04 the first outputs for seed 0
equal the reference stream (22).

### 4.5 `mp-linalg`

- `MP/Algebra.hs` (137 lines): classes `Semiring` (27), `Ring` (35),
  `Domain` (48, with `exactQuot`, documented at 41-47) and `Field` (51,
  `recipF` returning `Nothing` exactly for zero). `Num` is deliberately not
  used (3-5). Instances for `Integer` (64-75), `Rational` (77-93), `GF2`
  (97-119) and the tropical `MinPlus` (126-137), where `Nothing` is +infinity.
- `MP/Matrix.hs` (304 lines): `newtype Matrix (m :: Nat) (n :: Nat) a`
  (52), so a product of the wrong shapes is a type error (comment 3-9).
  `fromLists` returns `Nothing` unless the shape is exact (76-77); `withSize`
  brings a runtime size into the type (113). `mul` is the definition (141);
  `mulStrassen` (153) pads to the next power of two and recurses with the
  seven products (166-193), using `mul` below the cutoff; `power` by
  squaring (195); `trace` (201). `det` (210) is Bareiss: `bareiss` (213-228)
  flips the sign on a row swap and divides by the previous pivot with
  `exactQuot`. `detLeibniz` (242) is the exponential oracle. `rank` (263)
  row-reduces over a field and skips zero columns; `inverse` (281) is
  Gauss-Jordan and returns `Nothing` exactly for singular input.
- `MP/Participation.hs` (49 lines): `kishEffective` (23), `(Σw)²/Σw²` as an
  exact `Rational` over `Natural` weights; `kishAtLeast` (34) decides
  `k_eff >= k` by cross-multiplication, so `[2^32, 2^32]` against 3 is
  `False`; `participationRatio` (39), `tr(G)²/tr(G²)`; `frobeniusSq` (48).
- `test/Main.hs` (250 lines), 19 tests, tags at lines 18-41: semiring axioms
  for four types (LA-01); associativity, distributivity, unit (LA-02);
  Strassen against the definition over Integer, Rational and GF2 for several
  cutoffs (LA-03); Bareiss against Leibniz over Integer and GF2 and a matrix
  needing a row swap (LA-04); det multiplicative and transpose-invariant
  (LA-05); inverse exists exactly when det ≠ 0, and rank A = rank Aᵀ (LA-06);
  min-plus powers against a Floyd-Warshall written in the test (LA-07,
  `floydWarshall` at 188); Kish as the participation ratio of diag(w), and
  exactly 2 for `[2^32, 2^32]` (LA-08); 1 ≤ PR(AᵀA) ≤ rank(AᵀA) (LA-09); for
  2x2 symmetric G, tr(G²) = tr² − 2 det, and PR = 2 iff G = cI (LA-10).

### 4.6 `mp-lie`

`MP/RootSystem.hs` (196 lines). Systems are given only by their vectors
(comment 3-11); E8 and F4 are scaled by 2 to stay integral.
`axiomViolations` (55-75) lists every way a set fails to be a reduced
crystallographic root system: empty, zero vector, repeats, non-integral
`2(b,a)/(a,a)`, not closed under reflection, or non-reduced. Constructions:
`typeA` (85), `typeB` (89), `typeD` (93), `typeG2` (101), `typeF4` (109),
`typeE8` (114: 112 roots ±2eᵢ±2eⱼ and 128 sign vectors), and
`orthogonalSubsystem` (122), from which E7 and E6 are cut out of E8.
`genericFunctional` (131) picks positive roots; `simpleRoots` (144) are the
positive roots that are not sums of two others; `cartanMatrix` (154);
`weightOrbit` (163) enumerates a fundamental weight's orbit in Dynkin
labels; `weylOrder` (178-189) multiplies the smallest leaf orbit by the
order of the Cartan matrix with that node deleted, recursively.

`test/Main.hs` (127 lines): 20 cases (lines 21-33): A1-A6, B2-B6, D4-D7, G2,
F4, E6, E7, E8, each with rank, root count, Weyl order and Cartan
determinant from the tables. 106 tests: LI-01 axioms for all 20 plus three
rejections (E8 minus one root, a set with a and 2a, and (3,0) with (1,1))
(39-46); LI-02 root and simple-root counts (49); LI-03 positive roots are
non-negative integral sums of simple roots (53); LI-04 Weyl orders (57);
LI-05 Cartan determinants (61); LI-06 for E8, |W| as the product of the
degrees, |Φ⁺| = Σ(dᵢ − 1), |Φ| = rank × h, the root lattice even and
unimodular, and the order unchanged by relabelling nodes (65-75). The E8
Weyl order is 696,729,600 (case at line 30).

### 4.7 `mp-seq`

`MP/Recurrence.hs` (87 lines): `berlekampMassey` over any field (26),
returning the linear complexity and a minimal connection polynomial;
`generates` (60), `runLFSR` (68), `period` (80). `test/Main.hs` (63 lines),
8 tests: regeneration over GF(2) and Q (11-12), minimality by brute force
over GF(2) (13), recovery from 2l terms (14), period 31 for x⁵+x²+1 and 6 for
x⁴+x²+1 (15-19), Fibonacci's 1 − x − x² and the zero sequence (22-24).

### 4.8 `mp-analytic` and the zeta table

- `MP/Bernoulli.hs` (36 lines): `bernoullis` (13), memoised from
  `Σ C(m+1,k) B_k = 0` (comment 3-5); `bernoulli` (26); `binomial` (33).
- `MP/Primes.hs` (64 lines): an ST-array sieve (22-33); `isPrimeTrial` (36)
  as its oracle; `primePowerBase` (40); `vonMangoldt` (52); `chebyshevPsi`
  (56); `primePowerProduct` (60), exactly lcm(1..x); `primeCount` (63).
- `MP/Zeta.hs` (93 lines): `zeta` (21) calls `zetaWith (20 + ⌈|s|⌉) 24`;
  `zetaWith` (30-44) is complex Euler-Maclaurin, Σ_{k<N} k^−s + N^{1−s}/(s−1)
  + N^−s/2 + Bernoulli corrections; `theta` (49-56) with four correction
  terms after −π/8; `hardyZ` (61) returns Z(t) and the imaginary residue;
  `zerosBetween` (72-93) finds sign changes on a grid and bisects 60 times.
  The comment at 69-71 states that close pairs or even-order zeros would be
  missed.
- `MP/ExplicitFormula.hs` (28 lines): `zeroContribution` (20), 2 Re(x^ρ/ρ)
  for ρ = ½ + iγ; `psiExplicit` (26).
- `app/Main.hs` (28 lines): `mp-analytic-report`. Finds the zeros on
  (10, 827] (line 14), evaluates ψ(x) at x = 20.5, 40.5, ..., 1000.5, the 50
  points x + 0.5 for x = 20, 40, ..., 1000 whose integer part is not a prime
  power, which is all of them (16), and prints the error of the
  explicit formula with M = 0, 1, 10, 50, 100, 250, 512 zeros (17-28). The label "20.5..980.5" is hard-coded at line 26 and
  repeated in `model/ledger.toml:28`; the points actually run to 1000.5. Measured output:

| M | mean abs err | max abs err | max err/√x |
|---|---|---|---|
| 0 | 3.289051 | 12.539032 | 0.528519 |
| 1 | 3.251969 | 10.151486 | 0.468632 |
| 10 | 2.064361 | 8.009703 | 0.316488 |
| 50 | 1.779325 | 7.440339 | 0.259749 |
| 100 | 1.309902 | 5.711652 | 0.199399 |
| 250 | 1.053419 | 3.440788 | 0.125484 |
| 512 | 0.736835 | 3.425835 | 0.111709 |

- `test/Main.hs` (77 lines), 10 tests: AN-01 sieve against trial division up
  to 5000 and π(10^k) for k = 1..6 against OEIS A006880 (15-17); AN-02
  ∏p over prime powers = lcm(1..x) for x ≤ 300 and ψ(x) = log lcm(1..x) to
  1e-12 for x ≤ 600 (19-21); AN-03 B₀..B₁₂ and von Staudt-Clausen up to B₈₀
  (27-30); AN-04 ζ(2), ζ(4), ζ(0), ζ(−1) and ζ(½) = −1.4603545088095868 to
  1e-12, and Euler's formula for k = 1..10 (35-47); AN-05 |Im e^{iθ}ζ(½+it)| < 1e-9 on [10, 800] (48); AN-06 all 512
  tabulated zeros are found to 1e-8 and no others (52-55). The table is read
  from `../../oracles/zeta-zeros-odlyzko.txt` (line 76).

**The zeta table.** `oracles/zeta-zeros-odlyzko.txt` (520 lines) has an
8-line header citing Odlyzko's `zeros1` and saying the rows came from the
`prime-router` repository (lines 1-8), then 512 rows `index gamma`. Re-checked
at `ee9176b`: indices run 1 to 512, the values strictly increase from
14.1347251417 to 826.9058109541, and all 512 data rows are byte-identical to
`oracles/zeta-zeros-odlyzko_checked.txt`, which holds the LMFDB values rounded
to 10 decimals. AN-06 passes against it. The earlier finding that this table
was "fabricated in large part" (426 wrong rows) was about the fabricated
version and does not apply to this file. Odlyzko's site itself could not be
reached from the build machine, so the comparison is with LMFDB.

### 4.9 `mp-gate`: the rules

- `MP/Gate/Toml.hs` (130 lines): the TOML subset the model uses (comment
  1-7): comments, `key = value`, `[[name]]` arrays of tables, strings with
  escapes, integers, booleans, single-line string arrays; anything else is a
  parse error with its line number. `parseToml` (41).
- `MP/Gate/Model.hs` (88 lines): `Level` (20: `SomeTrue`, `Build`, `Open`),
  `Row` (37), `Claim` (48), `Authority` (57), `Model` (60), `readModel` (68).
- `MP/Gate/Render.hs` (56 lines): `renderConformance` (7).
- `MP/Gate/Scan.hs` (129 lines): `codeOnly` (62) blanks comments, strings and
  character literals; `identifiers` (97) and `operators` (105) tokenise;
  `testTags` (117) finds IDs in `unit`/`unitIO`/`prop`/`propN` calls. The
  marker, stub and partial-name lists (24-51) are spelled in halves so the
  scanner can read itself (5-7).
- `MP/Gate/Rules.hs` (215 lines): `checkRepo` (55) as a pure function;
  `modelRules` (62, R1 and R2, with `assertingWords` at 112), `testRules`
  (115, R3), `sourceRules` (141, R4-R6), `dependencies` (193) for
  `build-depends`, `bootPackages` (52).
- `app/Main.hs` (97 lines): `check` (42, default), `write` (33), `mutants`;
  `loadRepo` (53) reads the model, `CONFORMANCE.md`, `cabal.project`, the
  `.cabal` files and every `.hs` file.
- `app/Mutants.hs` (73 lines): `runMutants` (22); `runOne` (38-58) reports
  `STALE` unless the planted text occurs exactly once, writes the mutant,
  runs `cabal test` on the package, restores the file in a `finally`, and
  counts the mutant as caught only if the run fails and every expected ID
  printed `FAIL [ID]`.
- `test/Main.hs` (133 lines), 23 tests (GT-00..GT-07, lines 20-68): a clean
  synthetic repository has no violations; each rule fires on its planted
  defects and not on the near-misses in `VERIFICATION.md:19-26`.

### 4.10 The mutants

From `model/mutants.toml` and the measured replay:

| Line | Mutant | File | Expects | Failed in the replay |
|---|---|---|---|---|
| 11 | Strassen: wrong product in C22 | `mp-linalg/src/MP/Matrix.hs` | LA-03 | LA-03 |
| 19 | Bareiss: row swap without sign flip | `MP/Matrix.hs` | LA-04 | LA-04, LA-05 |
| 27 | Kish: 64-bit saturation reintroduced | `MP/Participation.hs` | LA-08 | LA-08 |
| 35 | Weyl orbit: only reflect on positive coordinates | `mp-lie/src/MP/RootSystem.hs` | LI-04 | LI-04, LI-06 |
| 43 | Root axioms: closure check disabled | `MP/RootSystem.hs` | LI-01 | LI-01 |
| 51 | Berlekamp-Massey: length update off by one | `mp-seq/src/MP/Recurrence.hs` | SQ-01, SQ-02 | SQ-01..SQ-04 |
| 59 | Sieve: crosses off with stride 2i | `mp-analytic/src/MP/Primes.hs` | AN-01 | AN-01, AN-03 |
| 67 | Euler-Maclaurin: N^−s/2 term dropped | `MP/Zeta.hs` | AN-04 | AN-04, AN-05, AN-06 |
| 75 | theta: −π/8 dropped | `MP/Zeta.hs` | AN-05 | AN-05 |
| 83 | Bernoulli: recurrence index shifted | `MP/Bernoulli.hs` | AN-03 | AN-03..AN-06 |
| 91 | Gate: R5 partial-function list emptied | `mp-gate/src/MP/Gate/Scan.hs` | GT-05 | GT-05 |
| 99 | Gate: R3 untested-ID check disabled | `MP/Gate/Rules.hs` | GT-03 | GT-03 |
| 107 | Harness: property runner stops after case 0 | `mp-check/src/MP/Check.hs` | CK-02 | CK-02 |

All 13 printed `CAUGHT`, and the working tree was clean afterwards.

## 5. The corrected copy (`montrepol_checked/`)

`montrepol_checked/` was made on 2026-11-15, before the restore, as a
corrected copy of what `montrepol/` then contained. That version did not
compile, and its copy was rewritten until it built. Since the version it
corrected was not the author's code, this directory is stale as a whole
(section 2). It is described here because it is still in the repository,
still built by CI, and still used by the Dex determinant check.

What it contains, measured when it was made and still true of the files:

- The same six package names and the same `cabal.project`. Ten files are
  byte-identical to the restored `montrepol/`: `.gitignore`,
  `cabal.project`, the `.cabal` files of `mp-analytic`, `mp-check`,
  `mp-gate`, `mp-linalg` and `mp-seq`, `MP/Check/Random.hs`, the mp-check
  tests, and the gate's `app/Main.hs`. Everything else differs.
- An untyped `MP.Matrix` (`data Matrix a = Matrix Int Int ...`,
  `montrepol_checked/packages/mp-linalg/src/MP/Matrix.hs:33`) with an
  `ExactDivision` class in `MP/Algebra.hs:39`, where the author's code has
  dimensions in the type and a `Domain` class.
- `mp-lie` with A2, B2, G2 and E8 only (`MP/RootSystem.hs:100`); the author's
  has 20 systems.
- `mp-analytic` with a separate zero finder `zerosUpTo` (`MP/Zeta.hs:75`)
  that reads `montrepol/oracles/zeta-zeros-odlyzko_checked.txt`
  (`test/Main.hs:14`).
- A model of 34 IDs, 10 mutants and 10 authorities, with its own
  `CONFORMANCE.md` (77 lines).
- 80 tests (mp-check 5, mp-linalg 19, mp-lie 13, mp-seq 8, mp-analytic 12,
  mp-gate 23), all passing; `mp-gate: R1-R6 hold over 6 packages`; 10 of 10
  mutants caught. CI run 71 and honesty run 51 on `ee9176b` both passed.

Nothing in it should be read as a statement about the author's code. If it
is kept, its role is limited to what the Dex determinant check compares
against (section 6).

## 6. The Dex dual oracle (`dex/`)

[Dex](https://github.com/google-research/dex-lang) is Google Research's
typed functional array language, compiled through LLVM. Each check has a
repository side and a Dex side, both drawing the same inputs from SplitMix64
with seed `0x5eed`, written separately in each language; CI requires
byte-identical output. Build and run details are in `docs/dex-oracle.md`.

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
(36-46) drawn with `MP.Check.Random`, determinant by `MP.Matrix.det`
(line 33), compiled with include paths into `montrepol_checked`'s
`mp-linalg` and `mp-check` (comment at 6-9). It is stale: against the
restored `montrepol/packages/mp-linalg` it does not compile (GHC 9.10.1,
error at 33:83: `det` expects a `Matrix n n a`, `fromLists` now returns
`Maybe (Matrix m n Integer)`). The random generator it uses,
`MP/Check/Random.hs`, is the same file in both trees.

**`dex/det.dx`** (84 lines). Dex side for the determinant: the same
SplitMix64 and `urem`; `mat_at` (45) embeds the n×n matrix in a 6×6 `Int64`
matrix with an identity block (lines 48-56); `leibniz` (62) sums over all
6^6 = 46,656 maps from Fin 6 to Fin 6 (`pow6`, line 58), keeps the bijections
(65) and multiplies each product by the sign from its inversion count
(69-72). Run time 1.26 to 1.36 s over three local runs.

Agreement, measured locally and in dex-oracle run 5 (commit `9e27e68`):
600 of 600 Poly64 lines and 200 of 200 determinants identical. Matrix sizes
1 to 6 occurred 33, 28, 30, 33, 40 and 36 times. Negative controls on
temporary copies: forcing every permutation sign to +1 changed 165 of 200
lines; adding 1 to every product term changed 400 of 600. The Poly64 result
is a check of `src/` and still holds. The determinant result is a check of
`montrepol_checked`'s Bareiss, not of the author's `det` in
`montrepol/packages/mp-linalg/src/MP/Matrix.hs:210`, which has its own
Leibniz oracle in the same file (`detLeibniz`, 242) and passes LA-04.

## 7. Root workflows (`.github/workflows/`)

GitHub runs only these three; the two under `montrepol/.github/` do not run.

**`ci.yml`** (180 lines), on pushes and pull requests to `main`:

| Job | Lines | What it does | `ee9176b` (run 71) |
|---|---|---|---|
| `scala-test` | 22-47 | installs scala-cli, compiles `U64.scala` and `Poly64.scala`, runs `Poly64Test` | success |
| `native-image` | 52-102 | GraalVM `native-image --shared` for `libuor`; `continue-on-error` (57), and the command ends in `|| echo` (87) | success (the job cannot fail, see 57 and 87) |
| `cabal` | 108-135 | in `montrepol_checked`: `cabal update`, build, test, `mp-gate` | success |
| `cabal-original` | 141-158 | in `montrepol/`: `cabal update`, `cabal build all --keep-going`; `continue-on-error` (145) | success |
| `status` | 163-180 | fails unless `scala-test` and `cabal` succeeded | success |

The restored `montrepol/` is only built here. Its 171 tests, its gate, its
`CONFORMANCE.md` check and its 13 mutants are not run by any workflow that
GitHub executes; the results in section 1 come from the build machine.

**`honesty.yml`** (39 lines): in `montrepol_checked`, `cabal update`, build,
`cabal run mp-gate -- mutants`, then `git diff --exit-code` (35-39). It
replays `montrepol_checked`'s 10 mutants. Run 51 on `ee9176b`: success.

**`dex-oracle.yml`** (170 lines): runs only when `dex/`, the workflow, the
Scala kernel, or `montrepol_checked`'s `mp-linalg` or `mp-check` change
(path filters at 9-22), so it did not run for the restore. Job `vectors`
(36) builds the Scala and Haskell outputs; job `dex` (75) runs in an
`ubuntu:22.04` container (80) for LLVM 12, sets `STACK_ROOT=/opt/stack-root`
(82-83), clones dex-lang at the pinned commit (95-97), compiles
`static/index.ts` with TypeScript 4.9.5 and the runtime with clang++-12
(119-121), builds with stack (123-124), caches a finished build under a
`-done` key (111, 133) and an unfinished one under a key with the run id
(140), runs both `.dx` files and diffs the outputs (145-160). The first full
Dex build took 10 min 17 s in run 5; run 5 was green.

`docs/workflows-original/ci.yml.txt` (162 lines) and `honesty.yml.txt`
(34 lines) are the root workflows as they were before they were rewritten.

## 8. Documents (`docs/`)

| File | Lines | What it is | Status |
|---|---|---|---|
| [`docs/README-audit.md`](docs/README-audit.md) | 262 | Claim-by-claim audit of the previous README and of `montrepol/` | Stale for everything about `montrepol/`; its Scala findings hold |
| [`docs/REPO.md`](docs/REPO.md) | 884 | Earlier file-by-file description of the repository at `67948e5` | Stale in sections 4, 5, 8 and the montrepol rows of its appendix |
| [`docs/README-original.md`](docs/README-original.md) | 287 | The top-level README as it was at commit `5db9b38`, verbatim | Historical copy |
| [`docs/dex-oracle.md`](docs/dex-oracle.md) | 113 | The Dex oracle: inputs, outputs, measured agreement, build commands | Determinant half tied to `montrepol_checked` |
| [`docs/files/src/main/scala/uor/kernel/Poly64.scala.md`](docs/files/src/main/scala/uor/kernel/Poly64.scala.md) | 926 | Detailed walkthrough of `Poly64.scala` (7,527 words) | Current |
| [`docs/workflows-original/ci.yml.txt`](docs/workflows-original/ci.yml.txt) | 162 | Root `ci.yml` before the rewrite | Historical copy |
| [`docs/workflows-original/honesty.yml.txt`](docs/workflows-original/honesty.yml.txt) | 34 | Root `honesty.yml` before the rewrite | Historical copy |

## 9. Build and test

    # Scala kernel (Java 21, scala-cli)
    scala-cli test --scala 3.5.2 --test-only uor.kernel.Poly64Test \
      src/main/scala/uor/kernel src/test/scala/uor/kernel/Poly64Test.scala

    # The author's Haskell monorepo (GHC 9.10.1, cabal 3.12.1.0, libgmp)
    cd montrepol
    cabal update                 # once; cabal 3.12 wants an index file
    cabal build all
    cabal test all               # 171 tests
    cabal run mp-gate            # R1-R6
    cabal run mp-gate -- mutants # 13 mutants; restores every file
    cabal run mp-gate -- write && git diff --exit-code CONFORMANCE.md
    cabal run mp-analytic-report # the explicit-formula error table

    # The stale corrected copy, as CI builds it
    cd montrepol_checked && cabal update && cabal build all && cabal test all

    # Dex oracle, repository side
    scala-cli run --server=false --scala 3.5.2 src/main/scala/uor/kernel \
      dex/scala/Poly64Vectors.scala -- 200

The Dex side needs a dex-lang build (LLVM 12, GHC 8.10.7 through stack);
`docs/dex-oracle.md` has the steps.

## 10. Open gaps

- No workflow GitHub executes runs the restored tree's tests, gate,
  conformance check or mutant replay. Its own `ci.yml` and `honesty.yml` sit
  under `montrepol/.github/`, where GitHub does not look.
- The Dex determinant check covers `montrepol_checked`, not the author's
  `det`; `BareissVectors.hs` does not compile against the restored code.
- `montrepol_checked/`, `docs/README-audit.md` and `docs/REPO.md` describe the
  fabricated tree and have not been revised.
- `Poly64` (Scala) compares by reference: two equal polynomials are not `==`
  because the case class holds arrays. Its arrays are public and mutable, and
  `fromRaw` accepts exponent vectors of the wrong length. Nothing calls the
  four `UorExports` entry points in a test.
- The zeta table was compared with LMFDB, not with Odlyzko's own files,
  which could not be reached.
- The explicit-formula error is measured, not bounded, as the author's
  ledger already says.

## Appendix: every file

All 109 files at `ee9176b`, with `wc -l` line counts and the section that
describes them. "stale" marks files built from the fabricated tree
(section 2).

| File | Lines | Section |
|---|---|---|
| `.github/workflows/ci.yml` | 180 | 7 |
| `.github/workflows/dex-oracle.yml` | 170 | 7 |
| `.github/workflows/honesty.yml` | 39 | 7 |
| `.gitignore` | 28 | 1 |
| `LICENSE` | 661 | 1 |
| `README.md` | 911 | 1 |
| `dex/det.dx` | 84 | 6 |
| `dex/haskell/BareissVectors.hs` | 50 | 6, stale |
| `dex/poly64.dx` | 113 | 6 |
| `dex/scala/Poly64Vectors.scala` | 49 | 6 |
| `docs/README-audit.md` | 262 | 8, stale |
| `docs/README-original.md` | 287 | 8 |
| `docs/REPO.md` | 884 | 8, stale |
| `docs/dex-oracle.md` | 113 | 8 |
| `docs/files/src/main/scala/uor/kernel/Poly64.scala.md` | 926 | 8 |
| `docs/workflows-original/ci.yml.txt` | 162 | 8 |
| `docs/workflows-original/honesty.yml.txt` | 34 | 8 |
| `montrepol/.devcontainer/devcontainer.json` | 17 | 4.1 |
| `montrepol/.github/workflows/ci.yml` | 32 | 4.2 |
| `montrepol/.github/workflows/honesty.yml` | 29 | 4.2 |
| `montrepol/.gitignore` | 11 | 4.1 |
| `montrepol/AGENTS.md` | 67 | 4.2 |
| `montrepol/CONFORMANCE.md` | 109 | 4.2 |
| `montrepol/LICENSE` | 661 | 4.2 |
| `montrepol/LICENSES/UOR-template-Apache-2.0.txt` | 176 | 4.2 |
| `montrepol/LICENSES/UOR-template-MIT.txt` | 21 | 4.2 |
| `montrepol/NOTICE` | 26 | 4.2 |
| `montrepol/README.md` | 85 | 4.2 |
| `montrepol/VERIFICATION.md` | 77 | 4.2 |
| `montrepol/cabal.project` | 25 | 4.1 |
| `montrepol/model/authorities.toml` | 52 | 4.3 |
| `montrepol/model/ids.toml` | 301 | 4.3 |
| `montrepol/model/ledger.toml` | 29 | 4.3 |
| `montrepol/model/mutants.toml` | 112 | 4.3 |
| `montrepol/oracles/zeta-zeros-odlyzko.txt` | 520 | 4.8 |
| `montrepol/oracles/zeta-zeros-odlyzko_checked.txt` | 519 | 4.8 |
| `montrepol/packages/mp-analytic/app/Main.hs` | 28 | 4.8 |
| `montrepol/packages/mp-analytic/mp-analytic.cabal` | 28 | 4.1 |
| `montrepol/packages/mp-analytic/src/MP/Bernoulli.hs` | 36 | 4.8 |
| `montrepol/packages/mp-analytic/src/MP/ExplicitFormula.hs` | 28 | 4.8 |
| `montrepol/packages/mp-analytic/src/MP/Primes.hs` | 64 | 4.8 |
| `montrepol/packages/mp-analytic/src/MP/Zeta.hs` | 93 | 4.8 |
| `montrepol/packages/mp-analytic/test/Main.hs` | 77 | 4.8 |
| `montrepol/packages/mp-check/mp-check.cabal` | 20 | 4.1 |
| `montrepol/packages/mp-check/src/MP/Check.hs` | 212 | 4.4 |
| `montrepol/packages/mp-check/src/MP/Check/Random.hs` | 76 | 4.4 |
| `montrepol/packages/mp-check/test/Main.hs` | 33 | 4.4 |
| `montrepol/packages/mp-gate/app/Main.hs` | 97 | 4.9 |
| `montrepol/packages/mp-gate/app/Mutants.hs` | 73 | 4.9 |
| `montrepol/packages/mp-gate/mp-gate.cabal` | 30 | 4.1 |
| `montrepol/packages/mp-gate/src/MP/Gate/Model.hs` | 88 | 4.9 |
| `montrepol/packages/mp-gate/src/MP/Gate/Render.hs` | 56 | 4.9 |
| `montrepol/packages/mp-gate/src/MP/Gate/Rules.hs` | 215 | 4.9 |
| `montrepol/packages/mp-gate/src/MP/Gate/Scan.hs` | 129 | 4.9 |
| `montrepol/packages/mp-gate/src/MP/Gate/Toml.hs` | 130 | 4.9 |
| `montrepol/packages/mp-gate/test/Main.hs` | 133 | 4.9 |
| `montrepol/packages/mp-lie/mp-lie.cabal` | 19 | 4.1 |
| `montrepol/packages/mp-lie/src/MP/RootSystem.hs` | 196 | 4.6 |
| `montrepol/packages/mp-lie/test/Main.hs` | 127 | 4.6 |
| `montrepol/packages/mp-linalg/mp-linalg.cabal` | 21 | 4.1 |
| `montrepol/packages/mp-linalg/src/MP/Algebra.hs` | 137 | 4.5 |
| `montrepol/packages/mp-linalg/src/MP/Matrix.hs` | 304 | 4.5 |
| `montrepol/packages/mp-linalg/src/MP/Participation.hs` | 49 | 4.5 |
| `montrepol/packages/mp-linalg/test/Main.hs` | 250 | 4.5 |
| `montrepol/packages/mp-seq/mp-seq.cabal` | 19 | 4.1 |
| `montrepol/packages/mp-seq/src/MP/Recurrence.hs` | 87 | 4.7 |
| `montrepol/packages/mp-seq/test/Main.hs` | 63 | 4.7 |
| `montrepol_checked/.gitignore` | 11 | 5, stale |
| `montrepol_checked/CONFORMANCE.md` | 77 | 5, stale |
| `montrepol_checked/cabal.project` | 25 | 5, stale |
| `montrepol_checked/model/authorities.toml` | 63 | 5, stale |
| `montrepol_checked/model/ids.toml` | 263 | 5, stale |
| `montrepol_checked/model/ledger.toml` | 22 | 5, stale |
| `montrepol_checked/model/mutants.toml` | 84 | 5, stale |
| `montrepol_checked/packages/mp-analytic/app/Main.hs` | 14 | 5, stale |
| `montrepol_checked/packages/mp-analytic/mp-analytic.cabal` | 28 | 5, stale |
| `montrepol_checked/packages/mp-analytic/src/MP/Bernoulli.hs` | 35 | 5, stale |
| `montrepol_checked/packages/mp-analytic/src/MP/ExplicitFormula.hs` | 16 | 5, stale |
| `montrepol_checked/packages/mp-analytic/src/MP/Primes.hs` | 52 | 5, stale |
| `montrepol_checked/packages/mp-analytic/src/MP/Zeta.hs` | 89 | 5, stale |
| `montrepol_checked/packages/mp-analytic/test/Main.hs` | 78 | 5, stale |
| `montrepol_checked/packages/mp-check/mp-check.cabal` | 20 | 5, stale |
| `montrepol_checked/packages/mp-check/src/MP/Check.hs` | 206 | 5, stale |
| `montrepol_checked/packages/mp-check/src/MP/Check/Random.hs` | 76 | 5, stale |
| `montrepol_checked/packages/mp-check/test/Main.hs` | 33 | 5, stale |
| `montrepol_checked/packages/mp-gate/app/Main.hs` | 97 | 5, stale |
| `montrepol_checked/packages/mp-gate/app/Mutants.hs` | 55 | 5, stale |
| `montrepol_checked/packages/mp-gate/mp-gate.cabal` | 30 | 5, stale |
| `montrepol_checked/packages/mp-gate/src/MP/Gate/Model.hs` | 109 | 5, stale |
| `montrepol_checked/packages/mp-gate/src/MP/Gate/Render.hs` | 46 | 5, stale |
| `montrepol_checked/packages/mp-gate/src/MP/Gate/Rules.hs` | 155 | 5, stale |
| `montrepol_checked/packages/mp-gate/src/MP/Gate/Scan.hs` | 122 | 5, stale |
| `montrepol_checked/packages/mp-gate/src/MP/Gate/Toml.hs` | 130 | 5, stale |
| `montrepol_checked/packages/mp-gate/test/Main.hs` | 91 | 5, stale |
| `montrepol_checked/packages/mp-lie/mp-lie.cabal` | 19 | 5, stale |
| `montrepol_checked/packages/mp-lie/src/MP/RootSystem.hs` | 119 | 5, stale |
| `montrepol_checked/packages/mp-lie/test/Main.hs` | 68 | 5, stale |
| `montrepol_checked/packages/mp-linalg/mp-linalg.cabal` | 21 | 5, stale |
| `montrepol_checked/packages/mp-linalg/src/MP/Algebra.hs` | 124 | 5, stale |
| `montrepol_checked/packages/mp-linalg/src/MP/Matrix.hs` | 201 | 5, stale |
| `montrepol_checked/packages/mp-linalg/src/MP/Participation.hs` | 19 | 5, stale |
| `montrepol_checked/packages/mp-linalg/test/Main.hs` | 161 | 5, stale |
| `montrepol_checked/packages/mp-seq/mp-seq.cabal` | 19 | 5, stale |
| `montrepol_checked/packages/mp-seq/src/MP/Recurrence.hs` | 87 | 5, stale |
| `montrepol_checked/packages/mp-seq/test/Main.hs` | 63 | 5, stale |
| `src/main/scala/uor/ffi/UorExports.scala` | 111 | 3 |
| `src/main/scala/uor/kernel/Poly64.scala` | 185 | 3 |
| `src/main/scala/uor/kernel/U64.scala` | 8 | 3 |
| `src/test/scala/uor/kernel/Poly64Test.scala` | 83 | 3 |

## License

AGPL-3.0-only OR LicenseRef-SnapKitty-Opaque-1.0. The AGPL text is in [LICENSE](LICENSE).
