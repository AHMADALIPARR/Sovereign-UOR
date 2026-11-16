-- SPDX-License-Identifier: AGPL-3.0-or-later
{-# OPTIONS --safe --without-K #-}

-- An abelian group with a product that distributes over addition on both
-- sides. Nothing else is assumed: the product need not be associative or
-- commutative and need not have a unit. Every ring is one, and so is the set
-- of n×n matrices over a ring (standard, not proved here), which is why
-- Strassen's identities proved over this structure apply to blocks.
module Montrepol.Bilinear where

open import Montrepol.Equality

record Bilinear (R : Set) : Set where
  infixl 6 _+_
  infixl 7 _*_
  infix  8 -_
  field
    _+_ : R → R → R
    _*_ : R → R → R
    -_  : R → R
    0#  : R
    +-assoc      : ∀ x y z → (x + y) + z ≡ x + (y + z)
    +-comm       : ∀ x y → x + y ≡ y + x
    +-identityʳ  : ∀ x → x + 0# ≡ x
    neg-inverseʳ : ∀ x → x + (- x) ≡ 0#
    distribˡ     : ∀ x y z → x * (y + z) ≡ x * y + x * z
    distribʳ     : ∀ x y z → (y + z) * x ≡ y * x + z * x

-- Consequences of the axioms, each derived rather than assumed.
module Derived {R : Set} (B : Bilinear R) where
  open Bilinear B
  open ≡-Reasoning

  infixl 6 _-_
  _-_ : R → R → R
  x - y = x + - y

  +-identityˡ : ∀ x → 0# + x ≡ x
  +-identityˡ x = trans (+-comm 0# x) (+-identityʳ x)

  neg-inverseˡ : ∀ x → - x + x ≡ 0#
  neg-inverseˡ x = trans (+-comm (- x) x) (neg-inverseʳ x)

  -- Inverses are unique: x + y = 0 forces y = - x.
  neg-unique : ∀ x y → x + y ≡ 0# → y ≡ - x
  neg-unique x y p = begin
    y               ≡⟨ sym (+-identityˡ y) ⟩
    0# + y          ≡⟨ cong (_+ y) (sym (neg-inverseˡ x)) ⟩
    (- x + x) + y   ≡⟨ +-assoc (- x) x y ⟩
    - x + (x + y)   ≡⟨ cong (- x +_) p ⟩
    - x + 0#        ≡⟨ +-identityʳ (- x) ⟩
    - x             ∎

  neg-zero : - 0# ≡ 0#
  neg-zero = sym (neg-unique 0# 0# (+-identityʳ 0#))

  neg-involutive : ∀ x → - (- x) ≡ x
  neg-involutive x = sym (neg-unique (- x) x (neg-inverseˡ x))

  interchange : ∀ a b c d → (a + b) + (c + d) ≡ (a + c) + (b + d)
  interchange a b c d = begin
    (a + b) + (c + d)   ≡⟨ +-assoc a b (c + d) ⟩
    a + (b + (c + d))   ≡⟨ cong (a +_) (sym (+-assoc b c d)) ⟩
    a + ((b + c) + d)   ≡⟨ cong (λ t → a + (t + d)) (+-comm b c) ⟩
    a + ((c + b) + d)   ≡⟨ cong (a +_) (+-assoc c b d) ⟩
    a + (c + (b + d))   ≡⟨ sym (+-assoc a c (b + d)) ⟩
    (a + c) + (b + d)   ∎

  neg-+ : ∀ x y → - (x + y) ≡ - x + - y
  neg-+ x y = sym (neg-unique (x + y) (- x + - y) (begin
    (x + y) + (- x + - y)   ≡⟨ interchange x y (- x) (- y) ⟩
    (x + - x) + (y + - y)   ≡⟨ cong₂ _+_ (neg-inverseʳ x) (neg-inverseʳ y) ⟩
    0# + 0#                 ≡⟨ +-identityʳ 0# ⟩
    0#                      ∎))

  -- The only idempotent of a group is its identity.
  idempotent-zero : ∀ a → a + a ≡ a → a ≡ 0#
  idempotent-zero a p = begin
    a                ≡⟨ sym (+-identityʳ a) ⟩
    a + 0#           ≡⟨ cong (a +_) (sym (neg-inverseʳ a)) ⟩
    a + (a + - a)    ≡⟨ sym (+-assoc a a (- a)) ⟩
    (a + a) + - a    ≡⟨ cong (_+ - a) p ⟩
    a + - a          ≡⟨ neg-inverseʳ a ⟩
    0#               ∎

  *-zeroʳ : ∀ x → x * 0# ≡ 0#
  *-zeroʳ x = idempotent-zero (x * 0#)
    (trans (sym (distribˡ x 0# 0#)) (cong (x *_) (+-identityʳ 0#)))

  *-zeroˡ : ∀ x → 0# * x ≡ 0#
  *-zeroˡ x = idempotent-zero (0# * x)
    (trans (sym (distribʳ x 0# 0#)) (cong (_* x) (+-identityʳ 0#)))

  *-negʳ : ∀ x y → x * (- y) ≡ - (x * y)
  *-negʳ x y = neg-unique (x * y) (x * (- y))
    (trans (sym (distribˡ x y (- y))) (trans (cong (x *_) (neg-inverseʳ y)) (*-zeroʳ x)))

  *-negˡ : ∀ x y → (- x) * y ≡ - (x * y)
  *-negˡ x y = neg-unique (x * y) ((- x) * y)
    (trans (sym (distribʳ y x (- x))) (trans (cong (_* y) (neg-inverseʳ x)) (*-zeroˡ y)))

  -- Expanding the four shapes of product Strassen uses.
  expand-++ : ∀ x y z w → (x + y) * (z + w) ≡ (x * z + x * w) + (y * z + y * w)
  expand-++ x y z w = trans (distribʳ (z + w) x y) (cong₂ _+_ (distribˡ x z w) (distribˡ y z w))

  expand-+· : ∀ x y z → (x + y) * z ≡ x * z + y * z
  expand-+· x y z = distribʳ z x y

  expand-·- : ∀ x z w → x * (z - w) ≡ x * z + - (x * w)
  expand-·- x z w = trans (distribˡ x z (- w)) (cong (x * z +_) (*-negʳ x w))

  expand--+ : ∀ x y z w → (x - y) * (z + w) ≡ (x * z + x * w) + (- (y * z) + - (y * w))
  expand--+ x y z w =
    trans (expand-++ x (- y) z w) (cong ((x * z + x * w) +_) (cong₂ _+_ (*-negˡ y z) (*-negˡ y w)))
