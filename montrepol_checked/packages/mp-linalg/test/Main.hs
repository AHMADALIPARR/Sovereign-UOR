-- SPDX-License-Identifier: AGPL-3.0-only
-- Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
-- Copyright (C) 2026 Ahmad Parr

module Main (main) where

import Data.Ratio ((%))
import MP.Algebra
import MP.Check
import MP.Matrix
import MP.Participation

main :: IO ()
main =
  runSuite
    "mp-linalg"
    [ prop "LA-01" "Integer is a semiring" (triple integerG) (axioms @Integer)
    , prop "LA-01" "Rational is a semiring" (triple rationalG) (axioms @Rational)
    , prop "LA-01" "GF2 is a semiring" (triple gf2G) (axioms @GF2)
    , prop "LA-01" "MinPlus is a semiring" (triple minPlusG) (axioms @MinPlus)
    , prop "LA-02" "mul is associative" threeMats assoc
    , prop "LA-02" "mul distributes over addition" twoMatsSame dist
    , prop "LA-02" "identity is a unit" oneMat unitI
    , prop "LA-03" "Strassen equals the definition over Integer, cutoffs 2..5" strassenG strassenEq
    , prop "LA-03" "Strassen equals the definition over Rational" strassenQ strassenEqQ
    , prop "LA-03" "Strassen equals the definition over GF2" strassenF strassenEqF
    , prop "LA-04" "Bareiss equals Leibniz over Integer, n up to 6" square bareissEq
    , prop "LA-04" "Bareiss equals Leibniz over GF2, n up to 6" squareF bareissEqF
    , unit "LA-04" "a matrix needing a pivot swap" $ det (fromLists [[0, 1], [1, 0]] :: Matrix Integer) === (-1)
    , prop "LA-05" "inverse multiplies back" nonsing invRound
    , unit "LA-05" "a singular matrix has no inverse" $ inverse (fromLists [[1, 2], [2, 4]] :: Matrix Rational) === Nothing
    , prop "LA-06" "rank equals the order of the largest nonzero minor" rect rankEq
    , unit "LA-06" "rank of a hand-checked matrix with a zero first column" $
        rank (fromLists [[0, 1, 2], [0, 2, 4], [0, 0, 1]] :: Matrix Integer) === 2
    , prop "LA-07" "participation ratio bounds" probVec partBounds
    , unit "LA-07" "uniform has full participation" $ participation (replicate 5 (1 % 5)) === 5
    ]
  where
    integerG = integerIn (-20) 20
    rationalG = rationalIn (-10) 10 5
    gf2G = GF2 <$> boolG
    minPlusG = elements Inf [Fin n | n <- [-5 .. 5]]
    triple g = (,,) <$> g <*> g <*> g
    mat m n g = fromLists <$> listOfLength m (listOfLength n g)
    dim = intIn 1 6
    oneMat = do
      m <- dim
      n <- dim
      mat m n integerG
    twoMatsSame = do
      m <- dim
      n <- dim
      p <- dim
      (,,) <$> mat m n integerG <*> mat n p integerG <*> mat n p integerG
    threeMats = do
      m <- dim
      n <- dim
      p <- dim
      q <- dim
      (,,) <$> mat m n integerG <*> mat n p integerG <*> mat p q integerG
    strassenShapes g = do
      cutoff <- intIn 2 5
      m <- intIn 1 20
      n <- intIn 1 20
      p <- intIn 1 20
      (,,) cutoff <$> mat m n g <*> mat n p g
    strassenG = strassenShapes integerG
    strassenQ = strassenShapes rationalG
    strassenF = strassenShapes gf2G
    square = do
      n <- dim
      mat n n integerG
    squareF = do
      n <- dim
      mat n n gf2G
    nonsing = do
      n <- intIn 1 4
      mat n n rationalG
    rect = do
      m <- intIn 1 5
      n <- intIn 1 5
      -- Small entries so that singular minors are common.
      mat m n (integerIn (-1) 1)
    probVec = do
      xs <- listOfLength 6 (integerIn 0 10)
      let s = sum xs
       in pure (if s == 0 then replicate 6 (1 % 6) else map (% s) xs)

