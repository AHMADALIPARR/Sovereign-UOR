-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | @mp-gate check@ (the default) reports every violation and exits non-zero
-- if there is one. @mp-gate write@ regenerates CONFORMANCE.md from the model.
-- @mp-gate mutants@ replays model/mutants.toml (see "Mutants").
-- Run from the repository root.
module Main (main) where

import Control.Monad (filterM, forM)
import Data.List (isSuffixOf, sort)
import MP.Gate.Model (readModel)
import MP.Gate.Render (renderConformance)
import MP.Gate.Rules
import Mutants (runMutants)
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import GHC.IO.Encoding (setLocaleEncoding)
import System.FilePath ((</>))
import System.IO (IOMode (..), hGetContents', hPutStr, hPutStrLn, hSetEncoding, stderr, stdout, utf8, withFile)

main :: IO ()
main = do
  setLocaleEncoding utf8 -- also governs pipes to child processes (mutants)
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
  args <- getArgs
  case args of
    ["write"] -> write
    ["mutants"] -> runMutants
    [] -> check
    ["check"] -> check
    _ -> hPutStrLn stderr "usage: mp-gate [check | write | mutants]" >> exitFailure

write :: IO ()
write = do
  ids <- readFile' "model/ids.toml"
  ledger <- readFile' "model/ledger.toml"
  auths <- readFile' "model/authorities.toml"
  case readModel ids ledger auths of
    Left e -> hPutStrLn stderr e >> exitFailure
    Right m -> writeUtf8 "CONFORMANCE.md" (renderConformance m) >> putStrLn "wrote CONFORMANCE.md"

check :: IO ()
check = do
  repo <- loadRepo
  let vs = checkRepo repo
  if null vs
    then putStrLn ("mp-gate: R1-R6 hold over " <> show (length (repoPackages repo)) <> " packages")
    else do
      mapM_ (\(Violation r msg) -> putStrLn (show r <> "  " <> msg)) vs
      putStrLn ("\nmp-gate: " <> show (length vs) <> " violation(s)")
      exitFailure

loadRepo :: IO Repo
loadRepo = do
  dirs <- sort <$> (listDirectory "packages" >>= filterM (doesDirectoryExist . ("packages" </>)))
  pkgs <- forM dirs $ \d -> do
    let root = "packages" </> d
        cabalPath = root </> (d <> ".cabal")
    hasCabal <- doesFileExist cabalPath
    cabal <- if hasCabal then readFile' cabalPath else pure ""
    srcs <- concat <$> mapM (\sub -> hsFiles (root </> sub) (sub == "test")) ["src", "app", "test"]
    pure (Package d cabal srcs)
  Repo
    <$> readFile' "model/ids.toml"
    <*> readFile' "model/ledger.toml"
    <*> readFile' "model/authorities.toml"
    <*> readFileOrEmpty "CONFORMANCE.md"
    <*> readFile' "cabal.project"
    <*> pure dirs
    <*> pure pkgs
    <*> filesWith ".agda" "formal" False
    <*> filesWith ".hs" "liquid/src" False
    <*> optionalFile "liquid/cabal.project"
    <*> optionalFile "liquid/mp-liquid.cabal"
    <*> topLevelFiles ".dx" "dex"

hsFiles :: FilePath -> Bool -> IO [SourceFile]
hsFiles = filesWith ".hs"

-- | Every file under @dir@ with the extension, recursively, in a stable order.
filesWith :: String -> FilePath -> Bool -> IO [SourceFile]
filesWith ext dir isTest = do
  exists <- doesDirectoryExist dir
  if not exists
    then pure []
    else do
      entries <- sort <$> listDirectory dir
      concat <$> forM entries (\e -> do
        let p = dir </> e
        isDir <- doesDirectoryExist p
        if isDir
          then filesWith ext p isTest
          else if ext `isSuffixOf` e then (\t -> [SourceFile p t isTest]) <$> readFile' p else pure [])

-- | The files directly in @dir@ with the extension. Not recursive: dex/
-- holds the upstream Dex checkout under .toolchain, which is not ours.
topLevelFiles :: String -> FilePath -> IO [SourceFile]
topLevelFiles ext dir = do
  exists <- doesDirectoryExist dir
  if not exists
    then pure []
    else do
      entries <- sort <$> listDirectory dir
      concat <$> forM entries (\e -> do
        let p = dir </> e
        isFile <- doesFileExist p
        if isFile && ext `isSuffixOf` e then (\t -> [SourceFile p t True]) <$> readFile' p else pure [])

optionalFile :: FilePath -> IO (Maybe String)
optionalFile p = do
  ok <- doesFileExist p
  if ok then Just <$> readFile' p else pure Nothing

readFileOrEmpty :: FilePath -> IO String
readFileOrEmpty p = do
  ok <- doesFileExist p
  if ok then readFile' p else pure ""

-- | Strict, so a file is closed before @write@ replaces it, and UTF-8
-- whatever the locale says.
readFile' :: FilePath -> IO String
readFile' p = withFile p ReadMode (\h -> hSetEncoding h utf8 >> hGetContents' h)

writeUtf8 :: FilePath -> String -> IO ()
writeUtf8 p s = withFile p WriteMode (\h -> hSetEncoding h utf8 >> hPutStr h s)
