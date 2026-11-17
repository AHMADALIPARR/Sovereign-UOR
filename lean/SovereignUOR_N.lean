-- SPDX-License-Identifier: AGPL-3.0-or-later
/-
  SovereignUOR_N.lean
  The B_n canonicalization for arbitrary n, Lean 4 core (Init) only.
  No Mathlib, no lake. Check with:  lean lean/SovereignUOR_N.lean

  Model:
    * a state is a List Int (length n is arbitrary)
    * Swap i j transposes coordinates i and j (no-op if i == j or out of range)
    * Flip i negates coordinate i (no-op if out of range)
    * a WeylWord is a List Gen, applied with foldr
    * canonical v = insertion sort of v.map Int.natAbs (a List Nat)
-/

namespace SovereignUORN

/-! ## Insertion sort on Nat -/

def ins (a : Nat) : List Nat → List Nat
  | [] => [a]
  | b :: l => if a ≤ b then a :: b :: l else b :: ins a l

def isort : List Nat → List Nat
  | [] => []
  | a :: l => ins a (isort l)

/-- Sorted ascending (≤), stated with core `List.Pairwise`. -/
abbrev Sorted (l : List Nat) : Prop := l.Pairwise (· ≤ ·)

theorem ins_perm (a : Nat) : ∀ l : List Nat, (ins a l).Perm (a :: l)
  | [] => List.Perm.refl _
  | b :: l => by
    unfold ins
    split
    · exact List.Perm.refl _
    · exact ((ins_perm a l).cons b).trans (List.Perm.swap a b l)

theorem isort_perm : ∀ l : List Nat, (isort l).Perm l
  | [] => List.Perm.refl _
  | a :: l => (ins_perm a (isort l)).trans ((isort_perm l).cons a)

theorem ins_sorted (a : Nat) : ∀ l : List Nat, Sorted l → Sorted (ins a l)
  | [], _ => by simp [ins]
  | b :: l, h => by
    unfold ins
    split
    · rename_i hab
      refine List.Pairwise.cons ?_ h
      intro x hx
      rcases List.mem_cons.mp hx with rfl | hx
      · exact hab
      · exact Nat.le_trans hab (List.rel_of_pairwise_cons h hx)
    · rename_i hab
      have hb : ∀ x ∈ l, b ≤ x := fun x hx => List.rel_of_pairwise_cons h hx
      refine List.Pairwise.cons ?_ (ins_sorted a l h.of_cons)
      intro x hx
      have hx' : x ∈ a :: l := (ins_perm a l).subset hx
      rcases List.mem_cons.mp hx' with rfl | hx'
      · omega
      · exact hb _ hx'

theorem isort_sorted : ∀ l : List Nat, Sorted (isort l)
  | [] => List.Pairwise.nil
  | a :: l => ins_sorted a _ (isort_sorted l)

theorem ins_comm (a b : Nat) : ∀ l : List Nat, ins a (ins b l) = ins b (ins a l)
  | [] => by
    simp only [ins]
    by_cases h1 : a ≤ b <;> by_cases h2 : b ≤ a <;> simp [h1, h2] <;> omega
  | c :: l => by
    by_cases hb : b ≤ c <;> by_cases ha : a ≤ c <;> by_cases hab : a ≤ b <;> by_cases hba : b ≤ a <;>
      simp [ins, ha, hb, hab, hba, ins_comm a b l] <;> omega

/-- Insertion sort sends permutations to the same list. -/
theorem isort_eq_of_perm {l₁ l₂ : List Nat} (p : l₁.Perm l₂) : isort l₁ = isort l₂ := by
  induction p with
  | nil => rfl
  | cons a _ ih => simp [isort, ih]
  | swap a b l => simp [isort, ins_comm]
  | trans _ _ ih₁ ih₂ => exact ih₁.trans ih₂

theorem ins_of_sorted (a : Nat) : ∀ l : List Nat, Sorted (a :: l) → ins a l = a :: l
  | [], _ => rfl
  | b :: l, h => by
    have : a ≤ b := List.rel_of_pairwise_cons h (List.mem_cons_self)
    simp [ins, this]

theorem isort_of_sorted : ∀ l : List Nat, Sorted l → isort l = l
  | [], _ => rfl
  | a :: l, h => by
    simp only [isort]
    rw [isort_of_sorted l h.of_cons]
    exact ins_of_sorted a l h

/-! ## Generators -/

