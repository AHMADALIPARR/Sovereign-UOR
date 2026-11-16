-- SPDX-License-Identifier: AGPL-3.0-only
-- Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
-- Copyright (C) 2026 Ahmad Parr

-- | Exact Bernoulli numbers by the recurrence from the definition of the
-- generating function, so the denominators are the ones von Staudt-Clausen
-- predicts (AN-03).
module MP.Bernoulli
  ( bernoulli
  , bernoullis
  ) where

import Data.Ratio ((%))

-- | B_0, B_1, B_2, ... with B_1 = -1/2. The list is shared, so each number
-- is computed once from the ones before it:
-- B_m = -(1 / (m + 1)) * sum_{k < m} C(m + 1, k) B_k.
bernoullis :: [Rational]
bernoullis = map fst (iterate step (1, (0, [1])))
  where
    -- state: (B_m, (m, [B_m, B_(m-1), .., B_0]))
    step (_, (m, prev)) =
      let m' = m + 1
          s = sum [fromInteger (choose (m' + 1) k) * b | (k, b) <- zip [0 ..] (reverse prev)]
          b' = negate s * (1 % (m' + 1))
       in (b', (m', b' : prev))

-- | B_m as a rational; 0 for negative m.
bernoulli :: Int -> Rational
bernoulli m
  | m < 0 = 0
  | otherwise = case drop m bernoullis of
      (b : _) -> b
      [] -> 0

choose :: Integer -> Integer -> Integer
choose n k
  | k < 0 || k > n = 0
  | otherwise = product [n - k + 1 .. n] `div` product [1 .. k]
