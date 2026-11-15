-- | Semirings, rings and fields, written out so the rest of the monorepo has
-- no dependency the gate would have to trust.
--
-- The instances are the ones the tests check the axioms of (LA-01). Nothing
-- here is partial: every operation is total on its type.
module MP.Algebra
  ( Semiring(..)
  , Ring(..)
  , Field(..)
  , GF2(..)
  , MinPlus(..)
  , isZero
  , sumS
  , productS
  ) where

import Data.Ratio (numerator, denominator)

class Semiring a where
  zero :: a
  one :: a
  (.+.) :: a -> a -> a
  (.*.) :: a -> a -> a

class Semiring a => Ring a where
  neg :: a -> a
  (.-.) :: a -> a -> a
  x .-. y = x .+. neg y

class Ring a => Field a where
  recipF :: a -> Maybe a

-- | Zero test that does not need Eq, so it works for MinPlus too.
isZero :: Semiring a => a -> Bool
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

instance Semiring Rational where
  zero = 0
  one = 1
  (.+.) = (+)
  (.*.) = (*)

instance Ring Rational where
  neg = negate

instance Field Rational where
  recipF x = if x == 0 then Nothing else Just (1 / x)

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

-- Eq for isZero. MinPlus has no Eq-free zero test that is useful, so it uses
-- the derived Eq.
instance Eq a => Eq (Maybe a) where
  Nothing == Nothing = True
  Just x == Just y = x == y
  _ == _ = False
