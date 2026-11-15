-- | Replays @model/mutants.toml@: each planted defect must be caught by the
-- tests it names. This is the falsifiability half of the gate; it shells out
-- to cabal, so it lives in the executable, not the pure library.
module Mutants (runMutants) where

import Control.Exception (finally)
import Data.List (isInfixOf, isPrefixOf, nub, tails)
import MP.Gate.Toml
import System.Exit (ExitCode (..), exitFailure)
import System.IO (IOMode (..), hGetContents', hPutStr, hSetEncoding, utf8, withFile)
import System.Process (readProcessWithExitCode)

data Mutant = Mutant
  { mName :: String
  , mPackage :: String
  , mFile :: FilePath
  , mOld :: String
  , mNew :: String
  , mExpect :: [String]
  }

runMutants :: IO ()
runMutants = do
  txt <- readUtf8 "model/mutants.toml"
  mutants <- case parseToml txt >>= traverse mutant . maybe [] id . lookup "mutant" . docArrays of
    Left e -> putStrLn ("model/mutants.toml: " <> e) >> exitFailure
    Right ms -> pure ms
  results <- mapM runOne mutants
  let missed = length (filter not results)
  putStrLn ("\n" <> show (length results - missed) <> " of " <> show (length results) <> " mutants caught")
  if missed == 0 then pure () else exitFailure
  where
    mutant t =
      Mutant <$> field "name" t <*> field "package" t <*> field "file" t <*> field "old" t <*> field "new" t
        <*> pure (lookupStrings "expect" t)
    field k t = maybe (Left ("mutant without " <> k)) Right (lookupString k t)

runOne :: Mutant -> IO Bool
runOne m = do
  original <- readUtf8 (mFile m)
  let occurrences = length (filter (mOld m `isPrefixOf`) (tails original))
  if occurrences /= 1
    then do
      putStrLn ("STALE  " <> mName m <> ": the planted text occurs " <> show occurrences <> " times in " <> mFile m)
      pure False
    else do
      writeUtf8 (mFile m) (replaceOnce (mOld m) (mNew m) original)
      (code, out, err) <-
        readProcessWithExitCode "cabal" ["test", "-v0", mPackage m] ""
          `finally` writeUtf8 (mFile m) original
      let combined = out <> err
          caught = code /= ExitSuccess && all (`isInfixOf` combined) (mExpect m)
      putStrLn ((if caught then "CAUGHT " else "MISSED ") <> mName m)
      pure caught

replaceOnce :: String -> String -> String -> String
replaceOnce old new hay =
  case break (old `isPrefixOf`) (tails hay) of
    (pre, rest : _) -> take (length pre) hay <> new <> drop (length old) rest
    _ -> hay

readUtf8 :: FilePath -> IO String
readUtf8 p = withFile p ReadMode (\h -> hSetEncoding h utf8 >> hGetContents' h)

writeUtf8 :: FilePath -> String -> IO ()
writeUtf8 p s = withFile p WriteMode (\h -> hSetEncoding h utf8 >> hPutStr h s)
