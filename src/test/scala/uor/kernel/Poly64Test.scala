// SPDX-License-Identifier: AGPL-3.0-only
// Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
// Copyright (C) 2026 Ahmad Parr

//> using scala 3.5.2
//> using dep org.scalameta::munit::1.0.0
package uor.kernel

import munit.FunSuite

class Poly64Test extends FunSuite:

  test("zero polynomial") {
    val z = Poly64.zero(2)
    assertEquals(z.termCount, 0)
  }

  test("addition merges like terms and drops zeros") {
    // 3·x0 + 5·x1  +  (-3)·x0  ==>  5·x1
    val a = Poly64.fromRaw(2,
      Array(Array(1, 0), Array(0, 1)),
      Array(3L, 5L))
    val b = Poly64.fromRaw(2,
      Array(Array(1, 0)),
      Array(-3L))
    val s = a + b
    assertEquals(s.termCount, 1)
    assertEquals(s.coeffs(0), 5L)
    assert(java.util.Arrays.equals(s.exps(0), Array(0, 1)))
  }

  test("wrapping addition mod 2^64 cancels") {
    val a = Poly64.fromRaw(1, Array(Array(0)), Array(1L))
    val b = Poly64.fromRaw(1, Array(Array(0)), Array(-1L))
    val s = a + b
    assertEquals(s.termCount, 0)
  }

  test("fromRaw + toFlatU64 round-trip") {
    val p = Poly64.fromRaw(2,
      Array(Array(0, 2), Array(1, 0)),
      Array(7L, 1L))
    val flat = p.toFlatU64
    val q = Poly64.fromFlatU64(2, flat)
    assertEquals(q.termCount, 2)
    assertEquals(q.coeffs.toSeq, Seq(7L, 1L))
  }

  test("booleanQuota enforces x_i^2 = x_i") {
    val x0 = Poly64.fromRaw(1, Array(Array(1)), Array(1L))
    val sq = x0 * x0                      // ordinary: x0^2
    val sqB = x0 * x0                     // still ordinary
    val sqBool = x0.*(x0, booleanQuota = true)
    assertEquals(sq.termCount, 1)
    assertEquals(sq.exps(0)(0), 2)
    assertEquals(sqBool.exps(0)(0), 1)
  }

  test("canonical example from README") {
    // (1·x0) + ((2^64-1)·x0) + (7·x1^2)  ==>  7·x1^2
    val neg1 = -1L
    val raw = Poly64.fromRaw(2,
      Array(Array(1, 0), Array(1, 0), Array(0, 2)),
      Array(1L, neg1, 7L))
    assertEquals(raw.termCount, 1)
    assertEquals(raw.coeffs(0), 7L)
    assert(java.util.Arrays.equals(raw.exps(0), Array(0, 2)))
  }

  test("digest is deterministic 32 bytes") {
    val p = Poly64.fromRaw(1, Array(Array(3)), Array(42L))
    val d1 = p.digestBytes
    val d2 = p.digestBytes
    assertEquals(d1.length, 32)
    assert(java.util.Arrays.equals(d1, d2))
    assert(p.urn.startsWith("urn:uor:poly64:"))
    assertEquals(p.urn.length, "urn:uor:poly64:".length + 64)
  }

  test("eval basic") {
    // 3 + 5·x0  at x0=2  ==> 13
    val p = Poly64.fromRaw(1,
      Array(Array(0), Array(1)),
      Array(3L, 5L))
    val r = p.eval(Array(2L))
    assertEquals(r.value, 13L)
  }
