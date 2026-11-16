// SPDX-License-Identifier: AGPL-3.0-only
// Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
// Copyright (C) 2026 Ahmad Parr

//> using scala 3.5.2
package uor.kernel

/** Simple wrapper for unsigned 64-bit integers (wrapping arithmetic on Long). */
final case class U64(value: Long) extends AnyVal:
  override def toString: String =
    if value >= 0 then value.toString
    else java.lang.Long.toUnsignedString(value)
