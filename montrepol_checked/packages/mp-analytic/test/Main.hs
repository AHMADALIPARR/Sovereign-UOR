-- SPDX-License-Identifier: AGPL-3.0-only
-- Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
-- Copyright (C) 2026 Ahmad Parr

module Main (main) where

import Data.Complex (imagPart)
import Data.Ratio (denominator, (%))
import MP.Bernoulli
import MP.Check
import MP.Primes
import MP.Zeta
import System.IO (IOMode (..), hGetContents', withFile)
import Text.Read (readMaybe)

main :: IO ()
main = do
  table <- readOracle "../../../montrepol/oracles/zeta-zeros-odlyzko_checked.txt"
  runSuite
    "mp-analytic"
    [ prop "AN-01" "sieve matches trial division" (intIn 2 2000) sieveOk
    , unit "AN-02" "von Mangoldt is supported exactly on prime powers, n <= 1000" $
        allOf [vonMangoldt n === lambdaDef n | n <- [1 .. 1000]]
    , unit "AN-02" "von Mangoldt of 8 is log 2" $ vonMangoldt 8 === Just 2
    , unit "AN-02" "exp(psi(x)) = lcm(1..x) for x <= 300" $
        allOf [psiExp x === foldr lcm 1 [1 .. toInteger x] | x <- [1 .. 300]]
    , unit "AN-03" "B2 = 1/6" $ bernoulli 2 === 1 % 6
    , unit "AN-03" "B4 = -1/30" $ bernoulli 4 === (-1) % 30
    , unit "AN-03" "odd Bernoulli numbers above B1 vanish, up to B61" $
        allOf [bernoulli m === 0 | m <- [3, 5 .. 61]]
    , unit "AN-03" "von Staudt-Clausen denominators, B2 .. B60" $
        allOf [denominator (bernoulli (2 * k)) === vsc (2 * k) | k <- [1 .. 30]]
    , unit "AN-04" "zeta(2k) = (-1)^(k+1) B_2k (2 pi)^2k / (2 (2k)!) for k = 1..4, to 1e-12" $
        allOf [assert ("k = " <> show k) (abs (zeta 30 (fromIntegral (2 * k)) - closed k) < 1e-12) | k <- [1 .. 4 :: Int]]
    , prop "AN-05" "exp(i theta(t)) zeta(1/2 + it) is real to 1e-9, t in [10, 800]" (rationalIn 10000 800000 1) realOnLine
    , unit "AN-06" "the oracle table has 512 rows" $ length table === 512
    , unit "AN-06" "zeros of Z on (10, 827] are the 512 tabulated zeros, each to 1e-8" $
        matchZeros (zerosUpTo 10 827 0.05 1e-11) table
    ]

readOracle :: FilePath -> IO [Double]
readOracle p = do
  txt <- withFile p ReadMode hGetContents'
  pure [g | l <- lines txt, take 1 l /= "#", [_, w] <- [words l], Just g <- [readMaybe w]]

sieveOk :: Int -> Result
sieveOk n = primesUpTo n === [p | p <- [2 .. n], isPrimeTrial p]
  where
    isPrimeTrial p = p >= 2 && all (\d -> p `mod` d /= 0) (takeWhile (\d -> d * d <= p) [2 ..])

-- | The definition, by trial factorisation: n is a power of its least prime
-- factor exactly when dividing that factor out leaves 1.
lambdaDef :: Int -> Maybe Int
lambdaDef n
  | n < 2 = Nothing
  | otherwise =
      let p = case [d | d <- [2 .. n], n `mod` d == 0] of
            (d : _) -> d
            [] -> n
          strip m = if m `mod` p == 0 then strip (m `div` p) else m
       in if strip n == 1 then Just p else Nothing

-- | Product of the primes p with (p - 1) dividing 2k.
vsc :: Int -> Integer
vsc k2 = product [toInteger p | p <- primesUpTo (k2 + 1), k2 `mod` (p - 1) == 0]

closed :: Int -> Double
closed k =
  let b = fromRational (bernoulli (2 * k))
      fact = fromInteger (product [1 .. toInteger (2 * k)])
   in (if odd k then 1 else -1) * b * (2 * pi) ^ (2 * k) / (2 * fact)

realOnLine :: Rational -> Result
realOnLine r =
  let t = fromRational r / 1000
      im = imagPart (rotated t)
   in assert ("Im = " <> show im <> " at t = " <> show t) (abs im < 1e-9)

matchZeros :: [Double] -> [Double] -> Result
matchZeros found table =
  length found === length table
    .&&. allOf [assert ("zero " <> show i <> ": found " <> show f <> ", table " <> show g) (abs (f - g) < 1e-8) | (i, f, g) <- zip3 [1 :: Int ..] found table]
