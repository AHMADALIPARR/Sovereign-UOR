-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | The Riemann zeta function, Hardy's Z function, and its zeros on the
-- critical line, in double precision.
--
-- Zeta is evaluated by Euler–Maclaurin summation, which is valid for every
-- @s /= 1@ and whose error is controlled by the two parameters: @N@ terms of
-- the Dirichlet series and @M@ Bernoulli corrections. The defaults are chosen
-- so the truncation error is far below double-precision rounding for
-- @|s| <= 10^3@; the tests compare against closed forms to @1e-12@.
module MP.Zeta
  ( zeta
  , zetaWith
  , theta
  , hardyZ
  , zerosBetween
  ) where

import Data.Complex (Complex (..), imagPart, magnitude, mkPolar, realPart)
import MP.Bernoulli (bernoulli)

-- | @zeta(s)@ with defaults that scale with @|s|@.
zeta :: Complex Double -> Complex Double
zeta s = zetaWith (20 + ceiling (magnitude s)) 24 s

-- | Euler–Maclaurin with @n@ terms and @m@ corrections:
--
-- > zeta(s) = sum_{k<n} k^-s + n^(1-s)/(s-1) + n^-s/2
-- >         + sum_{j=1..m} B_2j/(2j)! * s(s+1)..(s+2j-2) * n^(-s-2j+1) + R
--
-- At @s = 1@ (the pole) the result is not finite.
zetaWith :: Int -> Int -> Complex Double -> Complex Double
zetaWith n m s = direct + tailTerm + half + corrections
  where
    nd = fromIntegral n :: Double
    cpow x e = exp (e * (log x :+ 0)) -- x^e for real x > 0
    direct = sum [cpow (fromIntegral k) (negate s) | k <- [1 .. n - 1]]
    tailTerm = cpow nd (1 - s) / (s - 1)
    half = cpow nd (negate s) / 2
    corrections = sum (take m (zipWith3 term [1 ..] rising factorials))
    term j poch fac =
      let b = fromRational (bernoulli (2 * j)) :: Double
       in ((b / fac) :+ 0) * poch * cpow nd (negate s - fromIntegral (2 * j - 1))
    -- s(s+1)...(s+2j-2) for j = 1, 2, ..
    rising = scanl (\acc j -> acc * (s + fromIntegral (2 * j - 3)) * (s + fromIntegral (2 * j - 2))) s [2 :: Int ..]
    factorials = [product [1 .. fromIntegral (2 * j)] | j <- [1 :: Int ..]] :: [Double]

-- | The Riemann–Siegel theta function, @arg Gamma(1/4 + it/2) - (t/2) log pi@,
-- by its asymptotic expansion. The first omitted term is below @1e-12@ for
-- @t >= 10@, the only range used.
theta :: Double -> Double
theta t =
  t / 2 * log (t / (2 * pi)) - t / 2 - pi / 8
    + 1 / (48 * t)
    + 7 / (5760 * t ^ (3 :: Int))
    + 31 / (80640 * t ^ (5 :: Int))
    + 127 / (430080 * t ^ (7 :: Int))

-- | Hardy's @Z(t) = e^(i theta(t)) zeta(1/2 + it)@, which is real; its real
-- zeros are the zeros of zeta on the critical line. Also returns the
-- imaginary part, which is the numerical residue of that reality and is
-- tested to be negligible.
hardyZ :: Double -> (Double, Double)
hardyZ t =
  let v = mkPolar 1 (theta t) * zeta (0.5 :+ t)
   in (realPart v, imagPart v)

-- | Zeros of @Z@ in @(a, b]@, found as sign changes on a grid of the given
-- step and refined by bisection to the limit of double precision.
--
-- A pair of zeros closer together than the step, or a zero of even order,
-- is missed. That is a real limitation, not a formality; the tests check the
-- count against an independent table rather than assume completeness.
zerosBetween :: Double -> Double -> Double -> [Double]
zerosBetween step a b =
  [ bisect l r zl
  | ((l, zl), (r, zr)) <- zip samples (drop 1 samples)
  , signum zl /= signum zr
  , zl /= 0 || zr /= 0
  ]
  where
    grid = takeWhile (<= b) [a + step * fromIntegral k | k <- [0 :: Int ..]] ++ [b]
    samples = [(t, fst (hardyZ t)) | t <- grid]
    bisect l r zl = go (60 :: Int) l r zl
      where
        go 0 lo hi _ = (lo + hi) / 2
        go k lo hi zlo =
          let mid = (lo + hi) / 2
              zm = fst (hardyZ mid)
           in if zm == 0
                then mid
                else
                  if signum zm == signum zlo
                    then go (k - 1) mid hi zm
                    else go (k - 1) lo mid zlo
