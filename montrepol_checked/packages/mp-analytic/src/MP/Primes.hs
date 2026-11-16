-- SPDX-License-Identifier: AGPL-3.0-only
-- Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
-- Copyright (C) 2026 Ahmad Parr

-- | The sieve of Eratosthenes, von Mangoldt and Chebyshev psi, all exact.
--
-- Lambda(n) is log p when n = p^k and 0 otherwise, so it is represented by
-- its support: 'vonMangoldt' returns the prime p. Chebyshev psi(x) is the
-- sum of Lambda(n) for n <= x, which is log lcm(1..x); 'psiExp' returns that
-- lcm exactly and 'psi' its logarithm.
module MP.Primes
  ( primesUpTo
  , isPrime
  , vonMangoldt
  , psiExp
  , psi
  ) where

import Data.Array (accumArray, assocs)

primesUpTo :: Int -> [Int]
primesUpTo n
  | n < 2 = []
  | otherwise =
      let composite = accumArray (\_ b -> b) False (2, n) [(j, True) | i <- [2 .. isqrt n], j <- [i * i, i * i + i .. n]]
       in [i | (i, False) <- assocs composite]

isqrt :: Int -> Int
isqrt n = go 0
  where
    go k = if (k + 1) * (k + 1) <= n then go (k + 1) else k

isPrime :: Int -> Bool
isPrime n = n `elem` primesUpTo n

-- | The prime p with n = p^k (k >= 1), or Nothing when Lambda(n) = 0.
vonMangoldt :: Int -> Maybe Int
vonMangoldt n
  | n < 2 = Nothing
  | otherwise =
      case [p | p <- [2 .. n], n `mod` p == 0] of
        (p : _) | isPower n p -> Just p
        _ -> Nothing

isPower :: Int -> Int -> Bool
isPower n p
  | n == 1 = True
  | n `mod` p == 0 = isPower (n `div` p) p
  | otherwise = False

-- | exp(psi(x)) = product of p over prime powers p^k <= x.
psiExp :: Int -> Integer
psiExp x = product [toInteger p | k <- [2 .. x], Just p <- [vonMangoldt k]]

psi :: Int -> Double
psi x = sum [log (fromIntegral p) | k <- [2 .. x], Just p <- [vonMangoldt k]]
