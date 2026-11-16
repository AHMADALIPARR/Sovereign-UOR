{-# LANGUAGE DataKinds #-}

-- | Dense matrices with their dimensions in the type.
--
-- @Matrix m n a@ has @m@ rows and @n@ columns. Multiplication is
-- @Matrix m k a -> Matrix k n a -> Matrix m n a@, so a dimension mismatch is a
-- type error rather than a runtime check. The only partial operation in this
-- module is array indexing, and every index used is derived from the same
-- dimensions the array was built with.
module MP.Matrix
  ( Matrix
    -- * Construction
  , fromLists
  , generate
  , identity
  , zeroMatrix
  , diagonal
  , toLists
  , rows
  , cols
  , entry
  , withSize
    -- * Arithmetic
  , add
  , sub
  , negateM
  , scale
  , transpose
  , mul
  , mulStrassen
  , power
  , trace
    -- * Determinants, rank, inverse
  , det
  , detLeibniz
  , rank
  , inverse
  ) where

import Data.Array (Array, listArray, (!))
import Data.Proxy (Proxy (..))
import GHC.TypeNats (KnownNat, Nat, SomeNat (..), natVal, someNatVal)
import MP.Algebra
import Numeric.Natural (Natural)

------------------------------------------------------------------------------
-- Representation

-- | Row-major storage. The two 'Int's are the dimensions from the type, cached.
data Raw a = Raw !Int !Int !(Array Int a)

newtype Matrix (m :: Nat) (n :: Nat) a = Matrix (Raw a)

instance Eq a => Eq (Matrix m n a) where
  x == y = toLists x == toLists y

instance Show a => Show (Matrix m n a) where
  show = show . toLists

rawGen :: Int -> Int -> (Int -> Int -> a) -> Raw a
rawGen r c f =
  Raw r c (listArray (0, r * c - 1) [f i j | i <- [0 .. r - 1], j <- [0 .. c - 1]])

at :: Raw a -> Int -> Int -> a
at (Raw _ c arr) i j = arr ! (i * c + j)

rawLists :: Raw a -> [[a]]
rawLists raw@(Raw r c _) = [[at raw i j | j <- [0 .. c - 1]] | i <- [0 .. r - 1]]

dimOf :: forall k. KnownNat k => Proxy k -> Int
dimOf p = fromIntegral (natVal p)

------------------------------------------------------------------------------
-- Construction

-- | 'Nothing' unless the list has exactly @m@ rows of exactly @n@ entries.
fromLists :: forall m n a. (KnownNat m, KnownNat n) => [[a]] -> Maybe (Matrix m n a)
fromLists xss
  | length xss == r && all ((== c) . length) xss =
      Just (Matrix (Raw r c (listArray (0, r * c - 1) (concat xss))))
  | otherwise = Nothing
  where
    r = dimOf (Proxy :: Proxy m)
    c = dimOf (Proxy :: Proxy n)

generate :: forall m n a. (KnownNat m, KnownNat n) => (Int -> Int -> a) -> Matrix m n a
generate f = Matrix (rawGen (dimOf (Proxy :: Proxy m)) (dimOf (Proxy :: Proxy n)) f)

identity :: (KnownNat n, Semiring a) => Matrix n n a
identity = generate (\i j -> if i == j then one else zero)

zeroMatrix :: (KnownNat m, KnownNat n, Semiring a) => Matrix m n a
zeroMatrix = generate (\_ _ -> zero)

-- | The diagonal matrix with entry @f i@ at @(i, i)@.
diagonal :: (KnownNat n, Semiring a) => (Int -> a) -> Matrix n n a
diagonal f = generate (\i j -> if i == j then f i else zero)

toLists :: Matrix m n a -> [[a]]
toLists (Matrix raw) = rawLists raw

rows, cols :: Matrix m n a -> Int
rows (Matrix (Raw r _ _)) = r
cols (Matrix (Raw _ c _)) = c

entry :: Matrix m n a -> Int -> Int -> Maybe a
entry (Matrix raw@(Raw r c _)) i j
  | i >= 0 && i < r && j >= 0 && j < c = Just (at raw i j)
  | otherwise = Nothing

-- | Bring a runtime size into the type, for code (tests, mostly) that picks
-- dimensions at runtime.
withSize :: Natural -> (forall n. KnownNat n => Proxy n -> r) -> r
withSize k f = case someNatVal k of SomeNat p -> f p

------------------------------------------------------------------------------
-- Arithmetic

zipRaw :: (a -> b -> c) -> Raw a -> Raw b -> Raw c
zipRaw f x@(Raw r c _) y = rawGen r c (\i j -> f (at x i j) (at y i j))

mapRaw :: (a -> b) -> Raw a -> Raw b
mapRaw f x@(Raw r c _) = rawGen r c (\i j -> f (at x i j))

add :: Semiring a => Matrix m n a -> Matrix m n a -> Matrix m n a
add (Matrix x) (Matrix y) = Matrix (zipRaw (.+.) x y)

sub :: Ring a => Matrix m n a -> Matrix m n a -> Matrix m n a
sub (Matrix x) (Matrix y) = Matrix (zipRaw (.-.) x y)

negateM :: Ring a => Matrix m n a -> Matrix m n a
negateM (Matrix x) = Matrix (mapRaw neg x)

scale :: Semiring a => a -> Matrix m n a -> Matrix m n a
scale s (Matrix x) = Matrix (mapRaw (s .*.) x)

transpose :: Matrix m n a -> Matrix n m a
transpose (Matrix x@(Raw r c _)) = Matrix (rawGen c r (\i j -> at x j i))

-- | The definition: @(AB)_ij = sum_l A_il B_lj@. Works over any semiring.
mul :: Semiring a => Matrix m k a -> Matrix k n a -> Matrix m n a
mul (Matrix x) (Matrix y) = Matrix (naiveRaw x y)

naiveRaw :: Semiring a => Raw a -> Raw a -> Raw a
naiveRaw x@(Raw r k _) y@(Raw _ c _) =
  rawGen r c (\i j -> sumS [at x i l .*. at y l j | l <- [0 .. k - 1]])

-- | Strassen's algorithm. It needs subtraction, so it is over a 'Ring'.
--
-- Operands are padded with zeros to the next power of two and the result is
-- cropped; blocks at or below @cutoff@ rows use 'mul'. The cutoff changes cost,
-- never the result, and the tests check that for several cutoffs.
mulStrassen :: Ring a => Int -> Matrix m k a -> Matrix k n a -> Matrix m n a
mulStrassen cutoff (Matrix x@(Raw r k _)) (Matrix y@(Raw _ c _)) =
  let s = nextPow2 (foldr max 1 [r, k, c])
      pad z = rawGen s s (\i j -> let Raw zr zc _ = z in if i < zr && j < zc then at z i j else zero)
      full = strassenSq (max 1 cutoff) s (pad x) (pad y)
   in Matrix (rawGen r c (at full))

nextPow2 :: Int -> Int
nextPow2 n = head' (dropWhile (< n) (iterate (* 2) 1))
  where
    head' (v : _) = v
    head' [] = n

strassenSq :: Ring a => Int -> Int -> Raw a -> Raw a -> Raw a
strassenSq cutoff s a b
  | s <= cutoff = naiveRaw a b
  | otherwise =
      let h = s `div` 2
          q z r0 c0 = rawGen h h (\i j -> at z (r0 + i) (c0 + j))
          (a11, a12, a21, a22) = (q a 0 0, q a 0 h, q a h 0, q a h h)
          (b11, b12, b21, b22) = (q b 0 0, q b 0 h, q b h 0, q b h h)
          (+:) = zipRaw (.+.)
          (-:) = zipRaw (.-.)
          rec = strassenSq cutoff h
          m1 = rec (a11 +: a22) (b11 +: b22)
          m2 = rec (a21 +: a22) b11
          m3 = rec a11 (b12 -: b22)
          m4 = rec a22 (b21 -: b11)
          m5 = rec (a11 +: a12) b22
          m6 = rec (a21 -: a11) (b11 +: b12)
          m7 = rec (a12 -: a22) (b21 +: b22)
          c11 = ((m1 +: m4) -: m5) +: m7
          c12 = m3 +: m5
          c21 = m2 +: m4
          c22 = ((m1 -: m2) +: m3) +: m6
       in rawGen s s $ \i j -> case (i < h, j < h) of
            (True, True) -> at c11 i j
            (True, False) -> at c12 i (j - h)
            (False, True) -> at c21 (i - h) j
            (False, False) -> at c22 (i - h) (j - h)

-- | Exponentiation by squaring; @power a 0@ is the identity.
power :: (KnownNat n, Semiring a) => Matrix n n a -> Natural -> Matrix n n a
power a e
  | e == 0 = identity
  | even e = let h = power a (e `div` 2) in mul h h
  | otherwise = mul a (power a (e - 1))

trace :: Semiring a => Matrix n n a -> a
trace (Matrix x@(Raw r _ _)) = sumS [at x i i | i <- [0 .. r - 1]]

------------------------------------------------------------------------------
-- Determinants

-- | Fraction-free Gaussian elimination (Bareiss 1968). Every intermediate is
-- a minor of the input, so over 'Integer' nothing leaves the integers and no
-- entry grows beyond Hadamard's bound.
det :: Domain a => Matrix n n a -> a
det m = bareiss one one (toLists m)

bareiss :: Domain a => a -> a -> [[a]] -> a
bareiss _ sign [] = sign
bareiss prev sign rs = case pivotSplit rs of
  Nothing -> zero
  Just (swapped, pivotRow, others) ->
    let sign' = if swapped then neg sign else sign
     in case pivotRow of
          [] -> zero
          (p : prow)
            | null others -> sign' .*. p
            | otherwise ->
                let reduceRow r = case r of
                      [] -> []
                      (r0 : rrest) -> zipWith (\x y -> exactQuot ((x .*. p) .-. (r0 .*. y)) prev) rrest prow
                 in bareiss p sign' (map reduceRow others)

-- | The first row with a non-zero leading entry, moved to the front by a
-- single transposition with the current first row.
pivotSplit :: Semiring a => [[a]] -> Maybe (Bool, [a], [[a]])
pivotSplit rs = case break leadsNonZero rs of
  (_, []) -> Nothing
  ([], p : rest) -> Just (False, p, rest)
  (r0 : between, p : rest) -> Just (True, p, between ++ (r0 : rest))
  where
    leadsNonZero (x : _) = not (isZero x)
    leadsNonZero [] = False

-- | The Leibniz expansion, sum over permutations. Exponential: an oracle for
-- 'det' on small matrices, never something to call on a large one.
detLeibniz :: Ring a => Matrix n n a -> a
detLeibniz (Matrix x@(Raw r _ _)) =
  sumS
    [ (if even (inversions p) then id else neg) (productS [at x i j | (i, j) <- zip [0 ..] p])
    | p <- permutations' [0 .. r - 1]
    ]
  where
    inversions p = length [() | (i, a) <- zip [0 :: Int ..] p, (j, b) <- zip [0 ..] p, i < j, a > b]

-- | Permutations in an order whose correctness is easy to see.
permutations' :: [Int] -> [[Int]]
permutations' [] = [[]]
permutations' xs = [y : p | (y, ys) <- picks xs, p <- permutations' ys]
  where
    picks [] = []
    picks (z : zs) = (z, zs) : [(w, z : ws) | (w, ws) <- picks zs]

