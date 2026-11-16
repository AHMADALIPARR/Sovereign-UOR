# `src/main/scala/uor/kernel/Poly64.scala`

This document walks through `src/main/scala/uor/kernel/Poly64.scala` as it
stands at commit `9e27e68` (the file itself is unchanged since the first
commit that added it, `f2b2834`). Every statement about behaviour is either
read off a cited line or measured with a small Scala program run against this
file on 2026-11-15 (Scala 3.5.2, Java 21, scala-cli 1.19.0). The program and
its output are reproduced in section 12 so the measurements can be repeated.

Line numbers refer to the file as committed. The file is 185 lines long plus
a final newline.

## 1. What the file is for

The file defines one type, `Poly64`, and its companion object. A `Poly64` is
a polynomial in `k` variables `x_0, ..., x_{k-1}` whose coefficients live in
the ring of integers modulo 2^64. The doc comment at lines 8 to 10 says so in
the file's own words: "Canonical sparse multivariate polynomial in
(Z / 2^64 Z)[x_0, ..., x_{k-1}]. Monomials are stored sorted lexicographically
by exponent vector with non-zero U64 coefficients."

Three properties of that sentence carry the whole design:

1. **Sparse.** Only monomials with a non-zero coefficient are stored. A
   polynomial with three terms in eight variables costs three exponent
   vectors and three coefficients, not a dense table of every possible
   monomial.
2. **Canonical.** For a given polynomial there is exactly one stored
   representation: terms sorted by exponent vector, no duplicates, no zero
   coefficients. Two equal polynomials therefore have byte-identical
   serialisations, which is what makes the SHA-256 digest at lines 108 to 121
   a meaningful identity.
3. **Coefficients in Z/2^64.** Coefficients are JVM `Long` values, and all
   coefficient arithmetic uses the JVM's wrapping `+` and `*`. On the JVM,
   `Long` addition and multiplication are defined to wrap modulo 2^64 (two's
   complement), so the bit pattern of a `Long` result is exactly the residue
   of the mathematical result modulo 2^64. The comments at lines 33 and 67
   ("wrapping mod 2^64") point this out at the two places it matters.

The file is the core of the Scala tree. `U64.scala` supplies the return type
of `eval`. `src/main/scala/uor/ffi/UorExports.scala` exposes canonicalisation
and the digest through a C ABI (lines 82 to 110 of that file).
`src/test/scala/uor/kernel/Poly64Test.scala` tests it, and
`dex/scala/Poly64Vectors.scala` drives it for the Dex dual oracle.

## 2. Mathematical setting

### 2.1 The coefficient ring

Z/2^64 is the ring of residues modulo 2^64. It is a commutative ring with
unit, but not a field and not an integral domain: 2 is a zero divisor because
2 · 2^63 = 2^64 = 0. This has consequences that the file inherits without
comment:

- A product of two non-zero terms can be zero. Measured: multiplying the
  constant polynomial 2^63 (stored as `Long.MinValue`) by the constant
  polynomial 2 gives the zero polynomial (experiment E14 in section 12).
  `*` handles this correctly because it sends every raw product through
  `fromRaw`, which drops zero coefficients (lines 156 and 159).
- The degree of a product is not always the sum of the degrees. In a field
  the leading terms of `p` and `q` multiply to a non-zero leading term of
  `p · q`; here they can annihilate each other. The file never computes a
  degree, so nothing in it relies on the field-like rule.
- Division is not defined in general, and the file provides none.

The ring is also the natural model of unsigned 64-bit machine arithmetic,
which is why the type is called `Poly64` and why `eval` returns a `U64`: a
polynomial evaluated with machine words is exactly a polynomial over
Z/2^64.

### 2.2 The polynomial ring

`(Z/2^64)[x_0, ..., x_{k-1}]` is the set of finite formal sums
`Σ c_e · x^e`, where `e = (e_0, ..., e_{k-1})` is a vector of non-negative
integers, `x^e = x_0^{e_0} ··· x_{k-1}^{e_{k-1}}`, and `c_e ∈ Z/2^64`.
Addition adds coefficients of equal monomials; multiplication is the
convolution

    (p · q)_e = Σ_{a + b = e} p_a · q_b

over all pairs of exponent vectors that sum to `e`.

In the file, the exponent vector is `exps(i)`, an `Array[Int]` of length
`numVars`, and the coefficient is `coeffs(i)`. The number of variables is a
runtime value, `numVars`, carried by every polynomial. Operations on two
polynomials check that the counts agree (`require` at lines 16 and 49).

### 2.3 The canonical order

Terms are kept in increasing lexicographic order of their exponent vectors.
The comparison is `java.util.Arrays.compareUnsigned(int[], int[])` (lines 23
and 147). For two arrays of the same length, this compares element by
element, treating each `Int` as an unsigned 32-bit number, and returns the
sign of the first difference. So `(0, 2) < (1, 0) < (1, 1) < (2, 0)`.

For non-negative exponents below 2^31, unsigned and signed comparison agree,
so the order is ordinary lexicographic order. The unsigned comparison only
changes the picture for negative `Int` values, which the type never rules out;
see section 9.2.

Lexicographic order is a total order on exponent vectors of a fixed length,
which is all canonicalisation needs: it makes the sorted sequence of distinct
monomials unique. Unlike a graded order it does not put terms of the same
total degree together, and it is not used for any Gröbner-style reasoning in
this repository.

### 2.4 What "canonical" buys

Suppose `p` and `q` are equal as polynomials. If both are canonical, then
both have the same set of monomials with non-zero coefficient, those
monomials appear in the same (lexicographic) order, and the coefficients are
the same `Long` values. Then `toFlatU64` (lines 94 to 106) produces equal
arrays and `digestBytes` (lines 109 to 121) produces equal digests.
Conversely, if the digests are equal then, barring a SHA-256 collision, the
serialisations are equal and so are the polynomials. This is the property the
FFI export `uor_poly64_canonicalize` sells: callers can identify a
polynomial by 32 bytes.

The guarantee depends on every constructor producing canonical values. The
primary constructor is `private` (line 11), so outside code must go through
`zero`, `fromRaw` or `fromFlatU64`, and the last of these goes through
`fromRaw`. Inside the class, `+` constructs directly (line 45) and relies on
its inputs being canonical; `*` goes through `fromRaw` (line 71). Section 9
lists the places where the guarantee leaks.

