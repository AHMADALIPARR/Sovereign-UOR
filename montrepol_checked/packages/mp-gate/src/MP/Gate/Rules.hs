-- | The rules R1-R6 (see VERIFICATION.md and AGENTS.md in montrepol/).
module MP.Gate.Rules
  ( Rule(..)
  , Violation(..)
  , Repo(..)
  , Package(..)
  , SourceFile(..)
  , checkRepo
  , bootPackages
  ) where

import Data.Char (isAlpha, isDigit, isSpace, toLower)
import Data.List (isInfixOf, isPrefixOf, nub, sort)
import MP.Gate.Model
import MP.Gate.Render (render)
import MP.Gate.Scan

data Rule = R1 | R2 | R3 | R4 | R5 | R6 deriving (Eq, Ord, Show)

data Violation = Violation
  { violationRule :: Rule
  , violationMsg :: String
  } deriving (Eq, Show)

data SourceFile = SourceFile
  { sourcePath :: String
  , sourceText :: String
  , sourceIsTest :: Bool
  } deriving (Eq, Show)

data Package = Package
  { pkgName :: String
  , pkgCabal :: String
  , pkgSources :: [SourceFile]
  } deriving (Eq, Show)

data Repo = Repo
  { repoIds :: String
  , repoLedger :: String
  , repoAuthorities :: String
  , repoConformance :: String
  , repoProject :: String
  , repoPackageNames :: [String] -- ^ directories under packages/
  , repoPackages :: [Package]
  } deriving (Eq, Show)

checkRepo :: Repo -> [Violation]
checkRepo repo =
  case readModel (repoIds repo) (repoLedger repo) (repoAuthorities repo) of
    Left e -> [Violation R1 ("model does not parse: " <> e)]
    Right model ->
      map (Violation R1) (r1 repo model)
        ++ map (Violation R2) (r2 model)
        ++ map (Violation R3) (r3 repo model)
        ++ map (Violation R4) (r4 repo)
        ++ map (Violation R5) (r5 repo)
        ++ map (Violation R6) (r6 repo)

-- R1: single source; unique, well-formed IDs naming real packages; the
-- committed CONFORMANCE.md is exactly the rendered model.
r1 :: Repo -> Model -> [String]
r1 repo m =
  let ids = map rowId (modelIds m)
      dups = nub [i | i <- ids, length (filter (== i) ids) > 1]
   in ["duplicate ID " <> i | i <- dups]
        ++ ["malformed ID " <> show i | i <- ids, not (wellFormed i)]
        ++ ["ID " <> rowId r <> " names unknown package " <> rowPackage r | r <- modelIds m, rowPackage r `notElem` repoPackageNames repo]
        ++ ["CONFORMANCE.md differs from the model; run mp-gate write" | repoConformance repo /= render m]
  where
    wellFormed i = case i of
      [a, b, '-', c, d] -> all isAlpha [a, b] && all isDigit [c, d]
      _ -> False

-- R2: levels are load-bearing.
r2 :: Model -> [String]
r2 m =
  let known = map authId (modelAuthorities m)
      cited = concatMap rowAuthorities (modelIds m) ++ concatMap ledAuthorities (modelLedger m)
   in ["bad level " <> rowLevel r <> " on " <> rowId r | r <- modelIds m, rowLevel r `notElem` ["build", "some-true"]]
        ++ ["asserting word in " <> rowId r | r <- modelIds m, rowLevel r == "build", asserting (rowClaim r)]
        ++ ["asserting word in open ledger entry " <> ledKey e | e <- modelLedger m, ledLevel e == "open", asserting (ledStatement e)]
        ++ ["some-true without authority " <> rowId r | r <- modelIds m, rowLevel r == "some-true", null (rowAuthorities r)]
        ++ ["some-true without authority " <> ledKey e | e <- modelLedger m, ledLevel e == "some-true", null (ledAuthorities e)]
        ++ ["unknown authority " <> a | a <- nub cited, a `notElem` known]
        ++ ["authority never cited " <> a | a <- known, a `notElem` cited]
  where
    asserting s = any (`elem` ["proves", "proven", "proved", "guarantees", "guaranteed"]) (words (map toLower (filter (\c -> isAlpha c || isSpace c) s)))

