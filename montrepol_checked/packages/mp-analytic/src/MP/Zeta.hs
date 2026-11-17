-- SPDX-License-Identifier: AGPL-3.0-or-later
-- | zeta by Euler-Maclaurin, Riemann-Siegel theta, and Hardy Z.
--
-- The closed forms for even integers use this package's Bernoulli numbers
-- (AN-04). The reality of exp(i theta(t)) zeta(1/2 + it) is the functional
-- equation (AN-05). The zeros of Z on the critical line are located by sign
-- changes and bisection (AN-06).
module MP.Zeta
  ( zeta
  , zetaC
  , theta
  , hardyZ
  , rotated
  , zerosUpTo
  ) where

import Data.Complex (Complex (..), cis, imagPart, realPart)
import MP.Bernoulli

-- | zeta(s) for real s > 1 by Euler-Maclaurin with N terms; NaN for s <= 1,
-- where the series this uses does not apply.
zeta :: Int -> Double -> Double
zeta n s
  | s <= 1 = 0 / 0
  | otherwise = realPart (eulerMaclaurin n 12 (s :+ 0))

-- | zeta(s) for complex s /= 1, with N and M chosen from |Im s|.
zetaC :: Complex Double -> Complex Double
zetaC s =
  let t = abs (imagPart s)
      n = 20 + ceiling (t / pi)
   in eulerMaclaurin n 20 s

-- | sum_{k=1}^{N} k^-s - N^-s / 2 + N^(1-s) / (s - 1)
--   + sum_{j=1}^{M} B_2j / (2j)! * s (s+1) .. (s+2j-2) * N^(1-s-2j).
eulerMaclaurin :: Int -> Int -> Complex Double -> Complex Double
eulerMaclaurin n m s =
  let nn = fromIntegral n :: Complex Double
      direct = sum [fromIntegral k ** negate s | k <- [1 .. n]]
      tailTerm = nn ** (1 - s) / (s - 1)
      half = 0.5 * nn ** negate s
      corrections = sum (take m (correctionTerms nn s))
   in direct + tailTerm - half + corrections

correctionTerms :: Complex Double -> Complex Double -> [Complex Double]
correctionTerms nn s = go 1 (s * nn ** (negate s - 1)) 2
  where
    -- At step j, rising = s (s+1) .. (s+2j-2) * N^(1-s-2j), fact = (2j)!.
    go :: Int -> Complex Double -> Double -> [Complex Double]
    go j rising fact =
      let b = fromRational (bernoulli (2 * j)) :: Double
          term = (b / fact :+ 0) * rising
          j' = fromIntegral j :: Complex Double
          rising' = rising * (s + 2 * j' - 1) * (s + 2 * j') / (nn * nn)
          fact' = fact * fromIntegral ((2 * j + 1) * (2 * j + 2))
       in term : go (j + 1) rising' fact'

-- | Riemann-Siegel theta(t) by its asymptotic expansion, accurate to about
-- 1e-12 for t >= 10.
theta :: Double -> Double
theta t =
  t / 2 * log (t / (2 * pi)) - t / 2 - pi / 8
    + 1 / (48 * t) + 7 / (5760 * t ^ (3 :: Int)) + 31 / (80640 * t ^ (5 :: Int))
    + 127 / (430080 * t ^ (7 :: Int)) + 511 / (1216512 * t ^ (9 :: Int))

-- | exp(i theta(t)) zeta(1/2 + it); real by the functional equation.
rotated :: Double -> Complex Double
rotated t = cis (theta t) * zetaC (0.5 :+ t)

-- | Hardy Z(t), the real part of 'rotated'.
hardyZ :: Double -> Double
hardyZ = realPart . rotated

-- | Zeros of Z on (lo, hi], found by scanning with step h for sign changes and
-- bisecting each to an interval of width eps.
zerosUpTo :: Double -> Double -> Double -> Double -> [Double]
zerosUpTo lo hi h eps =
  let n = ceiling ((hi - lo) / h) :: Int
      grid = [lo + fromIntegral k * h | k <- [0 .. n]]
      vals = [(t, hardyZ t) | t <- grid]
      brackets = [(a, b, za) | ((a, za), (b, zb)) <- zip vals (drop 1 vals), b <= hi + h, signum za /= signum zb, za /= 0]
   in [bisect a b za | (a, b, za) <- brackets, (a + b) / 2 <= hi]
  where
    bisect a b za
      | b - a <= eps = (a + b) / 2
      | otherwise =
          let c = (a + b) / 2
              zc = hardyZ c
           in if signum zc == signum za then bisect c b zc else bisect a c za

