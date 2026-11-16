-- SPDX-License-Identifier: AGPL-3.0-only
-- Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
-- Copyright (C) 2026 Ahmad Parr

module Main (main) where

import MP.Bernoulli
import MP.Primes
import MP.Zeta

main :: IO ()
main = do
  putStrLn "Bernoulli numbers:"
  mapM_ (\n -> putStrLn (show n <> ": " <> show (bernoulli n))) [0 .. 10 :: Int]
  putStrLn "\nPrimes up to 50:"
  print (primesUpTo 50)
  putStrLn "\nzeta(2) by Euler-Maclaurin with N = 40:"
  print (zeta 40 2)
