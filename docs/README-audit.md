# README audit

Work in progress. This file is extended in later commits with every claim of
`docs/README-original.md` marked as matching or not matching the repository.

## Findings so far (2026-11-15)

1. `montrepol/` does not compile with GHC 9.10.1 (`cabal build all`). First errors:
   - `montrepol/packages/mp-linalg/src/MP/Algebra.hs:107` duplicate instance `Eq (Maybe a)`.
   - `montrepol/packages/mp-analytic/src/MP/Bernoulli.hs:8`, `MP/Primes.hs:10`, `mp-lie/src/MP/RootSystem.hs:17-18`: modules from `mp-linalg` imported without the package in `build-depends`.
   - `montrepol/packages/mp-gate/src/MP/Gate/Scan.hs:16,22,27,35` and `MP/Gate/Toml.hs:50`: warnings turned into errors by `-Werror`.
2. `montrepol/oracles/zeta-zeros-odlyzko.txt` is fabricated in large part. Compared with LMFDB (https://www.lmfdb.org/zeros/zeta/list?N=1&limit=600), 426 of 512 rows differ after rounding to 10 decimals; 397 differ by 1e-6 or more, all of them from row 130 to row 507. Rows 135 and 136 are the same number (295.8131297355). Rows 484 to 507 repeat the digit patterns `.8765432109`, `.2345678901`, `.9876543210`, `.1234567891`, and 22 rows exceed 826.91 although the header limits the table to the first 512 zeros (the 512th is 826.9058109541). Odlyzko's own site could not be reached from the build machine (HTTP 500 and TLS errors), so the comparison is against LMFDB.
3. The original README says the shared library exports three entry points; `UorExports.scala` defines four (`uor_d64_transform_inplace`, `uor_strata_histogram`, `uor_d64_digest`, `uor_poly64_canonicalize`).
