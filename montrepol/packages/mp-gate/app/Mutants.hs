-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | Replays @model/mutants.toml@: each planted defect must be caught by the
-- tests it names. This is the falsifiability half of the gate; it shells out
-- to cabal, so it lives in the executable, not the pure library.
module Mutants (runMutants) where

import Control.Exception (finally)
import Data.Char (isDigit)
import Data.List (isInfixOf, isPrefixOf, nub, tails)
import MP.Gate.Toml
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..), exitFailure)
import System.IO (IOMode (..), hGetContents', hPutStr, hSetEncoding, utf8, withFile)
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)

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
      (code, out, err) <- check (mPackage m) `finally` writeUtf8 (mFile m) original
      let output = out <> err
          failed = nub [tag l | l <- lines output, "FAIL [" `isInfixOf` l]
          formal = mPackage m `elem` ["formal", "liquid"]
          liquidSafe = mPackage m == "liquid" && "LIQUID: SAFE" `isInfixOf` output
          -- A proof mutant is caught when Agda rejects it with an error
          -- located in each file `expect` names (`File.agda:line,col`); the
          -- file merely being checked is not enough. A code mutant is caught
          -- when each test `expect` names fails.
          -- Agda prints a bare location line; Liquid Haskell prints
          -- `File.hs:line:col: error:` and also located warnings, which
          -- must not count.
          errorsIn file =
            [ l
            | l <- lines output
            , Just rest <- [after (file <> ":") l]
            , take 1 rest /= ""
            , all isDigit (take 1 rest)
            , mPackage m /= "liquid" || "error" `isInfixOf` rest
            ]
          -- dex/check.sh prints a unified diff of the file against Dex's
          -- output: a line "-x" is a line of the file Dex did not print.
          dexDiff = [drop 1 l | l <- lines output, take 1 l == "-", take 3 l /= "---"]
          caught
            -- A Dex mutant is caught when the quine check fails and its diff
            -- shows each expected line `expect` names no longer printed.
            | mPackage m == "dex" = code /= ExitSuccess && all (`elem` dexDiff) (mExpect m) && not (null (mExpect m))
            | formal = code /= ExitSuccess && not liquidSafe && all (not . null . errorsIn) (mExpect m) && not (null (mExpect m))
            | otherwise = code /= ExitSuccess && all (`elem` failed) (mExpect m) && not (null (mExpect m))
          detail
            | mPackage m == "dex" && code /= ExitSuccess = "the quine check failed at " <> unwords (take 1 (dexDiff ++ ["no expected line"]))
            | mPackage m == "dex" = "the quine check passed"
            | formal && code /= ExitSuccess = "rejected at " <> unwords (take 1 (concatMap errorsIn (mExpect m) ++ ["an unexpected place"]))
            | formal = "the checker accepted it"
            | not (null failed) = "failed: " <> unwords failed
            | code /= ExitSuccess = "the build broke; no test caught it"
            | otherwise = "every test passed"
      putStrLn ((if caught then "CAUGHT " else "MISSED ") <> mName m <> "  (" <> detail <> ")")
      pure caught
  where
    tag l = takeWhile (/= ']') (drop 1 (dropWhile (/= '[') l))

-- | Run the check a mutant is meant to break: the package's tests; for
-- @formal@, Agda over every proof; for @liquid@, the Liquid Haskell build;
-- for @dex@, the quine checks. Agda runs under a UTF-8 locale because
-- its error messages print the proofs' Unicode.
check :: String -> IO (ExitCode, String, String)
check "formal" = do
  env0 <- getEnvironment
  let env' = ("LC_ALL", "C.UTF-8") : filter ((/= "LC_ALL") . fst) env0
  readCreateProcessWithExitCode
    (proc "agda" ["--no-libraries", "-i", "formal", "formal/Everything.agda"]) {env = Just env'}
    ""
-- Dex files are checked as quines by dex/check.sh (after dex/build.sh).
check "dex" = readCreateProcessWithExitCode (proc "bash" ["dex/check.sh"]) ""
-- The Liquid Haskell layer is its own build, with Hackage and Z3.
check "liquid" =
  readCreateProcessWithExitCode (proc "cabal" ["build", "-v1", "all"]) {cwd = Just "liquid"} ""
check pkg = readCreateProcessWithExitCode (proc "cabal" ["test", "-v0", pkg]) ""

-- | The text after the first occurrence of @needle@.
after :: String -> String -> Maybe String
after needle hay = case [drop (length needle) t | t <- tails hay, needle `isPrefixOf` t] of
  (r : _) -> Just r
  [] -> Nothing

replaceOnce :: String -> String -> String -> String
replaceOnce old new s
  | old `isPrefixOf` s = new <> drop (length old) s
  | otherwise = case s of
      (c : rest) -> c : replaceOnce old new rest
      [] -> []

readUtf8 :: FilePath -> IO String
readUtf8 p = withFile p ReadMode (\h -> hSetEncoding h utf8 >> hGetContents' h)

writeUtf8 :: FilePath -> String -> IO ()
writeUtf8 p s = withFile p WriteMode (\h -> hSetEncoding h utf8 >> hPutStr h s)
