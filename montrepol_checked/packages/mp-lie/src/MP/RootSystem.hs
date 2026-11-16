-- | Crystallographic root systems and their Weyl groups.
--
-- A system is given by its simple roots in an integer coordinate space
-- (E8 uses doubled coordinates so the half-integral roots stay
-- integral; every quantity below is invariant under scaling). The full root
-- system is the closure of the simple roots under reflection. The Weyl group
-- order is computed by orbit-stabilizer: the stabilizer of a fundamental
-- weight is the parabolic subgroup on the remaining simple roots, so
-- |W(S)| = |W(S) . w_i| * |W(S \ {i})|, and the orbit is enumerated by
-- applying simple reflections to Dynkin labels.
module MP.RootSystem
  ( RootSystem
  , Vector
  , simpleRoots
  , roots
  , reflect
  , dot
  , cartan
  , weylOrder
  , system
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import MP.Matrix

-- | A root system is its simple roots.
newtype RootSystem = RootSystem [Vector]

type Vector = [Integer]

simpleRoots :: RootSystem -> [Vector]
simpleRoots (RootSystem s) = s

dot :: Vector -> Vector -> Integer
dot a b = sum (zipWith (*) a b)

-- | Reflection of b in the hyperplane orthogonal to a. Total: a zero vector
-- reflects nothing.
reflect :: Vector -> Vector -> Vector
reflect a b
  | aa == 0 = b
  | otherwise = zipWith (-) b (map (* c) a)
  where
    aa = dot a a
    c = (2 * dot a b) `div` aa

-- | The full root system: close the simple roots under the simple
-- reflections. The simple reflections generate the Weyl group, so this is
-- the orbit of the simple roots.
roots :: RootSystem -> Set Vector
roots (RootSystem s) = grow (Set.fromList s) (Set.fromList s)
  where
    grow seen frontier
      | Set.null frontier = seen
      | otherwise =
          let next = Set.fromList [reflect a v | a <- s, v <- Set.toList frontier]
              new = next `Set.difference` seen
           in grow (seen `Set.union` new) new

-- | Cartan matrix in Humphreys' convention ('Introduction to Lie Algebras
-- and Representation Theory'): entry (i, j) = 2 (a_i, a_j) / (a_j, a_j).
cartan :: RootSystem -> Matrix Integer
cartan (RootSystem s) = fromLists [[cartanEntry aj ai | aj <- s] | ai <- s]

cartanEntry :: Vector -> Vector -> Integer
cartanEntry ai aj = let d = dot ai ai in if d == 0 then 0 else (2 * dot ai aj) `div` d

-- | Weyl group order by orbit-stabilizer on fundamental weights.
weylOrder :: RootSystem -> Integer
weylOrder (RootSystem s) = go [0 .. length s - 1]
  where
    a i j = cartanEntry (at i) (at j)
    at i = case drop i s of
      (v : _) -> v
      [] -> []
    go [] = 1
    go idx@(_ : _) =
      let i = lastOf idx
          rest = filter (/= i) idx
       in toInteger (Set.size (orbit idx i)) * go rest
    lastOf = foldl (\_ x -> x) 0
    -- Orbit of the fundamental weight w_i under the reflections in idx,
    -- tracked by its Dynkin labels on idx. The simple root a_j has label
    -- a k j at node k, so s_j(l) = l - l_j * a_j.
    orbit idx i =
      let start = [if k == i then 1 else 0 | k <- idx]
          step l =
            [ zipWith (\k lk -> lk - lj * a k j) idx l
            | (j, lj) <- zip idx l
            , lj /= 0
            ]
          bfs seen [] = seen
          bfs seen (l : queue) =
            let new = filter (`Set.notMember` seen) (step l)
             in bfs (foldr Set.insert seen new) (queue ++ new)
       in bfs (Set.singleton start) [start]

-- | Named systems, by their simple roots (Bourbaki's ordering).
system :: String -> Maybe RootSystem
system "A1" = Just (RootSystem [[1]])
system "A2" = Just (RootSystem [[1, -1, 0], [0, 1, -1]])
system "B2" = Just (RootSystem [[1, -1], [0, 1]])
system "G2" = Just (RootSystem [[1, -1, 0], [-1, 2, -1]])
system "E8" = Just (RootSystem e8)
  where
    -- Doubled: a1 = (1/2)(e1 + e8) - (1/2)(e2 + ... + e7), a2 = e1 + e2,
    -- a_k = e_(k-1) - e_(k-2) for k = 3 .. 8.
    e8 =
      [ [1, -1, -1, -1, -1, -1, -1, 1]
      , [2, 2, 0, 0, 0, 0, 0, 0]
      , [-2, 2, 0, 0, 0, 0, 0, 0]
      , [0, -2, 2, 0, 0, 0, 0, 0]
      , [0, 0, -2, 2, 0, 0, 0, 0]
      , [0, 0, 0, -2, 2, 0, 0, 0]
      , [0, 0, 0, 0, -2, 2, 0, 0]
      , [0, 0, 0, 0, 0, -2, 2, 0]
      ]
system _ = Nothing
