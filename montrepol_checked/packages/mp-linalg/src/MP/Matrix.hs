-- | Matrices over a semiring.
--
-- The product is the definition: the (i, j) entry is the sum of the products
-- of the i-th row and the j-th column. Strassen is a second implementation of
-- the same product, checked against the definition (LA-03). Bareiss is the
-- integer-preserving elimination for the determinant (LA-04).
--
-- Dimensions are carried at run time, not in the type. Every function is
-- total: a matrix is treated as zero outside its stored shape, so a product
-- of mismatched shapes pads the shorter inner dimension with zeros, and the
-- determinant of a non-square matrix is that of its zero-padded square.
module MP.Matrix
  ( Matrix
  , rows
  , cols
  , entry
  , fromLists
  , toLists
  , identity
  , addM
  , subM
  , mul
  , strassen
  , det
  , echelon
  , rank
  , inverse
  ) where

import Data.Array (Array, listArray, bounds, (!))
import MP.Algebra

data Matrix a = Matrix Int Int (Array (Int, Int) a)

instance Eq a => Eq (Matrix a) where
  x == y = rows x == rows y && cols x == cols y && toLists x == toLists y

instance Show a => Show (Matrix a) where
  show x = "fromLists " <> show (toLists x)

rows, cols :: Matrix a -> Int
rows (Matrix m _ _) = m
cols (Matrix _ n _) = n

-- | The (i, j) entry, or zero outside the shape.
entry :: Semiring a => Matrix a -> Int -> Int -> a
entry (Matrix m n a) i j
  | i < 0 || j < 0 || i >= m || j >= n = zero
  | otherwise = a ! (i, j)

-- | Build an m x n matrix from a generator.
generate :: Int -> Int -> (Int -> Int -> a) -> Matrix a
generate m0 n0 f =
  let m = max 0 m0
      n = max 0 n0
   in Matrix m n (listArray ((0, 0), (m - 1, n - 1)) [f i j | i <- [0 .. m - 1], j <- [0 .. n - 1]])

-- | Rows of unequal length are padded with zeros to the longest.
fromLists :: Semiring a => [[a]] -> Matrix a
fromLists rs =
  let m = length rs
      n = foldr (max . length) 0 rs
      padded = [take n (r ++ repeat zero) | r <- rs]
   in Matrix m n (listArray ((0, 0), (m - 1, n - 1)) (concat padded))

toLists :: Matrix a -> [[a]]
toLists (Matrix m n a) =
  let ((r0, c0), _) = bounds a
   in [[a ! (r0 + i, c0 + j) | j <- [0 .. n - 1]] | i <- [0 .. m - 1]]

identity :: Semiring a => Int -> Matrix a
identity k = generate k k (\i j -> if i == j then one else zero)

addM :: Semiring a => Matrix a -> Matrix a -> Matrix a
addM x y = generate (max (rows x) (rows y)) (max (cols x) (cols y)) (\i j -> entry x i j .+. entry y i j)

subM :: Ring a => Matrix a -> Matrix a -> Matrix a
subM x y = generate (max (rows x) (rows y)) (max (cols x) (cols y)) (\i j -> entry x i j .-. entry y i j)

-- | The definition of the product.
mul :: Semiring a => Matrix a -> Matrix a -> Matrix a
mul x y =
  let p = max (cols x) (rows y)
   in generate (rows x) (cols y) (\i j -> sumS [entry x i k .*. entry y k j | k <- [0 .. p - 1]])

-- | Strassen, with a cutoff. When any dimension is below the cutoff (or the
-- cutoff is below 2, which would never terminate) it is the definition.
strassen :: Ring a => Int -> Matrix a -> Matrix a -> Matrix a
strassen cutoff x y
  | cutoff < 2 || rows x < cutoff || cols x < cutoff || rows y < cutoff || cols y < cutoff = mul x y
  | otherwise = strassen' cutoff x y

