-- SPDX-License-Identifier: AGPL-3.0-or-later
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module SovereignUOR
  ( StateVec
  , CanonicalUOR
  , WeylGen(..)
  , mkStateVec
  , reflect
  , applyWeylWord
  , canonicalize
  , chamberCoords
  , uorDigest64
  ) where

import Data.Bits (shiftR, xor, (.&.))
import Data.Int (Int64)
import Data.List (sort)
import Data.Proxy (Proxy(..))
import Data.Word (Word64)
import GHC.TypeLits (KnownNat, Nat, natVal)

-- | Dimension-indexed coordinate vector before Weyl quotienting.
newtype StateVec (n :: Nat) = StateVec { unStateVec :: [Int64] }
  deriving (Eq, Show)

-- | Unforgeable canonical UOR normal form in the fundamental Weyl chamber B_n.
data CanonicalUOR (n :: Nat) = CanonicalUOR
  { chamberCoords :: ![Word64]
  , uorDigest64   :: !Word64
  } deriving (Eq, Ord, Show)

-- | Coxeter reflection generators of the hyperoctahedral Weyl group B_n.
data WeylGen
  = Swap !Int !Int   -- ^ Coordinate transposition s_{i,j}
  | Flip !Int        -- ^ Sign reflection s_i (x_i -> -x_i)
  deriving (Eq, Show)

mkStateVec :: forall n. KnownNat n => [Int64] -> Maybe (StateVec n)
mkStateVec xs
  | length xs == expected = Just (StateVec xs)
  | otherwise             = Nothing
  where
    expected = fromIntegral (natVal (Proxy @n))

-- | Applies a single involutive reflection generator (s^2 = id).
reflect :: WeylGen -> StateVec n -> StateVec n
reflect (Flip i) (StateVec xs) =
  StateVec [ if idx == i then negate x else x | (idx, x) <- zip [0..] xs ]
reflect (Swap i j) (StateVec xs)
  | i < 0 || j < 0 || i >= len || j >= len || i == j = StateVec xs
  | otherwise =
      let xi = xs !! i
          xj = xs !! j
          step (idx, x)
            | idx == i  = xj
            | idx == j  = xi
            | otherwise = x
      in StateVec (map step (zip [0..] xs))
  where
    len = length xs

-- | Evaluates an arbitrary word in W(B_n).
applyWeylWord :: [WeylGen] -> StateVec n -> StateVec n
applyWeylWord gens v = foldr reflect v gens

-- | Projects any state into its unique B_n Weyl chamber representative
--   (0 <= c_0 <= c_1 <= ... <= c_{n-1}) and computes a bit-exact FNV-1a tag.
canonicalize :: StateVec n -> CanonicalUOR n
canonicalize (StateVec xs) =
  let sortedMag = sort (map absMagnitude xs)
      digest    = fnv1a64 sortedMag
  in CanonicalUOR sortedMag digest

-- | Total magnitude conversion without signed Int64 minBound overflow.
absMagnitude :: Int64 -> Word64
absMagnitude x
  | x == minBound = 0x8000000000000000
  | x < 0         = fromIntegral (negate x)
  | otherwise     = fromIntegral x

-- | Deterministic 64-bit little-endian FNV-1a over canonical chamber words.
fnv1a64 :: [Word64] -> Word64
fnv1a64 = foldl hashWord 0xcbf29ce484222325
  where
    prime :: Word64
    prime = 0x100000001b3

    hashWord :: Word64 -> Word64 -> Word64
    hashWord acc w =
      foldl
        (\h shift -> (h `xor` ((w `shiftR` shift) .&. 0xff)) * prime)
        acc
        [0, 8, 16, 24, 32, 40, 48, 56]
