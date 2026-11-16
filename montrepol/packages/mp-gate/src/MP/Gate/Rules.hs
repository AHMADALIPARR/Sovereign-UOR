-- | The rules, as a pure function from a snapshot of the repository to the
-- list of ways it breaks them. Purity is what makes the gate testable: the
-- test suite plants each defect in a snapshot and requires the named rule to
-- fire (VERIFICATION.md).
module MP.Gate.Rules
  ( Rule (..)
  , Violation (..)
  , SourceFile (..)
  , Package (..)
  , Repo (..)
  , checkRepo
  , bootPackages
  ) where

import Data.Char (isSpace, toLower)
import Data.List (isInfixOf, nub, sort, (\\))
import MP.Gate.Model
import MP.Gate.Render (renderConformance)
import MP.Gate.Scan

data Rule
  = R1 -- ^ the model is the single source
  | R2 -- ^ honesty levels are load-bearing
  | R3 -- ^ every ID is tested, every test tag is an ID
  | R4 -- ^ nothing is deferred
  | R5 -- ^ everything shipped is total
  | R6 -- ^ nothing arrives from outside the compiler and this repository
  deriving (Eq, Ord, Show)

data Violation = Violation Rule String
  deriving (Eq, Show)

data SourceFile = SourceFile {sourcePath :: FilePath, sourceText :: String, sourceIsTest :: Bool}

data Package = Package
  { packageName :: String
  , packageCabal :: String
  , packageSources :: [SourceFile]
  }

data Repo = Repo
  { repoIds :: String
  , repoLedger :: String
  , repoAuthorities :: String
  , repoConformance :: String
  , repoProject :: String
  , repoPackageDirs :: [String]
  , repoPackages :: [Package]
  }

-- | Libraries that ship with GHC 9.10.1. Nothing else may be depended on.
bootPackages :: [String]
bootPackages = ["base", "array", "containers", "directory", "filepath", "process"]

checkRepo :: Repo -> [Violation]
checkRepo repo = case readModel (repoIds repo) (repoLedger repo) (repoAuthorities repo) of
  Left e -> Violation R1 ("the model does not parse: " <> e) : sourceRules repo
  Right model -> modelRules repo model ++ sourceRules repo

------------------------------------------------------------------------------

modelRules :: Repo -> Model -> [Violation]
modelRules repo model@(Model rows claims auths) =
  concat
    [ -- R1
      [ Violation R1 "CONFORMANCE.md differs from the model; run `mp-gate write`"
      | repoConformance repo /= renderConformance model
      ]
    , [Violation R1 ("ID " <> i <> " is registered more than once") | i <- duplicates (map rowId rows)]
    , [Violation R1 ("ledger key " <> k <> " appears more than once") | k <- duplicates (map claimKey claims)]
    , [Violation R1 ("ID " <> show (rowId r) <> " is not of the form XX-00") | r <- rows, not (isConformanceId (rowId r))]
    , [ Violation R1 ("ID " <> rowId r <> " names package " <> rowPackage r <> ", which does not exist")
      | r <- rows
      , rowPackage r `notElem` map packageName (repoPackages repo)
      ]
    , -- R2
      [ Violation R2 ("ID " <> rowId r <> " is `open`: an ID has a test, and a test asserts")
      | r <- rows, rowLevel r == Open
      ]
    , [ Violation R2 ("ID " <> rowId r <> " is `some-true` but cites no authority")
      | r <- rows, rowLevel r == SomeTrue, null (rowAuthorities r)
      ]
    , [ Violation R2 ("ledger " <> claimKey c <> " is `some-true` but cites no authority")
      | c <- claims, claimLevel c == SomeTrue, null (claimAuthorities c)
      ]
    , [ Violation R2 ("ledger " <> claimKey c <> " is `build`: a built claim needs an ID and a test")
      | c <- claims, claimLevel c == Build
      ]
    , [ Violation R2 (what <> " asserts (" <> show w <> ") at level `" <> levelName l <> "`")
      | (what, l, text) <-
          [("ID " <> rowId r, rowLevel r, rowClaim r) | r <- rows]
            ++ [("ledger " <> claimKey c, claimLevel c, claimStatement c) | c <- claims]
      , l /= SomeTrue
      , w <- assertingWords
      , w `isInfixOf` map toLower text
      ]
    , [ Violation R2 (who <> " cites unknown authority " <> show k)
      | (who, ks) <- [("ID " <> rowId r, rowAuthorities r) | r <- rows] ++ [("ledger " <> claimKey c, claimAuthorities c) | c <- claims]
      , k <- ks
      , k `notElem` map authKey auths
      ]
    , [ Violation R2 ("authority " <> authKey a <> " is cited by nothing")
      | a <- auths
      , authKey a `notElem` (concatMap rowAuthorities rows ++ concatMap claimAuthorities claims)
      ]
    , -- R3
      testRules repo model
    ]

