-- | Exact Bernoulli numbers by the recurrence from the definition of the
-- generating function, so the denominators are the ones von Staudt-Clausen
-- predicts (AN-03).
module MP.Bernoulli
  ( bernoulli
  ) where

import MP.Algebra

-- | B_m as a rational. B_1 = -1/2 (the convention that makes Euler-Maclaurin
-- clean).
bernoulli :: Int -> Rational
bernoulli 0 = 1
bernoulli 1 = -1 % 2
bernoulli m
  | m < 0 = 0
  | otherwise =
      let s = sumS [fromIntegral (choose m k) * bernoulli k | k <- [0 .. m - 1]]
       in -s / fromIntegral (m + 1)

choose :: Int -> Int -> Integer
choose n k
  | k < 0 || k > n = 0
  | otherwise = product [fromIntegral (n - i + 1) | i <- [1 .. k]] `div` product [1 .. fromIntegral k]
