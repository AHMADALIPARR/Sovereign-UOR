-- | The explicit formula for psi(x), truncated at the zeros we have.
module MP.ExplicitFormula
  ( explicitPsi
  ) where

import MP.Algebra
import MP.Primes

-- | psi(x) approximated by the explicit formula using the first N zeros.
-- The error term is left open (see the ledger).
explicitPsi :: Double -> Int -> Double
explicitPsi x n =
  let main = x
      zeros = [14.13, 21.02, 25.01] -- placeholder; the real oracle is in oracles/
      sumZeros = sum [x ** (0.5) * cos (t * log x) / (0.25 + t * t) | t <- take n zeros]
   in main - sumZeros
