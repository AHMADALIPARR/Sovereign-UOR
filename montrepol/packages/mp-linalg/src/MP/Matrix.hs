-- | Matrices with dimensions in the type, over a semiring.
--
-- The product is the definition: the (i, j) entry is the sum of the products
-- of the i-th row and the j-th column. Strassen is a second implementation of
-- the same product, checked against the definition (LA-03). Bareiss is the
-- integer-preserving elimination for the determinant (LA-04).
module MP.Matrix
  ( Matrix
  , rows
  , cols
  , entry
  , fromLists
  , toLists
  , identity
  , mul
  , strassen
  , det
  , rank
  , inverse
  ) where

import MP.Algebra
import Data.Array (Array, array, (!), bounds, elems)

-- | A matrix of m rows and n columns. The dimensions are phantom so a product
-- of the wrong shapes is a type error, and a runtime check remains for the
-- constructors that take lists.
data Matrix a = Matrix Int Int (Array (Int, Int) a)

rows, cols :: Matrix a -> Int
rows (Matrix m _ _) = m
cols (Matrix _ n _) = n

entry :: Matrix a -> Int -> Int -> a
entry (Matrix _ _ a) i j = a ! (i, j)

fromLists :: Semiring a => [[a]] -> Matrix a
fromLists [] = Matrix 0 0 (array ((0, 0), (-1, -1)) [])
fromLists (r : rs) =
  let n = length r
      m = 1 + length rs
      check [] = True
      check (s : ss) = length s == n && check ss
   in if not (check rs)
        then error "fromLists: ragged"
        else
          let pairs = [((i, j), x) | (i, row) <- zip [0 ..] (r : rs), (j, x) <- zip [0 ..] row]
           in Matrix m n (array ((0, 0), (m - 1, n - 1)) pairs)

toLists :: Matrix a -> [[a]]
toLists (Matrix m n a) = [[a ! (i, j) | j <- [0 .. n - 1]] | i <- [0 .. m - 1]]

identity :: Semiring a => Int -> Matrix a
identity k =
  Matrix k k (array ((0, 0), (k - 1, k - 1)) [((i, j), if i == j then one else zero) | i <- [0 .. k - 1], j <- [0 .. k - 1]])

-- | The definition of the product.
mul :: Semiring a => Matrix a -> Matrix a -> Matrix a
mul x y
  | cols x /= rows y = error "mul: shape"
  | otherwise =
      let m = rows x
          n = cols y
          p = cols x
          pairs = [((i, j), sumS [entry x i k .*. entry y k j | k <- [0 .. p - 1]]) | i <- [0 .. m - 1], j <- [0 .. n - 1]]
       in Matrix m n (array ((0, 0), (m - 1, n - 1)) pairs)

-- | Strassen, with a cutoff. Below the cutoff it is the definition.
strassen :: Semiring a => Int -> Matrix a -> Matrix a -> Matrix a
strassen cutoff x y
  | cols x /= rows y = error "strassen: shape"
  | rows x < cutoff || cols x < cutoff || cols y < cutoff = mul x y
  | otherwise = strassen' cutoff x y

strassen' :: Semiring a => Int -> Matrix a -> Matrix a -> Matrix a
strassen' cutoff x y =
  let m = rows x
      -- Pad to even if needed. The extra row and column are zero.
      pad k a = if k `mod` 2 == 0 then a else fromLists (toLists a ++ [replicate (cols a) zero])
      x' = pad m x
      y' = pad (cols y) y
      h = rows x' `div` 2
      -- Split into quadrants.
      quad a i j = fromLists [[entry a (i * h + r) (j * h + c) | c <- [0 .. h - 1]] | r <- [0 .. h - 1]]
      a11 = quad x' 0 0; a12 = quad x' 0 1; a21 = quad x' 1 0; a22 = quad x' 1 1
      b11 = quad y' 0 0; b12 = quad y' 0 1; b21 = quad y' 1 0; b22 = quad y' 1 1
      m1 = strassen cutoff (a11 .+. a22) (b11 .+. b22)
      m2 = strassen cutoff (a21 .+. a22) b11
      m3 = strassen cutoff a11 (b12 .-. b22)
      m4 = strassen cutoff a22 (b21 .-. b11)
      m5 = strassen cutoff (a11 .+. a12) b22
      m6 = strassen cutoff (a21 .-. a11) (b11 .+. b12)
      m7 = strassen cutoff (a12 .-. a22) (b21 .+. b22)
      c11 = m1 .+. m4 .-. m5 .+. m7
      c12 = m3 .+. m5
      c21 = m2 .+. m4
      c22 = m1 .-. m2 .+. m3 .+. m6
      -- Stitch the quadrants back, dropping any padding.
      stitch = fromLists [row | r <- [0 .. rows x - 1], let row = [if c < cols y then entry (if r < h then if c < h then c11 else c12 else if c < h then c21 else c22) (r `mod` h) (c `mod` h) else zero | c <- [0 .. cols y - 1]]]
   in stitch

