module Main (main) where

import MP.Bernoulli
import MP.Primes
import MP.Zeta

main :: IO ()
main = do
  putStrLn "Bernoulli numbers:"
  mapM_ (\n -> putStrLn (show n <> ": " <> show (bernoulli n))) [0 .. 10]
  putStrLn "\nPrimes up to 50:"
  print (primesUpTo 50)
  putStrLn "\nzeta(2) approx:"
  print (zeta 40 2)
