-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | Conjunctions of linear constraints over the rationals, decided by
-- Fourier–Motzkin elimination, with a certificate either way.
--
-- Every constraint is @sum a_i x_i + c REL 0@ with @REL@ one of @<=@ or @<@.
-- A satisfiable system comes with a rational model, found by back-substitution
-- through the elimination. An unsatisfiable one comes with Farkas
-- multipliers: non-negative weights under which the constraints sum to a
-- constant contradiction. 'checkFarkas' and 'holds' check those directly
-- against the input, sharing nothing with the elimination.
--
-- Fourier–Motzkin can square the number of constraints at each step. It is
-- here because its certificates are easy to read, not because it is fast.
module MP.Hcalc.Linear
  ( Rel (..)
  , Constraint (..)
  , constraint
  , LinResult (..)
  , solveLinear
  , holds
  , checkFarkas
  , evalLinear
  ) where

import Data.List (nub, sortOn)
import qualified Data.Map.Strict as Map

data Rel = Le | Lt
  deriving (Eq, Ord, Show)

-- | @sum coeffs + constant REL 0@. Zero coefficients are never stored.
data Constraint = Constraint
  { coeffs :: Map.Map String Rational
  , constant :: Rational
  , rel :: Rel
  }
  deriving (Eq, Ord, Show)

constraint :: [(String, Rational)] -> Rational -> Rel -> Constraint
constraint cs c = Constraint (Map.filter (/= 0) (Map.fromListWith (+) cs)) c

data LinResult
  = -- | A model, as values for the variables that occur.
    Feasible (Map.Map String Rational)
  | -- | Farkas multipliers, indexed like the input list.
    Infeasible (Map.Map Int Rational)
  deriving (Eq, Show)

evalLinear :: Map.Map String Rational -> Constraint -> Rational
evalLinear m (Constraint cs c _) = c + sum [a * Map.findWithDefault 0 x m | (x, a) <- Map.toList cs]

holds :: Map.Map String Rational -> Constraint -> Bool
holds m k = case rel k of
  Le -> evalLinear m k <= 0
  Lt -> evalLinear m k < 0

-- | Whether the multipliers prove the constraints inconsistent: all
-- non-negative, some positive, every variable cancels, and the constant left
-- over is positive (or zero, if a strict constraint is used).
checkFarkas :: [Constraint] -> Map.Map Int Rational -> Bool
checkFarkas ks lam =
  all (>= 0) (Map.elems lam)
    && any (> 0) (Map.elems lam)
    && all (`elem` [0 .. length ks - 1]) (Map.keys lam)
    && all (== 0) (Map.elems combined)
    && (total > 0 || (total == 0 && strict))
  where
    used = [(l, k) | (i, k) <- zip [0 ..] ks, Just l <- [Map.lookup i lam], l /= 0]
    combined = Map.unionsWith (+) [Map.map (l *) (coeffs k) | (l, k) <- used]
    total = sum [l * constant k | (l, k) <- used]
    strict = any ((== Lt) . rel . snd) used

-- | A constraint together with the multipliers that derive it from the input.
type Derived = (Constraint, Map.Map Int Rational)

solveLinear :: [Constraint] -> LinResult
solveLinear ks =
  let start = [(k, Map.singleton i 1) | (i, k) <- zip [0 ..] ks]
      vars = nub (concatMap (Map.keys . coeffs) ks)
   in go vars start []
  where
    -- `stages` holds, for each eliminated variable, the system it was
    -- eliminated from, innermost first; back-substitution walks it.
    go [] system stages = case [d | (k, d) <- system, contradiction k] of
      (d : _) -> Infeasible (Map.filter (/= 0) d)
      [] -> Feasible (foldl' assign Map.empty stages)
    go (x : xs) system stages = go xs (eliminate x system) ((x, map fst system) : stages)

    contradiction (Constraint cs c r) = Map.null cs && (c > 0 || (c == 0 && r == Lt))

-- | Combine every lower bound on @x@ with every upper bound so that @x@
-- cancels; keep the constraints that do not mention it.
eliminate :: String -> [Derived] -> [Derived]
eliminate x system =
  nubOn fst (without ++ [combine p n | p <- pos, n <- neg])
  where
    coef (k, _) = Map.findWithDefault 0 x (coeffs k)
    pos = filter ((> 0) . coef) system
    neg = filter ((< 0) . coef) system
    without = filter ((== 0) . coef) system
    combine p@(kp, dp) n@(kn, dn) =
      let a = negate (coef n) -- > 0
          b = coef p -- > 0
          k =
            Constraint
              (Map.filter (/= 0) (Map.unionWith (+) (Map.map (a *) (coeffs kp)) (Map.map (b *) (coeffs kn))))
              (a * constant kp + b * constant kn)
              (if rel kp == Lt || rel kn == Lt then Lt else Le)
       in (k, Map.filter (/= 0) (Map.unionWith (+) (Map.map (a *) dp) (Map.map (b *) dn)))
    nubOn f = map snd . Map.toList . Map.fromList . map (\d -> (f d, d)) . reverse

-- | Choose a value for @x@ satisfying its bounds in the system it was
-- eliminated from, given the values already chosen for later variables. The
-- interval is non-empty because the eliminated system was satisfiable.
assign :: Map.Map String Rational -> (String, [Constraint]) -> Map.Map String Rational
assign m (x, system) = Map.insert x value m
  where
    bounds =
      [ (if a > 0 then Upper else Lower, negate rest / a, rel k)
      | k <- system
      , let a = Map.findWithDefault 0 x (coeffs k)
      , a /= 0
      , let rest = evalLinear m k {coeffs = Map.delete x (coeffs k)}
      ]
    lowers = [(b, r) | (Lower, b, r) <- bounds]
    uppers = [(b, r) | (Upper, b, r) <- bounds]
    -- The tightest bound on each side; at equal values a strict one is
    -- tighter, and False sorts before True.
    firstOf xs = case xs of
      (t : _) -> Just t
      [] -> Nothing
    lo = firstOf (sortOn (\(b, r) -> (negate b, r == Le)) lowers)
    hi = firstOf (sortOn (\(b, r) -> (b, r == Le)) uppers)
    value = case (lo, hi) of
      (Nothing, Nothing) -> 0
      (Just (l, r), Nothing) -> if r == Le then l else l + 1
      (Nothing, Just (u, r)) -> if r == Le then u else u - 1
      (Just (l, _), Just (u, _)) -> if l < u then (l + u) / 2 else l

data Side = Lower | Upper
  deriving (Eq)
