-- SPDX-License-Identifier: AGPL-3.0-or-later
{-# OPTIONS --safe --without-K #-}

-- Finite indices, vectors and pairs.
module Montrepol.Data where

open import Montrepol.Nat using (ℕ; zero; suc)

data Fin : ℕ → Set where
  fzero : {n : ℕ} → Fin (suc n)
  fsuc  : {n : ℕ} → Fin n → Fin (suc n)

-- The index k, saturating at the last one. Used only to name atoms; a wrong
-- index makes a proof fail to check, it cannot make a false one check.
toFin : {n : ℕ} → ℕ → Fin (suc n)
toFin zero              = fzero
toFin {zero}  (suc k)   = fzero
toFin {suc n} (suc k)   = fsuc (toFin k)

infixr 5 _∷_
data Vec (A : Set) : ℕ → Set where
  []  : Vec A zero
  _∷_ : {n : ℕ} → A → Vec A n → Vec A (suc n)

lookup : {A : Set} {n : ℕ} → Vec A n → Fin n → A
lookup (x ∷ xs) fzero    = x
lookup (x ∷ xs) (fsuc i) = lookup xs i

infixr 4 _,_
record _×_ (A B : Set) : Set where
  constructor _,_
  field
    fst : A
    snd : B
open _×_ public
