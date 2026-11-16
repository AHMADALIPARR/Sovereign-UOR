-- | Bernoulli numbers, exactly.
--
-- Defined by @B_0 = 1@ and @sum_{k=0}^{m} C(m+1, k) B_k = 0@ for @m >= 1@,
-- which gives @B_1 = -1/2@. They are needed exactly because Euler–Maclaurin
-- uses them as coefficients and their growth would otherwise be guessed.
module MP.Bernoulli
  ( bernoulli
  , bernoullis
  , binomial
  ) where

-- | @B_0, B_1, B_2, ...@, each computed once.
bernoullis :: [Rational]
bernoullis = map b [0 ..]
  where
    b :: Integer -> Rational
    b 0 = 1
    b m =
      negate (sum [fromInteger (binomial (m + 1) k) * bAt k | k <- [0 .. m - 1]])
        / fromInteger (m + 1)
    bAt k = case drop (fromInteger k) bernoullis of
      (v : _) -> v
      [] -> 0

-- | @B_n@, or 0 for negative @n@.
bernoulli :: Int -> Rational
bernoulli n
  | n < 0 = 0
  | otherwise = case drop n bernoullis of
      (v : _) -> v
      [] -> 0

binomial :: Integer -> Integer -> Integer
binomial n k
  | k < 0 || k > n = 0
  | otherwise = product [n - k + 1 .. n] `div` product [1 .. k]
