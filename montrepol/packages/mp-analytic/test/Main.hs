module Main (main) where

import Data.Complex (Complex (..), magnitude)
import Data.Ratio (denominator, (%))
import MP.Bernoulli
import MP.Check
import MP.Primes
import MP.Zeta
import Text.Read (readMaybe)

main :: IO ()
main =
  runSuite
    "mp-analytic"
    [ unit "AN-01" "the sieve agrees with trial division up to 5000" $
        primesUpTo 5000 === filter isPrimeTrial [1 .. 5000]
    , unit "AN-01" "pi(10^k) for k = 1..6 matches OEIS A006880" $
        map (primeCount . (10 ^)) [1 .. 6 :: Int] === [4, 25, 168, 1229, 9592, 78498]
    , unit "AN-02" "prod over prime powers p^k <= x of p equals lcm(1..x), x <= 300" $
        map primePowerProduct [1 .. 300] === map (\x -> foldr lcm 1 [1 .. toInteger x]) [1 .. 300 :: Int]
    , unit "AN-02" "psi(x) equals log lcm(1..x) to 1e-12 relative, x <= 600" $
        allOf
          [ assert ("x = " <> show x) (abs (chebyshevPsi (fromIntegral x) - lg) <= 1e-12 * max 1 lg)
          | x <- [2 .. 600 :: Int]
          , let lg = log (fromInteger (primePowerProduct x) :: Double)
          ]
    , unit "AN-03" "B_0..B_12 match the classical values" $
        map bernoulli [0 .. 12]
          === [1, -1 % 2, 1 % 6, 0, -1 % 30, 0, 1 % 42, 0, -1 % 30, 0, 5 % 66, 0, -691 % 2730]
    , unit "AN-03" "von Staudt–Clausen: B_2n + sum_{(p-1) | 2n} 1/p is an integer, 2n <= 80" $
        allOf
          [ assert ("2n = " <> show n2) (denominator (bernoulli n2 + sum [1 % toInteger p | p <- primesUpTo (n2 + 1), n2 `mod` (p - 1) == 0]) == 1)
          | n2 <- [2, 4 .. 80]
          ]
    , unit "AN-04" "zeta(2) = pi^2/6, zeta(4) = pi^4/90, zeta(0) = -1/2, zeta(-1) = -1/12" $
        allOf
          [ close 1e-12 (zeta 2) (pi ^ (2 :: Int) / 6)
          , close 1e-12 (zeta 4) (pi ^ (4 :: Int) / 90)
          , close 1e-12 (zeta 0) (-0.5)
          , close 1e-12 (zeta (-1)) (-1 / 12)
          , close 1e-12 (zeta 0.5) (-1.4603545088095868)
          ]
    , unit "AN-04" "Euler: zeta(2k) = (-1)^(k+1) B_2k (2 pi)^2k / (2 (2k)!), k = 1..10" $
        allOf
          [ close 1e-12 (zeta (fromIntegral (2 * k))) (euler k)
          | k <- [1 .. 10 :: Int]
          ]
    , prop "AN-05" "Z(t) is real: |Im e^(i theta) zeta(1/2 + it)| < 1e-9 on [10, 800]" (integerIn 1000 80000) $ \c ->
        let t = fromInteger c / 100 :: Double
            (_, im) = hardyZ t
         in assert ("Im = " <> show im <> " at t = " <> show t) (abs im < 1e-9)
    , unitIO "AN-06" "all 512 tabulated zeros are found, each to 1e-8, and no others" $ do
        table <- readOracle
        let found = zerosBetween 0.05 10 827
        pure $
          length found === length table
            .&&. allOf
              [ assert ("zero " <> show i <> ": " <> show f <> " vs " <> show g) (abs (f - g) < 1e-8)
              | (i, f, g) <- zip3 [1 :: Int ..] found table
              ]
    ]
  where
    euler k =
      let b = fromRational (bernoulli (2 * k)) :: Double
          sign = if even k then -1 else 1
       in sign * b * (2 * pi) ^ (2 * k) / (2 * product [1 .. fromIntegral (2 * k)])

close :: Double -> Complex Double -> Double -> Result
close tol z x =
  assert (show z <> " is not within " <> show tol <> " of " <> show x) (magnitude (z - (x :+ 0)) <= tol * max 1 (abs x))

-- | Odlyzko's table, as committed under @oracles/@. The test runs from the
-- package directory.
readOracle :: IO [Double]
readOracle = do
  txt <- readFile "../../oracles/zeta-zeros-odlyzko.txt"
  pure [g | l <- lines txt, take 1 l /= "#", [_, w] <- [words l], Just g <- [readMaybe w]]
