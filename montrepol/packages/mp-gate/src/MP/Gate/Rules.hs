-- | The rules R1-R6.
module MP.Gate.Rules
  ( Rule(..)
  , Violation(..)
  , Repo(..)
  , Package(..)
  , SourceFile(..)
  , checkRepo
  , check
  ) where

import Data.List (isInfixOf, isPrefixOf, tails)
import MP.Gate.Model
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
  , repoPackageNames :: [String]
  , repoPackages :: [Package]
  } deriving (Eq, Show)

checkRepo :: Repo -> [Violation]
checkRepo repo =
  case readModel (repoIds repo) (repoLedger repo) (repoAuthorities repo) of
    Left _ -> [Violation R1 "model does not parse"]
    Right model ->
      let tags = [(id, sourcePath sf) | pkg <- repoPackages repo, sf <- pkgSources pkg, sourceIsTest sf, Just id <- [tagOf (sourceText sf)]]
          srcs = [sourceText sf | pkg <- repoPackages repo, sf <- pkgSources pkg]
          cabs = [pkgCabal pkg | pkg <- repoPackages repo]
       in map (\s -> Violation R1 s) (r1 model)
            ++ map (\s -> Violation R2 s) (r2 model)
            ++ map (\s -> Violation R3 s) (r3 model tags)
            ++ map (\s -> Violation R4 s) (r4 srcs)
            ++ map (\s -> Violation R5 s) (r5 srcs cabs)
            ++ map (\s -> Violation R6 s) (r6 (repoProject repo))

-- Compatibility shim used by older call sites.
check :: Model -> [(String, String)] -> [String] -> [String] -> [String]
check model tags sources cabals =
  map violationMsg (checkRepo (Repo "" "" "" "" "" [] [Package "" (unlines cabals) [SourceFile "" (unlines sources) True]]))

r1 :: Model -> [String]
r1 m =
  let ids = map rowId (modelIds m)
      dups = [i | i <- ids, length (filter (== i) ids) > 1]
   in ["duplicate ID " <> i | i <- nub dups]

r2 :: Model -> [String]
r2 m =
  let badLevel = [rowId r | r <- modelIds m, rowLevel r `notElem` ["build", "some-true"]]
      noAuth = [rowId r | r <- modelIds m, rowLevel r == "some-true", null (rowAuthorities r)]
      unknown = [a | r <- modelIds m, a <- rowAuthorities r, a `notElem` map authId (modelAuthorities m)]
   in ["bad level " <> i | i <- badLevel]
        ++ ["some-true without authority " <> i | i <- noAuth]
        ++ ["unknown authority " <> a | a <- unknown]

r3 :: Model -> [(String, String)] -> [String]
r3 m tags =
  let registered = map rowId (modelIds m)
      tagged = map fst tags
      untested = [i | i <- registered, i `notElem` tagged]
      unregistered = [t | t <- tagged, t `notElem` registered]
   in ["untested ID " <> i | i <- untested] ++ ["unregistered tag " <> t | t <- unregistered]

r4 :: [String] -> [String]
r4 srcs = ["deferral " <> d | d <- concatMap (uncurry deferrals) (zip (map show [1 ..]) srcs)]

r5 :: [String] -> [String] -> [String]
r5 srcs cabs =
  let parts = ["partial " <> p | p <- concatMap (uncurry partials) (zip (map show [1 ..]) srcs)]
      noWerror = ["missing -Werror" | c <- cabs, not ("-Werror" `isInfixOf` c)]
   in parts ++ noWerror

r6 :: String -> [String]
r6 project
  | "active-repositories:" `isInfixOf` project && not (":none" `isInfixOf` project) = ["package repository enabled"]
  | otherwise = []

nub :: Eq a => [a] -> [a]
nub [] = []
nub (x : xs) = x : nub (filter (/= x) xs)