## 3. Line-by-line walkthrough

### Lines 1 to 6: directives and imports

    //> using scala 3.5.2
    package uor.kernel

    import java.nio.ByteBuffer
    import java.security.MessageDigest
    import java.util.Arrays

Line 1 is a scala-cli "using directive". It pins the compiler to Scala 3.5.2
when the file is compiled with scala-cli. The same directive appears in
`U64.scala:1` and in the test file; scala-cli warns that directives spread
over several files should be centralised in a `project.scala` (the warning is
printed in every run of section 12), but it is only a warning.

Line 2 puts the type in package `uor.kernel`, matching the directory.

Lines 4 to 6 import three JDK classes:

- `ByteBuffer` builds the byte string that is hashed in `digestBytes`
  (line 111). A freshly allocated `ByteBuffer` is big-endian, so every
  `putInt` and `putLong` writes the most significant byte first. This fixes
  the digest's byte layout independently of the host's endianness.
- `MessageDigest` provides SHA-256 (line 121).
- `Arrays` supplies `compareUnsigned` (lines 23 and 147), `equals`
  (line 157) and `copyOf` (lines 45 and 166).

There are no third-party dependencies. The file compiles with the Scala
standard library and the JDK alone, which is what lets the GraalVM native
image job build a shared library from it without a dependency resolver.

### Lines 8 to 12: the type and `termCount`

    final case class Poly64 private (numVars: Int, exps: Array[Array[Int]], coeffs: Array[Long]):
      def termCount: Int = coeffs.length

`Poly64` is a `final case class` with a private primary constructor. The
three fields are:

| Field | Type | Meaning |
|---|---|---|
| `numVars` | `Int` | `k`, the number of variables |
| `exps` | `Array[Array[Int]]` | `exps(i)` is the exponent vector of term `i`; each has length `numVars` when built by this file |
| `coeffs` | `Array[Long]` | `coeffs(i)` is the coefficient of term `i`, a residue mod 2^64 stored as its two's-complement bit pattern |

`termCount` (line 12) is the number of stored terms, read from the length of
`coeffs`. The zero polynomial has `termCount == 0`.

Being a case class gives `Poly64` compiler-generated `equals`, `hashCode`,
`toString`, `copy` and a companion `unapply`. Because two of the fields are
arrays, these generated members do not behave the way a reader of "canonical"
might expect:

- `equals` compares fields with `==`, and `==` on JVM arrays is reference
  equality. Measured (E5): `fromRaw(2, [(1,0),(1,0),(0,2)], [1,-1,7])` and
  `fromRaw(2, [(0,2)], [7])` both canonicalise to `7·x_1^2`, have identical
  digests, and compare unequal with `==`. Even `Poly64.zero(2) ==
  Poly64.zero(2)` is `false` (E6).
- `hashCode` hashes array identities, so equal polynomials land in different
  hash buckets; a `Set[Poly64]` or `Map[Poly64, _]` keyed by value does not
  work.
- `toString` prints array identities (`[[I@...`), not exponents.
- `copy` and the companion `apply` take the access of the constructor in
  Scala 3, so both are private. Checked by compiling a probe outside the
  class: `p.copy(numVars = 3)` fails with "private method copy can only be
  accessed from class Poly64", and `Poly64(1, Array.empty, Array.empty)` is
  rejected as well. Neither opens a way around canonicalisation.

The fields are public `val`s holding mutable arrays. Nothing stops a caller
from writing `p.coeffs(0) = 0L` or `p.exps(0)(0) = 5` and breaking the
canonical invariant after construction. The test file reads these arrays
directly (for example `Poly64Test.scala:24-25`), and so does the Dex vector
generator (`dex/scala/Poly64Vectors.scala`), which is reading, not writing.

The colon at the end of line 11 opens a Scala 3 indentation-based template
body; everything indented under it, through line 133, is a member of the
class.

### Lines 14 to 45: addition

    /** Ring addition in (Z / 2^64 Z)[X] in O(m + n) merge time */
    def +(other: Poly64): Poly64 =

Addition is a merge of two sorted term lists, the same pattern as merging two
sorted runs in merge sort.

**Line 16.** `require(numVars == other.numVars, "Variable count mismatch")`
rejects polynomials in different numbers of variables with an
`IllegalArgumentException`. Measured (E16): adding a 2-variable and a
3-variable polynomial throws with the message "requirement failed: Variable
count mismatch".

**Lines 17 to 20.** The output can have at most `m + n` terms, where `m` and
`n` are the term counts; two arrays of that size are allocated, and three
cursors are set up: `i` into `this`, `j` into `other`, `k` into the output.

**Lines 22 to 38.** While both inputs have terms left, the exponent vectors at
the two cursors are compared (line 23):

- If `this` has the smaller monomial (`cmp < 0`, lines 24 to 27), its term is
  copied to the output and `i` and `k` advance.
- If `other` has the smaller monomial (`cmp > 0`, lines 28 to 31), the same
  with `j`.
- If the monomials are equal (lines 32 to 38), the coefficients are added
  with wrapping `Long` addition (line 33). If the sum is non-zero it is
  written out with the shared exponent vector (lines 34 to 37); if the sum is
  zero modulo 2^64 the term is dropped. Either way both input cursors advance
  (line 38).

The zero check at line 34 is the step that keeps the result canonical: in
Z/2^64, `c + (2^64 − c) = 0`, so terms that cancel must vanish rather than be
stored with coefficient 0. The test "wrapping addition mod 2^64 cancels"
(`Poly64Test.scala:28-33`) checks exactly this with `1 + (−1)`, where `−1`
is the `Long` bit pattern of 2^64 − 1.

**Lines 40 to 43.** When one input runs out, the rest of the other is copied
over. Because the remaining terms are all larger than everything already
written, order is preserved.

**Line 45.** The output arrays are trimmed to `k` with `Arrays.copyOf`, and a
new `Poly64` is built directly with the private constructor, without going
through `fromRaw`. That is safe only if both inputs were canonical: then the
merged sequence is sorted, has no duplicate monomials, and no zero
coefficients.

**Sharing.** The output reuses the input exponent arrays by reference
(`outExps(k) = exps(i)` at lines 25, 35 and 41; `other.exps(j)` at lines 29
and 43). No exponent vector is copied. Since nothing in the file mutates an
exponent array after construction, this is invisible as long as callers do
not mutate the public arrays either.