-- R3: every ID tagged in its own package's tests; every tag registered.
r3 :: Repo -> Model -> [String]
r3 repo m =
  let tags = [(i, pkgName p) | p <- repoPackages repo, sf <- pkgSources p, sourceIsTest sf, (i, _) <- tagsIn (sourcePath sf) (sourceText sf)]
      registered = map rowId (modelIds m)
   in ["untested ID " <> rowId r | r <- modelIds m, (rowId r, rowPackage r) `notElem` tags]
        ++ ["unregistered tag " <> t <> " in " <> p | (t, p) <- nub tags, t `notElem` registered]

-- R4: nothing deferred.
r4 :: Repo -> [String]
r4 repo = ["deferral at " <> d | p <- repoPackages repo, sf <- pkgSources p, d <- deferrals (sourcePath sf) (sourceText sf)]

-- R5: total code, warnings as errors (in cabal.project or every .cabal file).
r5 :: Repo -> [String]
r5 repo =
  ["partial function at " <> d | p <- repoPackages repo, sf <- pkgSources p, d <- partials (sourcePath sf) (sourceText sf)]
    ++ ["missing -Werror for " <> pkgName p | not projectWerror, p <- repoPackages repo, not ("-Werror" `isInfixOf` pkgCabal p)]
  where
    projectWerror = any (\l -> "ghc-options:" `isPrefixOf` dropWhile isSpace l && "-Werror" `isInfixOf` l) (lines (repoProject repo))

-- R6: nothing from outside GHC and this repository.
r6 :: Repo -> [String]
r6 repo =
  ["package repository enabled" | not noRepos]
    ++ ["package " <> d <> " not listed in cabal.project" | d <- repoPackageNames repo, ("packages/" <> d) `notElem` listed]
    ++ concat [depProblems p | p <- repoPackages repo]
  where
    proj = lines (repoProject repo)
    repoLines = [filter (not . isSpace) l | l <- proj, "active-repositories:" `isPrefixOf` dropWhile isSpace l]
    noRepos = not (null repoLines) && all (== "active-repositories::none") repoLines
    listed = [w | l <- dropWhile (not . ("packages:" `isPrefixOf`)) proj, w <- words l, "packages/" `isPrefixOf` w]
    internal = repoPackageNames repo
    depProblems p =
      [ pkgName p <> ": " <> problem
      | (dep, constraint) <- buildDepends (pkgCabal p)
      , problem <-
          if dep `elem` internal
            then []
            else
              if dep `elem` bootPackages
                then ["unbounded boot dependency " <> dep | not (">=" `isInfixOf` constraint && "<" `isInfixOf` filter (/= '=') constraint)]
                else ["outside dependency " <> dep]
      ]

-- | Packages shipped with GHC 9.10.1.
bootPackages :: [String]
bootPackages =
  [ "array", "base", "binary", "bytestring", "containers", "deepseq", "directory", "exceptions"
  , "filepath", "ghc-prim", "mtl", "parsec", "pretty", "process", "stm", "template-haskell"
  , "text", "time", "transformers", "unix"
  ]

-- | (name, constraint) for every entry of every build-depends field.
buildDepends :: String -> [(String, String)]
buildDepends cabal = sort [dep e | e <- concatMap (splitOn ',') (fields (lines cabal)), not (all isSpace e)]
  where
    fields [] = []
    fields (l : ls)
      | "build-depends:" `isPrefixOf` dropWhile isSpace l =
          let indent = length (takeWhile isSpace l)
              (cont, rest) = span (\x -> not (all isSpace x) && length (takeWhile isSpace x) > indent && ':' `notElem` takeWhile (not . isSpace) (dropWhile isSpace x)) ls
           in unwords (drop 1 (dropWhile (/= ':') l) : cont) : fields rest
      | otherwise = fields ls
    dep e = let (n, c) = span (\x -> not (isSpace x) && x `notElem` "<>=^") (dropWhile isSpace e) in (n, c)
    splitOn c s = case break (== c) s of
      (a, []) -> [a]
      (a, _ : b) -> a : splitOn c b
