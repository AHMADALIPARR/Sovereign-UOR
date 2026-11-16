-- SPDX-License-Identifier: AGPL-3.0-only
-- Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
-- Copyright (C) 2026 Ahmad Parr

namespace SovereignUOR

/-- 3-axis integer coordinate state before Weyl-orbit quotienting. -/
structure Vec3 where
  x : Int
  y : Int
  z : Int
  deriving DecidableEq, Repr

/-- Simple Coxeter reflection generators of the Weyl group B₃ (order 2³ · 3! = 48). -/
def s1 (v : Vec3) : Vec3 := ⟨v.y, v.x, v.z⟩
def s2 (v : Vec3) : Vec3 := ⟨v.x, v.z, v.y⟩
def s3 (v : Vec3) : Vec3 := ⟨v.x, v.y, -v.z⟩

/-! ### 1. Kernel-Checked Coxeter Presentation of B₃ -/

theorem s1_involutive (v : Vec3) : s1 (s1 v) = v := by
  cases v; rfl

theorem s2_involutive (v : Vec3) : s2 (s2 v) = v := by
  cases v; rfl

theorem s3_involutive (v : Vec3) : s3 (s3 v) = v := by
  cases v; simp [s3]

theorem braid_s1_s2 (v : Vec3) :
    s1 (s2 (s1 (s2 (s1 (s2 v))))) = v := by
  cases v; rfl

theorem commute_s1_s3 (v : Vec3) :
    s1 (s3 (s1 (s3 v))) = v := by
  cases v; rfl

theorem braid_s2_s3 (v : Vec3) :
    s2 (s3 (s2 (s3 (s2 (s3 (s2 (s3 v))))))) = v := by
  cases v; simp [s2, s3]

/-! ### 2. Fundamental Weyl Chamber Projection (Canonical Normal Form) -/

def sort3 (a b c : Nat) : Nat × Nat × Nat :=
  let (a1, b1) := if a ≤ b then (a, b) else (b, a)
  let (b2, c1) := if b1 ≤ c then (b1, c) else (c, b1)
  let (a2, b3) := if a1 ≤ b2 then (a1, b2) else (b2, a1)
  (a2, b3, c1)

/-- Maps any vector into the unique fundamental Weyl chamber `0 ≤ c₁ ≤ c₂ ≤ c₃`. -/
def canonical (v : Vec3) : Nat × Nat × Nat :=
  sort3 v.x.natAbs v.y.natAbs v.z.natAbs

/-- Lifts a canonical chamber coordinate back into `Vec3`. -/
def liftCanonical (c : Nat × Nat × Nat) : Vec3 :=
  ⟨Int.ofNat c.1, Int.ofNat c.2.1, Int.ofNat c.2.2⟩

theorem sort3_swap12 (a b c : Nat) : sort3 b a c = sort3 a b c := by
  simp only [sort3, Prod.mk.injEq]
  refine ⟨?_, ?_, ?_⟩ <;> (repeat' split) <;> omega

theorem sort3_swap23 (a b c : Nat) : sort3 a c b = sort3 a b c := by
  simp only [sort3, Prod.mk.injEq]
  refine ⟨?_, ?_, ?_⟩ <;> (repeat' split) <;> omega

theorem sort3_sorted (a b c : Nat) :
    (sort3 a b c).1 ≤ (sort3 a b c).2.1 ∧ (sort3 a b c).2.1 ≤ (sort3 a b c).2.2 := by
  simp only [sort3]
  refine ⟨?_, ?_⟩ <;> (repeat' split) <;> omega

theorem sort3_of_sorted {a b c : Nat} (hab : a ≤ b) (hbc : b ≤ c) :
    sort3 a b c = (a, b, c) := by
  simp only [sort3, Prod.mk.injEq]
  refine ⟨?_, ?_, ?_⟩ <;> (repeat' split) <;> omega

theorem canonical_s1 (v : Vec3) : canonical (s1 v) = canonical v :=
  sort3_swap12 v.x.natAbs v.y.natAbs v.z.natAbs

theorem canonical_s2 (v : Vec3) : canonical (s2 v) = canonical v :=
  sort3_swap23 v.x.natAbs v.y.natAbs v.z.natAbs

theorem canonical_s3 (v : Vec3) : canonical (s3 v) = canonical v := by
  simp [canonical, s3]

/-! ### 3. Arbitrary Weyl-Word Orbit Invariance & Idempotence -/

inductive WeylWord where
  | id   : WeylWord
  | s1   : WeylWord
  | s2   : WeylWord
  | s3   : WeylWord
  | comp : WeylWord → WeylWord → WeylWord
  deriving DecidableEq, Repr

def eval : WeylWord → Vec3 → Vec3
  | .id,         v => v
  | .s1,         v => s1 v
  | .s2,         v => s2 v
  | .s3,         v => s3 v
  | .comp w₁ w₂, v => eval w₁ (eval w₂ v)

/-- Every element of the Weyl group preserves the canonical UOR normal form. -/
theorem canonical_weyl_invariant (w : WeylWord) (v : Vec3) :
    canonical (eval w v) = canonical v := by
  induction w generalizing v with
  | id => rfl
  | s1 => exact canonical_s1 v
  | s2 => exact canonical_s2 v
  | s3 => exact canonical_s3 v
  | comp w₁ w₂ ih₁ ih₂ =>
    simp only [eval]
    rw [ih₁, ih₂]

/-- Projecting a canonical normal form is strictly idempotent. -/
theorem canonical_idempotent (v : Vec3) :
    canonical (liftCanonical (canonical v)) = canonical v := by
  have hs := sort3_sorted v.x.natAbs v.y.natAbs v.z.natAbs
  simp only [canonical, liftCanonical, Int.natAbs_ofNat]
  exact sort3_of_sorted hs.1 hs.2

/-- Canonical representatives are injective on the fundamental Weyl chamber. -/
theorem liftCanonical_injective {c₁ c₂ : Nat × Nat × Nat}
    (h : liftCanonical c₁ = liftCanonical c₂) : c₁ = c₂ := by
  cases c₁; cases c₂
  simp only [liftCanonical, Vec3.mk.injEq, Int.ofNat.injEq] at h
  obtain ⟨h1, h2, h3⟩ := h
  subst h1; subst h2; subst h3
  rfl

end SovereignUOR
