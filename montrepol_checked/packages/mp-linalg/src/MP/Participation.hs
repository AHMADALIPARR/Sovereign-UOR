-- | Participation ratio (Kish k_eff) of a probability vector.
--
-- For a vector of non-negative entries that sum to 1, the participation ratio
-- is 1 / sum p_i^2. It is 1 for a point mass and n for the uniform distribution
-- on n points.
module MP.Participation
  ( participation
  ) where

import MP.Algebra

-- | Participation ratio of a probability vector. The caller guarantees the
-- entries are non-negative and sum to one; the function is total on any list
-- of rationals.
participation :: [Rational] -> Rational
participation [] = 0
participation p =
  let s = sumS [x .*. x | x <- p]
   in if isZero s then 0 else 1 / s
