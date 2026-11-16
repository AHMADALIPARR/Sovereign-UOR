-- SPDX-License-Identifier: AGPL-3.0-or-later

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
    , unit "GT-06" "R6: a source file without the SPDX header fires" $
        rulesFired (mkRepo cleanIds cleanLedger cleanCabal "module A where\n" testSrc) === [R6]
    , unit "GT-06" "R6: a .cabal file without the SPDX header fires" $
        rulesFired (mkRepo cleanIds cleanLedger "build-depends: base >=4 && <5\n" cleanSrc testSrc) === [R6]
    , unit "GT-06" "R6: re-enabling a package repository fires" $
        rulesFired clean {repoProject = "packages: packages/pkg-a\nghc-options: -Wall -Werror -Wincomplete-uni-patterns\n"} === [R6]
    , unit "GT-08" "a clean formal tree with a proved claim has no violations" $
        rulesFired (withFormal cleanProved cleanFormal) === []
    , unit "GT-08" "a proved claim citing a missing Agda file fires R2" $
        rulesFired (withFormal (cleanLedger <> provedClaim "formal/Montrepol/Gone.agda: thm") cleanFormal) === [R2]
    , unit "GT-08" "a proved claim citing a lemma the file does not define fires R2" $
        rulesFired (withFormal (cleanLedger <> provedClaim "formal/Montrepol/A.agda: thm, ghost") cleanFormal) === [R2]
    , unit "GT-08" "an ID at level proved fires R2" $
        rulesFired (withIds (idRow "GA-01" "proved" "x")) === [R2]
    , unit "GT-08" "a postulate fires R4" $
        rulesFired (withFormal cleanProved [everything, agda "A" "postulate\n  thm : Set\n"]) === [R4]
    , unit "GT-08" "a module without --safe fires R5" $
        rulesFired (withFormal cleanProved [everything, SourceFile "formal/Montrepol/A.agda" (spdxHeader <> "\nmodule Montrepol.A where\nthm : Set₁\nthm = Set\n") False]) === [R5]
    , unit "GT-08" "a module Everything.agda does not import fires R5" $
        rulesFired (withFormal cleanProved (cleanFormal ++ [agda "B" "lemma : Set₁\nlemma = Set\n"])) === [R5]
    , unit "GT-08" "an Agda file without the SPDX header fires R6" $
        rulesFired (withFormal cleanProved [everything, SourceFile "formal/Montrepol/A.agda" "{-# OPTIONS --safe #-}\nmodule Montrepol.A where\nthm : Set₁\nthm = Set\n" False]) === [R6]
    , unit "GT-08" "asserting words are allowed at level proved" $
        rulesFired (withFormal (cleanLedger <> provedClaim' ("it pro" <> "ves that thm holds") "formal/Montrepol/A.agda: thm") cleanFormal) === []
    , unit "GT-09" "a clean liquid layer has no violations" $
        rulesFired (withLiquid [liquidSrc "{-@ f :: Nat -> Nat @-}\n"] (Just "packages: .\n") project) === []
    , unit "GT-09" "liquid sources without their own cabal.project fire R6" $
        rulesFired (withLiquid [liquidSrc ""] Nothing project) === [R6]
    , unit "GT-09" "the root cabal.project including the liquid layer fires R6" $
        rulesFired (withLiquid [liquidSrc ""] (Just "packages: .\n") (project <> "  liquid\n")) === [R6]
    , unit "GT-09" "a core package depending on liquidhaskell fires R6" $
        rulesFired (withCabal "build-depends: base >=4 && <5, liquidhaskell >=0.9 && <0.10\n") === [R6]
    , unit "GT-09" "an assumed refinement in the liquid layer fires R4" $
        rulesFired (withLiquid [liquidSrc ("{-@ ass" <> "ume f :: Int -> Nat @-}\n")] (Just "packages: .\n") project) === [R4]
    , unit "GT-10" "a refined claim with a spec in a module the liquid build compiles has no violations" $
        rulesFired (withRefined (refinedClaim "pkg-a/src/A.hs: f") liquidCabal) === []
    , unit "GT-10" "a refined claim naming a function with no spec fires R2" $
        rulesFired (withRefined (refinedClaim "pkg-a/src/A.hs: f, g") liquidCabal) === [R2]
    , unit "GT-10" "a refined claim on a module the liquid build does not compile fires R2" $
        rulesFired (withRefined (refinedClaim "pkg-a/src/A.hs: f") (Just "exposed-modules: Other\n")) === [R2]
    , unit "GT-10" "a refined claim citing a file that is not a core source fires R2" $
        rulesFired (withRefined (refinedClaim "pkg-a/src/Gone.hs: f") liquidCabal) === [R2]
    , unit "GT-11" "a Dex check tagged with a registered dex ID has no violations" $
        rulesFired (withDex (dexRow "DX-01") [dexFile "# check DX-01\n:p 1 + 1\n> 2\n"]) === []
    , unit "GT-11" "a dex ID with no tagged check fires R3" $
        rulesFired (withDex (dexRow "DX-01" <> dexRow "DX-02") [dexFile "# check DX-01\n"]) === [R3]
    , unit "GT-11" "a Dex check tagged with an unregistered ID fires R3" $
        rulesFired (withDex (dexRow "DX-01") [dexFile "# check DX-01\n# check DX-07\n"]) === [R3]
    , unit "GT-11" "a Dex file without the SPDX header fires R6" $
        rulesFired (withDex (dexRow "DX-01") [SourceFile "dex/A.dx" "# check DX-01\n" True]) === [R6]
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
testSrc = spdxHeader <> "\nt = unit \"GA-01\" \"x\" pass\n"

project :: String
project = "packages: packages/pkg-a\nactive-repositories: :none\nghc-options: -Wall -Werror -Wincomplete-uni-patterns\n"

-- A small formal/ tree that keeps every rule, and the ledger claim citing it.
agda :: String -> String -> SourceFile
agda m body =
  SourceFile
    ("formal/Montrepol/" <> m <> ".agda")
    (spdxHeader <> "\n{-# OPTIONS --safe --without-K #-}\nmodule Montrepol." <> m <> " where\n" <> body)
    False

everything :: SourceFile
everything =
  SourceFile
    "formal/Everything.agda"
    (spdxHeader <> "\n{-# OPTIONS --safe --without-K #-}\nmodule Everything where\nimport Montrepol.A\n")
    False

cleanFormal :: [SourceFile]
cleanFormal = [everything, agda "A" "thm : Set₁\nthm = Set\n"]

provedClaim' :: String -> String -> String
provedClaim' statement evidence =
  "[[claim]]\nkey = \"p\"\nlevel = \"proved\"\nstatement = \"" <> statement <> "\"\nevidence = \"" <> evidence <> "\"\n"

provedClaim :: String -> String
provedClaim = provedClaim' "a theorem"

cleanProved :: String
cleanProved = cleanLedger <> provedClaim "formal/Montrepol/A.agda: thm"

refinedClaim :: String -> String
refinedClaim evidence =
  cleanLedger <> "[[claim]]\nkey = \"r\"\nlevel = \"refined\"\nstatement = \"f returns a natural\"\nevidence = \"" <> evidence <> "\"\n"

liquidCabal :: Maybe String
liquidCabal = Just "exposed-modules:  A\n"

-- The clean repository, with a core module carrying a spec for f, the liquid
-- build compiling it, and this ledger.
withRefined :: String -> Maybe String -> Repo
withRefined ledger cabal =
  let src = spdxHeader <> "\nmodule A where\n{-@ f :: Int -> Nat @-}\nf :: Int -> Int\nf x = if x < 0 then 0 else x\n"
   in (mkRepo cleanIds ledger cleanCabal src testSrc) {repoLiquidCabal = cabal}

dexRow :: String -> String
dexRow i = "[[id]]\nid = \"" <> i <> "\"\npackage = \"dex\"\nlevel = \"build\"\nclaim = \"x\"\noracle = \"y\"\n"

dexFile :: String -> SourceFile
dexFile body = SourceFile "dex/A.dx" ("# SPDX-License-" <> "Identifier: AGPL-3.0-or-later\n" <> body) True

withDex :: String -> [SourceFile] -> Repo
withDex extraIds files = (mkRepo (cleanIds <> extraIds) cleanLedger cleanCabal cleanSrc testSrc) {repoDex = files}

liquidSrc :: String -> SourceFile
liquidSrc body = SourceFile "liquid/src/MP/Liquid/A.hs" (spdxHeader <> "\nmodule MP.Liquid.A where\n" <> body) False

withLiquid :: [SourceFile] -> Maybe String -> String -> Repo
withLiquid srcs proj root = clean {repoLiquid = srcs, repoLiquidProject = proj, repoProject = root}

-- The clean repository with this ledger and this formal/ tree.
withFormal :: String -> [SourceFile] -> Repo
withFormal ledger formal = (mkRepo cleanIds ledger cleanCabal cleanSrc testSrc) {repoFormal = formal}

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
        , repoFormal = []
        , repoLiquid = []
        , repoLiquidProject = Nothing
        , repoLiquidCabal = Nothing
        , repoDex = []
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
cleanCabal = spdxHeader <> "\nbuild-depends: base >=4 && <5\n"
cleanSrc = spdxHeader <> "\nmodule A where\nf :: Int -> Int\nf x = x + 1\n"

clean :: Repo
clean = mkRepo cleanIds cleanLedger cleanCabal cleanSrc testSrc

-- Each regenerates CONFORMANCE.md, so only the planted defect differs.
withIds, withLedger, withCabal, withSrc, withTest :: String -> Repo
withIds ids = mkRepo ids cleanLedger cleanCabal cleanSrc testSrc
withLedger l = mkRepo cleanIds l cleanCabal cleanSrc testSrc
withCabal c = mkRepo cleanIds cleanLedger (spdxHeader <> "\n" <> c) cleanSrc testSrc
withSrc s = mkRepo cleanIds cleanLedger cleanCabal (spdxHeader <> "\n" <> s) testSrc
withTest t = mkRepo cleanIds cleanLedger cleanCabal cleanSrc (spdxHeader <> "\n" <> t)