strassen' :: Ring a => Int -> Matrix a -> Matrix a -> Matrix a
strassen' cutoff x y =
  let s = largest [rows x, cols x, rows y, cols y]
      h = (s + 1) `div` 2
      -- Quadrant (qi, qj) of a matrix, zero-padded to h x h.
      quad a qi qj = generate h h (\r c -> entry a (qi * h + r) (qj * h + c))
      a11 = quad x 0 0; a12 = quad x 0 1; a21 = quad x 1 0; a22 = quad x 1 1
      b11 = quad y 0 0; b12 = quad y 0 1; b21 = quad y 1 0; b22 = quad y 1 1
      m1 = strassen cutoff (addM a11 a22) (addM b11 b22)
      m2 = strassen cutoff (addM a21 a22) b11
      m3 = strassen cutoff a11 (subM b12 b22)
      m4 = strassen cutoff a22 (subM b21 b11)
      m5 = strassen cutoff (addM a11 a12) b22
      m6 = strassen cutoff (subM a21 a11) (addM b11 b12)
      m7 = strassen cutoff (subM a12 a22) (addM b21 b22)
      c11 = addM (subM (addM m1 m4) m5) m7
      c12 = addM m3 m5
      c21 = addM m2 m4
      c22 = addM (addM (subM m1 m2) m3) m6
      pick r c
        | r < h && c < h = entry c11 r c
        | r < h = entry c12 r (c - h)
        | c < h = entry c21 (r - h) c
        | otherwise = entry c22 (r - h) (c - h)
   in generate (rows x) (cols y) pick
  where
    largest = foldr max 0

-- | Bareiss determinant, integer-preserving: every division is by the
-- previous pivot and is exact. A row swap flips the sign. A matrix with no
-- pivot in some column is singular and has determinant zero.
det :: (ExactDivision a, Eq a) => Matrix a -> a
det a0 =
  let n = max (rows a0) (cols a0)
      a = generate n n (entry a0)
      go k sgn a' prev
        | k >= n - 1 = if sgn then entry a' (n - 1) (n - 1) else neg (entry a' (n - 1) (n - 1))
        | otherwise =
            case findPivot k k a' of
              Nothing -> zero
              Just p ->
                let swapped = swapRows k p a'
                    sgn' = if p == k then sgn else not sgn
                    piv = entry swapped k k
                 in go (k + 1) sgn' (eliminate k k piv prev swapped) piv
   in if n == 0 then one else go 0 True a one

-- | First row at or below @r@ with a nonzero entry in column @c@.
findPivot :: (Eq a, Semiring a) => Int -> Int -> Matrix a -> Maybe Int
findPivot r c a =
  case [i | i <- [r .. rows a - 1], not (isZero (entry a i c))] of
    [] -> Nothing
    (i : _) -> Just i

swapRows :: Semiring a => Int -> Int -> Matrix a -> Matrix a
swapRows r s a
  | r == s = a
  | otherwise = generate (rows a) (cols a) (\i j -> if i == r then entry a s j else if i == s then entry a r j else entry a i j)

-- | One Bareiss step with pivot at (r, c): every row below r becomes
-- (piv * row - a_ic * row_r) / prev. Rows at or above r are unchanged.
eliminate :: ExactDivision a => Int -> Int -> a -> a -> Matrix a -> Matrix a
eliminate r c piv prev a =
  generate (rows a) (cols a) $ \i j ->
    if i <= r
      then entry a i j
      else (piv .*. entry a i j .-. entry a i c .*. entry a r j) `exactDiv` prev

-- | Fraction-free row echelon form (Bareiss). Columns without a pivot are
-- skipped, so the result is in echelon form for any shape.
echelon :: (ExactDivision a, Eq a) => Matrix a -> Matrix a
echelon a0 = go 0 0 one a0
  where
    go r c prev a
      | r >= rows a || c >= cols a = a
      | otherwise =
          case findPivot r c a of
            Nothing -> go r (c + 1) prev a
            Just p ->
              let swapped = swapRows r p a
                  piv = entry swapped r c
               in go (r + 1) (c + 1) piv (eliminate r c piv prev swapped)

-- | Rank as the number of nonzero rows of the Bareiss echelon form.
rank :: (ExactDivision a, Eq a) => Matrix a -> Int
rank a = length [row | row <- toLists (echelon a), any (not . isZero) row]

-- | Inverse by Gauss-Jordan elimination on the matrix with the identity
-- adjoined. Nothing if singular or not square.
inverse :: (Field a, Eq a) => Matrix a -> Maybe (Matrix a)
inverse a
  | rows a /= cols a = Nothing
  | otherwise = go 0 (generate n (2 * n) aug)
  where
    n = rows a
    aug i j = if j < n then entry a i j else if j - n == i then one else zero
    go k b
      | k >= n = Just (generate n n (\i j -> entry b i (j + n)))
      | otherwise =
          case findPivot k k b of
            Nothing -> Nothing
            Just p ->
              let b1 = swapRows k p b
               in case recipF (entry b1 k k) of
                    Nothing -> Nothing
                    Just r ->
                      let b2 = generate n (2 * n) (\i j -> if i == k then r .*. entry b1 i j else entry b1 i j)
                          b3 = generate n (2 * n) (\i j -> if i == k then entry b2 i j else entry b2 i j .-. entry b2 i k .*. entry b2 k j)
                       in go (k + 1) b3
