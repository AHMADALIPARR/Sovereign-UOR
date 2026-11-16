-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | Propositional satisfiability by DPLL, with a certificate either way.
--
-- A satisfiable answer comes with a model; an unsatisfiable one with a tree
-- resolution refutation read off the search tree. 'checkRefutation' replays
-- that refutation by resolution alone, sharing no code with the search, so an
-- unsatisfiable answer does not have to be taken on trust.
module MP.Hcalc.Sat
  ( Lit
  , Clause
  , Refutation (..)
  , SatResult (..)
  , solveSat
  , satisfies
  , checkRefutation
  , variables
  ) where

import Data.List (delete, nub, sort)
import qualified Data.Map.Strict as Map

-- | DIMACS convention: variable @v >= 1@ is the literal @v@, its negation @-v@.
type Lit = Int

type Clause = [Lit]

-- | How the empty clause is derived. @Conflict i@ is clause @i@ of the input;
-- @Split v t f@ resolves, on @v@, what was derived with @v@ true (@t@) and
-- with @v@ false (@f@).
data Refutation = Conflict Int | Split Int Refutation Refutation
  deriving (Eq, Show)

data SatResult = Satisfiable (Map.Map Int Bool) | Unsatisfiable Refutation
  deriving (Eq, Show)

variables :: [Clause] -> [Int]
variables = sort . nub . map abs . concat

litValue :: Map.Map Int Bool -> Lit -> Maybe Bool
litValue m l = (if l > 0 then id else not) <$> Map.lookup (abs l) m

-- | DPLL. The branching variable is taken from a unit clause when there is
-- one, so its losing branch closes at once on that clause; this is unit
-- propagation, expressed as search so that it leaves a resolution step.
solveSat :: [Clause] -> SatResult
solveSat cs = go Map.empty
  where
    indexed = zip [0 ..] cs
    go m = case [i | (i, c) <- indexed, all ((== Just False) . litValue m) c] of
      (i : _) -> Unsatisfiable (Conflict i)
      [] ->
        let open = [c | (_, c) <- indexed, not (any ((== Just True) . litValue m) c)]
            unassigned c = [l | l <- c, litValue m l == Nothing]
         in case open of
              [] -> Satisfiable (Map.union m (Map.fromList [(v, False) | v <- variables cs]))
              _ ->
                let units = [l | c <- open, [l] <- [unassigned c]]
                    l0 = case units ++ concatMap unassigned (take 1 open) of
                      (l : _) -> l
                      [] -> 0
                    v = abs l0
                    first = l0 > 0
                 in case go (Map.insert v first m) of
                      sat@(Satisfiable _) -> sat
                      Unsatisfiable r1 -> case go (Map.insert v (not first) m) of
                        sat@(Satisfiable _) -> sat
                        Unsatisfiable r2 ->
                          Unsatisfiable (if first then Split v r1 r2 else Split v r2 r1)

satisfies :: Map.Map Int Bool -> [Clause] -> Bool
satisfies m = all (any ((== Just True) . litValue m))

-- | Replay a refutation by resolution. 'True' exactly when it derives the
-- empty clause from the given clauses.
checkRefutation :: [Clause] -> Refutation -> Bool
checkRefutation cs r = derive r == Just []
  where
    derive (Conflict i)
      | i >= 0 = case drop i cs of
          (c : _) -> Just (sort (nub c))
          [] -> Nothing
      | otherwise = Nothing
    derive (Split v t f) = do
      ct <- derive t
      cf <- derive f
      if negate v `notElem` ct
        then Just ct -- already false without v: weakening, no resolution needed
        else
          if v `notElem` cf
            then Just cf
            else Just (sort (nub (delete (negate v) ct ++ delete v cf)))