**Cost.** Each loop iteration advances at least one cursor, so the loops run
at most `m + n` times, and each comparison costs `O(k)`. Total
`O((m + n) · k)` time and `O(m + n)` new references. Measured (E20): adding
two random 3-variable polynomials of 938 terms each takes about 41
microseconds on the build machine after JIT warm-up.

### Lines 47 to 71: multiplication

    /** Ring multiplication in (Z / 2^64 Z)[X]; set booleanQuota = true to enforce x_i^2 = x_i */
    def *(other: Poly64, booleanQuota: Boolean = false): Poly64 =

Multiplication forms every pairwise product of terms and then canonicalises.

**Line 49.** Same variable-count check as addition.

**Line 50.** `prodCount = termCount * other.termCount` is the number of raw
products. This is an `Int` multiplication. It overflows when the product of
the term counts exceeds 2^31 − 1, for example two polynomials with 46,341
terms each. A negative `prodCount` would make the array allocations at lines
53 and 54 throw `NegativeArraySizeException`; a positive wrapped value would
allocate too-small arrays and throw `ArrayIndexOutOfBoundsException` inside
the loop. This was not exercised (it needs about 2^31 raw products and tens of
gigabytes of memory), but the arithmetic is plain from the line.

**Line 51.** If either factor is zero the product is the zero polynomial,
returned early. The `return` keyword is legal in Scala 3 inside a method
body.

**Lines 53 to 70.** Two nested loops over the terms of `this` (index `i`) and
`other` (index `j`). For each pair:

- A fresh exponent vector `e` is allocated (line 60) and filled with the
  coordinate-wise sums `exps(i)(v) + other.exps(j)(v)` (line 63). Exponent
  addition is `Int` addition and would overflow above 2^31 − 1; with the
  exponents this repository uses (single digits) it never comes close.
- If `booleanQuota` is set and a summed exponent exceeds 1, it is clamped to
  1 (line 64). See below.
- The coefficient is the wrapping `Long` product `coeffs(i) * other.coeffs(j)`
  (line 67). JVM `Long` multiplication returns the low 64 bits of the exact
  product, which is the residue modulo 2^64.

**Line 71.** The `prodCount` raw terms, in no particular order and possibly
with repeated monomials and zero coefficients, are handed to `fromRaw`, which
sorts them, merges equal monomials and drops zeros.

**The convolution, checked.** Expanding `(x_0 + x_1)^2` gives the raw terms
`x_0^2, x_0 x_1, x_1 x_0, x_1^2`; `fromRaw` merges the middle two into
`2 x_0 x_1`. Measured (E12): `(0,2):1 + (1,1):2 + (2,0):1`, which is
`x_1^2 + 2 x_0 x_1 + x_0^2` in lexicographic order of exponent vectors.

**`booleanQuota`.** With the flag set, the product is computed in the quotient
ring `(Z/2^64)[x_0..x_{k-1}] / (x_0^2 − x_0, ..., x_{k-1}^2 − x_{k-1})`, the
ring of multilinear polynomials, where every variable behaves like a Boolean
value (`x^2 = x`). Clamping an exponent to 1 is the reduction `x^n → x` for
`n ≥ 1`, which is valid in that quotient because `x^n = x` follows from
`x^2 = x` by induction. Measured (E13): `(x_0 + x_1)^2` with the flag gives
`(0,1):1 + (1,0):1 + (1,1):2`, which is `x_1 + x_0 + 2 x_0 x_1`, the correct
reduction of `x_0^2 + 2x_0x_1 + x_1^2`.

Two limits of the flag, read from the code:

- It applies to exponents produced by a product. A summed exponent is 1 only
  when one factor has exponent 1 and the other 0; every summed exponent of 2
  or more is clamped. So the product is always multilinear, whatever the
  factors look like. A polynomial with exponents above 1 that is never
  multiplied with the flag set keeps them.- Because Scala methods named `*` with a default argument can only receive
  the flag through method-call syntax, the flag is passed as
  `x0.*(x0, booleanQuota = true)` (`Poly64Test.scala:49`). The infix form
  `x0 * x0` always uses the default `false`.

**Cost.** `m · n` raw products, each costing `O(k)` to build, then
`fromRaw`'s sort of `m · n` items with `O(k)` comparisons:
`O(m n k log(m n))` time and `O(m n k)` memory for the raw exponent vectors.
Measured (E19): multiplying two random 3-variable polynomials with 938 terms
each (exponents below 20) takes about 351 ms after warm-up and produces 55,003
terms. Most of the time goes into allocating 879,844 three-element arrays and
sorting them. A hash-based accumulation or a heap merge would avoid the full
sort, but the current approach is simple and its output is canonical by
construction.

### Lines 73 to 91: evaluation

    /** Evaluate polynomial at point x in (Z / 2^64 Z)^k */
    def eval(point: Array[Long]): U64 =

`eval` computes `Σ_i c_i · Π_v x_v^{e_{i,v}}` modulo 2^64.

**Line 75.** `require(point.length == numVars)`: the point must have one
coordinate per variable. No message is given, so a mismatch throws
`IllegalArgumentException("requirement failed")`.

**Lines 76 to 90.** For each term, `term` starts at the coefficient (line 79)
and is multiplied by `x_v^{e}` for each variable, using binary
exponentiation (lines 82 to 87):

    var e = exps(i)(v)
    var b = point(v)
    while e > 0 do
      if (e & 1) == 1 then term *= b
      b *= b
      e >>>= 1

This is the standard right-to-left square-and-multiply: `b` runs through
`x, x^2, x^4, ...` and is multiplied into `term` whenever the corresponding
bit of `e` is set. All multiplications are wrapping `Long` multiplications,
so the result is `c_i · x^e mod 2^64`. The loop runs `⌊log_2 e⌋ + 1` times,
so the cost per variable is logarithmic in the exponent.

The term is added into `acc` with wrapping addition (line 89).

**Line 91.** The sum is wrapped in `U64`, a value class whose `toString`
prints the unsigned decimal value (`U64.scala:6-8`). Measured (E15): `3 + 5x`
at `x = 2` gives `13`, which is also what the test "eval basic" asserts
(`Poly64Test.scala:76-82`).

**Why the result is right modulo 2^64.** Reduction modulo 2^64 is a ring
homomorphism from the integers, so reducing after every addition and
multiplication gives the same residue as computing the exact integer value
and reducing once. Wrapping `Long` arithmetic is exactly "reduce after every
operation", so `eval` returns `p(x) mod 2^64` for the integer lift of `p` and
`x`.