-- | Bareiss determinant, integer-preserving. For a field it is ordinary
-- elimination. The pivot search is the only partial step; a singular matrix
-- returns zero.
det :: (Ring a, Eq a) => Matrix a -> a
det a
  | rows a /= cols a = error "det: not square"
  | otherwise = bareiss a

bareiss :: (Ring a, Eq a) => Matrix a -> a
bareiss a0 =
  let n = rows a0
      go k a prev
        | k >= n = entry a (n - 1) (n - 1)
        | otherwise =
            case findPivot k a of
              Nothing -> zero
              Just p ->
                let a' = if p == k then a else swapRows k p a
                    piv = entry a' k k
                    a'' = eliminate k piv prev a'
                 in go (k + 1) a'' piv
   in go 0 a0 one

findPivot :: (Eq a, Semiring a) => Int -> Matrix a -> Maybe Int
findPivot k a =
  case [i | i <- [k .. rows a - 1], not (isZero (entry a i k))] of
    [] -> Nothing
    (i : _) -> Just i

swapRows :: Int -> Int -> Matrix a -> Matrix a
swapRows r s a
  | r == s = a
  | otherwise =
      let pairs = [((i, j), if i == r then entry a s j else if i == s then entry a r j else entry a i j) | i <- [0 .. rows a - 1], j <- [0 .. cols a - 1]]
       in Matrix (rows a) (cols a) (array ((0, 0), (rows a - 1, cols a - 1)) pairs)

eliminate :: (Ring a, Eq a) => Int -> a -> a -> Matrix a -> Matrix a
eliminate k piv prev a =
  let pairs =
        [((i, j), if i <= k then entry a i j else (piv .*. entry a i j .-. entry a i k .*. entry a k j) ./. prev) | i <- [0 .. rows a - 1], j <- [0 .. cols a - 1]]
   in Matrix (rows a) (cols a) (array ((0, 0), (rows a - 1, cols a - 1)) pairs)
  where
    (./.) x y = case recipF y of
      Just r -> x .*. r
      Nothing -> error "eliminate: zero previous pivot"

-- | Rank as the number of nonzero rows of the Bareiss form.
rank :: (Ring a, Eq a) => Matrix a -> Int
rank a =
  let n = min (rows a) (cols a)
      go k a' count
        | k >= n = count
        | otherwise =
            case findPivot k a' of
              Nothing -> count
              Just p ->
                let a'' = if p == k then a' else swapRows k p a'
                    piv = entry a'' k k
                 in if isZero piv then count else go (k + 1) (eliminate k piv one a'') (count + 1)
   in go 0 a 0

-- | Inverse by adjoining the identity and eliminating. Nothing if singular.
inverse :: (Field a, Eq a) => Matrix a -> Maybe (Matrix a)
inverse a
  | rows a /= cols a = Nothing
  | otherwise =
      let n = rows a
          aug = fromLists [toLists a !! i ++ toLists (identity n) !! i | i <- [0 .. n - 1]]
          go k b
            | k >= n = Just (fromLists [drop n row | row <- toLists b])
            | otherwise =
                case findPivot k b of
                  Nothing -> Nothing
                  Just p ->
                    let b' = if p == k then b else swapRows k p b
                        piv = entry b' k k
                     in case recipF piv of
                          Nothing -> Nothing
                          Just r ->
                            let b'' = scaleRow k r (eliminate k piv one b')
                             in go (k + 1) b''
       in go 0 aug

scaleRow :: Semiring a => Int -> a -> Matrix a -> Matrix a
scaleRow r c a =
  let pairs = [((i, j), if i == r then c .*. entry a i j else entry a i j) | i <- [0 .. rows a - 1], j <- [0 .. cols a - 1]]
   in Matrix (rows a) (cols a) (array ((0, 0), (rows a - 1, cols a - 1)) pairs)