axioms :: (Semiring a, Eq a) => (a, a, a) -> Result
axioms (x, y, z) =
  assert "assoc +" ((x .+. y) .+. z == x .+. (y .+. z))
    .&&. assert "comm +" (x .+. y == y .+. x)
    .&&. assert "zero" (x .+. zero == x)
    .&&. assert "assoc *" ((x .*. y) .*. z == x .*. (y .*. z))
    .&&. assert "one" (x .*. one == x)
    .&&. assert "dist" (x .*. (y .+. z) == (x .*. y) .+. (x .*. z))

assoc :: (Matrix Integer, Matrix Integer, Matrix Integer) -> Result
assoc (a, b, c) = mul (mul a b) c === mul a (mul b c)

dist :: (Matrix Integer, Matrix Integer, Matrix Integer) -> Result
dist (a, b, c) = mul a (addM b c) === addM (mul a b) (mul a c)

unitI :: Matrix Integer -> Result
unitI a = mul a (identity (cols a)) === a .&&. mul (identity (rows a)) a === a

strassenEq :: (Int, Matrix Integer, Matrix Integer) -> Result
strassenEq (k, a, b) = strassen k a b === mul a b

strassenEqQ :: (Int, Matrix Rational, Matrix Rational) -> Result
strassenEqQ (k, a, b) = strassen k a b === mul a b

strassenEqF :: (Int, Matrix GF2, Matrix GF2) -> Result
strassenEqF (k, a, b) = strassen k a b === mul a b

bareissEq :: Matrix Integer -> Result
bareissEq a = det a === leibniz a

bareissEqF :: Matrix GF2 -> Result
bareissEqF a = det a === leibniz a

-- | The permutation expansion, the definition of the determinant.
leibniz :: Ring a => Matrix a -> a
leibniz a =
  let n = rows a
      sign p x = if even (inversions p) then x else neg x
      inversions p = length [() | (i, pi') <- zip [0 :: Int ..] p, (j, pj) <- zip [0 ..] p, i < j, pi' > pj]
   in sumS [sign p (productS [entry a i j | (i, j) <- zip [0 ..] p]) | p <- permutations [0 .. n - 1]]

permutations :: [a] -> [[a]]
permutations [] = [[]]
permutations xs = [y : zs | (y, ys) <- picks xs, zs <- permutations ys]
  where
    picks [] = []
    picks (z : zs) = (z, zs) : [(y, z : ys) | (y, ys) <- picks zs]

invRound :: Matrix Rational -> Result
invRound a =
  case inverse a of
    Nothing -> det a === 0
    Just b -> mul a b === identity (rows a) .&&. mul b a === identity (rows a)

-- | Rank by its definition: the largest k with a nonzero k x k minor, each
-- minor computed by the Leibniz expansion.
rankEq :: Matrix Integer -> Result
rankEq a = rank a === minorRank a

minorRank :: Matrix Integer -> Int
minorRank a =
  let ks = [k | k <- [1 .. min (rows a) (cols a)], any (/= 0) (minors k)]
   in foldr max 0 ks
  where
    minors k =
      [ leibniz (fromLists [[entry a i j | j <- cs] | i <- rs])
      | rs <- choose k [0 .. rows a - 1]
      , cs <- choose k [0 .. cols a - 1]
      ]
    choose 0 _ = [[]]
    choose _ [] = []
    choose k (x : xs) = map (x :) (choose (k - 1) xs) ++ choose k xs

partBounds :: [Rational] -> Result
partBounds p =
  let k = participation p
   in assert "below 1" (k >= 1) .&&. assert "above length" (k <= fromIntegral (length p))