**Negative exponents.** The loop condition `e > 0` treats any `e ≤ 0` as
exponent 0. A term stored with exponent −1 (possible through `fromRaw`, see
section 9.2) is evaluated as if the variable were absent. Measured (E8):
`x^{-1} + x^2` at `x = 3` evaluates to 10 (= 1 + 9). Note also that the
`>>>=` on line 87 is an unsigned shift; for the non-negative `e` that enter
the loop it is the same as a signed shift.

**Cost.** `O(m · k · log(max exponent))` multiplications. No Horner scheme
or sharing of powers between terms is attempted; for the sizes used in this
repository that does not matter.

**Connection to the Dex oracle.** `dex/poly64.dx` evaluates the same
product polynomials with a completely different method (a dense 7×7 table
and an explicit power table, `poly_eval` and `power` in that file). The
200 evaluation lines agree byte for byte with this `eval` (section 8).

### Lines 93 to 106: the flat encoding

    /** Pack canonical form into flat stride-(numVars + 1) u64 array for C ABI / BQN FFI */
    def toFlatU64: Array[Long] =

`toFlatU64` serialises the polynomial as one `Array[Long]` of length
`termCount · (numVars + 1)`. Term `i` occupies the `numVars + 1` slots
starting at `i · (numVars + 1)`: first its exponents, then its coefficient.

    [e_{0,0}, ..., e_{0,k-1}, c_0,  e_{1,0}, ..., e_{1,k-1}, c_1,  ...]

Each exponent is widened with `exps(i)(v).toLong & 0xFFFFFFFFL` (line 102),
which zero-extends the 32-bit pattern: an exponent stored as `Int` −1 becomes
4,294,967,295, not −1. For the normal range (0 to 2^31 − 1) this is the same
as a plain widening; measured (E9): exponent 2,147,483,647 is written as
`2147483647`.

This is the layout used by the C export `uor_poly64_canonicalize`
(`UorExports.scala:82-110`), which reads `termCount · (numVars + 1)` longs
from the caller, decodes them with `fromFlatU64`, canonicalises, and writes
`toFlatU64` of the result back into the same buffer (lines 98 to 103 of that
file), returning the new term count (line 110). The caller's buffer must
therefore be large enough for the input; the output is never longer than the
input, because canonicalisation only merges and drops terms.

### Lines 108 to 121: the digest

    /** Deterministic canonical SHA-256 digest bytes (32 bytes) */
    def digestBytes: Array[Byte] =

The digest is SHA-256 of the following byte string, written big-endian by
`ByteBuffer`:

| Offset | Size | Content | Line |
|---|---|---|---|
| 0 | 1 | the tag byte `0x04` | 112 |
| 1 | 4 | `numVars` as a signed 32-bit integer | 112 |
| 5 | 4 | `termCount` as a signed 32-bit integer | 112 |
| 9 | per term `4·numVars + 8` | each exponent as 32 bits, then the coefficient as 64 bits | 114 to 120 |

The buffer size at line 110, `1 + 4 + 4 + termCount * (numVars * 4 + 8)`,
matches this layout exactly, so the backing array is fully written and
`buf.array()` (line 121) is the exact message.

**Why it identifies the polynomial.** The header fixes `numVars` and the
number of terms, so the term data parses unambiguously. Together with
canonical form (section 2.4), equal polynomials give equal messages, and
different canonical polynomials give different messages. Equal digests then
mean equal polynomials unless SHA-256 has a collision.

**The tag byte.** `0x04` separates polynomial digests from other digests in
the same family: `UorExports.d64Digest` hashes a 10-byte message starting
with `0x03` (`UorExports.scala:66-70`). A polynomial message has
`9 + m(4k + 8)` bytes, which is 9 or at least 17, so it can never be the
10 bytes of a dihedral message; the tag makes the separation explicit even
so.

**Measured values (E2, E4).**

| Polynomial | SHA-256 |
|---|---|
| `7·x_1^2` in two variables (the README example) | `02a9fb47034782411ec4ce49acee55fa5ab5092da46d928d48adbed5bccb7d49` |
| zero polynomial in two variables | `97f47c511e0ae8e4bf03ccea459cc1a58c532d845e675ca678960d8c9aa5b048` |

The zero polynomial's message is the 9 bytes `04 00000002 00000000`.

**Cost.** One pass over the terms and one SHA-256 over
`9 + m(4k + 8)` bytes.

### Lines 123 to 133: the URN

    def urn: String =

`urn` formats the 32 digest bytes as 64 lowercase hex digits (lines 124 to
132; each byte is split into its high and low nibble, lines 130 and 131) and
prefixes `urn:uor:poly64:` (line 133). Measured (E3): the README example's URN
is `urn:uor:poly64:02a9fb47034782411ec4ce49acee55fa5ab5092da46d928d48adbed5bccb7d49`.

The test "digest is deterministic 32 bytes" (`Poly64Test.scala:66-74`)
checks that the digest is 32 bytes, that computing it twice gives the same
bytes, that the URN starts with the prefix and that it is the prefix plus 64
characters. It does not check any specific digest value, so it would not
notice a change to the byte layout or the tag; the values in the table above
could serve as a regression vector.

### Lines 135 to 137: the zero polynomial

    object Poly64:
      def zero(numVars: Int): Poly64 =
        Poly64(numVars, Array.empty, Array.empty)

The companion object starts at line 135. `zero` builds a polynomial with no
terms in `numVars` variables. It is canonical trivially. `numVars` is not
validated: `zero(-1)` is accepted, and its `digestBytes` would encode −1 as
`ffffffff`. The test "zero polynomial" (`Poly64Test.scala:9-12`) checks only
`termCount == 0`.

### Lines 139 to 166: canonicalisation

    /** Canonicalize arbitrary unsorted / duplicate / zero-coeff terms */
    def fromRaw(numVars: Int, rawExps: Array[Array[Int]], rawCoeff: Array[Long]): Poly64 =

`fromRaw` is the only general constructor. It takes parallel arrays of
exponent vectors and coefficients in any order, with repeats and zeros
allowed, and returns the canonical polynomial.

