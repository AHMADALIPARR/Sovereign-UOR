# Sovereign UOR

**Canonical sparse multivariate polynomials over `(Z / 2^64 Z)[x₀, …, x_{k-1}]`**  
with GraalVM Native Image shared-library FFI for BQN / C ABI.

Includes:
- `Poly64` — sorted sparse terms, O(m+n) addition, multiplication (optional Boolean quotient `x_i² = x_i`), evaluation, flat packing, and deterministic SHA-256 URN digests.
- `D_{2^64}` dihedral vector transforms (bitwise NOT + modular shift).
- 65-bin Hamming-weight (strata) histograms.
- In-place polynomial canonicalization with digest emission.

## Layout

```
src/main/scala/
├── uor/kernel/
│   ├── Poly64.scala      # core ring operations
│   └── U64.scala         # thin unsigned wrapper
└── uor/ffi/
    └── UorExports.scala  # @CEntryPoint exports
```

## Build (GraalVM Native Image)

Requires a GraalVM JDK with the `native-image` component (e.g. GraalVM for JDK 21+).

```bash
mkdir -p build
scalac -d build \
  src/main/scala/uor/kernel/U64.scala \
  src/main/scala/uor/kernel/Poly64.scala \
  src/main/scala/uor/ffi/UorExports.scala

native-image --shared \
  -cp build \
  -H:Name=libuor \
  -O3 --march=native \
  --no-fallback
```

This produces `libuor.so` (Linux) / `libuor.dylib` (macOS) and the corresponding header.

## BQN FFI Example

```bqn
lib ← "./libuor.so"

# 1. Boot a GraalVM IsolateThread
CreateIsolate ← lib •FFI "i32"‿"graal_create_isolate"‿">*"‿">*"‿">&u64"
rc‿tbuf ← CreateIsolate ⟨0, 0, ⟨0⟩⟩
thread ← 0 ⊏ tbuf

# 2. Bind UOR native kernels
D64Transform ← lib •FFI ""‿"uor_d64_transform_inplace"‿">u64"‿">&u64"‿">u64"‿">u64"‿">i32"
StrataHist   ← lib •FFI ""‿"uor_strata_histogram"‿">u64"‿">*u64"‿">u64"‿">&u64"
Poly64Canon  ← lib •FFI "i32"‿"uor_poly64_canonicalize"‿">u64"‿">i32"‿">i32"‿">&u64"‿">&u8"

# 3. Apply D_{2^64} dihedral action (bnot followed by +1 = succ) across 1M u64 elements
vec ← ↡1000000
res ← D64Transform ⟨thread, vec, ≠vec, 1, 1⟩
hist ← StrataHist ⟨thread, res, ≠res, 65ⰵ0⟩

# 4. Reduce an unnormalized 2-variable polynomial in (Z/2^64 Z)[x0, x1]:
#    (1·x0¹·x1⁰) + ((2^64 - 1)·x0¹·x1⁰) + (7·x0⁰·x1²)  ==>  7·x1²
neg1 ← ¯1 + 2⋅64
rawTerms ←  Join ⟨
  1‿0‿1
  1‿0‿neg1
  0‿2‿7
⟩
k‿canonTerms‿sha256 ← Poly64Canon ⟨thread, 2, 3, rawTerms, 32ⰵ0⟩
•Show k                  # 1 surviving canonical term
•Show (k‿3) ⰵ canonTerms # ⟨ 0 2 7 ⟩
•Show sha256             # 32-byte canonical UOR digest
```

## License

All rights reserved / sovereign.  
Use at your own risk; the mathematics is public, the implementation is yours to own.
