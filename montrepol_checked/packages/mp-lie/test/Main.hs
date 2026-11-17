-- SPDX-License-Identifier: AGPL-3.0-or-later
module Main (main) where

import qualified Data.Set as Set
import MP.Check
import MP.Matrix
import MP.RootSystem

main :: IO ()
main =
  runSuite
    "mp-lie"
    [ unit "LI-01" "A2 satisfies the root axioms" $ withSystem "A2" axioms
    , unit "LI-01" "B2 satisfies the root axioms" $ withSystem "B2" axioms
    , unit "LI-01" "G2 satisfies the root axioms" $ withSystem "G2" axioms
    , unit "LI-01" "E8 satisfies the root axioms" $ withSystem "E8" axioms
    , unit "LI-01" "E8 has 240 roots" $ withSystem "E8" (\rs -> Set.size (roots rs) === 240)
    , unit "LI-02" "simple roots generate A2" $ withSystem "A2" generates
    , unit "LI-02" "simple roots generate E8" $ withSystem "E8" generates
    , unit "LI-03" "Cartan of A2 is the published matrix" $
        withSystem "A2" (\rs -> cartan rs === fromLists [[2, -1], [-1, 2]])
    , unit "LI-03" "Cartan of G2 is the published matrix" $
        withSystem "G2" (\rs -> cartan rs === fromLists [[2, -1], [-3, 2]])
    , unit "LI-04" "Weyl order of A2 is 6" $ withSystem "A2" (\rs -> weylOrder rs === 6)
    , unit "LI-04" "Weyl order of B2 is 8" $ withSystem "B2" (\rs -> weylOrder rs === 8)
    , unit "LI-04" "Weyl order of G2 is 12" $ withSystem "G2" (\rs -> weylOrder rs === 12)
    , unit "LI-04" "Weyl order of E8 is 696729600" $ withSystem "E8" (\rs -> weylOrder rs === 696729600)
    ]

withSystem :: String -> (RootSystem -> Result) -> Result
withSystem name k = maybe (failWith ("unknown system " <> name)) k (system name)

-- | Finite, spans (the simple roots are independent and the roots have the
-- same rank), closed under reflection, and 2(a,b)/(a,a) integral.
axioms :: RootSystem -> Result
axioms rs =
  let r = Set.toList (roots rs)
      s = simpleRoots rs
   in assert "finite" (not (null r))
        .&&. rank (fromLists r) === length s
        .&&. rank (fromLists s) === length s
        .&&. assert "closed" (all (\a -> all (\b -> Set.member (refl a b) (roots rs)) r) r)
        .&&. assert "integer" (all (\a -> all (\b -> (2 * ip a b) `mod` ip a a == 0) r) r)

-- | The reflections are written out again here so the closure check does not
-- reuse the function that built the set.
refl :: [Integer] -> [Integer] -> [Integer]
refl a b = zipWith (-) b (map (* ((2 * ip a b) `div` ip a a)) a)

ip :: [Integer] -> [Integer] -> Integer
ip a b = sum (zipWith (*) a b)

-- | The simple roots lie in the closure, and every root is an integer
-- combination of the simple roots with all coefficients of one sign. The
-- coefficients are solved from the Gram matrix over the rationals.
generates :: RootSystem -> Result
generates rs =
  let s = simpleRoots rs
      full = Set.toList (roots rs)
      gram = fromLists [[fromInteger (ip a b) | b <- s] | a <- s] :: Matrix Rational
   in assert "simple roots not in the closure" (all (`elem` full) s)
        .&&. case inverse gram of
          Nothing -> failWith "simple roots are dependent"
          Just gi ->
            let coeffs v = [c | [c] <- toLists (mul gi (fromLists [[fromInteger (ip a v)] | a <- s]))]
                ok v =
                  let cs = coeffs v
                   in all (\c -> c == fromInteger (round c)) cs && (all (>= 0) cs || all (<= 0) cs)
             in assert "a root is not a one-signed integer combination of the simple roots" (all ok full)
