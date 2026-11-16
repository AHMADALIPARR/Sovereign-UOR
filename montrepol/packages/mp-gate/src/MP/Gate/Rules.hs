-- SPDX-License-Identifier: AGPL-3.0-or-later

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
  , spdxHeader
  ) where

import Data.Char (isSpace, toLower)
import Data.List (isInfixOf, isPrefixOf, isSuffixOf, nub, sort, (\\))
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
  , repoFormal :: [SourceFile]
  -- ^ every @.agda@ file under @formal/@, with paths like @formal/Montrepol/Kish.agda@
  , repoLiquid :: [SourceFile]
  -- ^ every @.hs@ file under @liquid/@, the one layer allowed outside dependencies
  , repoLiquidProject :: Maybe String
  -- ^ @liquid/cabal.project@, if it exists
  , repoLiquidCabal :: Maybe String
  -- ^ @liquid/mp-liquid.cabal@, if it exists
  , repoDex :: [SourceFile]
  -- ^ every @.dx@ file under @dex/@: quines whose checks are tagged
  -- @# check XX-00@ and registered to the package @dex@
  }

-- | The first line of every Haskell source, and one of the first two of
-- every @.cabal@ file.
spdxHeader :: String
spdxHeader = "-- SPDX-License-" <> "Identifier: AGPL-3.0-or-later"

-- | Libraries that ship with GHC 9.10.1. Nothing else may be depended on.
bootPackages :: [String]
bootPackages = ["base", "array", "containers", "directory", "filepath", "process"]

