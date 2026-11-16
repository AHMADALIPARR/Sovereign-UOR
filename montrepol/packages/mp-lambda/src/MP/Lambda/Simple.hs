-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | The simply typed lambda calculus with integers and booleans, in de Bruijn
-- form: a type checker and a call-by-value small-step semantics.
--
-- The metatheory (progress, preservation, the substitution lemma, and that
-- evaluation terminates) is tested on random well-typed terms in @test/@. It
-- is evidence, not proof; the proofs of these facts are classical.
--
-- The @{-\@ ... \@-}@ comments are Liquid Haskell refinements. GHC ignores
-- them; the separate build in @liquid/@ compiles this very file with the
-- Liquid Haskell plugin and Z3, and checks them, together with termination of
-- every function here and totality of every pattern match.
module MP.Lambda.Simple
  ( Ty (..)
  , Term (..)
  , typeOf
  , isValue
  , shift
  , subst
  , step
  , evaluate
  , size
  ) where

infixr 5 `TArr`

data Ty = TInt | TBool | TArr Ty Ty
  deriving (Eq, Show)

-- | @Var 0@ is the innermost binder.
data Term
  = Var Int
  | Lam Ty Term
  | App Term Term
  | Lit Integer
  | BoolLit Bool
  | Add Term Term
  | Leq Term Term
  | If Term Term Term
  deriving (Eq, Show)

-- | The type of a term in a context, if it has one. Terminates because every
-- recursive call is on a strictly smaller term.
{-@ typeOf :: [Ty] -> t:Term -> Maybe Ty / [size t] @-}
typeOf :: [Ty] -> Term -> Maybe Ty
typeOf ctx t = case t of
  Var i -> case drop i ctx of
    (ty : _) | i >= 0 -> Just ty
    _ -> Nothing
  Lam a body -> TArr a <$> typeOf (a : ctx) body
  App f x -> do
    tf <- typeOf ctx f
    tx <- typeOf ctx x
    case tf of
      TArr a b | a == tx -> Just b
      _ -> Nothing
  Lit _ -> Just TInt
  BoolLit _ -> Just TBool
  Add a b -> do
    ta <- typeOf ctx a
    tb <- typeOf ctx b
    if ta == TInt && tb == TInt then Just TInt else Nothing
  Leq a b -> do
    ta <- typeOf ctx a
    tb <- typeOf ctx b
    if ta == TInt && tb == TInt then Just TBool else Nothing
  If c a b -> do
    tc <- typeOf ctx c
    ta <- typeOf ctx a
    tb <- typeOf ctx b
    if tc == TBool && ta == tb then Just ta else Nothing

isValue :: Term -> Bool
isValue t = case t of
  Lam _ _ -> True
  Lit _ -> True
  BoolLit _ -> True
  _ -> False

-- | @shift d c t@ adds @d@ to every variable of @t@ at or above the cutoff @c@.
shift :: Int -> Int -> Term -> Term
shift d c t = case t of
  Var i -> Var (if i >= c then i + d else i)
  Lam a body -> Lam a (shift d (c + 1) body)
  App f x -> App (shift d c f) (shift d c x)
  Add a b -> Add (shift d c a) (shift d c b)
  Leq a b -> Leq (shift d c a) (shift d c b)
  If x a b -> If (shift d c x) (shift d c a) (shift d c b)
  _ -> t

-- | @subst j s t@ is @t[j := s]@.
subst :: Int -> Term -> Term -> Term
subst j s t = case t of
  Var i -> if i == j then s else Var i
  Lam a body -> Lam a (subst (j + 1) (shift 1 0 s) body)
  App f x -> App (subst j s f) (subst j s x)
  Add a b -> Add (subst j s a) (subst j s b)
  Leq a b -> Leq (subst j s a) (subst j s b)
  If x a b -> If (subst j s x) (subst j s a) (subst j s b)
  _ -> t

-- | One call-by-value step, or 'Nothing' for a value or a stuck term.
step :: Term -> Maybe Term
step t = case t of
  App (Lam _ body) v | isValue v -> Just (shift (-1) 0 (subst 0 (shift 1 0 v) body))
  App f x
    | not (isValue f) -> (`App` x) <$> step f
    | otherwise -> App f <$> step x
  Add (Lit a) (Lit b) -> Just (Lit (a + b))
  Add a b
    | not (isValue a) -> (`Add` b) <$> step a
    | otherwise -> Add a <$> step b
  Leq (Lit a) (Lit b) -> Just (BoolLit (a <= b))
  Leq a b
    | not (isValue a) -> (`Leq` b) <$> step a
    | otherwise -> Leq a <$> step b
  If (BoolLit c) a b -> Just (if c then a else b)
  If c a b -> (\c' -> If c' a b) <$> step c
  _ -> Nothing

-- | Step until a value, a stuck term, or the fuel runs out ('Nothing').
-- Terminates because the fuel decreases and is checked before each step.
{-@ evaluate :: fuel:Int -> Term -> Maybe Term / [fuel] @-}
evaluate :: Int -> Term -> Maybe Term
evaluate fuel t
  | isValue t = Just t
  | fuel <= 0 = Nothing
  | otherwise = case step t of
      Just t' -> evaluate (fuel - 1) t'
      Nothing -> Just t

{-@ measure size @-}
{-@ size :: Term -> {v:Int | v >= 1} @-}
size :: Term -> Int
size t = case t of
  Lam _ b -> 1 + size b
  App a b -> 1 + size a + size b
  Add a b -> 1 + size a + size b
  Leq a b -> 1 + size a + size b
  If c a b -> 1 + size c + size a + size b
  _ -> 1
