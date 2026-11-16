-- | Primes, the von Mangoldt function and Chebyshev's psi.
--
-- @psi(x) = sum_{n <= x} Lambda(n)@, where @Lambda(p^k) = log p@ and is zero
-- off prime powers. Exponentiating, @e^psi(x) = lcm(1, ..., x)@, which is an
-- identity between integers and is what the tests check: it pins down
-- 'primePowerBase' without any floating point.
module MP.Primes
  ( primesUpTo
  , isPrimeTrial
  , primePowerBase
  , vonMangoldt
  , chebyshevPsi
  , primePowerProduct
  , primeCount
  ) where

import Control.Monad (forM_, when)
import Data.Array.ST (newArray, readArray, runSTUArray, writeArray)
import Data.Array.Unboxed (UArray, assocs)

-- | Sieve of Eratosthenes.
primesUpTo :: Int -> [Int]
primesUpTo n
  | n < 2 = []
  | otherwise = [i | (i, True) <- assocs sieve]
  where
    sieve :: UArray Int Bool
    sieve = runSTUArray $ do
      arr <- newArray (2, n) True
      forM_ (takeWhile (\i -> i * i <= n) [2 ..]) $ \i -> do
        isP <- readArray arr i
        when isP $ forM_ [i * i, i * i + i .. n] $ \j -> writeArray arr j False
      pure arr

-- | Trial division: slow, obviously correct, the oracle for the sieve.
isPrimeTrial :: Int -> Bool
isPrimeTrial n = n >= 2 && all (\d -> n `mod` d /= 0) (takeWhile (\d -> d * d <= n) [2 ..])

-- | @Just p@ when @n = p^k@ for a prime @p@ and @k >= 1@.
primePowerBase :: Int -> Maybe Int
primePowerBase n
  | n < 2 = Nothing
  | otherwise =
      let p = smallestFactor n
       in if strip p n == 1 then Just p else Nothing
  where
    smallestFactor m = case [d | d <- takeWhile (\d -> d * d <= m) [2 ..], m `mod` d == 0] of
      (d : _) -> d
      [] -> m
    strip p m = if m `mod` p == 0 then strip p (m `div` p) else m

vonMangoldt :: Int -> Double
vonMangoldt = maybe 0 (log . fromIntegral) . primePowerBase

-- | @psi(x)@ for real @x@: the sum over @n <= floor x@.
chebyshevPsi :: Double -> Double
chebyshevPsi x = sum (map vonMangoldt [2 .. floor x])

-- | @prod_{p^k <= x} p@, exactly; equal to @lcm(1, ..., x)@.
primePowerProduct :: Int -> Integer
primePowerProduct x = product [toInteger p | n <- [2 .. x], Just p <- [primePowerBase n]]

primeCount :: Int -> Int
primeCount = length . primesUpTo
