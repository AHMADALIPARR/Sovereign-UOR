-- SPDX-License-Identifier: AGPL-3.0-or-later
{-# OPTIONS --safe --without-K #-}

-- A decision procedure for equations in an abelian group, by reflection.
--
-- An expression over n atoms is normalised to two vectors of natural numbers:
-- how many times each atom occurs positively and negatively. Two expressions
-- are equal in every abelian group when p₁ + q₂ = p₂ + q₁ pointwise, which
-- Agda decides by computation. `sound` is the theorem that makes this
-- trustworthy: evaluating an expression and evaluating its normal form agree,
-- in every model of the axioms.
open import Montrepol.Bilinear

module Montrepol.Solver {R : Set} (B : Bilinear R) where

open import Montrepol.Equality
open import Montrepol.Nat using (ℕ; zero; suc) renaming (_+_ to _+ℕ_)
open import Montrepol.Data
open Bilinear B
open Derived B
open ≡-Reasoning

infixl 6 _⊕_
infix  8 ⊝_
data Expr (n : ℕ) : Set where
  atom : Fin n → Expr n
  zer  : Expr n
  _⊕_  : Expr n → Expr n → Expr n
  ⊝_   : Expr n → Expr n

⟦_⟧ : {n : ℕ} → Expr n → Vec R n → R
⟦ atom i ⟧ ρ = lookup ρ i
⟦ zer    ⟧ ρ = 0#
⟦ e ⊕ f  ⟧ ρ = ⟦ e ⟧ ρ + ⟦ f ⟧ ρ
⟦ ⊝ e    ⟧ ρ = - ⟦ e ⟧ ρ

zeros : {n : ℕ} → Vec ℕ n
zeros {zero}  = []
zeros {suc n} = 0 ∷ zeros

unit : {n : ℕ} → Fin n → Vec ℕ n
unit fzero    = 1 ∷ zeros
unit (fsuc i) = 0 ∷ unit i

infixl 6 _⊞_
_⊞_ : {n : ℕ} → Vec ℕ n → Vec ℕ n → Vec ℕ n
[]       ⊞ []       = []
(a ∷ as) ⊞ (b ∷ bs) = (a +ℕ b) ∷ (as ⊞ bs)

NF : ℕ → Set
NF n = Vec ℕ n × Vec ℕ n

norm : {n : ℕ} → Expr n → NF n
norm (atom i) = unit i , zeros
norm zer      = zeros , zeros
norm (e ⊕ f)  = fst (norm e) ⊞ fst (norm f) , snd (norm e) ⊞ snd (norm f)
norm (⊝ e)    = snd (norm e) , fst (norm e)

infixr 7 _·_
_·_ : ℕ → R → R
zero  · x = 0#
suc k · x = x + k · x

Σ : {n : ℕ} → Vec ℕ n → Vec R n → R
Σ []       []       = 0#
Σ (k ∷ ks) (x ∷ xs) = k · x + Σ ks xs

value : {n : ℕ} → NF n → Vec R n → R
value nf ρ = Σ (fst nf) ρ - Σ (snd nf) ρ

·-+ : ∀ j k x → (j +ℕ k) · x ≡ j · x + k · x
·-+ zero    k x = sym (+-identityˡ (k · x))
·-+ (suc j) k x = trans (cong (x +_) (·-+ j k x)) (sym (+-assoc x (j · x) (k · x)))

Σ-⊞ : {n : ℕ} (u v : Vec ℕ n) (ρ : Vec R n) → Σ (u ⊞ v) ρ ≡ Σ u ρ + Σ v ρ
Σ-⊞ []       []       []       = sym (+-identityʳ 0#)
Σ-⊞ (a ∷ us) (b ∷ vs) (x ∷ ρ)  = begin
  (a +ℕ b) · x + Σ (us ⊞ vs) ρ          ≡⟨ cong₂ _+_ (·-+ a b x) (Σ-⊞ us vs ρ) ⟩
  (a · x + b · x) + (Σ us ρ + Σ vs ρ)   ≡⟨ interchange (a · x) (b · x) (Σ us ρ) (Σ vs ρ) ⟩
  (a · x + Σ us ρ) + (b · x + Σ vs ρ)   ∎

Σ-zeros : {n : ℕ} (ρ : Vec R n) → Σ zeros ρ ≡ 0#
Σ-zeros []      = refl
Σ-zeros (x ∷ ρ) = trans (+-identityˡ (Σ zeros ρ)) (Σ-zeros ρ)

Σ-unit : {n : ℕ} (i : Fin n) (ρ : Vec R n) → Σ (unit i) ρ ≡ lookup ρ i
Σ-unit fzero    (x ∷ ρ) = trans (cong₂ _+_ (+-identityʳ x) (Σ-zeros ρ)) (+-identityʳ x)
Σ-unit (fsuc i) (x ∷ ρ) = trans (+-identityˡ (Σ (unit i) ρ)) (Σ-unit i ρ)

-- Soundness of normalisation, in every model of the axioms.
sound : {n : ℕ} (e : Expr n) (ρ : Vec R n) → ⟦ e ⟧ ρ ≡ value (norm e) ρ
sound (atom i) ρ = begin
  lookup ρ i                        ≡⟨ sym (Σ-unit i ρ) ⟩
  Σ (unit i) ρ                      ≡⟨ sym (+-identityʳ (Σ (unit i) ρ)) ⟩
  Σ (unit i) ρ + 0#                 ≡⟨ cong (Σ (unit i) ρ +_) (sym neg-zero) ⟩
  Σ (unit i) ρ + - 0#               ≡⟨ cong (λ t → Σ (unit i) ρ + - t) (sym (Σ-zeros ρ)) ⟩
  Σ (unit i) ρ + - Σ zeros ρ        ∎
sound zer ρ = sym (neg-inverseʳ (Σ zeros ρ))
sound (e ⊕ f) ρ = begin
  ⟦ e ⟧ ρ + ⟦ f ⟧ ρ                   ≡⟨ cong₂ _+_ (sound e ρ) (sound f ρ) ⟩
  (Pe + - Qe) + (Pf + - Qf)           ≡⟨ interchange Pe (- Qe) Pf (- Qf) ⟩
  (Pe + Pf) + (- Qe + - Qf)           ≡⟨ cong₂ _+_ (sym (Σ-⊞ pe pf ρ)) (sym (neg-+ Qe Qf)) ⟩
  Σ (pe ⊞ pf) ρ + - (Qe + Qf)         ≡⟨ cong (λ t → Σ (pe ⊞ pf) ρ + - t) (sym (Σ-⊞ qe qf ρ)) ⟩
  Σ (pe ⊞ pf) ρ + - Σ (qe ⊞ qf) ρ     ∎
  where
    pe = fst (norm e)
    qe = snd (norm e)
    pf = fst (norm f)
    qf = snd (norm f)
    Pe = Σ pe ρ
    Qe = Σ qe ρ
    Pf = Σ pf ρ
    Qf = Σ qf ρ
sound (⊝ e) ρ = begin
  - ⟦ e ⟧ ρ            ≡⟨ cong -_ (sound e ρ) ⟩
  - (P + - Q)          ≡⟨ neg-+ P (- Q) ⟩
  - P + - (- Q)        ≡⟨ cong (- P +_) (neg-involutive Q) ⟩
  - P + Q              ≡⟨ +-comm (- P) Q ⟩
  Q + - P              ∎
  where
    P = Σ (fst (norm e)) ρ
    Q = Σ (snd (norm e)) ρ

-- a + d = c + b gives a - b = c - d.
balance : ∀ a b c d → a + d ≡ c + b → a - b ≡ c - d
balance a b c d p = begin
  a + - b                       ≡⟨ sym (+-identityʳ (a + - b)) ⟩
  (a + - b) + 0#                ≡⟨ cong ((a + - b) +_) (sym (neg-inverseʳ d)) ⟩
  (a + - b) + (d + - d)         ≡⟨ interchange a (- b) d (- d) ⟩
  (a + d) + (- b + - d)         ≡⟨ cong (_+ (- b + - d)) p ⟩
  (c + b) + (- b + - d)         ≡⟨ +-assoc c b (- b + - d) ⟩
  c + (b + (- b + - d))         ≡⟨ cong (c +_) (sym (+-assoc b (- b) (- d))) ⟩
  c + ((b + - b) + - d)         ≡⟨ cong (λ t → c + (t + - d)) (neg-inverseʳ b) ⟩
  c + (0# + - d)                ≡⟨ cong (c +_) (+-identityˡ (- d)) ⟩
  c + - d                       ∎

-- The decision procedure. The equation between normal forms is closed and is
-- discharged by `refl`, i.e. by computation; everything else is `sound`.
solve : {n : ℕ} (e f : Expr n) →
        fst (norm e) ⊞ snd (norm f) ≡ fst (norm f) ⊞ snd (norm e) →
        (ρ : Vec R n) → ⟦ e ⟧ ρ ≡ ⟦ f ⟧ ρ
solve e f eq ρ = begin
  ⟦ e ⟧ ρ               ≡⟨ sound e ρ ⟩
  value (norm e) ρ      ≡⟨ balance (Σ pe ρ) (Σ qe ρ) (Σ pf ρ) (Σ qf ρ) cross ⟩
  value (norm f) ρ      ≡⟨ sym (sound f ρ) ⟩
  ⟦ f ⟧ ρ               ∎
  where
    pe = fst (norm e)
    qe = snd (norm e)
    pf = fst (norm f)
    qf = snd (norm f)
    cross : Σ pe ρ + Σ qf ρ ≡ Σ pf ρ + Σ qe ρ
    cross = begin
      Σ pe ρ + Σ qf ρ     ≡⟨ sym (Σ-⊞ pe qf ρ) ⟩
      Σ (pe ⊞ qf) ρ       ≡⟨ cong (λ v → Σ v ρ) eq ⟩
      Σ (pf ⊞ qe) ρ       ≡⟨ Σ-⊞ pf qe ρ ⟩
      Σ pf ρ + Σ qe ρ     ∎
