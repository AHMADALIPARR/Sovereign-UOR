module Main (main) where

import Data.Set (Set)
import qualified Data.Set as Set
import MP.Algebra
import MP.Check
import MP.Matrix
import MP.RootSystem

main :: IO ()
main =
  runSuite
    "mp-lie"
    [ unit "LI-01" "A2 satisfies the root axioms" $ axioms (system "A2")
    , unit "LI-01" "B2 satisfies the root axioms" $ axioms (system "B2")
    , unit "LI-01" "G2 satisfies the root axioms" $ axioms (system "G2")
    , unit "LI-01" "E8 satisfies the root axioms" $ axioms (system "E8")
    , unit "LI-02" "simple roots generate A2" $ generates (system "A2")
    , unit "LI-03" "Cartan of A2 is the published matrix" $
        cartan (fromJust (system "A2")) === fromLists [[2, -1], [-1, 2]]
    , unit "LI-04" "Weyl order of A2 is 6" $ weylOrder (fromJust (system "A2")) === 6
    , unit "LI-04" "Weyl order of B2 is 8" $ weylOrder (fromJust (system "B2")) === 8
    ]
  where
    fromJust (Just x) = x
    fromJust Nothing = error "missing system"

axioms :: Maybe RootSystem -> Result
axioms Nothing = failWith "unknown system"
axioms (Just rs) =
  let r = roots rs
   in assert "finite" (not (Set.null r))
        .&&. assert "closed" (all (\a -> all (\b -> Set.member (reflect a b) r) (Set.toList r)) (Set.toList r))
        .&&. assert "integer" (all (\a -> all (\b -> (2 * dot a b) `mod` (dot a a) == 0) (Set.toList r)) (Set.toList r))

generates :: Maybe RootSystem -> Result
generates Nothing = failWith "unknown system"
generates (Just rs) =
  let s = Set.fromList (simpleRoots rs)
      full = roots rs
   in assert "simple generate" (s `Set.isSubsetOf` full)

reflect :: [Integer] -> [Integer] -> [Integer]
reflect a b = zipWith (-) b (map (* c) a)
  where
    c = 2 * dot a b `div` dot a a

dot :: [Integer] -> [Integer] -> Integer
dot a b = sum (zipWith (*) a b)
