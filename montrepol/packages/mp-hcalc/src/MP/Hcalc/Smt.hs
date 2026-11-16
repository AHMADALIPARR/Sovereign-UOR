-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | Quantifier-free linear rational arithmetic with propositional structure:
-- a lazy DPLL(T) loop over "MP.Hcalc.Sat" and "MP.Hcalc.Linear".
--
-- The SAT solver proposes a truth assignment to the atoms; Fourier–Motzkin
-- either finds a rational model of the arithmetic it implies, or returns
-- Farkas multipliers, from which a lemma clause is learned and the loop goes
-- round again. The answer is certified either way:
--
-- * 'Sat' carries a model, which 'evalFormula' checks against the formula
--   itself, with no reference to the encoding.
-- * 'Unsat' carries every learned lemma with its Farkas multipliers and a
--   resolution refutation of the clauses plus lemmas. 'checkUnsat' checks
--   both. What it shares with the solver, and so trusts, is the Tseitin
--   encoding ('tseitin') and the reading of terms as linear expressions.
--
-- The semantics is over the rationals. A formula valid over the rationals is
-- valid over the integers, but not conversely: @x < y ==> x + 1 <= y@ holds
-- for integers and is reported invalid here, with a rational counter-model.
module MP.Hcalc.Smt
  ( Term (..)
  , Formula (..)
  , Model (..)
  , Lemma (..)
  , Certificate (..)
  , SmtResult (..)
  , smt
  , valid
  , evalFormula
  , checkUnsat
  , tseitin
  , linearTerm
  ) where

import qualified Data.Map.Strict as Map
import MP.Hcalc.Linear
import MP.Hcalc.Sat

infixl 6 `TAdd`, `TSub`

data Term
  = TVar String
  | TConst Rational
  | TAdd Term Term
  | TSub Term Term
  | TScale Rational Term
  deriving (Eq, Show)

data Formula
  = FTrue
  | FFalse
  | FProp String
  | FLe Term Term
  | FLt Term Term
  | FEq Term Term
  | FNot Formula
  | FAnd [Formula]
  | FOr [Formula]
  | FImp Formula Formula
  deriving (Eq, Show)

-- | Propositions default to false and variables to 0 when the model is
-- silent about them.
data Model = Model
  { propModel :: Map.Map String Bool
  , realModel :: Map.Map String Rational
  }
  deriving (Eq, Show)

-- | A clause valid in the theory, and why: Farkas multipliers over the
-- negations of its literals, by position in the clause.
data Lemma = Lemma {lemmaClause :: Clause, lemmaFarkas :: Map.Map Int Rational}
  deriving (Eq, Show)

data Certificate = Certificate {certLemmas :: [Lemma], certRefutation :: Refutation}
  deriving (Eq, Show)

data SmtResult = Sat Model | Unsat Certificate
  deriving (Eq, Show)

------------------------------------------------------------------------------
-- Semantics

linearTerm :: Term -> (Map.Map String Rational, Rational)
linearTerm t = case t of
  TVar x -> (Map.singleton x 1, 0)
  TConst c -> (Map.empty, c)
  TAdd a b -> plus (linearTerm a) (linearTerm b)
  TSub a b -> plus (linearTerm a) (scaled (-1) (linearTerm b))
  TScale k a -> scaled k (linearTerm a)
  where
    plus (m1, c1) (m2, c2) = (Map.unionWith (+) m1 m2, c1 + c2)
    scaled k (m, c) = (Map.map (k *) m, k * c)

evalTerm :: Model -> Term -> Rational
evalTerm m t = let (cs, c) = linearTerm t in c + sum [a * Map.findWithDefault 0 x (realModel m) | (x, a) <- Map.toList cs]

evalFormula :: Model -> Formula -> Bool
evalFormula m f = case f of
  FTrue -> True
  FFalse -> False
  FProp p -> Map.findWithDefault False p (propModel m)
  FLe a b -> evalTerm m a <= evalTerm m b
  FLt a b -> evalTerm m a < evalTerm m b
  FEq a b -> evalTerm m a == evalTerm m b
  FNot g -> not (evalFormula m g)
  FAnd gs -> all (evalFormula m) gs
  FOr gs -> any (evalFormula m) gs
  FImp a b -> not (evalFormula m a) || evalFormula m b

------------------------------------------------------------------------------
-- Tseitin encoding

data Atom = PropAtom String | LinAtom Constraint
  deriving (Eq, Ord, Show)

-- | Next free variable, atoms seen so far, clauses emitted (reversed).
data Enc = Enc Int (Map.Map Atom Int) [Clause]

newtype EncM a = EncM (Enc -> (a, Enc))

instance Functor EncM where fmap f (EncM g) = EncM (\s -> let (a, s') = g s in (f a, s'))

