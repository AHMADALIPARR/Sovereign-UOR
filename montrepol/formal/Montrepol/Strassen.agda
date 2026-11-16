-- SPDX-License-Identifier: AGPL-3.0-or-later
{-# OPTIONS --safe --without-K #-}

-- Strassen's identities: seven products recombine into the four entries of
-- a 2×2 product.
--
-- They hold in every Bilinear structure: an abelian group with a product that
-- distributes on both sides, with no associativity, commutativity or unit
-- assumed. The products and combinations are those of MP.Matrix.strassenSq;
-- that the Haskell matches them is checked by reading, not mechanically.
open import Montrepol.Bilinear

module Montrepol.Strassen {R : Set} (B : Bilinear R) where

open import Montrepol.Equality
open import Montrepol.Nat using (ℕ) renaming (_+_ to _+ℕ_)
open import Montrepol.Data
open Bilinear B
open Derived B
open import Montrepol.Solver B

module Entries (a₁₁ a₁₂ a₂₁ a₂₂ b₁₁ b₁₂ b₂₁ b₂₂ : R) where

  M₁ M₂ M₃ M₄ M₅ M₆ M₇ : R
  M₁ = (a₁₁ + a₂₂) * (b₁₁ + b₂₂)
  M₂ = (a₂₁ + a₂₂) * b₁₁
  M₃ = a₁₁ * (b₁₂ - b₂₂)
  M₄ = a₂₂ * (b₂₁ - b₁₁)
  M₅ = (a₁₁ + a₁₂) * b₂₂
  M₆ = (a₂₁ - a₁₁) * (b₁₁ + b₁₂)
  M₇ = (a₁₂ - a₂₂) * (b₂₁ + b₂₂)

  -- The sixteen products aᵢ bⱼ, as the atoms of the group equations.
  ρ : Vec R 16
  ρ = a₁₁ * b₁₁ ∷ a₁₁ * b₁₂ ∷ a₁₁ * b₂₁ ∷ a₁₁ * b₂₂ ∷
      a₁₂ * b₁₁ ∷ a₁₂ * b₁₂ ∷ a₁₂ * b₂₁ ∷ a₁₂ * b₂₂ ∷
      a₂₁ * b₁₁ ∷ a₂₁ * b₁₂ ∷ a₂₁ * b₂₁ ∷ a₂₁ * b₂₂ ∷
      a₂₂ * b₁₁ ∷ a₂₂ * b₁₂ ∷ a₂₂ * b₂₁ ∷ a₂₂ * b₂₂ ∷ []

  -- P i j is the atom aᵢ bⱼ, counting a₁₁, a₁₂, a₂₁, a₂₂ (and likewise b) as 0..3.
  P : ℕ → ℕ → Expr 16
  P i j = atom (toFin (i +ℕ i +ℕ i +ℕ i +ℕ j))

  -- Each product, expanded by distributivity alone.
  E₁ E₂ E₃ E₄ E₅ E₆ E₇ : Expr 16
  E₁ = (P 0 0 ⊕ P 0 3) ⊕ (P 3 0 ⊕ P 3 3)
  E₂ = P 2 0 ⊕ P 3 0
  E₃ = P 0 1 ⊕ ⊝ P 0 3
  E₄ = P 3 2 ⊕ ⊝ P 3 0
  E₅ = P 0 3 ⊕ P 1 3
  E₆ = (P 2 0 ⊕ P 2 1) ⊕ (⊝ P 0 0 ⊕ ⊝ P 0 1)
  E₇ = (P 1 2 ⊕ P 1 3) ⊕ (⊝ P 3 2 ⊕ ⊝ P 3 3)

  m₁ : M₁ ≡ ⟦ E₁ ⟧ ρ
  m₁ = expand-++ a₁₁ a₂₂ b₁₁ b₂₂
  m₂ : M₂ ≡ ⟦ E₂ ⟧ ρ
  m₂ = expand-+· a₂₁ a₂₂ b₁₁
  m₃ : M₃ ≡ ⟦ E₃ ⟧ ρ
  m₃ = expand-·- a₁₁ b₁₂ b₂₂
  m₄ : M₄ ≡ ⟦ E₄ ⟧ ρ
  m₄ = expand-·- a₂₂ b₂₁ b₁₁
  m₅ : M₅ ≡ ⟦ E₅ ⟧ ρ
  m₅ = expand-+· a₁₁ a₁₂ b₂₂
  m₆ : M₆ ≡ ⟦ E₆ ⟧ ρ
  m₆ = expand--+ a₂₁ a₁₁ b₁₁ b₁₂
  m₇ : M₇ ≡ ⟦ E₇ ⟧ ρ
  m₇ = expand--+ a₁₂ a₂₂ b₂₁ b₂₂

  -- The four entries. In each, the products are expanded and the resulting
  -- equation in the free abelian group on the aᵢ bⱼ is decided by `solve`.
  strassen-c11 : M₁ + M₄ - M₅ + M₇ ≡ a₁₁ * b₁₁ + a₁₂ * b₂₁
  strassen-c11 = trans (cong₂ _+_ (cong₂ _-_ (cong₂ _+_ m₁ m₄) m₅) m₇)
                       (solve (E₁ ⊕ E₄ ⊕ ⊝ E₅ ⊕ E₇) (P 0 0 ⊕ P 1 2) refl ρ)

  strassen-c12 : M₃ + M₅ ≡ a₁₁ * b₁₂ + a₁₂ * b₂₂
  strassen-c12 = trans (cong₂ _+_ m₃ m₅) (solve (E₃ ⊕ E₅) (P 0 1 ⊕ P 1 3) refl ρ)

  strassen-c21 : M₂ + M₄ ≡ a₂₁ * b₁₁ + a₂₂ * b₂₁
  strassen-c21 = trans (cong₂ _+_ m₂ m₄) (solve (E₂ ⊕ E₄) (P 2 0 ⊕ P 3 2) refl ρ)

  strassen-c22 : M₁ - M₂ + M₃ + M₆ ≡ a₂₁ * b₁₂ + a₂₂ * b₂₂
  strassen-c22 = trans (cong₂ _+_ (cong₂ _+_ (cong₂ _-_ m₁ m₂) m₃) m₆)
                       (solve (E₁ ⊕ ⊝ E₂ ⊕ E₃ ⊕ E₆) (P 2 1 ⊕ P 3 3) refl ρ)
