-- | The algebraic structures the matrix code is generic over.
--
-- 'Num' is not used: it bundles 'abs', 'signum' and 'fromInteger', which a
-- semiring does not have, and it would let a tropical or Boolean matrix be
-- negated by accident. Each class here carries exactly its axioms' operations.
-- The axioms themselves are checked by property tests in @test/@, per instance.
module MP.Algebra
  ( Semiring (..)
  , Ring (..)
  , (.-.)
  , Domain (..)
  , Field (..)
  , GF2 (..)
  , MinPlus (..)
  , sumS
  , productS
  ) where

import Data.Ratio (denominator, numerator)

infixl 6 .+.
infixl 7 .*.
infixl 6 .-.

-- | @(a, .+., zero)@ is a commutative monoid, @(a, .*., one)@ a monoid,
-- multiplication distributes over addition and @zero@ annihilates.
class Semiring a where
  zero :: a
  one :: a
  (.+.) :: a -> a -> a
  (.*.) :: a -> a -> a
  isZero :: a -> Bool

-- | A semiring with additive inverses.
class Semiring a => Ring a where
  neg :: a -> a

(.-.) :: Ring a => a -> a -> a
a .-. b = a .+. neg b

-- | A commutative ring without zero divisors, with exact division.
--
-- @exactQuot a b@ is the @q@ with @q .*. b == a@ when one exists and @b@ is
-- non-zero. It is total: on other inputs it returns some value, and every use
-- in this repository is at a point where divisibility is a theorem (Sylvester's
-- identity, for Bareiss). The tests compare against division-free oracles, so
-- a non-exact division would surface as a wrong answer.
class Ring a => Domain a where
  exactQuot :: a -> a -> a

class Domain a => Field a where
  -- | 'Nothing' exactly for zero.
  recipF :: a -> Maybe a

sumS :: Semiring a => [a] -> a
sumS = foldr (.+.) zero

productS :: Semiring a => [a] -> a
productS = foldr (.*.) one

------------------------------------------------------------------------------
-- Integers and rationals

instance Semiring Integer where
  zero = 0
  one = 1
  (.+.) = (+)
  (.*.) = (*)
  isZero = (== 0)

instance Ring Integer where neg = negate

instance Domain Integer where
  exactQuot _ 0 = 0
  exactQuot a b = a `quot` b

instance Semiring Rational where
  zero = 0
  one = 1
  (.+.) = (+)
  (.*.) = (*)
  isZero = (== 0)

instance Ring Rational where neg = negate

instance Domain Rational where
  exactQuot a b = maybe 0 (a *) (recipF b)

instance Field Rational where
  recipF q
    | numerator q == 0 = Nothing
    | otherwise = Just (fromInteger (denominator q) / fromInteger (numerator q))

------------------------------------------------------------------------------
-- The field with two elements

newtype GF2 = GF2 Bool
  deriving (Eq, Ord)

instance Show GF2 where
  show (GF2 b) = if b then "1" else "0"

instance Semiring GF2 where
  zero = GF2 False
  one = GF2 True
  GF2 a .+. GF2 b = GF2 (a /= b)
  GF2 a .*. GF2 b = GF2 (a && b)
  isZero (GF2 b) = not b

instance Ring GF2 where neg = id

instance Domain GF2 where
  exactQuot a (GF2 True) = a
  exactQuot _ (GF2 False) = GF2 False

instance Field GF2 where
  recipF (GF2 True) = Just (GF2 True)
  recipF (GF2 False) = Nothing

------------------------------------------------------------------------------
-- The tropical (min, +) semiring

-- | 'Nothing' is +infinity. Matrix powers over this semiring compute shortest
-- paths, which is the reason it is here: it shows the multiplication really is
-- semiring-generic and is checked against Floyd–Warshall.
newtype MinPlus = MinPlus (Maybe Integer)
  deriving (Eq, Show)

instance Semiring MinPlus where
  zero = MinPlus Nothing
  one = MinPlus (Just 0)
  MinPlus Nothing .+. b = b
  a .+. MinPlus Nothing = a
  MinPlus (Just x) .+. MinPlus (Just y) = MinPlus (Just (min x y))
  MinPlus (Just x) .*. MinPlus (Just y) = MinPlus (Just (x + y))
  _ .*. _ = MinPlus Nothing
  isZero (MinPlus m) = m == Nothing