**Lines 141 and 142.** `n` is the number of raw terms, taken from
`rawCoeff.length`. If it is 0 the zero polynomial is returned. If `rawExps`
is shorter than `rawCoeff`, the loop below will throw
`ArrayIndexOutOfBoundsException`; if it is longer, the extra exponent vectors
are ignored. The two lengths are not checked against each other.

**Lines 144 to 147.** An index array `order = [0, 1, ..., n − 1]` is sorted
in place with `sortInPlaceWith`, using `compareUnsigned` on the exponent
vectors as the "less than" test. The comment at line 145 explains why: the
JDK has no `Arrays.sort(int[], Comparator)`, because primitive arrays cannot
be sorted with a comparator. Sorting indices rather than the exponent arrays
keeps exponents and coefficients paired. Raw terms with equal monomials end
up next to each other; their relative order does not matter, because they
are summed and addition modulo 2^64 is commutative and associative.

**Lines 149 to 165.** A single pass over the sorted indices, building the
output with a write cursor `k`:

- A zero coefficient is skipped outright (line 156).
- If the monomial equals the last one written (`k > 0 &&
  Arrays.equals(outExps(k - 1), rawExps(idx))`, line 157), the coefficient is
  added into it with wrapping addition (line 158). If the sum is zero, the
  last output term is removed by decrementing `k` (line 159); otherwise the
  sum is stored (line 160).
- Otherwise a new output term is started with a defensive copy of the
  exponent vector (`rawExps(idx).clone()`, line 162). The copy means later
  changes to the caller's arrays cannot alter the polynomial.

