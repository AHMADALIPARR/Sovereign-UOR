-- | Falsifiability of the gate. A gate that cannot fail reads as evidence
-- and is worse than none, so each rule is shown firing on a planted defect,
-- and firing alone: a defect must be reported under the rule it breaks.
--
-- Planted text that the gate itself would flag in this file (markers) is
-- assembled from halves, for the same reason as in "MP.Gate.Scan".
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
    [ unit "GT-00" "a clean repository has no violations" $ rulesFired clean === []
    , unit "GT-01" "R1: a hand-edited CONFORMANCE.md fires" $
        rulesFired clean {repoConformance = repoConformance clean <> "edited\n"} === [R1]
    , unit "GT-01" "R1: a duplicated ID fires" $
        rulesFired (withIds (idRow "GA-01" "build" "x" <> idRow "GA-01" "build" "x")) === [R1]
    , unit "GT-01" "R1: an unparsable model fires" $
        rulesFired clean {repoIds = "this is not toml\n"} === [R1]
    , unit "GT-02" "R2: an ID at level open fires" $
        rulesFired (withIds (idRow "GA-01" "open" "measured")) === [R2]
    , unit "GT-02" "R2: an asserting word in an open claim fires" $
        rulesFired (withLedger (openClaim ("it pro" <> "ves the bound") <> trueClaim)) === [R2]
    , unit "GT-02" "R2: some-true without an authority fires" $
        rulesFired (withLedger (openClaim "a measurement" <> trueClaim <> bareTrue)) === [R2]
    , unit "GT-02" "R2: a citation of an unknown authority fires" $
        rulesFired (withIds (idRow "GA-01" "build" "x" <> "authorities = [\"nobody-1999\"]\n")) === [R2]
    , unit "GT-03" "R3: an ID with no test fires" $
        rulesFired (withIds (idRow "GA-01" "build" "x" <> idRow "GA-02" "build" "y")) === [R3]
    , unit "GT-03" "R3: a test tagged with an unregistered ID fires" $
        rulesFired (withTest "t = unit \"GA-01\" \"x\" pass\nu = prop \"GA-09\" \"y\" g p\n") === [R3]
    , unit "GT-04" "R4: a deferral marker fires" $
        rulesFired (withSrc ("-- " <> "TO" <> "DO: finish\nf = 1\n")) === [R4]
    , unit "GT-04" "R4: a stub fires" $
        rulesFired (withSrc "f :: Int\nf = undefined\n") === [R4]
    , unit "GT-04" "R4: the same word in a comment or a string does not fire" $
        rulesFired (withSrc "-- undefined behaviour\nf = \"undefined\"\n") === []
    , unit "GT-05" "R5: a partial function fires" $
        rulesFired (withSrc "f xs = head xs\n") === [R5]
    , unit "GT-05" "R5: a partial operator fires" $
        rulesFired (withSrc "f xs = xs !! 2\n") === [R5]
    , unit "GT-05" "R5: a primed name, a string and a comment do not fire" $
        rulesFired (withSrc "f = head' \"head\" -- head of the list\n  where head' = 'h'\n") === []
    , unit "GT-05" "R5: removing -Werror fires" $
        rulesFired clean {repoProject = "packages: packages/pkg-a\nactive-repositories: :none\nghc-options: -Wall -Wincomplete-uni-patterns\n"} === [R5]
    , unit "GT-06" "R6: a dependency from outside fires" $
        rulesFired (withCabal "build-depends: base >=4 && <5, aeson >=2 && <3\n") === [R6]
    , unit "GT-06" "R6: an unbounded boot dependency fires" $
        rulesFired (withCabal "build-depends: base\n") === [R6]
    , unit "GT-06" "R6: a package directory missing from cabal.project fires" $
        rulesFired clean {repoPackageDirs = ["pkg-a", "pkg-b"]} === [R6]
    , unit "GT-06" "R6: re-enabling a package repository fires" $
        rulesFired clean {repoProject = "packages: packages/pkg-a\nghc-options: -Wall -Werror -Wincomplete-uni-patterns\n"} === [R6]
    , unit "GT-07" "TOML: arrays of tables, escapes, arrays, comments" $
        parseToml "a = \"x # not a comment\" # a comment\n[[t]]\nk = \"q\\\"uote\"\nn = [\"p\", \"q\"]\n[[t]]\nk = \"2\"\n"
          === Right
            ( Doc
                [("a", VString "x # not a comment")]
                [("t", [[("k", VString "q\"uote"), ("n", VStrings ["p", "q"])], [("k", VString "2")]])]
            )
    , unit "GT-07" "TOML: a line it cannot read is an error, not a guess" $
        assert "accepted garbage" (either (const True) (const False) (parseToml "k = \"ok\"\nwhat is this\n"))
    ]

