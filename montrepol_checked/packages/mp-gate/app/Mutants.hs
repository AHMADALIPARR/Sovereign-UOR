-- | Replays @model/mutants.toml@: each planted defect must be caught by the
-- tests it names. This is the falsifiability half of the gate; it shells out
-- to cabal, so it lives in the executable, not the pure library.
module Mutants (runMutants) where

import Control.Exception (finally)
import Data.List (isInfixOf, isPrefixOf, tails)
import MP.Gate.Model (Mutant (..), parseMutants)
import System.Exit (ExitCode (..), exitFailure)
import System.IO (IOMode (..), hGetContents', hPutStr, hSetEncoding, utf8, withFile)
import System.Process (readProcessWithExitCode)

runMutants :: IO ()
runMutants = do
  txt <- readUtf8 "model/mutants.toml"
  mutants <- case parseMutants txt of
    Left e -> putStrLn ("model/mutants.toml: " <> e) >> exitFailure
    Right ms -> pure ms
  results <- mapM runOne mutants
  let missed = length (filter not results)
  putStrLn ("\n" <> show (length results - missed) <> " of " <> show (length results) <> " mutants caught")
  if missed == 0 then pure () else exitFailure

runOne :: Mutant -> IO Bool
runOne m = do
  original <- readUtf8 (mutFile m)
  let occurrences = length (filter (mutOld m `isPrefixOf`) (tails original))
  if occurrences /= 1
    then do
      putStrLn ("STALE  " <> mutName m <> ": the planted text occurs " <> show occurrences <> " times in " <> mutFile m)
      pure False
    else do
      writeUtf8 (mutFile m) (replaceOnce (mutOld m) (mutNew m) original)
      (code, out, err) <-
        readProcessWithExitCode "cabal" ["test", "-v0", "--test-show-details=direct", mutPackage m] ""
          `finally` writeUtf8 (mutFile m) original
      let combined = out <> err
          failed i = ("FAIL [" <> i <> "]") `isInfixOf` combined
          caught = code /= ExitSuccess && all failed (mutExpect m)
      putStrLn ((if caught then "CAUGHT " else "MISSED ") <> mutName m)
      pure caught

replaceOnce :: String -> String -> String -> String
replaceOnce old new hay = go hay
  where
    go [] = []
    go s@(c : cs)
      | old `isPrefixOf` s = new <> drop (length old) s
      | otherwise = c : go cs

readUtf8 :: FilePath -> IO String
readUtf8 p = withFile p ReadMode (\h -> hSetEncoding h utf8 >> hGetContents' h)

writeUtf8 :: FilePath -> String -> IO ()
writeUtf8 p s = withFile p WriteMode (\h -> hSetEncoding h utf8 >> hPutStr h s)
