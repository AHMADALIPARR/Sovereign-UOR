-- | First side of the determinant dual oracle: the Bareiss determinant of
-- montrepol_checked (MP.Matrix.det) on matrices drawn from SplitMix64
-- (MP.Check.Random). dex/det.dx draws the same matrices with its own
-- SplitMix64 and computes the Leibniz expansion; CI requires identical output.
--
-- Build from the repository root:
--   ghc -O0 -outputdir /tmp/bv -o /tmp/bv/bareiss-vectors \
--     -imontrepol_checked/packages/mp-linalg/src \
--     -imontrepol_checked/packages/mp-check/src dex/haskell/BareissVectors.hs
module Main (main) where

import Data.Word (Word64)
import MP.Check.Random (Seed, mkSeed, nextWord64)
import MP.Matrix (det, fromLists)
import System.Environment (getArgs)
import Text.Read (readMaybe)

main :: IO ()
main = do
  args <- getArgs
  let cases = case args of
        [s] | Just k <- readMaybe s -> k
        _ -> 200 :: Int
  go 0 cases (mkSeed 0x5eed)
  where
    go c cases s
      | c >= cases = pure ()
      | otherwise = do
          let (w, s1) = nextWord64 s
              n = 1 + fromIntegral (w `mod` 6) :: Int
              (entries, s2) = draw (n * n) s1
              rows = chunk n entries
          putStrLn ("case " <> show c <> " n " <> show n <> " det " <> show (det (fromLists rows)))
          go (c + 1) cases s2

-- | k entries, each (w mod 41) - 20.
draw :: Int -> Seed -> ([Integer], Seed)
draw k s
  | k <= 0 = ([], s)
  | otherwise =
      let (w, s') = nextWord64 s
          (rest, s'') = draw (k - 1) s'
       in (entryOf w : rest, s'')

entryOf :: Word64 -> Integer
entryOf w = toInteger (w `mod` 41) - 20

chunk :: Int -> [a] -> [[a]]
chunk _ [] = []
chunk n xs = take n xs : chunk n (drop n xs)