**Correctness of the cancellation step.** When `k` is decremented at line 159
the slot `k` still holds the cancelled monomial's array, but the next written
term overwrites it. Could a later raw term with the same monomial be merged
into the wrong place? After the decrement, the comparison at line 157 looks at
`outExps(k − 1)`, which is the previous, strictly smaller monomial, so a
further raw term with the cancelled monomial starts a fresh output term with
its own coefficient. That is the right answer: the coefficients seen so far
summed to zero, so the result is the remaining coefficients. Measured (E7):
raw terms `5x, −5x, 3x` give `3x`. And the test "canonical example from
README" (`Poly64Test.scala:55-64`) checks `1·x_0 + (2^64 − 1)·x_0 + 7·x_1^2 =
7·x_1^2`; measured (E1) the same.

**Line 166.** The output arrays are trimmed to `k` and wrapped with the
private constructor.

**Cost.** `O(n log n)` comparisons of `O(k)` each, plus `O(n k)` for the
copies.

**What `fromRaw` does not check.**

- Exponent vector length. Measured (E17): with `numVars = 2`, raw exponent
  vectors `(1)` and `(1, 0)` are accepted as two distinct terms
  `(1):1 + (1,0):1`. `compareUnsigned` orders a proper prefix before the
  longer array, so the sort still terminates. The result is not a valid
  2-variable polynomial: `digestBytes` then throws
  `ArrayIndexOutOfBoundsException` (E18) because it reads `exps(i)(1)` from
  a length-1 array, and `eval` would do the same.
- Negative exponents. Measured (E8): exponent −1 is accepted and, because the
  comparison is unsigned, sorts after exponent 2.
- `numVars` itself (it can be zero or negative).

These are input-validation gaps, not arithmetic errors: for well-formed input
(vectors of length `numVars`, exponents ≥ 0) the function is correct.

### Lines 168 to 185: decoding the flat encoding

    /** Decode flat stride-(numVars + 1) u64 array from C ABI / BQN FFI */
    def fromFlatU64(numVars: Int, flat: Array[Long]): Poly64 =

The inverse of `toFlatU64`. The number of terms is
`flat.length / (numVars + 1)` with integer division (line 171), so trailing
values that do not fill a whole term are silently ignored. Measured (E11):
five longs with `numVars = 2` (stride 3) decode as one term `(1,2):3` and the
values 4 and 5 are dropped.

Each exponent is narrowed with `.toInt` (line 180), keeping the low 32 bits.
Exponents of 2^31 or more turn into negative `Int`s; measured (E10): the flat
value 2,147,483,648 decodes to exponent −2,147,483,648. Exponents of 2^32 or
more wrap around entirely. Combined with the zero-extension in `toFlatU64`,
an exponent survives a round trip through the flat encoding exactly when it
lies in 0 to 2^31 − 1.

The decoded terms go through `fromRaw` (line 185), so a C caller may pass
unsorted, duplicated or zero terms and get the canonical form back. With
`numVars = −1` the stride would be 0 and line 171 would divide by zero; with
`numVars < −1` the stride is negative. The C export passes whatever `numVars`
the caller supplies.

The test "fromRaw + toFlatU64 round-trip" (`Poly64Test.scala:35-43`) encodes
`7·x_1^2 + x_0` and decodes it again, checking the term count and the
coefficient order `(7, 1)`. It does not compare exponents.

## 4. Inputs and outputs, member by member

| Member | Inputs | Output | Fails with |
|---|---|---|---|
| `termCount` | none | `Int`, number of stored terms | never |
| `+` | another `Poly64` | canonical sum | `IllegalArgumentException` on different `numVars` |
| `*` | another `Poly64`, optional `booleanQuota` | canonical product (multilinear if the flag is set) | `IllegalArgumentException` on different `numVars`; array exceptions if `termCount · other.termCount` overflows `Int` |
| `eval` | `Array[Long]` of length `numVars` | `U64`, value mod 2^64 | `IllegalArgumentException` on wrong length |
| `toFlatU64` | none | `Array[Long]` of length `termCount · (numVars + 1)` | never for well-formed values |
| `digestBytes` | none | 32-byte SHA-256 | `ArrayIndexOutOfBoundsException` if an exponent vector is shorter than `numVars` |
| `urn` | none | `"urn:uor:poly64:" + 64 hex digits` | as `digestBytes` |
| `Poly64.zero` | `numVars` | zero polynomial | never |
| `Poly64.fromRaw` | `numVars`, exponent vectors, coefficients | canonical polynomial | `ArrayIndexOutOfBoundsException` if fewer exponent vectors than coefficients |
| `Poly64.fromFlatU64` | `numVars`, flat array | canonical polynomial | `ArithmeticException` if `numVars = −1` |

## 5. The algebra, derived

### 5.1 Addition is correct

Let `p = Σ_{a ∈ A} p_a x^a` and `q = Σ_{b ∈ B} q_b x^b` be canonical, with
`A` and `B` the sets of monomials with non-zero coefficient, each listed in
increasing order. The merge visits the union `A ∪ B` in increasing order,
because at each step it emits the smaller of the two current heads (or both
when equal), and both lists are sorted. For a monomial in `A \ B` it emits
`p_a`, for `B \ A` it emits `q_b`, and for `A ∩ B` it emits `p_a + q_a mod
2^64` when that is non-zero. Those are exactly the non-zero coefficients of
`p + q`, in increasing order, with no repeats. So the output is canonical and
equals `p + q`.

### 5.2 Multiplication is correct

The raw list contains, for every pair `(a, b) ∈ A × B`, the monomial
`a + b` (coordinate-wise) with coefficient `p_a q_b mod 2^64`. Grouping the
raw list by monomial and summing — which is what `fromRaw` does after
sorting — gives, for each `e`, `Σ_{a + b = e} p_a q_b mod 2^64 = (p q)_e`.
Dropping zeros and keeping sorted order gives the canonical product.

With `booleanQuota`, each raw monomial `a + b` is replaced by `min(a + b, 1)`
coordinate-wise. Grouping by the clamped monomial computes the image of `p q`
under the quotient map to the multilinear ring, because the quotient map is a
ring homomorphism sending `x^e` to `x^{min(e,1)}` and is additive on
coefficients.

### 5.3 Evaluation is a ring homomorphism

For a fixed point `x ∈ (Z/2^64)^k`, the map `p ↦ p(x)` from
`(Z/2^64)[x_0..x_{k-1}]` to `Z/2^64` is a ring homomorphism. So for any
`p, q`: `(p + q)(x) = p(x) + q(x)` and `(p q)(x) = p(x) q(x)` modulo 2^64.
This gives a cheap consistency check that the file's tests do not use but
that the Dex oracle effectively uses: the Dex side computes `(p q)(x)` from
its own dense product, the Scala side from its sparse product, and the two
agree on all 200 random cases.

Note that with `booleanQuota` the homomorphism property holds only at points
whose coordinates satisfy `x_v^2 = x_v` in Z/2^64. The idempotents of Z/2^64
are only 0 and 1 (because 2^64 is a prime power), so the multilinear product
agrees with the ordinary product under evaluation exactly at 0/1 points.

### 5.4 Canonical form is unique

Two canonical representations of the same polynomial have the same set of
monomials with non-zero coefficient (by the definition of a polynomial as a
finitely supported function from monomials to coefficients), the same
coefficient for each, and — because lexicographic order on vectors of a fixed
length is a total order — the same order. So they are equal term by term.
This is the fact `digestBytes` relies on.

## 6. Tests

All eight tests live in `src/test/scala/uor/kernel/Poly64Test.scala` and run
in CI (`.github/workflows/ci.yml`, job `scala-test`, step "Unit tests"). They
passed in CI run 52 (commit `a6806eb`) and CI run 54 (commit `29b8ef5`).

| Test | Lines | What it checks in `Poly64.scala` | What it leaves out |
|---|---|---|---|
| zero polynomial | 9-12 | `zero` has no terms (lines 136-137) | digest of zero, arithmetic with zero |
| addition merges like terms and drops zeros | 14-26 | merge and cancellation in `+` (lines 22-38) | sums with no common monomials, longer inputs |
| wrapping addition mod 2^64 cancels | 28-33 | `1 + (2^64 − 1) = 0` drops the term (line 34) | — |
| fromRaw + toFlatU64 round-trip | 35-43 | flat encode/decode, term order | exponents after the round trip |
| booleanQuota enforces x_i^2 = x_i | 45-53 | clamping at line 64 | multi-variable cases; line 48 computes `sqB` and never uses it |
| canonical example from README | 55-64 | `fromRaw` merges `x_0 + (2^64−1) x_0` to nothing (lines 157-159) | — |
| digest is deterministic 32 bytes | 66-74 | digest length, determinism, URN format | any concrete digest value |
| eval basic | 76-82 | `3 + 5x` at 2 is 13 (lines 74-91) | wrapping in `eval`, several variables |

Gaps worth noting:

- No test multiplies two polynomials with more than one term each, so the
  convolution and the merge in `fromRaw` after a product are untested by
  this file. The Dex oracle covers this (section 8).
- No test checks that `==` works, and it does not (section 3, lines 8-12).
- No test pins a digest value; the two values measured in section 3 could be
  added.
- No test exercises the validation gaps of section 9.

## 7. Connections to other files

| File | Relation |
|---|---|
| `src/main/scala/uor/kernel/U64.scala` | Return type of `eval` (line 74). `U64` is a value class around `Long` whose `toString` prints unsigned decimal. |
| `src/main/scala/uor/ffi/UorExports.scala` | `poly64Canonicalize` (lines 82-110) calls `fromFlatU64`, `toFlatU64` and `digestBytes`. `d64Digest` (lines 58-75) uses the sibling tag `0x03`. |
| `src/test/scala/uor/kernel/Poly64Test.scala` | The unit tests of section 6. |
| `dex/scala/Poly64Vectors.scala` | Drives `fromRaw`, `+`, `*` and `eval` on 200 random cases for the Dex oracle and prints the canonical terms by reading `exps` and `coeffs`. |
| `dex/poly64.dx` | Independent dense re-implementation in Dex; the outputs are compared byte for byte by `.github/workflows/dex-oracle.yml`. |
| `.github/workflows/ci.yml` | Compiles `U64.scala` and `Poly64.scala` (step "Compile kernel"), runs `Poly64Test`, and in the non-blocking `native-image` job builds `libuor.so` from these files plus `UorExports.scala`. |
| `docs/README-audit.md` | Section 2 records the README claims about this file. |

Nothing in `montrepol/` or `montrepol_checked/` uses this file; the two trees
share no code.

## 8. The Dex dual oracle and this file

`dex/scala/Poly64Vectors.scala` draws 200 pairs of random 2-variable
polynomials with SplitMix64 (seed `0x5eed`): each has 1 to 4 terms, exponents
0 to 3 in each variable and full 64-bit random coefficients, built with
`fromRaw`, so repeated monomials are merged on construction. For each pair it
prints the canonical terms of `p + q` and `p · q` and the value of `p · q` at
a random point.

`dex/poly64.dx` draws the same numbers with its own SplitMix64 and computes
the same three results with dense coefficient tables: a 4×4 table per input,
element-wise addition, a 7×7 table for the product built by the explicit
convolution sum over all index pairs, and evaluation by summing
`t[a][b] · x_0^a · x_1^b` over the table.

Measured on the build machine: all 600 output lines are identical. A planted
change in the Dex product (each term increased by 1) makes 400 of the 600
lines differ, which shows the comparison is sensitive to the product and the
evaluation. Details and commands are in `docs/dex-oracle.md`.

What this establishes about `Poly64.scala`: on 200 random cases with
coefficients spread over the full 64-bit range, `+`, `*` (without
`booleanQuota`), `fromRaw`'s merging and sorting, and `eval` agree with an
implementation that shares no code, no data layout and no language with it.
It does not cover `booleanQuota`, the flat encoding, the digest, or more than
two variables.

## 9. Audit status, gaps and risks

### 9.1 Truncation

The file is complete: it ends with the closing line of `fromFlatU64` (line
185) and a newline, every block is closed, there are no placeholders and no
undefined references, and it compiles without warnings under Scala 3.5.2.

### 9.2 Behaviour that differs from what a reader would expect

All of these were measured (section 12):

1. **Value equality is reference equality** (E5, E6). The case class compares
   arrays by identity. Two canonical, equal polynomials are `!=`, and
   `hashCode` is not consistent with polynomial equality. Code that wants to
   compare polynomials must compare `digestBytes`, or `termCount`, `exps` and
   `coeffs` element-wise.
2. **The arrays are public and mutable.** Any holder of a `Poly64` can
   change its terms and break canonical form.
3. **`fromRaw` accepts malformed input** (E8, E17, E18): exponent vectors of
   the wrong length, negative exponents, and mismatched array lengths are not
   rejected. The result can later throw from `digestBytes` or `eval`.
4. **The flat encoding narrows exponents to 32 bits** (E9, E10), and ignores
   trailing values (E11).
5. **`*` can overflow its raw term count** when `termCount · other.termCount
   > 2^31 − 1` (line 50). Not measured.
6. **Exponent sums can overflow** in `*` (line 63) above 2^31 − 1. Not
   measured.

None of these affect results for well-formed polynomials with modest
exponents, which is how the rest of the repository uses the type.

### 9.3 Fabrication

The file makes no numeric claims. The original README's description of the
kernel directory as holding "Poly64, dihedral transforms, strata" does not
match: this file holds Poly64 only, and the dihedral and strata functions are
in `UorExports.scala` (see `docs/README-audit.md`, section 2).

### 9.4 What would close the gaps

Kept as notes; no change was made to this file.

- Override `equals` and `hashCode` (comparing `numVars`, then the arrays
  element-wise), and `toString` (printing terms), or turn the arrays into
  immutable sequences.
- Validate in `fromRaw`: equal array lengths, exponent vectors of length
  `numVars`, non-negative exponents, `numVars ≥ 0`.
- Compute `prodCount` as a `Long` and reject results above the maximum array
  size.
- Add tests for a multi-term product, for a pinned digest value, and for the
  validation rules.

## 10. Building, running and testing

Compile the kernel the way CI does:

    scala-cli compile --scala 3.5.2 \
      src/main/scala/uor/kernel/U64.scala \
      src/main/scala/uor/kernel/Poly64.scala

Run the unit tests:

    scala-cli test --scala 3.5.2 --test-only uor.kernel.Poly64Test \
      src/main/scala/uor/kernel src/test/scala/uor/kernel/Poly64Test.scala

Produce the Poly64 vectors for the Dex oracle (200 cases, 600 lines):

    scala-cli run --server=false --scala 3.5.2 \
      src/main/scala/uor/kernel dex/scala/Poly64Vectors.scala -- 200

Use it from a REPL:

    scala-cli repl --scala 3.5.2 src/main/scala/uor/kernel
    scala> import uor.kernel.*
    scala> val p = Poly64.fromRaw(2, Array(Array(1,0), Array(0,1)), Array(1L, 1L))
    scala> (p * p).termCount    // 3
    scala> (p * p).eval(Array(2L, 3L))   // 25

## 11. Worked example

Take the README example, the raw terms `1·x_0`, `(2^64 − 1)·x_0` and
`7·x_1^2` in two variables.

1. `fromRaw` sorts the exponent vectors `(1,0), (1,0), (0,2)` into
   `(0,2), (1,0), (1,0)`.
2. It writes `(0,2):7` as the first output term.
3. It writes `(1,0):1` as the second.
4. The third raw term has the same monomial as the last written one; the
   coefficients `1 + (2^64 − 1)` wrap to 0, so `k` drops back to 1.
5. The result is `7·x_1^2`, one term (E1).
6. `toFlatU64` gives `[0, 2, 7]`.
7. `digestBytes` hashes `04 00000002 00000001 00000000 00000002
   0000000000000007` (1 + 4 + 4 + 4 + 4 + 8 = 25 bytes), giving
   `02a9fb47…7d49` (E2).
8. `urn` gives `urn:uor:poly64:02a9fb47034782411ec4ce49acee55fa5ab5092da46d928d48adbed5bccb7d49` (E3).

Squaring `x_0 + x_1`:

1. The raw products are `(2,0):1`, `(1,1):1`, `(1,1):1`, `(0,2):1`.
2. Sorted: `(0,2), (1,1), (1,1), (2,0)`.
3. Merged: `(0,2):1, (1,1):2, (2,0):1` (E12).
4. Evaluated at `(2, 3)`: `9 + 2·6 + 4 = 25`.

With `booleanQuota`: the raw products become `(1,0):1`, `(1,1):1`,
`(1,1):1`, `(0,1):1`, which canonicalise to `(0,1):1, (1,0):1, (1,1):2`
(E13).

## 12. Reproducing the measurements

The measurements above come from this program, saved as `/tmp/p64exp/Exp.scala`
and run from the repository root with

    scala-cli run --server=false --scala 3.5.2 src/main/scala/uor/kernel /tmp/p64exp/Exp.scala

It is not committed, because it is a one-off probe rather than a test.

```scala
//> using scala 3.5.2
import uor.kernel.*