------------------------------------------------------------------------------
-- A small repository that passes, and ways to break it

rulesFired :: Repo -> [Rule]
rulesFired = sort . nub . map (\(Violation r _) -> r) . checkRepo

idRow :: String -> String -> String -> String
idRow i level claim =
  "[[id]]\nid = \"" <> i <> "\"\npackage = \"pkg-a\"\nlevel = \"" <> level <> "\"\nclaim = \"" <> claim <> "\"\noracle = \"an oracle\"\n"

openClaim :: String -> String
openClaim s = "[[claim]]\nkey = \"m\"\nlevel = \"open\"\nstatement = \"" <> s <> "\"\nevidence = \"a report\"\n"

trueClaim :: String
trueClaim = "[[claim]]\nkey = \"t\"\nlevel = \"some-true\"\nstatement = \"a theorem\"\nevidence = \"a book\"\nauthorities = [\"book-2000\"]\n"

bareTrue :: String
bareTrue = "[[claim]]\nkey = \"u\"\nlevel = \"some-true\"\nstatement = \"another\"\nevidence = \"none\"\n"

authorities :: String
authorities = "[[authority]]\nkey = \"book-2000\"\ncite = \"A. Author, A Book, 2000\"\n"

testSrc :: String
testSrc = "t = unit \"GA-01\" \"x\" pass\n"

project :: String
project = "packages: packages/pkg-a\nactive-repositories: :none\nghc-options: -Wall -Werror -Wincomplete-uni-patterns\n"

mkRepo :: String -> String -> String -> String -> String -> Repo
mkRepo ids ledger cabal src test =
  let conformance = either (const "") renderConformance (readModel ids ledger authorities)
   in Repo
        { repoIds = ids
        , repoLedger = ledger
        , repoAuthorities = authorities
        , repoConformance = conformance
        , repoProject = project
        , repoPackageDirs = ["pkg-a"]
        , repoPackages =
            [ Package
                "pkg-a"
                cabal
                [SourceFile "pkg-a/src/A.hs" src False, SourceFile "pkg-a/test/Main.hs" test True]
            ]
        }

cleanIds, cleanLedger, cleanCabal, cleanSrc :: String
cleanIds = idRow "GA-01" "build" "a claim"
cleanLedger = openClaim "a measurement" <> trueClaim
cleanCabal = "build-depends: base >=4 && <5\n"
cleanSrc = "module A where\nf :: Int -> Int\nf x = x + 1\n"

clean :: Repo
clean = mkRepo cleanIds cleanLedger cleanCabal cleanSrc testSrc

-- Each regenerates CONFORMANCE.md, so only the planted defect differs.
withIds, withLedger, withCabal, withSrc, withTest :: String -> Repo
withIds ids = mkRepo ids cleanLedger cleanCabal cleanSrc testSrc
withLedger l = mkRepo cleanIds l cleanCabal cleanSrc testSrc
withCabal c = mkRepo cleanIds cleanLedger c cleanSrc testSrc
withSrc s = mkRepo cleanIds cleanLedger cleanCabal s testSrc
withTest t = mkRepo cleanIds cleanLedger cleanCabal cleanSrc t
