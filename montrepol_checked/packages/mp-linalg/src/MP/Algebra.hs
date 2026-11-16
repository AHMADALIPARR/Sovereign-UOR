-- SPDX-License-Identifier: AGPL-3.0-only
-- Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
-- Copyright (C) 2026 Ahmad Parr

-- | Semirings, rings and fields, written out so the rest of the monorepo has
-- no dependency the gate would have to trust.
--
-- The instances are the ones the tests check the axioms of (LA-01). Nothing
-- here is partial: every operation is total on its type.
module MP.Algebra
  ( Semiring(..)
  , Ring(..)
  , Field(..)
  , ExactDivision(..)
  , GF2(..)
  , MinPlus(..)
  , isZero
  , sumS
  , productS
  ) where

class Semiring a where
  zero :: a
  one :: a
  (.+.) :: a -> a -> a
  (.*.) :: a -> a -> a

infixl 6 .+.
infixl 7 .*.
infixl 6 .-.

class Semiring a => Ring a where
  neg :: a -> a
  (.-.) :: a -> a -> a
  x .-. y = x .+. neg y

class Ring a => Field a where
  recipF :: a -> Maybe a

-- | Division that is exact whenever the caller knows the quotient lies in the
-- ring. Bareiss elimination only ever divides by the previous pivot, and
-- Sylvester's identity makes that division exact, so Integer can use it.
class Ring a => ExactDivision a where
  exactDiv :: a -> a -> a

-- | Zero test.
isZero :: (Semiring a, Eq a) => a -> Bool
isZero x = x == zero

sumS :: Semiring a => [a] -> a
sumS = foldr (.+.) zero

productS :: Semiring a => [a] -> a
productS = foldr (.*.) one

------------------------------------------------------------------------------
-- Instances

instance Semiring Integer where
  zero = 0
  one = 1
  (.+.) = (+)
  (.*.) = (*)

instance Ring Integer where
  neg = negate

-- | Truncating 'quot'; exact for the divisions Bareiss performs. Division by
-- zero returns zero rather than failing, which keeps the function total.
instance ExactDivision Integer where
  exactDiv x y = if y == 0 then 0 else x `quot` y

instance Semiring Rational where
  zero = 0
  one = 1
  (.+.) = (+)
  (.*.) = (*)

instance Ring Rational where
  neg = negate

instance Field Rational where
  recipF x = if x == 0 then Nothing else Just (1 / x)

instance ExactDivision Rational where
  exactDiv x y = if y == 0 then 0 else x / y

-- | GF(2), as a boolean: False is 0, True is 1. Addition is xor, multiplication
-- is and.
newtype GF2 = GF2 Bool deriving (Eq, Ord)

instance Show GF2 where
  show (GF2 False) = "0"
  show (GF2 True) = "1"

instance Semiring GF2 where
  zero = GF2 False
  one = GF2 True
  GF2 a .+. GF2 b = GF2 (a /= b)
  GF2 a .*. GF2 b = GF2 (a && b)

instance Ring GF2 where
  neg = id

instance Field GF2 where
  recipF (GF2 False) = Nothing
  recipF (GF2 True) = Just one

-- | The only nonzero divisor is 1.
instance ExactDivision GF2 where
  exactDiv x _ = x

-- | Tropical (min, +) semiring. The additive identity is infinity.
data MinPlus = Fin Integer | Inf deriving (Eq, Ord)

instance Show MinPlus where
  show Inf = "inf"
  show (Fin n) = show n

instance Semiring MinPlus where
  zero = Inf
  one = Fin 0
  Inf .+. y = y
  x .+. Inf = x
  Fin x .+. Fin y = Fin (min x y)
  Inf .*. _ = Inf
  _ .*. Inf = Inf
  Fin x .*. Fin y = Fin (x + y)
