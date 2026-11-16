<!-- Generated from model/*.toml by `mp-gate write`. Do not edit: R1. -->

# Conformance

Every claim this repository makes, by honesty level:

| Level | Meaning |
| --- | --- |
| `some-true` | reproduced from an authority. **Not established here.** |
| `build` | constructed here and checked against an oracle by a test. Evidence, not proof. |
| `open` | measured and reported. **Never asserted.** |

## Register

39 IDs. Each is discharged by the tests tagged with it.

### mp-check

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `CK-01` | `build` | integerIn lo hi yields values in the closed interval [lo, hi]. | 200 generated intervals and draws. |
| `CK-02` | `build` | The property runner reports a property that fails on one value in ten, and accepts a true one. | x /= 7 over [0, 9], 200 cases. |
| `CK-03` | `build` | integerIn reaches every value of a small range. | 400 draws from [0, 9]. |
| `CK-04` | `build` | The SplitMix64 stream matches the published algorithm. | First three outputs for seed 0 from an independent C implementation. (steele-2014) |

### mp-linalg

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `LA-01` | `build` | Integer, Rational, GF2 and MinPlus satisfy the semiring axioms. | Random triples, each axiom checked as an equation. |
| `LA-02` | `build` | Matrix multiplication is associative, distributes over addition and has the identity as unit. | Random integer matrices of random compatible shapes up to 6. |
| `LA-03` | `build` | Strassen multiplication equals the definition of the product, for every cutoff, over Integer, Rational and GF2. | The naive sum-of-products, on random shapes up to 20x20. (strassen-1969) |
| `LA-04` | `build` | The Bareiss determinant equals the Leibniz expansion over Integer and GF2. | The permutation expansion, on random matrices up to 6x6, and a hand-checked matrix needing a pivot swap. (bareiss-1968) |
| `LA-05` | `build` | det(AB) = det(A) det(B) and det(A^T) = det(A). | Random integer matrices up to 6x6. |
| `LA-06` | `build` | Over Q the inverse exists exactly when det is non-zero and is a two-sided inverse; rank A = rank A^T, and rank is full exactly when det is non-zero. | Random rational and integer matrices up to 5x5. |
| `LA-07` | `build` | Powers of a min-plus adjacency matrix give all-pairs shortest path lengths. | An independent Floyd-Warshall on random weighted digraphs up to 7 vertices. |
| `LA-08` | `build` | Kish's effective sample size is the participation ratio of diag(w), lies in [1, number of non-zero weights], and is exact: [2^32, 2^32] has k_eff = 2 and is rejected against 3. | Random weight vectors; the saturating-arithmetic case from prism-ciris. (kish-1965) |
| `LA-09` | `build` | For non-zero A, 1 <= PR(A^T A) <= rank(A^T A), and tr(G^2) is the squared Frobenius norm of symmetric G. | Random integer matrices up to 6x6. |
| `LA-10` | `build` | For 2x2 symmetric G, tr(G^2) = tr(G)^2 - 2 det G; for PSD G, PR(G) lies in [1, 2] and equals 2 exactly when G is a multiple of the identity. | Random G = B^T B. |

### mp-lie

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `LI-01` | `build` | The constructed A1-A6, B2-B6, D4-D7, G2, F4, E6, E7 and E8 satisfy the axioms of a reduced crystallographic root system. | Exhaustive check of closure under reflections, integrality and reducedness; and rejection of E8 with a root deleted, a non-reduced set and a non-crystallographic set. |
| `LI-02` | `build` | Each system has the tabulated number of roots, and the extracted simple roots number the rank. | The classification tables. (bourbaki-lie-4-6) |
| `LI-03` | `build` | Every positive root is a non-negative integral combination of the extracted simple roots. | Exact rational solve against the Gram matrix of the simple roots. |
| `LI-04` | `build` | The Weyl group order computed by orbit-stabilizer from the Cartan matrix matches the table, from A1 to E8 = 696729600. | The classification tables. (humphreys-1990) |
| `LI-05` | `build` | The determinant of each computed Cartan matrix matches the table. | The classification tables. (bourbaki-lie-4-6) |
| `LI-06` | `build` | For E8: \|W\| is the product of the degrees, the positive roots number the sum of (d_i - 1), \|Phi\| = rank times the Coxeter number 30, the root lattice is even and unimodular, and \|W\| does not depend on how the nodes are labelled. | The degrees 2, 8, 12, 14, 18, 20, 24, 30; random relabellings. (humphreys-1990) |

### mp-seq

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `SQ-01` | `build` | The Berlekamp-Massey connection polynomial generates the input sequence, over GF(2) and over Q. | Random sequences. (massey-1969) |
| `SQ-02` | `build` | Berlekamp-Massey returns the least length: no shorter LFSR generates the sequence. | Brute force over every shorter connection polynomial, GF(2), lengths up to 11. |
| `SQ-03` | `build` | From 2l terms of a length-l LFSR sequence, Berlekamp-Massey recovers a recurrence that predicts the rest. | Random LFSRs of length up to 8, run to 6l terms. (massey-1969) |
| `SQ-04` | `build` | x^5 + x^2 + 1 gives period 31 and linear complexity 5; x^4 + x^2 + 1 = (x^2 + x + 1)^2 gives period 6, not 15. | Direct simulation of the shift register. (lidl-niederreiter-1997) |
| `SQ-05` | `build` | The Fibonacci numbers have connection polynomial 1 - x - x^2, and the zero sequence has linear complexity 0. | Direct computation. |

### mp-analytic

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `AN-01` | `build` | The sieve agrees with trial division, and pi(10^k) for k = 1..6 matches the published counts. | Trial division to 5000; OEIS A006880. (oeis-a006880) |
| `AN-02` | `build` | The product of p over prime powers p^k <= x equals lcm(1..x), so exp psi(x) = lcm(1..x); psi(x) matches log lcm(1..x) to 1e-12. | Exact integer lcm for x <= 300; logarithms for x <= 600. |
| `AN-03` | `build` | The exact Bernoulli numbers match the classical values and satisfy von Staudt-Clausen up to B_80. | B_0..B_12 as tabulated; the theorem as an integrality check. (ireland-rosen-1990) |
| `AN-04` | `build` | Euler-Maclaurin zeta matches zeta(2), zeta(4), zeta(0), zeta(-1), zeta(1/2) and Euler's formula for zeta(2k), k <= 10, to 1e-12. | Closed forms, using this package's own Bernoulli numbers for Euler's formula. (edwards-1974) |
| `AN-05` | `build` | exp(i theta(t)) zeta(1/2 + it) is real to 1e-9 for t in [10, 800]. | The functional equation, which makes Z(t) real; 200 random t. (edwards-1974) |
| `AN-06` | `build` | The zeros of Z(t) located on (10, 827] are exactly the 512 tabulated zeros, each to 1e-8. | Odlyzko's table, committed under oracles/. (odlyzko-zeros) |

### mp-gate

| ID | Level | Claim | Checked against |
| --- | --- | --- | --- |
| `GT-00` | `build` | A repository that keeps the rules produces no violations. | A synthetic clean repository. |
| `GT-01` | `build` | R1 fires on a hand-edited CONFORMANCE.md, a duplicated ID and an unparsable model, and on nothing else. | Planted defects. |
| `GT-02` | `build` | R2 fires on an open ID, an asserting word in an open claim, some-true with no authority and a citation of an unknown authority. | Planted defects. |
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
| `zeta-zeros-complete` | `some-true` | Odlyzko's table lists every non-trivial zero of zeta with imaginary part in (0, 826.91], and each lies on the critical line. Here the zeros are located independently and matched to the table (AN-06); completeness is the table's, not verified by Turing's method here. | oracles/zeta-zeros-odlyzko.txt (odlyzko-zeros) |
| `explicit-formula-truncation` | `open` | Error of the explicit formula truncated to the first M zeros, against psi(x), x in 20.5..980.5 off prime powers. Measured max \|err\|/sqrt(x): 0.529 (M=0), 0.317 (M=10), 0.199 (M=100), 0.112 (M=512). No bound on the truncation error is claimed. | cabal run mp-analytic-report |

## Authorities

- **steele-2014**: G. L. Steele, D. Lea, C. H. Flood. Fast splittable pseudorandom number generators. OOPSLA 2014. (SplitMix64; constants as in Java's SplittableRandom.)
- **strassen-1969**: V. Strassen. Gaussian elimination is not optimal. Numerische Mathematik 13 (1969) 354-356.
- **bareiss-1968**: E. H. Bareiss. Sylvester's identity and multistep integer-preserving Gaussian elimination. Mathematics of Computation 22 (1968) 565-578.
- **kish-1965**: L. Kish. Survey Sampling. Wiley, 1965. (Effective sample size.)
- **humphreys-1990**: J. E. Humphreys. Reflection Groups and Coxeter Groups. Cambridge University Press, 1990. Sections 2.10-2.11 and 3.7 (orders and degrees).
- **bourbaki-lie-4-6**: N. Bourbaki. Lie Groups and Lie Algebras, Chapters 4-6. Springer, 2002. Plates I-IX (root counts, Cartan matrices).
- **massey-1969**: J. L. Massey. Shift-register synthesis and BCH decoding. IEEE Transactions on Information Theory 15 (1969) 122-127.
- **lidl-niederreiter-1997**: R. Lidl, H. Niederreiter. Finite Fields, 2nd ed. Cambridge University Press, 1997. Chapter 8 (linear recurring sequences, periods).
- **oeis-a006880**: OEIS A006880: number of primes below 10^n.
- **ireland-rosen-1990**: K. Ireland, M. Rosen. A Classical Introduction to Modern Number Theory, 2nd ed. Springer, 1990. Chapter 15 (Bernoulli numbers, von Staudt-Clausen).
- **edwards-1974**: H. M. Edwards. Riemann's Zeta Function. Academic Press, 1974. Chapter 3 (explicit formula), 6.4 (Euler-Maclaurin), 6.5 (Riemann-Siegel theta).
- **odlyzko-zeros**: A. M. Odlyzko. Tables of zeros of the Riemann zeta function, file zeros1. https://www-users.cse.umn.edu/~odlyzko/zeta_tables/
