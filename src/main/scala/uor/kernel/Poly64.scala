// SPDX-License-Identifier: AGPL-3.0-only
// Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
// Copyright (C) 2026 Ahmad Parr

//> using scala 3.5.2
package uor.kernel

import java.nio.ByteBuffer
import java.security.MessageDigest
import java.util.Arrays

/** Canonical sparse multivariate polynomial in (Z / 2^64 Z)[x_0, ..., x_{k-1}].
  * Monomials are stored sorted lexicographically by exponent vector with non-zero U64 coefficients.
  */
final case class Poly64 private (numVars: Int, exps: Array[Array[Int]], coeffs: Array[Long]):
  def termCount: Int = coeffs.length

  /** Ring addition in (Z / 2^64 Z)[X] in O(m + n) merge time */
  def +(other: Poly64): Poly64 =
    require(numVars == other.numVars, "Variable count mismatch")
    val maxTerms = termCount + other.termCount
    val outExps  = new Array[Array[Int]](maxTerms)
    val outCoeff = new Array[Long](maxTerms)
    var i = 0; var j = 0; var k = 0

    while i < termCount && j < other.termCount do
      val cmp = Arrays.compareUnsigned(exps(i), other.exps(j))
      if cmp < 0 then
        outExps(k)  = exps(i)
        outCoeff(k) = coeffs(i)
        i += 1; k += 1
      else if cmp > 0 then
        outExps(k)  = other.exps(j)
        outCoeff(k) = other.coeffs(j)
        j += 1; k += 1
      else
        val sum = coeffs(i) + other.coeffs(j) // wrapping mod 2^64
        if sum != 0L then
          outExps(k)  = exps(i)
          outCoeff(k) = sum
          k += 1
        i += 1; j += 1

    while i < termCount do
      outExps(k) = exps(i); outCoeff(k) = coeffs(i); i += 1; k += 1
    while j < other.termCount do
      outExps(k) = other.exps(j); outCoeff(k) = other.coeffs(j); j += 1; k += 1

    Poly64(numVars, Arrays.copyOf(outExps, k), Arrays.copyOf(outCoeff, k))

  /** Ring multiplication in (Z / 2^64 Z)[X]; set booleanQuota = true to enforce x_i^2 = x_i */
  def *(other: Poly64, booleanQuota: Boolean = false): Poly64 =
    require(numVars == other.numVars, "Variable count mismatch")
    val prodCount = termCount * other.termCount
    if prodCount == 0 then return Poly64.zero(numVars)

    val rawExps  = new Array[Array[Int]](prodCount)
    val rawCoeff = new Array[Long](prodCount)
    var idx      = 0
    var i        = 0
    while i < termCount do
      var j = 0
      while j < other.termCount do
        val e = new Array[Int](numVars)
        var v = 0
        while v < numVars do
          val sumExp = exps(i)(v) + other.exps(j)(v)
          e(v) = if booleanQuota && sumExp > 1 then 1 else sumExp
          v += 1
        rawExps(idx)  = e
        rawCoeff(idx) = coeffs(i) * other.coeffs(j) // wrapping mod 2^64
        idx += 1
        j += 1
      i += 1
    Poly64.fromRaw(numVars, rawExps, rawCoeff)

  /** Evaluate polynomial at point x in (Z / 2^64 Z)^k */
  def eval(point: Array[Long]): U64 =
    require(point.length == numVars)
    var acc = 0L
    var i   = 0
    while i < termCount do
      var term = coeffs(i)
      var v    = 0
      while v < numVars do
        var e = exps(i)(v)
        var b = point(v)
        while e > 0 do
          if (e & 1) == 1 then term *= b
          b *= b
          e >>>= 1
        v += 1
      acc += term
      i += 1
    U64(acc)

  /** Pack canonical form into flat stride-(numVars + 1) u64 array for C ABI / BQN FFI */
  def toFlatU64: Array[Long] =
    val stride = numVars + 1
    val flat   = new Array[Long](termCount * stride)
    var i      = 0
    while i < termCount do
      val base = i * stride
      var v    = 0
      while v < numVars do
        flat(base + v) = exps(i)(v).toLong & 0xFFFFFFFFL
        v += 1
      flat(base + numVars) = coeffs(i)
      i += 1
    flat

  /** Deterministic canonical SHA-256 digest bytes (32 bytes) */
  def digestBytes: Array[Byte] =
    val byteLen = 1 + 4 + 4 + termCount * (numVars * 4 + 8)
    val buf     = ByteBuffer.allocate(byteLen)
    buf.put(0x04.toByte).putInt(numVars).putInt(termCount)
    var i = 0
    while i < termCount do
      var v = 0
      while v < numVars do
        buf.putInt(exps(i)(v))
        v += 1
      buf.putLong(coeffs(i))
      i += 1
    MessageDigest.getInstance("SHA-256").digest(buf.array())

  def urn: String =
    val hex = "0123456789abcdef".toCharArray
    val d   = digestBytes
    val out = new Array[Char](64)
    var i   = 0
    while i < 32 do
      val b = d(i) & 0xFF
      out(i * 2)     = hex(b >>> 4)
      out(i * 2 + 1) = hex(b & 0x0F)
      i += 1
    s"urn:uor:poly64:${new String(out)}"

object Poly64:
  def zero(numVars: Int): Poly64 =
    Poly64(numVars, Array.empty, Array.empty)

  /** Canonicalize arbitrary unsorted / duplicate / zero-coeff terms */
  def fromRaw(numVars: Int, rawExps: Array[Array[Int]], rawCoeff: Array[Long]): Poly64 =
    val n = rawCoeff.length
    if n == 0 then return zero(numVars)

    // Sort indices by lexicographic (unsigned) order of exponent vectors.
    // Arrays.sort(int[], Comparator) does not exist in the JDK, so we use Scala's sortInPlaceWith.
    val order = Array.tabulate(n)(identity)
    order.sortInPlaceWith((a, b) => Arrays.compareUnsigned(rawExps(a), rawExps(b)) < 0)

    val outExps  = new Array[Array[Int]](n)
    val outCoeff = new Array[Long](n)
    var k        = 0
    var i        = 0
    while i < n do
      val idx = order(i)
      val c   = rawCoeff(idx)
      if c != 0L then
        if k > 0 && Arrays.equals(outExps(k - 1), rawExps(idx)) then
          val merged = outCoeff(k - 1) + c
          if merged == 0L then k -= 1
          else outCoeff(k - 1) = merged
        else
          outExps(k)  = rawExps(idx).clone()
          outCoeff(k) = c
          k += 1
      i += 1
    Poly64(numVars, Arrays.copyOf(outExps, k), Arrays.copyOf(outCoeff, k))

  /** Decode flat stride-(numVars + 1) u64 array from C ABI / BQN FFI */
  def fromFlatU64(numVars: Int, flat: Array[Long]): Poly64 =
    val stride = numVars + 1
    val n      = flat.length / stride
    val exps   = new Array[Array[Int]](n)
    val coeffs = new Array[Long](n)
    var i      = 0
    while i < n do
      val base = i * stride
      val e    = new Array[Int](numVars)
      var v    = 0
      while v < numVars do
        e(v) = flat(base + v).toInt
        v += 1
      exps(i)   = e
      coeffs(i) = flat(base + numVars)
      i += 1
    fromRaw(numVars, exps, coeffs)
