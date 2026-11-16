-- | Falsifiability of the gate. A gate that cannot fail reads as evidence
-- and is worse than none, so each rule is shown firing on a planted defect,
-- and firing alone: a defect must be reported under the rule it breaks.
--
-- Planted text that the gate itself would flag in this file (markers,
-- partial names) is assembled from halves.
module Main (main) where

import Data.List (nub, sort)
import MP.Check
import MP.Gate.Model
import MP.Gate.Render
import MP.Gate.Rules
import MP.Gate.Toml

main :: IO ()
main =
  runSuite
    "mp-gate"
    [ unit "GT-00" "a clean repository has no violations" $ fired clean === []
    , unit "GT-01" "R1 fires on a hand-edited CONFORMANCE.md" $ fired clean {repoConformance = repoConformance clean <> "\n# edited"} === [R1]
    , unit "GT-01" "R1 fires on a duplicated ID" $ fired (withIds (ck01 <> ck01)) === [R1]
    , unit "GT-01" "R1 fires on an unparsable model" $ fired clean {repoIds = "id = "} === [R1]
    , unit "GT-02" "R2 fires on an open ID" $ fired (withIds (idRow "CK-01" "open" "x" "")) === [R2]
    , unit "GT-02" "R2 fires on an asserting word in a build claim" $ fired (withIds (idRow "CK-01" "build" "This proves x." "")) === [R2]
    , unit "GT-02" "R2 fires on some-true with no authority" $ fired (withIds (idRow "CK-01" "some-true" "x" "")) === [R2]
    , unit "GT-02" "R2 fires on an unknown authority" $ fired (withIds (idRow "CK-01" "build" "x" "authorities = [\"nobody\"]\n")) === [R2]
    , unit "GT-03" "R3 fires on an ID with no test" $ fired (withIds (ck01 <> idRow "CK-02" "build" "x" "")) === [R3]
    , unit "GT-03" "R3 fires on a test tagged with an unregistered ID" $ fired (withTest (testSrc <> "\n  , unit \"CK-77\" \"y\" pass")) === [R3]
    , unit "GT-04" "R4 fires on a deferral marker" $ fired (withTest (testSrc <> "\nx = " <> "TO" <> "DO")) === [R4]
    , unit "GT-04" "R4 fires on a stub" $ fired (withTest (testSrc <> "\nx = " <> "st" <> "ub")) === [R4]
    , unit "GT-04" "R4 does not fire on the marker in a comment or a string" $
        fired (withTest (testSrc <> "\n-- " <> "TO" <> "DO" <> "\nx = \"" <> "TO" <> "DO" <> "\"")) === []
    , unit "GT-05" "R5 fires on a partial function" $ fired (withTest (testSrc <> "\nx = " <> "he" <> "ad ys")) === [R5]
    , unit "GT-05" "R5 fires on a partial operator" $ fired (withTest (testSrc <> "\nx = ys " <> "!" <> "! 3")) === [R5]
    , unit "GT-05" "R5 fires on a missing -Werror" $ fired clean {repoProject = projectWith ""} === [R5]
    , unit "GT-05" "R5 does not fire on primed names, strings or comments" $
        fired (withTest (testSrc <> "\nx = " <> "he" <> "ad' ys\ny = \"" <> "he" <> "ad\"\n-- " <> "he" <> "ad")) === []
    , unit "GT-06" "R6 fires on an outside dependency" $ fired (withCabal "  build-depends: base >=4.20 && <4.21, aeson") === [R6]
    , unit "GT-06" "R6 fires on an unbounded boot dependency" $ fired (withCabal "  build-depends: base") === [R6]
    , unit "GT-06" "R6 fires on an unlisted package" $ fired clean {repoPackageNames = ["mp-check", "mp-extra"]} === [R6]
    , unit "GT-06" "R6 fires on a re-enabled package repository" $
        fired clean {repoProject = goodProject <> "active-repositories: hackage.haskell.org\n"} === [R6]
    , unit "GT-07" "the TOML reader parses the model subset" $
        parseToml "a = \"x\\\"y\"\nb = [\"p\", \"q\"]\nc = 3\n[[t]]\nk = true\n[[t]]\nk = false\n"
          === Right (VTable [("a", VString "x\"y"), ("b", VArray [VString "p", VString "q"]), ("c", VInt 3), ("t", VArray [VTable [("k", VBool True)], VTable [("k", VBool False)]])])
    , unit "GT-07" "the TOML reader rejects what it cannot parse" $
        allOf [assert ("accepted " <> show s) (isLeft (parseToml s)) | s <- ["[", "[[t]", "a = ", "a = \"open", "a = [1, 2", "[plain]", "= 1"]]
    ]
  where
    fired repo = nub (sort (map violationRule (checkRepo repo)))
    isLeft = either (const True) (const False)

-- Synthetic repository for the tests. The real one is loaded by the CLI.
idRow :: String -> String -> String -> String -> String
idRow i level claim extra =
  "\n[[id]]\nid = \"" <> i <> "\"\npackage = \"mp-check\"\nlevel = \"" <> level <> "\"\nclaim = \"" <> claim <> "\"\noracle = \"y\"\n" <> extra

ck01 :: String
ck01 = idRow "CK-01" "build" "x" ""

projectWith :: String -> String
projectWith extra = "packages:\n  packages/mp-check\n\nactive-repositories: :none\n" <> extra

goodProject :: String
goodProject = projectWith "package *\n  ghc-options: -Wall -Werror\n"

testSrc :: String
testSrc = "main = runSuite \"t\"\n  [ prop \"CK-01\" \"x\" g p"

cabalFile :: String
cabalFile = "name: mp-check\nlibrary\n  build-depends: base >=4.20 && <4.21\n"

-- | A repository whose CONFORMANCE.md is regenerated for its model, so only
-- the planted defect can fire.
mkRepo :: String -> String -> String -> String -> Repo
mkRepo ids project cabal src =
  let conf = either (const "") render (readModel ids "" "")
   in Repo ids "" "" conf project ["mp-check"] [Package "mp-check" cabal [SourceFile "packages/mp-check/test/Main.hs" src True]]

clean :: Repo
clean = mkRepo ("spec = \"montrepol/1\"\n" <> ck01) goodProject cabalFile testSrc

withIds :: String -> Repo
withIds rows = mkRepo ("spec = \"montrepol/1\"\n" <> rows) goodProject cabalFile testSrc

withTest :: String -> Repo
withTest = mkRepo ("spec = \"montrepol/1\"\n" <> ck01) goodProject cabalFile

withCabal :: String -> Repo
withCabal deps = mkRepo ("spec = \"montrepol/1\"\n" <> ck01) goodProject ("name: mp-check\nlibrary\n" <> deps <> "\n") testSrc
