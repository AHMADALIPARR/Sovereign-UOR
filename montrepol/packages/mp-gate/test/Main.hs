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
    , unit "GT-01" "R1 fires on a hand-edited CONFORMANCE.md" $ fired r1Edited === [R1]
    , unit "GT-01" "R1 fires on a duplicated ID" $ fired r1Dup === [R1]
    , unit "GT-02" "R2 fires on an open ID" $ fired r2Open === [R2]
    , unit "GT-03" "R3 fires on an ID with no test" $ fired r3Untested === [R3]
    , unit "GT-04" "R4 fires on a deferral marker" $ fired r4Marker === [R4]
    , unit "GT-05" "R5 fires on a partial function" $ fired r5Partial === [R5]
    , unit "GT-06" "R6 fires on an outside dependency" $ fired r6Outside === [R6]
    , unit "GT-07" "the TOML reader rejects what it cannot parse" $ parseFail
    ]
  where
    fired r = rulesFired r
    rulesFired repo = nub (sort (map violationRule (checkRepo repo)))

-- Synthetic repositories for the tests. The real one is loaded by the CLI.
clean :: Repo
clean = Repo ids ledger auths conf project packages pkgs
  where
    ids = "spec = \"montrepol/1\"\n\n[[id]]\nid = \"CK-01\"\npackage = \"mp-check\"\nlevel = \"build\"\nclaim = \"x\"\noracle = \"y\""
    ledger = ""
    auths = ""
    conf = "# CONFORMANCE\n\nGenerated from `model/` by `cabal run mp-gate -- write`. Do not edit.\n"
    project = "packages: packages/*\nactive-repositories: :none"
    packages = ["mp-check"]
    pkgs = [Package "mp-check" "" [SourceFile "packages/mp-check/test/Main.hs" "prop \"CK-01\" \"x\" g p" True]]

r1Edited = clean { repoConformance = repoConformance clean <> "\n# edited" }
r1Dup = clean { repoIds = repoIds clean <> "\n[[id]]\nid = \"CK-01\"\npackage = \"mp-check\"\nlevel = \"build\"\nclaim = \"z\"\noracle = \"w\"" }
r2Open = clean { repoIds = "spec = \"montrepol/1\"\n\n[[id]]\nid = \"CK-99\"\npackage = \"mp-check\"\nlevel = \"open\"\nclaim = \"x\"\noracle = \"y\"" }
r3Untested = clean { repoIds = "spec = \"montrepol/1\"\n\n[[id]]\nid = \"CK-99\"\npackage = \"mp-check\"\nlevel = \"build\"\nclaim = \"x\"\noracle = \"y\"" }
r4Marker = clean { repoPackages = [Package "mp-check" "" [SourceFile "x.hs" "x = 1 -- " <> "TODO" True]] }
r5Partial = clean { repoPackages = [Package "mp-check" "" [SourceFile "x.hs" "x = head ys" True]] }
r6Outside = clean { repoProject = "packages: packages/*\nactive-repositories: hackage.haskell.org" }

parseFail :: Result
parseFail = case parseToml "[" of
  Left _ -> pass
  Right _ -> failWith "accepted an unclosed table"
