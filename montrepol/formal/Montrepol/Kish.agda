-- SPDX-License-Identifier: AGPL-3.0-or-later
{-# OPTIONS --safe --without-K #-}

-- Kish's effective sample size of weights w is (Σ w)² / Σ w². Its lower
-- bound of 1 is the inequality Σ w² ≤ (Σ w)², proved here over ℕ for every
-- list of weights. (The upper bound, k_eff ≤ n, is Cauchy–Schwarz and is not
-- proved here.)
module Montrepol.Kish where

open import Montrepol.Equality
open import Montrepol.Nat
open ≡-Reasoning

infixr 5 _∷_
data List (A : Set) : Set where
  []  : List A
  _∷_ : A → List A → List A

sum : List ℕ → ℕ
sum []       = zero
sum (x ∷ xs) = x + sum xs

sumSq : List ℕ → ℕ
sumSq []       = zero
sumSq (x ∷ xs) = x * x + sumSq xs

infix 4 _≤_
data _≤_ (m n : ℕ) : Set where
  by : (k : ℕ) → m + k ≡ n → m ≤ n

-- (a + b) + (k + (c + d)) = (a + c) + (d + (b + k)), in a commutative monoid.
rearrange : ∀ a b k c d → (a + b) + (k + (c + d)) ≡ (a + c) + (d + (b + k))
rearrange a b k c d = begin
  (a + b) + (k + (c + d))   ≡⟨ +-assoc a b (k + (c + d)) ⟩
  a + (b + (k + (c + d)))   ≡⟨ cong (a +_) (sym (+-assoc b k (c + d))) ⟩
  a + ((b + k) + (c + d))   ≡⟨ cong (a +_) (+-comm (b + k) (c + d)) ⟩
  a + ((c + d) + (b + k))   ≡⟨ cong (a +_) (+-assoc c d (b + k)) ⟩
  a + (c + (d + (b + k)))   ≡⟨ sym (+-assoc a c (d + (b + k))) ⟩
  (a + c) + (d + (b + k))   ∎

kish-step : ∀ x s b k → b + k ≡ s * s →
            (x * x + b) + (k + (x * s + s * x)) ≡ (x + s) * (x + s)
kish-step x s b k p = begin
  (x * x + b) + (k + (x * s + s * x))   ≡⟨ rearrange (x * x) b k (x * s) (s * x) ⟩
  (x * x + x * s) + (s * x + (b + k))   ≡⟨ cong (λ t → (x * x + x * s) + (s * x + t)) p ⟩
  (x * x + x * s) + (s * x + s * s)     ≡⟨ sym (cong₂ _+_ (*-distribˡ x x s) (*-distribˡ s x s)) ⟩
  x * (x + s) + s * (x + s)             ≡⟨ sym (*-distribʳ x s (x + s)) ⟩
  (x + s) * (x + s)                     ∎

-- Σ w² ≤ (Σ w)²: the witness is the sum of the cross terms 2·wᵢ·wⱼ.
kish-lower : ∀ ws → sumSq ws ≤ sum ws * sum ws
kish-lower []       = by zero refl
kish-lower (x ∷ xs) with kish-lower xs
... | by k p = by (k + (x * sum xs + sum xs * x)) (kish-step x (sum xs) (sumSq xs) k p)
