-- | The explicit formula for psi(x), truncated at the zeros supplied.
module MP.ExplicitFormula
  ( explicitPsi
  ) where

-- | psi(x) by the von Mangoldt explicit formula using the given ordinates
-- gamma of zeros 1/2 + i gamma (each paired with its conjugate):
--
-- x - sum_rho 2 Re(x^rho / rho) - log(2 pi) - log(1 - x^-2) / 2.
--
-- The error under truncation is left open (see the ledger).
explicitPsi :: Double -> [Double] -> Double
explicitPsi x gammas =
  let lx = log x
      term g = 2 * sqrt x * (0.5 * cos (g * lx) + g * sin (g * lx)) / (0.25 + g * g)
   in x - sum (map term gammas) - log (2 * pi) - 0.5 * log (1 - 1 / (x * x))