------------------------------------------------------------------------------
-- Rank and inverse over a field

-- | Row-reduce to echelon form and count pivots.
rank :: Field a => Matrix m n a -> Int
rank = go . toLists
  where
    go rs = case filter (not . null) rs of
      [] -> 0
      rs' -> case pivotSplit rs' of
        Nothing -> go (map (drop 1) rs') -- leading column is all zero
        Just (_, p, others) -> case p of
          [] -> 0
          (p0 : prest) -> case recipF p0 of
            Nothing -> 0
            Just pinv ->
              let elim r = case r of
                    [] -> []
                    (r0 : rrest) -> zipWith (\x y -> x .-. (r0 .*. pinv .*. y)) rrest prest
               in 1 + go (map elim others)

-- | Gauss–Jordan on @[A | I]@. 'Nothing' exactly when @A@ is singular.
inverse :: forall n a. (KnownNat n, Field a) => Matrix n n a -> Maybe (Matrix n n a)
inverse a = do
  let n = rows a
      augmented = zipWith (++) (toLists a) (toLists (identity :: Matrix n n a))
  reduced <- jordan 0 n augmented
  fromLists (map (drop n) reduced)

jordan :: Field a => Int -> Int -> [[a]] -> Maybe [[a]]
jordan k n rs
  | k >= n = Just rs
  | otherwise = do
      let (above, from) = splitAt k rs
      (pivot, rest) <- pickPivot from
      pinv <- recipF (col pivot)
      let pivot' = map (pinv .*.) pivot
          clear r = let f = col r in zipWith (\x y -> x .-. (f .*. y)) r pivot'
      jordan (k + 1) n (map clear above ++ (pivot' : map clear rest))
  where
    col r = case drop k r of
      (v : _) -> v
      [] -> zero
    pickPivot from = case break (not . isZero . col) from of
      (_, []) -> Nothing
      (before, p : after) -> Just (p, before ++ after)