/-- Transpose coordinates i and j; no-op when i == j or either is out of range. -/
def swapAt {α : Type} (i j : Nat) (v : List α) : List α :=
  if h : i < v.length ∧ j < v.length ∧ i ≠ j then
    (v.set i (v[j]'h.2.1)).set j (v[i]'h.1)
  else v

/-- Negate coordinate i; no-op when out of range. -/
def flipAt (i : Nat) (v : List Int) : List Int :=
  if h : i < v.length then v.set i (-(v[i]'h)) else v

inductive Gen where
  | swap (i j : Nat)
  | flip (i : Nat)
  deriving Repr, DecidableEq

def applyGen : Gen → List Int → List Int
  | .swap i j, v => swapAt i j v
  | .flip i, v => flipAt i v

abbrev WeylWord := List Gen

def applyWeylWord (w : WeylWord) (v : List Int) : List Int :=
  w.foldr applyGen v

def magnitudes (v : List Int) : List Nat := v.map Int.natAbs

def canonical (v : List Int) : List Nat := isort (magnitudes v)

/-- Lift a canonical Nat vector back to an Int state. -/
def lift (c : List Nat) : List Int := c.map Int.ofNat

/-! ## Involutivity -/

theorem swapAt_length {α : Type} (i j : Nat) (v : List α) : (swapAt i j v).length = v.length := by
  unfold swapAt; split <;> simp

theorem swapAt_swapAt {α : Type} (i j : Nat) (v : List α) : swapAt i j (swapAt i j v) = v := by
  unfold swapAt
  by_cases h : i < v.length ∧ j < v.length ∧ i ≠ j
  · rw [dite_eq_left h]
    have h' : i < ((v.set i (v[j]'h.2.1)).set j (v[i]'h.1)).length ∧
        j < ((v.set i (v[j]'h.2.1)).set j (v[i]'h.1)).length ∧ i ≠ j := by
      simp [h.1, h.2.1, h.2.2]
    rw [dite_eq_left h']
    apply List.ext_getElem
    · simp
    · intro k hk _
      simp only [List.getElem_set]
      by_cases hki : i = k <;> by_cases hkj : j = k <;> simp_all
  · rw [dite_eq_right h, dite_eq_right h]

theorem flipAt_flipAt (i : Nat) (v : List Int) : flipAt i (flipAt i v) = v := by
  unfold flipAt
  by_cases h : i < v.length
  · rw [dite_eq_left h]
    have h' : i < (v.set i (-(v[i]'h))).length := by simp [h]
    rw [dite_eq_left h']
    apply List.ext_getElem
    · simp
    · intro k hk _
      simp only [List.getElem_set]
      by_cases hki : i = k <;> simp_all
  · rw [dite_eq_right h, dite_eq_right h]

theorem applyGen_involutive (g : Gen) (v : List Int) : applyGen g (applyGen g v) = v := by
  cases g with
  | swap i j => exact swapAt_swapAt i j v
  | flip i => exact flipAt_flipAt i v

/-! ## Invariance of canonical -/

theorem swapAt_perm (i j : Nat) (v : List Nat) : (swapAt i j v).Perm v := by
  unfold swapAt
  split
  · rename_i h
    rw [List.perm_iff_count]
    intro b
    have hj1 : j < (v.set i (v[j]'h.2.1)).length := by simp [h.2.1]
    rw [List.count_set hj1, List.count_set h.1]
    have hget : (v.set i (v[j]'h.2.1))[j]'hj1 = v[j]'h.2.1 := by
      simp [h.2.2]
    rw [hget]
    have hle : (if (v[i]'h.1) == b then 1 else 0) ≤ v.count b := by
      by_cases e : (v[i]'h.1) == b
      · simp only [e, ite_true]
        have : (v[i]'h.1) = b := by simpa using e
        exact List.count_pos_iff.mpr (this ▸ List.getElem_mem h.1)
      · simp [e]
    revert hle
    split <;> split <;> omega
  · exact List.Perm.refl _

theorem magnitudes_swapAt (i j : Nat) (v : List Int) :
    magnitudes (swapAt i j v) = swapAt i j (magnitudes v) := by
  unfold magnitudes swapAt
  by_cases h : i < v.length ∧ j < v.length ∧ i ≠ j
  · have h' : i < (v.map Int.natAbs).length ∧ j < (v.map Int.natAbs).length ∧ i ≠ j := by
      simpa using h
    rw [dite_eq_left h, dite_eq_left h']
    simp [List.map_set]
  · have h' : ¬ (i < (v.map Int.natAbs).length ∧ j < (v.map Int.natAbs).length ∧ i ≠ j) := by
      simpa using h
    rw [dite_eq_right h, dite_eq_right h']

theorem magnitudes_flipAt (i : Nat) (v : List Int) : magnitudes (flipAt i v) = magnitudes v := by
  unfold magnitudes flipAt
  split
  · rename_i h
    rw [List.map_set]
    apply List.ext_getElem
    · simp
    · intro k _ _
      simp only [List.getElem_set, List.getElem_map]
      split <;> simp_all
  · rfl

theorem canonical_applyGen (g : Gen) (v : List Int) : canonical (applyGen g v) = canonical v := by
  cases g with
  | swap i j =>
    unfold canonical
    rw [applyGen, magnitudes_swapAt]
    exact isort_eq_of_perm (swapAt_perm i j _)
  | flip i =>
    unfold canonical
    rw [applyGen, magnitudes_flipAt]

theorem canonical_applyWeylWord (w : WeylWord) (v : List Int) :
    canonical (applyWeylWord w v) = canonical v := by
  induction w with
  | nil => rfl
  | cons g w ih =>
    simp only [applyWeylWord, List.foldr_cons] at *
    rw [canonical_applyGen, ih]

/-! ## Output shape -/

theorem canonical_sorted (v : List Int) : Sorted (canonical v) := isort_sorted _

theorem canonical_perm (v : List Int) : (canonical v).Perm (magnitudes v) := isort_perm _

theorem magnitudes_lift (c : List Nat) : magnitudes (lift c) = c := by
  simp [magnitudes, lift, List.map_map, Function.comp_def]

theorem canonical_idempotent (v : List Int) : canonical (lift (canonical v)) = canonical v := by
  unfold canonical
  rw [magnitudes_lift]
  exact isort_of_sorted _ (isort_sorted _)

/-! ## Sanity checks by evaluation -/

example : canonical [3, -1, 2] = [1, 2, 3] := by decide
example : applyWeylWord [.swap 0 2, .flip 1] [3, -1, 2] = [2, 1, 3] := by decide
example : canonical (applyWeylWord [.swap 0 2, .flip 1, .flip 0] [3, -1, 2]) = [1, 2, 3] := by decide

end SovereignUORN

#print axioms SovereignUORN.applyGen_involutive
#print axioms SovereignUORN.canonical_applyGen
#print axioms SovereignUORN.canonical_applyWeylWord
#print axioms SovereignUORN.canonical_sorted
#print axioms SovereignUORN.canonical_perm
#print axioms SovereignUORN.canonical_idempotent
