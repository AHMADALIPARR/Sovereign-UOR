-- | @CONFORMANCE.md@, generated from the model and never edited (R1).
module MP.Gate.Render (renderConformance) where

import Data.List (intercalate, nub)
import MP.Gate.Model

renderConformance :: Model -> String
renderConformance (Model rows claims auths) =
  unlines $
    [ "<!-- Generated from model/*.toml by `mp-gate write`. Do not edit: R1. -->"
    , ""
    , "# Conformance"
    , ""
    , "Every claim this repository makes, by honesty level:"
    , ""
    , "| Level | Meaning |"
    , "| --- | --- |"
    , "| `some-true` | reproduced from an authority. **Not established here.** |"
    , "| `build` | constructed here and checked against an oracle by a test. Evidence, not proof. |"
    , "| `open` | measured and reported. **Never asserted.** |"
    , ""
    , "## Register"
    , ""
    , show (length rows) <> " IDs. Each is discharged by the tests tagged with it."
    ]
      ++ concatMap packageSection (nub (map rowPackage rows))
      ++ [ ""
         , "## Ledger"
         , ""
         , "Claims with no ID, and so no test: reproduced facts and measured quantities."
         , ""
         , "| Key | Level | Statement | Evidence |"
         , "| --- | --- | --- | --- |"
         ]
      ++ [ "| `" <> claimKey c <> "` | `" <> levelName (claimLevel c) <> "` | " <> cell (claimStatement c)
             <> " | " <> cell (claimEvidence c) <> cites (claimAuthorities c) <> " |"
         | c <- claims
         ]
      ++ ["", "## Authorities", ""]
      ++ ["- **" <> authKey a <> "**: " <> authCite a | a <- auths]
  where
    packageSection p =
      [ ""
      , "### " <> p
      , ""
      , "| ID | Level | Claim | Checked against |"
      , "| --- | --- | --- | --- |"
      ]
        ++ [ "| `" <> rowId r <> "` | `" <> levelName (rowLevel r) <> "` | " <> cell (rowClaim r)
               <> " | " <> cell (rowOracle r) <> cites (rowAuthorities r) <> " |"
           | r <- rows
           , rowPackage r == p
           ]
    cites [] = ""
    cites ks = " (" <> intercalate ", " ks <> ")"
    cell = concatMap (\ch -> if ch == '|' then "\\|" else [ch])