instance Applicative EncM where
  pure a = EncM (\s -> (a, s))
  EncM f <*> EncM g = EncM (\s -> let (h, s1) = f s; (a, s2) = g s1 in (h a, s2))

instance Monad EncM where
  EncM g >>= k = EncM (\s -> let (a, s1) = g s; EncM h = k a in h s1)

fresh :: EncM Int
fresh = EncM (\(Enc n as cs) -> (n, Enc (n + 1) as cs))

emit :: Clause -> EncM ()
emit c = EncM (\(Enc n as cs) -> ((), Enc n as (c : cs)))

atomVar :: Atom -> EncM Int
atomVar a = EncM $ \s@(Enc n as cs) -> case Map.lookup a as of
  Just v -> (v, s)
  Nothing -> (n, Enc (n + 1) (Map.insert a n as) cs)

linAtom :: Rel -> Term -> Term -> Atom
linAtom r a b = let (cs, c) = linearTerm (TSub a b) in LinAtom (Constraint (Map.filter (/= 0) cs) c r)

encode :: Formula -> EncM Lit
encode f = case f of
  FTrue -> fresh >>= \v -> emit [v] >> pure v
  FFalse -> fresh >>= \v -> emit [negate v] >> pure v
  FProp p -> atomVar (PropAtom p)
  FLe a b -> atomVar (linAtom Le a b)
  FLt a b -> atomVar (linAtom Lt a b)
  FEq a b -> encode (FAnd [FLe a b, FLe b a])
  FNot g -> negate <$> encode g
  FImp a b -> encode (FOr [FNot a, b])
  FAnd gs -> do
    ls <- mapM encode gs
    g <- fresh
    mapM_ (\l -> emit [negate g, l]) ls
    emit (g : map negate ls)
    pure g
  FOr gs -> do
    ls <- mapM encode gs
    g <- fresh
    emit (negate g : ls)
    mapM_ (\l -> emit [g, negate l]) ls
    pure g

-- | Clauses equisatisfiable with the formula (the last asserts its root), and
-- the atom each atom variable stands for.
tseitin :: Formula -> ([Clause], [(Int, Atom)])
tseitin f =
  let EncM run = encode f >>= \root -> emit [root]
      ((), Enc _ atoms clauses) = run (Enc 1 Map.empty [])
   in (reverse clauses, [(v, a) | (a, v) <- Map.toList atoms])

-- | The constraint a theory literal asserts: the atom, or its negation.
-- @not (e <= 0)@ is @-e < 0@ and @not (e < 0)@ is @-e <= 0@.
literalConstraint :: [(Int, Atom)] -> Lit -> Maybe Constraint
literalConstraint atoms l = case lookup (abs l) atoms of
  Just (LinAtom k)
    | l > 0 -> Just k
    | otherwise ->
        Just
          (Constraint (Map.map negate (coeffs k)) (negate (constant k)) (if rel k == Le then Lt else Le))
  _ -> Nothing

------------------------------------------------------------------------------
-- DPLL(T)

smt :: Formula -> SmtResult
smt f = loop []
  where
    (clauses, atoms) = tseitin f
    loop lemmas = case solveSat (clauses ++ map lemmaClause lemmas) of
      Unsatisfiable r -> Unsat (Certificate lemmas r)
      Satisfiable m ->
        let value v = Map.findWithDefault False v m
            theoryLits = [if value v then v else negate v | (v, LinAtom _) <- atoms]
            props = Map.fromList [(p, value v) | (v, PropAtom p) <- atoms]
            constraints = [k | l <- theoryLits, Just k <- [literalConstraint atoms l]]
         in case solveLinear constraints of
              Feasible rm -> Sat (Model props rm)
              Infeasible lam ->
                -- Learn: not all of the literals the multipliers use.
                let used = [(l, w) | (i, l) <- zip [0 ..] theoryLits, Just w <- [Map.lookup i lam]]
                    lemma = Lemma (map (negate . fst) used) (Map.fromList (zip [0 ..] (map snd used)))
                 in loop (lemma : lemmas)

-- | 'Unsat' means valid: the negation has no model. 'Sat' is a counter-model.
valid :: Formula -> SmtResult
valid = smt . FNot

-- | Check an unsatisfiability certificate against the formula: every lemma
-- is a theory consequence by its Farkas multipliers, and the refutation
-- derives the empty clause from the encoding plus the lemmas.
checkUnsat :: Formula -> Certificate -> Bool
checkUnsat f (Certificate lemmas r) =
  all lemmaValid lemmas && checkRefutation (clauses ++ map lemmaClause lemmas) r
  where
    (clauses, atoms) = tseitin f
    lemmaValid (Lemma c lam) = case traverse (literalConstraint atoms . negate) c of
      Just ks -> not (null c) && checkFarkas ks lam
      Nothing -> False
