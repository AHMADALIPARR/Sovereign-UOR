module Main (main) where

import MP.Bernoulli
import MP.Primes
import MP.Zeta

main :: IO ()
main = do
  putStrLn "Bernoulli numbers:"
  mapM_ (\n -> putStrLn (show n <> ": " <> show (bernoulli n))) [0 .. 10 :: Int]
  putStrLn "\nPrimes up to 50:"
  print (primesUpTo 50)
  putStrLn "\nzeta(2) by Euler-Maclaurin with N = 40:"
  print (zeta 40 2)
