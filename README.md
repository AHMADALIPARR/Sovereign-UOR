# Sovereign UOR

**Inverted monorepo** — two sovereign stacks that share a claim discipline and nothing else:

| Tree | Language | What it is |
|------|----------|------------|
| **`src/`** (root) | Scala 3 + GraalVM | Canonical sparse multivariate polynomials over `(Z/2⁶⁴Z)` with native-image FFI for BQN / C |
| **`montrepol/`** | Haskell (Cabal) | Exact mathematics with every claim tied to a test that can fail — 6 packages, R1–R6 gate, 171 checks |

[![CI](https://github.com/AHMADALIPARR/Sovereign-UOR/actions/workflows/ci.yml/badge.svg)](https://github.com/AHMADALIPARR/Sovereign-UOR/actions/workflows/ci.yml)

```
Sovereign-UOR/
├── src/main/scala/uor/     # Poly64 kernel + GraalVM CEntryPoint exports
├── src/test/scala/uor/     # munit suite
├── montrepol/              # Cabal monorepo (exact math)
│   ├── cabal.project       # active-repositories: :none (no Hackage)
│   ├── packages/           # mp-check, mp-linalg, mp-lie, mp-seq, mp-analytic, mp-gate
│   ├── model/              # claim register (ids, authorities, mutants, ledger)
│   └── oracles/            # Odlyzko zeros, etc.
└── .github/workflows/ci.yml
```

---

## 1. Scala / UOR (`src/`)

Canonical sparse polynomials, dihedral `D_{2^64}` transforms, strata histograms, SHA-256 digests / URNs, GraalVM shared library.

```bash
# JVM tests
scala-cli test src/main/scala/uor/kernel src/test/scala/uor/kernel/Poly64Test.scala

# Native shared library
mkdir -p build
scalac -d build src/main/scala/uor/kernel/*.scala src/main/scala/uor/ffi/UorExports.scala
native-image --shared -cp build -H:Name=libuor -O3 --no-fallback
```

See the [BQN FFI example](#bqn-ffi-example) below.

---

## 2. montrepol (`montrepol/`)

Exact mathematics in Haskell. Depends on nothing but GHC: no Hackage packages, no network. The test harness, PRNG, TOML reader and every algorithm are written here.

```bash
cd montrepol
cabal build all          # GHC 9.10.1, cabal 3.12
cabal test all           # 171 checks across 6 packages
cabal run mp-gate        # rules R1–R6 over the model, sources and build
cabal run mp-gate -- mutants   # 13 planted defects; each must be caught
```

| Package | Role |
|---------|------|
| `mp-check` | Test harness: SplitMix64, generators, ID-tagged tests |
| `mp-linalg` | Semirings, typed matrices, Strassen, Bareiss, participation ratio |
| `mp-lie` | Root systems A–G, Cartan matrices, Weyl orders |
| `mp-seq` | Berlekamp–Massey, LFSRs |
| `mp-analytic` | Sieve, Bernoulli, ζ, Hardy Z, explicit formula |
| `mp-gate` | Rules R1–R6 + mutant replay |

Full package docs: [`montrepol/README.md`](montrepol/README.md) · [`montrepol/CONFORMANCE.md`](montrepol/CONFORMANCE.md) · [`montrepol/VERIFICATION.md`](montrepol/VERIFICATION.md)

---

## CI

Root workflow runs **both** stacks:

1. **Scala** — compile kernel, munit, GraalVM `libuor.so`
2. **Cabal** — `cabal build all && cabal test all && cabal run mp-gate` inside `montrepol/`

---

## BQN FFI Example

```bqn
lib ← "./libuor.so"
CreateIsolate ← lib •FFI "i32"‿"graal_create_isolate"‿">*"‿">*"‿">&u64"
rc‿tbuf ← CreateIsolate ⟨0, 0, ⟨0⟩⟩
thread ← 0 ⊏ tbuf
D64Transform ← lib •FFI ""‿"uor_d64_transform_inplace"‿">u64"‿">&u64"‿">u64"‿">u64"‿">i32"
StrataHist   ← lib •FFI ""‿"uor_strata_histogram"‿">u64"‿">*u64"‿">u64"‿">&u64"
Poly64Canon  ← lib •FFI "i32"‿"uor_poly64_canonicalize"‿">u64"‿">i32"‿">i32"‿">&u64"‿">&u8"
vec ← ↡1000000
res ← D64Transform ⟨thread, vec, ≠vec, 1, 1⟩
hist ← StrataHist ⟨thread, res, ≠res, 65ⰵ0⟩
neg1 ← ¯1 + 2⋅64
rawTerms ← Join ⟨ 1‿0‿1 ⋄ 1‿0‿neg1 ⋄ 0‿2‿7 ⟩
k‿canonTerms‿sha256 ← Poly64Canon ⟨thread, 2, 3, rawTerms, 32ⰵ0⟩
```

---

## Licence

- **Scala / UOR (root):** all rights reserved / sovereign.
- **montrepol:** AGPL-3.0-or-later ([`montrepol/LICENSE`](montrepol/LICENSE)); UOR Foundation template parts retain MIT / Apache-2.0 notices ([`montrepol/NOTICE`](montrepol/NOTICE)).
