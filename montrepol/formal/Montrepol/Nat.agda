-- SPDX-License-Identifier: AGPL-3.0-or-later
{-# OPTIONS --safe --without-K #-}

-- Natural numbers and the semiring laws the Kish bound needs.
module Montrepol.Nat where

open import Montrepol.Equality
open ≡-Reasoning

data ℕ : Set where
  zero : ℕ
  suc  : ℕ → ℕ

{-# BUILTIN NATURAL ℕ #-}

infixl 6 _+_
infixl 7 _*_

_+_ : ℕ → ℕ → ℕ
zero  + n = n
suc m + n = suc (m + n)

_*_ : ℕ → ℕ → ℕ
zero  * n = zero
suc m * n = n + m * n

+-identityʳ : ∀ m → m + zero ≡ m
+-identityʳ zero    = refl
+-identityʳ (suc m) = cong suc (+-identityʳ m)

+-suc : ∀ m n → m + suc n ≡ suc (m + n)
+-suc zero    n = refl
+-suc (suc m) n = cong suc (+-suc m n)

+-comm : ∀ m n → m + n ≡ n + m
+-comm zero    n = sym (+-identityʳ n)
+-comm (suc m) n = trans (cong suc (+-comm m n)) (sym (+-suc n m))

+-assoc : ∀ m n k → (m + n) + k ≡ m + (n + k)
+-assoc zero    n k = refl
+-assoc (suc m) n k = cong suc (+-assoc m n k)

*-zeroʳ : ∀ m → m * zero ≡ zero
*-zeroʳ zero    = refl
*-zeroʳ (suc m) = *-zeroʳ m

*-suc : ∀ m n → m * suc n ≡ m + m * n
*-suc zero    n = refl
*-suc (suc m) n = cong suc (begin
    n + m * suc n    ≡⟨ cong (n +_) (*-suc m n) ⟩
    n + (m + m * n)  ≡⟨ sym (+-assoc n m (m * n)) ⟩
    (n + m) + m * n  ≡⟨ cong (_+ m * n) (+-comm n m) ⟩
    (m + n) + m * n  ≡⟨ +-assoc m n (m * n) ⟩
    m + (n + m * n)  ∎)

*-comm : ∀ m n → m * n ≡ n * m
*-comm zero    n = sym (*-zeroʳ n)
*-comm (suc m) n = trans (cong (n +_) (*-comm m n)) (sym (*-suc n m))

*-distribʳ : ∀ m n k → (m + n) * k ≡ m * k + n * k
*-distribʳ zero    n k = refl
*-distribʳ (suc m) n k = trans (cong (k +_) (*-distribʳ m n k)) (sym (+-assoc k (m * k) (n * k)))

*-distribˡ : ∀ k m n → k * (m + n) ≡ k * m + k * n
*-distribˡ k m n =
  trans (*-comm k (m + n)) (trans (*-distribʳ m n k) (cong₂ _+_ (*-comm m k) (*-comm n k)))
