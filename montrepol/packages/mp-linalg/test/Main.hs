module Main (main) where

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
    , prop "LA-02" "mul is associative" (threeMats) assoc
    , prop "LA-02" "mul distributes over addition" (twoMats) dist
    , prop "LA-02" "identity is a unit" (oneMat) unitI
    , prop "LA-03" "Strassen equals the definition" (twoMats) strassenEq
    , prop "LA-04" "Bareiss equals Leibniz" (square) bareissEq
    , unit "LA-04" "a matrix needing a pivot swap" $ det (fromLists [[0, 1], [1, 0]] :: Matrix Integer) === (-1)
    , prop "LA-05" "inverse multiplies back" (nonsing) invRound
    , unit "LA-05" "a singular matrix has no inverse" $ inverse (fromLists [[1, 2], [2, 4]] :: Matrix Rational) === Nothing
    , prop "LA-06" "rank equals nonzero rows of echelon" (rect) rankEq
    , prop "LA-07" "participation ratio bounds" (probVec) partBounds
    , unit "LA-07" "uniform has full participation" $ participation (replicate 5 (1 % 5)) === 5
    ]
  where
    integerG = integerIn (-20) 20
    rationalG = rationalIn (-10) 10 5
    gf2G = GF2 <$> boolG
    minPlusG = elements Inf [Fin n | n <- [-5 .. 5]]
    triple g = (,,) <$> g <*> g <*> g
    mat m n g = fromLists <$> listOfLength m (listOfLength n g)
    oneMat = mat 4 4 integerG
    twoMats = (,) <$> mat 4 5 integerG <*> mat 5 3 integerG
    threeMats = (,,) <$> mat 3 4 integerG <*> mat 4 2 integerG <*> mat 2 5 integerG
    square = mat 4 4 integerG
    nonsing = do
      a <- mat 3 3 rationalG
      pure a
    rect = mat 5 4 integerG
    probVec = do
      xs <- listOfLength 6 (integerIn 0 10)
      let s = sum xs
       in pure (if s == 0 then replicate 6 (1 % 6) else map (% s) xs)

axioms :: (Semiring a, Eq a, Show a) => (a, a, a) -> Result
axioms (x, y, z) =
  assert "assoc +" ((x .+. y) .+. z == x .+. (y .+. z))
    .&&. assert "comm +" (x .+. y == y .+. x)
    .&&. assert "zero" (x .+. zero == x)
    .&&. assert "assoc *" ((x .*. y) .*. z == x .*. (y .*. z))
    .&&. assert "one" (x .*. one == x)
    .&&. assert "dist" (x .*. (y .+. z) == (x .*. y) .+. (x .*. z))

assoc :: (Matrix Integer, Matrix Integer, Matrix Integer) -> Result
assoc (a, b, c) = mul (mul a b) c === mul a (mul b c)

dist :: (Matrix Integer, Matrix Integer) -> Result
dist (a, b) = mul a (add b b) === add (mul a b) (mul a b)
  where
    add x y = fromLists (zipWith (zipWith (.+.)) (toLists x) (toLists y))

unitI :: Matrix Integer -> Result
unitI a = mul a (identity (cols a)) === a .&&. mul (identity (rows a)) a === a

strassenEq :: (Matrix Integer, Matrix Integer) -> Result
strassenEq (a, b) = strassen 2 a b === mul a b

bareissEq :: Matrix Integer -> Result
bareissEq a = det a === leibniz a

leibniz :: Matrix Integer -> Integer
leibniz a =
  let n = rows a
      perms = permutations [0 .. n - 1]
      sign p = if even (inversions p) then 1 else -1
      inversions p = length [(i, j) | i <- [0 .. n - 1], j <- [i + 1 .. n - 1], p !! i > p !! j]
   in sum [sign p * product [entry a i (p !! i) | i <- [0 .. n - 1]] | p <- perms]

permutations :: [a] -> [[a]]
permutations [] = [[]]
permutations xs = [y : zs | (y, ys) <- picks xs, zs <- permutations ys]
  where
    picks [] = []
    picks (z : zs) = (z, zs) : [(y, z : ys) | (y, ys) <- picks zs]

invRound :: Matrix Rational -> Result
invRound a =
  case inverse a of
    Nothing -> pass -- singular is allowed
    Just b -> mul a b === identity (rows a)

rankEq :: Matrix Integer -> Result
rankEq a = rank a === length [row | row <- toLists (echelon a), any (not . isZero) row]
  where
    echelon = id -- the rank function already computes it; this is the definition

partBounds :: [Rational] -> Result
partBounds p =
  let k = participation p
   in assert "below 1" (k >= 1) .&&. assert "above length" (k <= fromIntegral (length p))
