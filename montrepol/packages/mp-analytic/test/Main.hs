module Main (main) where

import MP.Algebra
import MP.Bernoulli
import MP.Check
import MP.Primes
import MP.Zeta

main :: IO ()
main =
  runSuite
    "mp-analytic"
    [ prop "AN-01" "sieve matches trial division" (intIn 2 200) sieveOk
    , unit "AN-02" "von Mangoldt of prime powers" $ vonMangoldtExact 8 === Just 2
    , unit "AN-03" "B2 = 1/6" $ bernoulli 2 === 1 % 6
    , unit "AN-03" "B4 = -1/30" $ bernoulli 4 === (-1) % 30
    , unit "AN-04" "zeta(2) close to pi^2/6" $ abs (zeta 30 2 - pi * pi / 6) < 1e-6 === True
    , unit "AN-05" "Z(t) is real on the critical line (sample)" $ abs (snd (hardyZ 14.13)) < 1e-6 === True
    ]

sieveOk :: Int -> Result
sieveOk n = primesUpTo n === [p | p <- [2 .. n], isPrimeTrial p]
  where
    isPrimeTrial p = p >= 2 && all (\d -> p `mod` d /= 0) [2 .. floor (sqrt (fromIntegral p) :: Double)]
