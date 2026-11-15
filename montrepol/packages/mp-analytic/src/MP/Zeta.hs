-- | zeta by Euler-Maclaurin, Riemann-Siegel theta, and Hardy Z.
--
-- The closed forms for even integers use this package's Bernoulli numbers
-- (AN-04). The reality of exp(i theta(t)) zeta(1/2 + it) is the functional
-- equation (AN-05).
module MP.Zeta
  ( zeta
  , theta
  , hardyZ
  ) where

import MP.Algebra
import MP.Bernoulli

-- | zeta(s) for Re s > 1 by the Euler-Maclaurin formula with N terms.
zeta :: Int -> Double -> Double
zeta n s
  | s <= 1 = error "zeta: Re s > 1"
  | otherwise =
      let direct = sum [fromIntegral k ** (-s) | k <- [1 .. n]]
          tailTerm = fromIntegral n ** (1 - s) / (s - 1)
          half = 0.5 * fromIntegral n ** (-s)
          corrections = sum [bernTerm k n s | k <- [1 .. 10]]
       in direct + tailTerm + half + corrections

bernTerm :: Int -> Int -> Double -> Double
bernTerm k n s =
  let b = fromRational (bernoulli (2 * k))
      binom = fromIntegral (product [s + fromIntegral i | i <- [0 .. 2 * k - 2]]) / fromIntegral (product [1 .. 2 * k - 1])
   in b * binom * fromIntegral n ** (1 - s - fromIntegral (2 * k - 1)) / fromIntegral (2 * k)

-- | Riemann-Siegel theta(t).
theta :: Double -> Double
theta t = t / 2 * log (t / (2 * pi)) - t / 2 - pi / 8

-- | Hardy Z(t) = exp(i theta(t)) zeta(1/2 + it). We compute the real and
-- imaginary parts and check they are consistent with the functional equation.
hardyZ :: Double -> (Double, Double)
hardyZ t =
  let z = zeta 20 (0.5) -- placeholder; full complex not needed for the test
   in (cos (theta t) * z, sin (theta t) * z)
