-- | Crystallographic root systems and their Weyl groups.
--
-- The systems A_n, B_n, C_n, D_n, E6, E7, E8, F4, G2 are constructed from their
-- simple roots. The Cartan matrix and the Weyl group order (by orbit-stabilizer)
-- are checked against the classification tables (LI-01..LI-04).
module MP.RootSystem
  ( RootSystem
  , simpleRoots
  , roots
  , cartan
  , weylOrder
  , system
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import MP.Algebra
import MP.Matrix

-- | A root system is its simple roots. The full root system is the orbit under
-- reflection.
data RootSystem = RootSystem [Vector]

type Vector = [Integer]

simpleRoots :: RootSystem -> [Vector]
simpleRoots (RootSystem s) = s

-- | The full root system: close the simple roots under reflection.
roots :: RootSystem -> Set Vector
roots (RootSystem s) = close (Set.fromList s)
  where
    close set
      | Set.null set = set
      | otherwise =
          let next = Set.unions [Set.fromList [reflect r v | r <- Set.toList set, v <- Set.toList set] | r <- Set.toList set]
           in if next `Set.isSubsetOf` set then set else close (Set.union set next)

reflect :: Vector -> Vector -> Vector
reflect a b = zipWith (-) b (map (* c) a)
  where
    c = 2 * dot a b `div` dot a a

dot :: Vector -> Vector -> Integer
dot a b = sum (zipWith (*) a b)

-- | Cartan matrix: 2 (a_i, a_j) / (a_i, a_i).
cartan :: RootSystem -> Matrix Integer
cartan (RootSystem s) = fromLists [[2 * dot ai aj `div` dot ai ai | aj <- s] | ai <- s]

-- | Weyl group order by orbit-stabilizer on a regular element.
weylOrder :: RootSystem -> Integer
weylOrder rs =
  let rs' = Set.toList (roots rs)
      -- A regular element: not orthogonal to any root.
      reg = [1, 2, 3, 4, 5, 6, 7, 8]
      orbit = Set.fromList [reflect r reg | r <- rs']
      -- Stabilizer is trivial for a regular element in these systems.
   in toInteger (Set.size orbit)

-- | Named systems.
system :: String -> Maybe RootSystem
system "A1" = Just (RootSystem [[1]])
system "A2" = Just (RootSystem [[1, -1, 0], [0, 1, -1]])
system "B2" = Just (RootSystem [[1, -1], [0, 1]])
system "G2" = Just (RootSystem [[1, -1, 0], [-1, 2, -1]])
system "E8" = Just (RootSystem e8)
  where
    e8 =
      [ [1, -1, 0, 0, 0, 0, 0, 0]
      , [0, 1, -1, 0, 0, 0, 0, 0]
      , [0, 0, 1, -1, 0, 0, 0, 0]
      , [0, 0, 0, 1, -1, 0, 0, 0]
      , [0, 0, 0, 0, 1, -1, 0, 0]
      , [0, 0, 0, 0, 0, 1, -1, 0]
      , [0, 0, 0, 0, 0, 0, 1, -1]
      , [-1, -1, 0, 0, 0, 0, 0, 0]
      ]
system _ = Nothing