object Exp:
  def hex(a: Array[Byte]) = a.map(b => f"${b & 0xff}%02x").mkString
  def show(p: Poly64) = (0 until p.termCount).map(i => p.exps(i).mkString("(", ",", ")") + ":" + java.lang.Long.toUnsignedString(p.coeffs(i))).mkString(" + ")
  def main(args: Array[String]): Unit =
    val a = Poly64.fromRaw(2, Array(Array(1, 0), Array(1, 0), Array(0, 2)), Array(1L, -1L, 7L))
    println("E1 README example: " + show(a) + " terms=" + a.termCount)
    println("E2 digest(7*x1^2) = " + hex(a.digestBytes))
    println("E3 urn = " + a.urn)
    val z = Poly64.zero(2)
    println("E4 zero digest = " + hex(z.digestBytes) + " urn=" + z.urn)
    val b = Poly64.fromRaw(2, Array(Array(0, 2)), Array(7L))
    println("E5 a == b (same polynomial, separate arrays): " + (a == b) + "; digests equal: " + java.util.Arrays.equals(a.digestBytes, b.digestBytes))
    println("E6 zero(2) == zero(2): " + (Poly64.zero(2) == Poly64.zero(2)))
    val t = Poly64.fromRaw(1, Array(Array(1), Array(1), Array(1)), Array(5L, -5L, 3L))
    println("E7 5x - 5x + 3x = " + show(t))
    val neg = Poly64.fromRaw(1, Array(Array(-1), Array(2)), Array(1L, 1L))
    println("E8 exponent -1 accepted: " + show(neg) + "; eval at 3 = " + neg.eval(Array(3L)).value)
    val big = Poly64.fromRaw(1, Array(Array(Int.MaxValue)), Array(1L))
    val flat = big.toFlatU64
    println("E9 exponent 2^31-1 flat = " + flat.mkString(","))
    val back = Poly64.fromFlatU64(1, Array(0x80000000L, 1L))
    println("E10 flat exponent 2^31 decodes to " + back.exps(0)(0))
    val odd = Poly64.fromFlatU64(2, Array(1L, 2L, 3L, 4L, 5L))
    println("E11 flat length 5 with stride 3 -> terms " + odd.termCount + ": " + show(odd))
    val x = Poly64.fromRaw(2, Array(Array(1, 0)), Array(1L))
    val y = Poly64.fromRaw(2, Array(Array(0, 1)), Array(1L))
    val s = x + y
    println("E12 (x0+x1)*(x0+x1) = " + show(s * s))
    println("E13 boolean quota (x0+x1)^2 = " + show(s.*(s, booleanQuota = true)))
    val two = Poly64.fromRaw(1, Array(Array(0)), Array(Long.MinValue))
    println("E14 2^63 * 2 = " + show(two * Poly64.fromRaw(1, Array(Array(0)), Array(2L))))
    println("E15 eval 3+5x at 2 = " + Poly64.fromRaw(1, Array(Array(0), Array(1)), Array(3L, 5L)).eval(Array(2L)))
    try { x + Poly64.zero(3); println("E16 no error") } catch { case e: IllegalArgumentException => println("E16 + with different numVars: " + e.getMessage) }
    val mixed = Poly64.fromRaw(2, Array(Array(1), Array(1, 0)), Array(1L, 1L))
    println("E17 fromRaw with exponent vectors of length 1 and 2 under numVars=2: terms " + mixed.termCount + " -> " + show(mixed))
    try { println("E18 digest: " + hex(mixed.digestBytes)) } catch { case e: Throwable => println("E18 digest throws " + e.getClass.getSimpleName) }
    val r = new scala.util.Random(1)
    def rp(n: Int) = Poly64.fromRaw(3, Array.fill(n)(Array.fill(3)(r.nextInt(20))), Array.fill(n)(r.nextLong()))
    val p = rp(1000); val q = rp(1000)
    for _ <- 1 to 3 do { p * q; p + q }
    val t0 = System.nanoTime(); var acc = 0; for _ <- 1 to 10 do acc += (p * q).termCount
    val t1 = System.nanoTime(); for _ <- 1 to 1000 do acc += (p + q).termCount
    val t2 = System.nanoTime()
    println(f"E19 1000x1000-term product (3 vars, exps<20): ${(t1 - t0) / 10 / 1e6}%.1f ms each, result ${(p * q).termCount} terms; p.termCount=${p.termCount}, q.termCount=${q.termCount}")
    println(f"E20 sum of the same: ${(t2 - t1) / 1000 / 1e3}%.1f us each")
