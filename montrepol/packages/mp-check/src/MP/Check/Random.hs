-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | SplitMix64 (Steele, Lea, Flood 2014; the constants of Java's
-- @SplittableRandom@), written out rather than imported so
-- the harness has no dependency the gate would have to trust.
--
-- The generator is a pure state transition. Determinism matters more than
-- statistical quality here: a failing property must be reproducible from the
-- seed it prints.
module MP.Check.Random
  ( Seed
  , mkSeed
  , nextWord64
  , splitSeed
  , boundedBelow
  ) where

import Data.Bits (shiftR, xor, (.|.), popCount)
import Data.Word (Word64)

data Seed = Seed !Word64 !Word64 -- state, odd gamma
  deriving (Eq, Show)

goldenGamma :: Word64
goldenGamma = 0x9e3779b97f4a7c15

mkSeed :: Word64 -> Seed
mkSeed s = Seed s goldenGamma

mix64 :: Word64 -> Word64
mix64 z0 =
  let z1 = (z0 `xor` (z0 `shiftR` 33)) * 0xff51afd7ed558ccd
      z2 = (z1 `xor` (z1 `shiftR` 33)) * 0xc4ceb9fe1a85ec53
   in z2 `xor` (z2 `shiftR` 33)

mix64variant13 :: Word64 -> Word64
mix64variant13 z0 =
  let z1 = (z0 `xor` (z0 `shiftR` 30)) * 0xbf58476d1ce4e5b9
      z2 = (z1 `xor` (z1 `shiftR` 27)) * 0x94d049bb133111eb
   in z2 `xor` (z2 `shiftR` 31)

-- | A gamma must be odd and must not have too few bit transitions, or the
-- split streams correlate. This is the published fix-up.
mixGamma :: Word64 -> Word64
mixGamma z0 =
  let z1 = mix64 z0 .|. 1
      n = popCount (z1 `xor` (z1 `shiftR` 1))
   in if n >= 24 then z1 else z1 `xor` 0xaaaaaaaaaaaaaaaa

nextWord64 :: Seed -> (Word64, Seed)
nextWord64 (Seed s g) = let s' = s + g in (mix64variant13 s', Seed s' g)

splitSeed :: Seed -> (Seed, Seed)
splitSeed (Seed s g) =
  let s1 = s + g
      s2 = s1 + g
   in (Seed s2 g, Seed (mix64variant13 s1) (mixGamma s2))

-- | Uniform integer in @[0, n)@ for @n >= 1@, by rejection, so there is no
-- modulo bias. For @n < 1@ the result is 0; callers never pass that, and the
-- function stays total rather than calling 'error'.
boundedBelow :: Integer -> Seed -> (Integer, Seed)
boundedBelow n seed
  | n <= 1 = (0, seed)
  | otherwise = go seed
  where
    -- Enough 64-bit limbs to exceed n, then reject above the largest multiple.
    limbs = length (takeWhile (> 0) (iterate (`div` (2 ^ (64 :: Int))) n))
    range = 2 ^ (64 * limbs) :: Integer
    limit = range - (range `mod` n)
    draw k sd acc
      | k <= (0 :: Int) = (acc, sd)
      | otherwise =
          let (w, sd') = nextWord64 sd
           in draw (k - 1) sd' (acc * 2 ^ (64 :: Int) + toInteger w)
    go sd =
      let (x, sd') = draw limbs sd 0
       in if x < limit then (x `mod` n, sd') else go sd'
