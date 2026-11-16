// SPDX-License-Identifier: AGPL-3.0-only
// Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
// Copyright (C) 2026 Ahmad Parr

//> using scala 3.5.2
//> using dep org.graalvm.sdk:nativeimage:24.2.1
package uor.ffi

import org.graalvm.nativeimage.IsolateThread
import org.graalvm.nativeimage.c.function.CEntryPoint
import org.graalvm.nativeimage.c.`type`.{CCharPointer, CLongPointer}
import uor.kernel.*
import java.nio.ByteBuffer
import java.security.MessageDigest

class UorExports

object UorExports:

  /** In-place D_{2^64} dihedral vector transform: data[i] = (flip ? ~data[i] : data[i]) + shift */
  @scala.annotation.static
  @CEntryPoint(name = "uor_d64_transform_inplace")
  def d64TransformInplace(
      thread: IsolateThread,
      data: CLongPointer,
      len: Long,
      shift: Long,
      flip: Int
  ): Unit =
    // CLongPointer index overloads take Int (or SignedWord), not Long
    var i = 0
    val n = len.toInt
    if flip != 0 then
      while i < n do
        data.write(i, (~data.read(i)) + shift)
        i += 1
    else
      while i < n do
        data.write(i, data.read(i) + shift)
        i += 1

  /** Compute 65-bin Hamming weight (stratum) histogram across a u64 buffer */
  @scala.annotation.static
  @CEntryPoint(name = "uor_strata_histogram")
  def strataHistogram(
      thread: IsolateThread,
      data: CLongPointer,
      len: Long,
      outCounts65: CLongPointer
  ): Unit =
    var b = 0
    while b < 65 do
      outCounts65.write(b, 0L)
      b += 1
    var i = 0
    val n = len.toInt
    while i < n do
      val w = java.lang.Long.bitCount(data.read(i))
      outCounts65.write(w, outCounts65.read(w) + 1L)
      i += 1

  /** Write 32-byte canonical SHA-256 digest of a D_{2^64} element into outDigest32 */
  @scala.annotation.static
  @CEntryPoint(name = "uor_d64_digest")
  def d64Digest(
      thread: IsolateThread,
      shift: Long,
      flip: Int,
      outDigest32: CCharPointer
  ): Unit =
    val buf = ByteBuffer.allocate(10)
      .put(0x03.toByte)
      .putLong(shift)
      .put(if flip != 0 then 1.toByte else 0.toByte)
      .array()
    val digest = MessageDigest.getInstance("SHA-256").digest(buf)
    var i = 0
    while i < 32 do
      outDigest32.write(i, digest(i))
      i += 1

  /** Canonicalize a flat multivariate polynomial over (Z / 2^64 Z)[x_0..x_{k-1}] in-place,
    * write its 32-byte canonical SHA-256 digest, and return the reduced term count.
    */
  @scala.annotation.static
  @CEntryPoint(name = "uor_poly64_canonicalize")
  def poly64Canonicalize(
      thread: IsolateThread,
      numVars: Int,
      termCount: Int,
      flatTermsInOut: CLongPointer,
      outDigest32: CCharPointer
  ): Int =
    val stride = numVars + 1
    val total  = termCount * stride
    val buf    = new Array[Long](total)
    var i      = 0
    while i < total do
      buf(i) = flatTermsInOut.read(i)
      i += 1

    val canon   = Poly64.fromFlatU64(numVars, buf)
    val outFlat = canon.toFlatU64
    var j       = 0
    while j < outFlat.length do
      flatTermsInOut.write(j, outFlat(j))
      j += 1

    val digest = canon.digestBytes
    var d      = 0
    while d < 32 do
      outDigest32.write(d, digest(d))
      d += 1

    canon.termCount
