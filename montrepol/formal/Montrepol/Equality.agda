-- SPDX-License-Identifier: AGPL-3.0-or-later
{-# OPTIONS --safe --without-K #-}

-- Propositional equality and equational reasoning, written here so that the
-- proofs depend on nothing but Agda's kernel.
module Montrepol.Equality where

infix 4 _≡_
data _≡_ {A : Set} (x : A) : A → Set where
  refl : x ≡ x

sym : {A : Set} {x y : A} → x ≡ y → y ≡ x
sym refl = refl

trans : {A : Set} {x y z : A} → x ≡ y → y ≡ z → x ≡ z
trans refl q = q

cong : {A B : Set} (f : A → B) {x y : A} → x ≡ y → f x ≡ f y
cong f refl = refl

cong₂ : {A B C : Set} (f : A → B → C) {x y : A} {u v : B} → x ≡ y → u ≡ v → f x u ≡ f y v
cong₂ f refl refl = refl

module ≡-Reasoning {A : Set} where
  infix  1 begin_
  infixr 2 _≡⟨_⟩_
  infix  3 _∎

  begin_ : {x y : A} → x ≡ y → x ≡ y
  begin p = p

  _≡⟨_⟩_ : (x : A) {y z : A} → x ≡ y → y ≡ z → x ≡ z
  x ≡⟨ p ⟩ q = trans p q

  _∎ : (x : A) → x ≡ x
  x ∎ = refl