-- | Words that claim more than a test or a measurement can carry. Halves, as
-- in "MP.Gate.Scan", so the gate does not trip over itself.
assertingWords :: [String]
assertingWords = ["pro" <> "ves", "pro" <> "ven", "guaran" <> "tee", "establish" <> "es", "always hol" <> "ds"]

testRules :: Repo -> Model -> [Violation]
testRules repo (Model rows _ _) =
  concat
    [ [ Violation R3 ("ID " <> rowId r <> " has no test tagged with it in " <> rowPackage r)
      | r <- rows
      , rowId r `notElem` tagsIn (rowPackage r)
      ]
    , [ Violation R3 ("test in " <> packageName p <> " is tagged " <> show t <> ", which is not registered")
      | p <- repoPackages repo
      , t <- nub (tagsOf p)
      , t `notElem` map rowId rows
      ]
    , [ Violation R3 ("test in " <> packageName p <> " is tagged " <> t <> ", registered to " <> rowPackage r)
      | p <- repoPackages repo
      , t <- nub (tagsOf p)
      , r <- rows
      , rowId r == t
      , rowPackage r /= packageName p
      ]
    ]
  where
    tagsOf p = concatMap (testTags . sourceText) (filter sourceIsTest (packageSources p))
    tagsIn name = concatMap tagsOf (filter ((== name) . packageName) (repoPackages repo))

------------------------------------------------------------------------------

sourceRules :: Repo -> [Violation]
sourceRules repo =
  concat
    [ -- R4
      [ Violation R4 (sourcePath f <> ": deferral marker " <> m)
      | f <- sources, m <- deferralMarkers, m `isInfixOf` sourceText f
      ]
    , [ Violation R4 (sourcePath f <> ": stub " <> n)
      | f <- sources, n <- stubNames, n `elem` identifiers (codeOnly (sourceText f))
      ]
    , -- R5
      [ Violation R5 (sourcePath f <> ": partial or unsafe " <> n)
      | f <- sources
      , let code = codeOnly (sourceText f)
      , n <- nub (filter (`elem` partialNames) (identifiers code) ++ filter (`elem` partialOperators) (operators code))
      ]
    , [ Violation R5 ("cabal.project does not set " <> flag)
      | flag <- ["-Wall", "-Werror", "-Wincomplete-uni-patterns"]
      , flag `notElem` words (repoProject repo)
      ]
    , [ Violation R5 (packageName p <> ".cabal weakens warnings with " <> w)
      | p <- repoPackages repo
      , w <- ["-Wwarn", "-Wno-"]
      , w `isInfixOf` packageCabal p
      ]
    , -- R6
      [ Violation R6 "cabal.project does not set `active-repositories: :none`"
      | not ("active-repositories: :none" `isInfixOf` repoProject repo)
      ]
    , [ Violation R6 ("packages/" <> d <> " is not listed in cabal.project")
      | d <- repoPackageDirs repo
      , ("packages/" <> d) `notElem` words (repoProject repo)
      ]
    , [ Violation R6 (packageName p <> " depends on " <> name <> ", which is neither a GHC boot package nor in this repository")
      | p <- repoPackages repo
      , (name, _) <- dependencies (packageCabal p)
      , name `notElem` bootPackages
      , name `notElem` local
      ]
    , [ Violation R6 (packageName p <> " depends on " <> name <> " without both a lower and an upper bound")
      | p <- repoPackages repo
      , (name, bounds) <- dependencies (packageCabal p)
      , name `elem` bootPackages
      , not (">=" `isInfixOf` bounds && "<" `isInfixOf` filter (/= '=') bounds)
      ]
    ]
  where
    sources = concatMap packageSources (repoPackages repo)
    local = map packageName (repoPackages repo)

-- | @(name, version constraint)@ for every @build-depends@ entry. Entries
-- may continue on following, more-indented lines.
dependencies :: String -> [(String, String)]
dependencies cabal =
  [ (name, trim rest)
  | entry <- concatMap (splitOn ',') (dependsBlocks (lines cabal))
  , let (name, rest) = break isSpace (trim entry)
  , not (null name)
  ]
  where
    dependsBlocks [] = []
    dependsBlocks (l : ls)
      | "build-depends:" `isInfixOf` l =
          let ind = indent l
              (cont, others) = span (\x -> not (all isSpace x) && indent x > ind && not (':' `elem` x)) ls
           in unwords (drop 1 (dropWhile (/= "build-depends:") (words l)) ++ concatMap words cont) : dependsBlocks others
      | otherwise = dependsBlocks ls
    indent = length . takeWhile isSpace
    splitOn c s = case break (== c) s of
      (a, _ : b) -> a : splitOn c b
      (a, []) -> [a]
    trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

duplicates :: Ord a => [a] -> [a]
duplicates xs = nub (sort (xs \\ nub xs))
