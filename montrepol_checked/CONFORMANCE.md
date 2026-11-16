# CONFORMANCE

Generated from `model/` by `cabal run mp-gate -- write`. Do not edit.

## mp-check

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `CK-01` | `build` | integerIn lo hi yields values in the closed interval [lo, hi]. | 200 generated intervals and draws. |
| `CK-02` | `build` | The property runner reports a property that fails on one value in ten, and accepts a true one. | x /= 7 over [0, 9], 200 cases. |
| `CK-03` | `build` | integerIn reaches every value of a small range. | 400 draws from [0, 9]. |
| `CK-04` | `build` | The SplitMix64 stream matches the published algorithm. | First three outputs for seed 0 from an independent C implementation. (steele-2014) |

## mp-linalg

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `LA-01` | `build` | Integer, Rational, GF2 and MinPlus satisfy the semiring axioms. | Random triples, each axiom checked as an equation. |
| `LA-02` | `build` | Matrix multiplication is associative, distributes over addition and has the identity as unit. | Random integer matrices of random compatible shapes up to 6. |
| `LA-03` | `build` | Strassen multiplication equals the definition of the product, for cutoffs 2 to 5, over Integer, Rational and GF2. | The naive sum-of-products, on random shapes up to 20x20. (strassen-1969) |
| `LA-04` | `build` | The Bareiss determinant equals the Leibniz expansion over Integer and GF2. | The permutation expansion, on random matrices up to 6x6, and a hand-checked matrix needing a pivot swap. (bareiss-1968) |
| `LA-05` | `build` | The inverse of a nonsingular matrix multiplies back to the identity, and a singular matrix has no inverse. | Random rational matrices up to 4x4 (when no inverse is returned the determinant must be 0) and a hand-checked singular matrix. |
| `LA-06` | `build` | The rank equals the number of nonzero rows of the Bareiss echelon form. | The largest nonzero minor (Leibniz) on random matrices up to 5x5, and a hand-checked matrix. |
| `LA-07` | `build` | The participation ratio of a probability vector is between 1 and its length, and equals the length of a uniform vector. | Hand-checked and random probability vectors. |

## mp-lie

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `LI-01` | `build` | The root systems A2, B2, G2 and E8 satisfy the root axioms: finite, spans, closed under reflection, and 2(a,b)/(a,a) integer. | The classification tables. (bourbaki-lie, humphreys-1972) |
| `LI-02` | `build` | The simple roots generate the whole root system under reflection, and every root is a one-signed integer combination of them. | Coefficients solved from the Gram matrix over the rationals, for A2 and E8. |
| `LI-03` | `build` | The Cartan matrix has the published entries. | Bourbaki / Humphreys tables. (bourbaki-lie, humphreys-1972) |
| `LI-04` | `build` | The Weyl group order, computed by orbit-stabilizer on fundamental weights, equals the published order. | The published orders of A2, B2, G2 and E8 (6, 8, 12, 696729600). (bourbaki-lie, humphreys-1972) |

## mp-seq

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `SQ-01` | `build` | Berlekamp-Massey's polynomial regenerates the sequence it was built from, over any field. | Random sequences over GF(2) and Q. (massey-1969) |
| `SQ-02` | `build` | The linear complexity is minimal: no shorter LFSR generates the sequence. | Brute force over GF(2). (massey-1969) |
| `SQ-03` | `build` | A length-l LFSR is recovered from 2l terms and predicts the rest. | Random LFSRs, Massey's theorem. (massey-1969) |
| `SQ-04` | `build` | Primitive polynomials have the maximal period; non-primitive do not. | Hand-checked polynomials. |
| `SQ-05` | `build` | The Fibonacci sequence has connection polynomial 1 - x - x^2; the zero sequence has complexity 0. | Hand-checked. |

## mp-analytic

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `AN-01` | `build` | The sieve produces the primes up to n. | Trial division. |
| `AN-02` | `build` | von Mangoldt and Chebyshev psi match their definitions. | Hand-checked values. |
| `AN-03` | `build` | The Bernoulli numbers match the von Staudt-Clausen denominators and the closed forms. | von Staudt-Clausen, OEIS. (von-staudt-clausen) |
| `AN-04` | `build` | zeta(s) by Euler-Maclaurin matches the closed forms for s = 2, 4, 6, 8. | Closed forms using this package's Bernoulli numbers. (edwards-1974) |
| `AN-05` | `build` | exp(i theta(t)) zeta(1/2 + it) is real to 1e-9 for t in [10, 800]. | The functional equation; 200 random t. (edwards-1974) |
| `AN-06` | `build` | The zeros of Z(t) located on (10, 827] are exactly the 512 tabulated zeros, each to 1e-8. | The table montrepol/oracles/zeta-zeros-odlyzko_checked.txt (LMFDB values rounded to 10 decimals). (lmfdb-zeros) |

## mp-gate

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `GT-00` | `build` | A repository that keeps the rules produces no violations. | A synthetic clean repository. |
| `GT-01` | `build` | R1 fires on a hand-edited CONFORMANCE.md, a duplicated ID and an unparsable model, and on nothing else. | Planted defects. |
| `GT-02` | `build` | R2 fires on an open ID, an asserting word in a build claim, some-true with no authority and a citation of an unknown authority. | Planted defects. |
| `GT-03` | `build` | R3 fires on an ID with no test and on a test tagged with an unregistered ID. | Planted defects. |
| `GT-04` | `build` | R4 fires on a deferral marker and on a stub, and not on the same word in a comment or a string. | Planted defects and planted near-misses. |
| `GT-05` | `build` | R5 fires on a partial function, a partial operator and a missing -Werror, and not on primed names, strings or comments. | Planted defects and planted near-misses. |
| `GT-06` | `build` | R6 fires on an outside dependency, an unbounded boot dependency, an unlisted package and a re-enabled package repository. | Planted defects. |
| `GT-07` | `build` | The TOML reader parses the subset the model uses and rejects what it cannot read. | Hand-written documents. |

## Ledger

Claims with no ID, and so no test: reproduced facts and measured quantities.

| Key | Level | Statement | Evidence |
| --- | --- | --- | --- |
| `strassen-exponent` | `some-true` | Strassen's algorithm uses O(n^log2(7)) ring operations. This repository checks that it computes the product, not how fast. | Cited, not measured. (strassen-1969) |
| `zeta-zeros-complete` | `some-true` | Odlyzko's table lists every non-trivial zero of zeta with imaginary part in (0, 826.91], and each lies on the critical line. Here the zeros are located independently and matched to the table (AN-06); completeness is the table's, not verified by Turing's method here. | montrepol/oracles/zeta-zeros-odlyzko_checked.txt (LMFDB values); the original oracles/zeta-zeros-odlyzko.txt does not match published values (odlyzko-zeros) |
| `explicit-formula-truncation` | `open` | Error of the explicit formula under truncation of the zeros. | Not checked here. |
