-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | Measures, and only measures, how well the truncated explicit formula
-- reproduces psi(x). The numbers this prints are the evidence for the
-- ledger's @open@ rows; nothing here is asserted, because no error bound for
-- the truncation is proved in this repository.
module Main (main) where

import MP.ExplicitFormula (psiExplicit)
import MP.Primes (chebyshevPsi, primePowerBase)
import MP.Zeta (zerosBetween)
import Text.Printf (printf)

main :: IO ()
main = do
  let zeros = zerosBetween 0.05 10 827
      -- Midpoints between integers avoid the jumps of psi at prime powers.
      xs = [x + 0.5 | x <- [20, 40 .. 1000], primePowerBase (floor (x + 0.5)) == Nothing] :: [Double]
  printf "zeros found on (10, 827]: %d\n\n" (length zeros)
  printf "%8s %12s %14s %14s %14s\n" "M" "x range" "mean |err|" "max |err|" "max |err|/sqrt x"
  mapM_
    ( \m -> do
        let gs = take m zeros
            errs = [(x, abs (chebyshevPsi x - psiExplicit gs x)) | x <- xs]
            mean = sum (map snd errs) / fromIntegral (length errs)
            worst = foldr (max . snd) 0 errs
            scaled = foldr max 0 [e / sqrt x | (x, e) <- errs]
        printf "%8d %12s %14.6f %14.6f %14.6f\n" m "20.5..980.5" mean worst scaled
    )
    [0, 1, 10, 50, 100, 250, 512 :: Int]
