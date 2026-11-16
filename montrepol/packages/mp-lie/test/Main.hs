-- SPDX-License-Identifier: AGPL-3.0-or-later

{-# LANGUAGE DataKinds #-}

module Main (main) where

import Data.Proxy (Proxy (..))
import Data.Ratio (denominator)
import MP.Check
import MP.Matrix (Matrix, det, fromLists, inverse, mul, toLists, withSize)
import MP.RootSystem

-- | (name, roots, rank, |roots| from the table, |W| from the table,
-- det of the Cartan matrix from the table). The table entries are the
-- authority (Humphreys 1990, sec. 2.10–2.11, and Bourbaki Lie VI, Plates);
-- everything else is computed.
data Case = Case String [Vec] Int Int Integer Integer

e7, e6 :: [Vec]
e7 = orthogonalSubsystem [[2, 2, 0, 0, 0, 0, 0, 0]] typeE8
e6 = orthogonalSubsystem [[2, 2, 0, 0, 0, 0, 0, 0], [-2, 0, 2, 0, 0, 0, 0, 0]] typeE8

cases :: [Case]
cases =
  [Case ("A" <> show n) (typeA n) n (n * (n + 1)) (fact (n + 1)) (toInteger n + 1) | n <- [1 .. 6]]
    ++ [Case ("B" <> show n) (typeB n) n (2 * n * n) (2 ^ n * fact n) 2 | n <- [2 .. 6]]
    ++ [Case ("D" <> show n) (typeD n) n (2 * n * (n - 1)) (2 ^ (n - 1) * fact n) 4 | n <- [4 .. 7]]
    ++ [ Case "G2" typeG2 2 12 12 1
       , Case "F4" typeF4 4 48 1152 1
       , Case "E6" e6 6 72 51840 3
       , Case "E7" e7 7 126 2903040 2
       , Case "E8" typeE8 8 240 696729600 1
       ]
  where
    fact k = product [1 .. toInteger k]

main :: IO ()
main =
  runSuite "mp-lie" $
    concat
      [ [ unit "LI-01" (name <> " satisfies the root system axioms") (axiomViolations rs === [])
        | Case name rs _ _ _ _ <- cases
        ]
      , [ unit "LI-01" "E8 with one root deleted is rejected as not closed" $
            assert "accepted" (any (("not closed" ==) . take 10) (axiomViolations (drop 1 typeE8)))
        , unit "LI-01" "a set containing a and 2a is rejected as not reduced" $
            assert "accepted" (any (("not reduced" ==) . take 11) (axiomViolations (typeB 2 ++ [[2, 0], [-2, 0]])))
        , unit "LI-01" "(3,0) with (1,1), where 2(b,a)/(a,a) = 2/3, is rejected as not crystallographic" $
            assert "accepted" (any (("not crystallographic" ==) . take 20) (axiomViolations [[3, 0], [-3, 0], [1, 1], [-1, -1]]))
        ]
      , [ unit "LI-02" (name <> " has the tabulated number of roots and simple roots") $
            length rs === nRoots .&&. length (simpleRoots rs) === rk
        | Case name rs rk nRoots _ _ <- cases
        ]
      , [ unit "LI-03" (name <> ": every positive root is a non-negative integral sum of simple roots") $
            simpleCoordinates rs
        | Case name rs _ _ _ _ <- cases
        ]
      , [ unit "LI-04" (name <> " Weyl group order, by orbit-stabilizer, matches the table") $
            weylOrder (cartanMatrix (simpleRoots rs)) === w
        | Case name rs _ _ w _ <- cases
        ]
      , [ unit "LI-05" (name <> " Cartan determinant matches the table") $
            cartanDet (cartanMatrix (simpleRoots rs)) === d
        | Case name rs _ _ _ d <- cases
        ]
      , [ unit "LI-06" "E8: |W| = product of the degrees, |Phi+| = sum (d_i - 1), |Phi| = rank * h" $
            let degrees = [2, 8, 12, 14, 18, 20, 24, 30]
             in weylOrder (cartanMatrix (simpleRoots typeE8)) === product degrees
                  .&&. toInteger (length (positiveRoots typeE8)) === sum (map (subtract 1) degrees)
                  .&&. length typeE8 === 8 * 30
        , unit "LI-06" "E8 lattice: simple-root Gram matrix is even and unimodular" $
            let g = [[dot a b `div` 4 | b <- simpleRoots typeE8] | a <- simpleRoots typeE8]
             in assert "diagonal not all 2" (and [x == 2 | (i, r) <- zip [0 :: Int ..] g, (j, x) <- zip [0 ..] r, i == j])
                  .&&. cartanDet g === 1
                  .&&. assert "Gram /= Cartan for simply-laced E8" (g == cartanMatrix (simpleRoots typeE8))
        , propN "LI-06" "Weyl order is independent of how E8's nodes are labelled" 20 (permutationOf 8) $ \p ->
            let c = cartanMatrix (simpleRoots typeE8)
                c' = [[c `at2` (i, j) | j <- p] | i <- p]
             in weylOrder c' === 696729600
        ]
      ]

------------------------------------------------------------------------------

at2 :: [[Integer]] -> (Int, Int) -> Integer
at2 m (i, j) = case drop j <$> take 1 (drop i m) of
  [x : _] -> x
  _ -> 0

permutationOf :: Int -> Gen [Int]
permutationOf n = go [0 .. n - 1]
  where
    go [] = pure []
    go xs = do
      k <- intIn 0 (length xs - 1)
      let (before, rest) = splitAt k xs
      case rest of
        (y : after) -> (y :) <$> go (before ++ after)
        [] -> pure []

cartanDet :: [[Integer]] -> Integer
cartanDet c = withSize (fromIntegral (length c)) $ \(_ :: Proxy n) ->
  maybe 0 det (fromLists c :: Maybe (Matrix n n Integer))

-- | Solve @G x = (a_i . b)@ with @G@ the Gram matrix of the simple roots, and
-- require each solution for a positive root to be a non-negative integer
-- vector. Uses the rational inverse from mp-linalg.
simpleCoordinates :: [Vec] -> Result
simpleCoordinates rs =
  let simple = simpleRoots rs
      n = length simple
      gram = [[fromInteger (dot a b) | b <- simple] | a <- simple] :: [[Rational]]
   in withSize (fromIntegral n) $ \(_ :: Proxy n) ->
        case fromLists gram :: Maybe (Matrix n n Rational) of
          Nothing -> failWith "Gram matrix has the wrong shape"
          Just g -> case inverse g of
            Nothing -> failWith "simple roots are linearly dependent"
            Just gi ->
              allOf
                [ case fromLists [[fromInteger (dot a b)] | a <- simple] :: Maybe (Matrix n 1 Rational) of
                    Nothing -> failWith "shape"
                    Just rhs ->
                      let xs = concat (toLists (mul gi rhs))
                       in assert
                            ("positive root " <> show b <> " has coordinates " <> show xs)
                            (all (\x -> denominator x == 1 && x >= 0) xs)
                | b <- positiveRoots rs
                ]