checkRepo :: Repo -> [Violation]
checkRepo repo = case readModel (repoIds repo) (repoLedger repo) (repoAuthorities repo) of
  Left e -> Violation R1 ("the model does not parse: " <> e) : sourceRules repo ++ formalRules repo ++ liquidRules repo ++ dexRules repo
  Right model -> modelRules repo model ++ sourceRules repo ++ formalRules repo ++ liquidRules repo ++ dexRules repo

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
      , not (rowPackage r == "dex" && not (null (repoDex repo)))
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
    , [ Violation R2 ("ID " <> rowId r <> " is `proved`: a proof belongs in the ledger, with its Agda file as evidence")
      | r <- rows, rowLevel r == Proved
      ]
    , concat [provedEvidence repo c | c <- claims, claimLevel c == Proved]
    , [ Violation R2 ("ID " <> rowId r <> " is `refined`: a Liquid Haskell result belongs in the ledger")
      | r <- rows, rowLevel r == Refined
      ]
    , concat [refinedEvidence repo c | c <- claims, claimLevel c == Refined]
    , [ Violation R2 (what <> " asserts (" <> show w <> ") at level `" <> levelName l <> "`")
      | (what, l, text) <-
          [("ID " <> rowId r, rowLevel r, rowClaim r) | r <- rows]
            ++ [("ledger " <> claimKey c, claimLevel c, claimStatement c) | c <- claims]
      , l `notElem` [SomeTrue, Proved, Refined]
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
    , [ Violation R3 (sourcePath f <> " is tagged " <> show t <> ", which is not registered")
      | f <- repoDex repo
      , t <- nub (dexTags (sourceText f))
      , t `notElem` map rowId rows
      ]
    , [ Violation R3 (sourcePath f <> " is tagged " <> t <> ", registered to " <> rowPackage r)
      | f <- repoDex repo
      , t <- nub (dexTags (sourceText f))
      , r <- rows
      , rowId r == t
      , rowPackage r /= "dex"
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
    tagsIn name
      | name == "dex" = concatMap (dexTags . sourceText) (repoDex repo)
      | otherwise = concatMap tagsOf (filter ((== name) . packageName) (repoPackages repo))

-- | IDs in @# check XX-00@ comments (Dex comments start with @#@), which
-- tag the Dex check that follows.
dexTags :: String -> [String]
dexTags src = [i | l <- lines src, ["#", "check", i] <- [words l]]

-- | Dex's comment syntax is @#@, so its header is spelled that way.
dexSpdxHeader :: String
dexSpdxHeader = "# SPDX-License-" <> "Identifier: AGPL-3.0-or-later"

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
      [ Violation R6 (sourcePath f <> ": first line is not the SPDX licence header")
      | f <- sources
      , take 1 (lines (sourceText f)) /= [spdxHeader]
      ]
    , -- Cabal insists that cabal-version is the first line, so there the
      -- header may be second.
      [ Violation R6 (packageName p <> ".cabal: neither of the first two lines is the SPDX licence header")
      | p <- repoPackages repo
      , spdxHeader `notElem` take 2 (lines (packageCabal p))
      ]
    , [ Violation R6 "cabal.project does not set `active-repositories: :none`"
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

------------------------------------------------------------------------------
-- The formal layer

-- | A @proved@ claim's evidence is @formal/Path.agda: lemma1, lemma2@. The
-- file must exist and define every lemma named. Whether the lemmas *prove*
-- the statement is Agda's job; that the claim points at real lemmas is this.
provedEvidence :: Repo -> Claim -> [Violation]
provedEvidence repo c = case break (== ':') (claimEvidence c) of
  (path, ':' : names) -> case [f | f <- repoFormal repo, sourcePath f == trim path] of
    [] -> [Violation R2 ("ledger " <> claimKey c <> " cites " <> trim path <> ", which does not exist")]
    (f : _) ->
      [ Violation R2 ("ledger " <> claimKey c <> " cites lemma " <> n <> ", which " <> trim path <> " does not define")
      | n <- map trim (splitOn ',' names)
      , not (null n)
      , not (any ((n <> " :") `isPrefixOf`) (map (dropWhile isSpace) (lines (sourceText f))))
      ]
        ++ [Violation R2 ("ledger " <> claimKey c <> " names no lemmas") | all (null . trim) (splitOn ',' names)]
  _ -> [Violation R2 ("ledger " <> claimKey c <> " is `proved` but its evidence is not `formal/File.agda: lemma, ...`")]

-- | A @refined@ claim's evidence is @packages/.../Module.hs: f, g@. The
-- file must be a core source, every function named must carry a
-- @{-\@ f :: ... \@-}@ spec in it, and its module must be one the liquid
-- build compiles: otherwise the spec would be a comment nothing checks.
refinedEvidence :: Repo -> Claim -> [Violation]
refinedEvidence repo c = case break (== ':') (claimEvidence c) of
  (path, ':' : names) -> case [f | p <- repoPackages repo, f <- packageSources p, sourcePath f == trim path] of
    [] -> [Violation R2 ("ledger " <> claimKey c <> " cites " <> trim path <> ", which is not a core source")]
    (f : _) ->
      [ Violation R2 ("ledger " <> claimKey c <> ": " <> trim path <> " has no Liquid Haskell spec for " <> n)
      | n <- map trim (splitOn ',' names)
      , not (null n)
      , not (any (("{-@ " <> n <> " ::") `isPrefixOf`) (map (dropWhile isSpace) (lines (sourceText f))))
      ]
        ++ [ Violation R2 ("ledger " <> claimKey c <> ": the liquid build does not compile " <> modName)
           | modName <- [moduleOfSource (trim path)]
           , not (modName `elem` words (maybe "" id (repoLiquidCabal repo)))
           ]
  _ -> [Violation R2 ("ledger " <> claimKey c <> " is `refined` but its evidence is not `packages/.../File.hs: f, ...`")]
  where
    -- packages/mp-lambda/src/MP/Lambda/Simple.hs is the module MP.Lambda.Simple
    moduleOfSource p =
      let rel = case breakOn "/src/" p of
            Just r -> r
            Nothing -> p
          base = if ".hs" `isSuffixOf` rel then take (length rel - 3) rel else rel
       in map (\ch -> if ch == '/' then '.' else ch) base
    breakOn needle hay = case [drop (length needle) t | t <- suffixes hay, needle `isPrefixOf` t] of
      (r : _) -> Just r
      [] -> Nothing
    suffixes s = s : case s of
      (_ : rest) -> suffixes rest
      [] -> []

-- | Agda escape hatches. Any of them would let a false statement check.
-- @--safe@ already refuses most of them; this is a second, independent net,
-- and it also catches an escape in a file that has lost its @--safe@.
agdaEscapes :: [String]
agdaEscapes =
  [ "postulate", "{!", "TERMINATING", "NON_TERMINATING", "NO_POSITIVITY_CHECK"
  , "NO_UNIVERSE_CHECK", "--type-in-type", "--allow-unsolved-metas", "--no-term" <> "ination-check"
  , "--cumulativity", "--sized-types", "--guardedness", "--injective-type-constructors"
  ]

formalRules :: Repo -> [Violation]
formalRules repo =
  concat
    [ [ Violation R4 (sourcePath f <> ": escape hatch " <> e)
      | f <- fs, e <- agdaEscapes, e `isInfixOf` sourceText f
      ]
    , [ Violation R4 (sourcePath f <> ": deferral marker " <> m)
      | f <- fs, m <- deferralMarkers, m `isInfixOf` sourceText f
      ]
    , [ Violation R5 (sourcePath f <> ": not checked under --safe")
      | f <- fs, not ("{-# OPTIONS --safe" `isInfixOf` sourceText f)
      ]
    , [ Violation R5 (sourcePath f <> " is not imported by formal/Everything.agda, so nothing checks it")
      | not (null fs)
      , f <- fs
      , sourcePath f /= "formal/Everything.agda"
      , ("import " <> moduleOf (sourcePath f)) `notElem` map (unwords . take 2 . words) everything
      ]
    , [ Violation R5 "formal/ has Agda files but no formal/Everything.agda to check them"
      | not (null fs), null [() | f <- fs, sourcePath f == "formal/Everything.agda"]
      ]
    , [ Violation R6 (sourcePath f <> ": first line is not the SPDX licence header")
      | f <- fs, [spdxHeader] /= take 1 (lines (sourceText f))
      ]
    ]
  where
    fs = repoFormal repo
    everything = concat [lines (sourceText f) | f <- fs, sourcePath f == "formal/Everything.agda"]
    -- formal/Montrepol/Kish.agda is the module Montrepol.Kish
    moduleOf p =
      let rel = drop (length "formal/") p
          base = if ".agda" `isSuffixOf` rel then take (length rel - length ".agda") rel else rel
       in map (\ch -> if ch == '/' then '.' else ch) base

------------------------------------------------------------------------------
-- The Liquid Haskell layer

-- | @liquid/@ is exempt from R6's no-outside-dependencies rule, and only in
-- one direction: it may use Hackage and Z3, but it is a separate build, the
-- root project may not include it, and no core package may depend on it (the
-- ordinary R6 dependency check already refuses @liquidhaskell@ and
-- @mp-liquid@ in @packages/@). Its sources keep every other rule that can
-- be read from them.
liquidRules :: Repo -> [Violation]
liquidRules repo =
  concat
    [ [ Violation R6 "liquid/ has sources but no liquid/cabal.project of its own"
      | not (null fs), repoLiquidProject repo == Nothing
      ]
    , [ Violation R6 ("the root cabal.project includes the liquid layer (" <> w <> ")")
      | w <- words (repoProject repo)
      , "liquid" `isPrefixOf` w
      ]
    , [ Violation R6 (sourcePath f <> ": first line is not the SPDX licence header")
      | f <- fs, [spdxHeader] /= take 1 (lines (sourceText f))
      ]
    , [ Violation R4 (sourcePath f <> ": deferral marker " <> m)
      | f <- fs, m <- deferralMarkers, m `isInfixOf` sourceText f
      ]
    , -- The refinements of core modules live in the core sources, so the
      -- escapes are refused there too.
      [ Violation R4 (sourcePath f <> ": lazy or assumed refinement (" <> a <> ")")
      | f <- fs ++ concatMap packageSources (repoPackages repo)
      , a <- liquidEscapes
      , a `isInfixOf` sourceText f
      ]
    ]
  where
    fs = repoLiquid repo

-- | Dex files keep the licence and deferral rules.
dexRules :: Repo -> [Violation]
dexRules repo =
  [ Violation R6 (sourcePath f <> ": first line is not the SPDX licence header")
  | f <- repoDex repo, [dexSpdxHeader] /= take 1 (lines (sourceText f))
  ]
    ++ [ Violation R4 (sourcePath f <> ": deferral marker " <> m)
       | f <- repoDex repo, m <- deferralMarkers, m `isInfixOf` sourceText f
       ]

-- | Liquid Haskell annotations that switch checking off for what they touch.
-- In halves, so that this list does not match itself (see "MP.Gate.Scan").
liquidEscapes :: [String]
liquidEscapes = ["@ ass" <> "ume", "@ la" <> "zy", "@ ig" <> "nore", "--no-term" <> "ination", "--skip-mod" <> "ule"]

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

splitOn :: Char -> String -> [String]
splitOn ch s = case break (== ch) s of
  (a, _ : b) -> a : splitOn ch b
  (a, []) -> [a]

duplicates :: Ord a => [a] -> [a]
duplicates xs = nub (sort (xs \\ nub xs))