```

Output on the build machine (2026-11-15):

```
E1 README example: (0,2):7 terms=1
E2 digest(7*x1^2) = 02a9fb47034782411ec4ce49acee55fa5ab5092da46d928d48adbed5bccb7d49
E3 urn = urn:uor:poly64:02a9fb47034782411ec4ce49acee55fa5ab5092da46d928d48adbed5bccb7d49
E4 zero digest = 97f47c511e0ae8e4bf03ccea459cc1a58c532d845e675ca678960d8c9aa5b048 urn=urn:uor:poly64:97f47c511e0ae8e4bf03ccea459cc1a58c532d845e675ca678960d8c9aa5b048
E5 a == b (same polynomial, separate arrays): false; digests equal: true
E6 zero(2) == zero(2): false
E7 5x - 5x + 3x = (1):3
E8 exponent -1 accepted: (2):1 + (-1):1; eval at 3 = 10
E9 exponent 2^31-1 flat = 2147483647,1
E10 flat exponent 2^31 decodes to -2147483648
E11 flat length 5 with stride 3 -> terms 1: (1,2):3
E12 (x0+x1)*(x0+x1) = (0,2):1 + (1,1):2 + (2,0):1
E13 boolean quota (x0+x1)^2 = (0,1):1 + (1,0):1 + (1,1):2
E14 2^63 * 2 =
E15 eval 3+5x at 2 = 13
E16 + with different numVars: requirement failed: Variable count mismatch
E17 fromRaw with exponent vectors of length 1 and 2 under numVars=2: terms 2 -> (1):1 + (1,0):1
E18 digest throws ArrayIndexOutOfBoundsException
E19 1000x1000-term product (3 vars, exps<20): 351.2 ms each, result 55003 terms; p.termCount=938, q.termCount=938
E20 sum of the same: 40.6 us each
```

E14 prints nothing after the equals sign because the product is the zero
polynomial. The timings in E19 and E20 depend on the machine and on JIT
warm-up; they are given to show orders of magnitude, not as benchmarks. The
random polynomials have 938 terms rather than 1000 because `fromRaw` merged
the repeated monomials among 1000 random draws.
