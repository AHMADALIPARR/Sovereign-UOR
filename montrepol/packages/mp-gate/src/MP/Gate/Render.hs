-- | Render the model as CONFORMANCE.md.
module MP.Gate.Render
  ( render
  ) where

import MP.Gate.Model

render :: Model -> String
render m =
  unlines
    [ "# CONFORMANCE"
    , ""
    , "Generated from `model/` by `cabal run mp-gate -- write`. Do not edit."
    , ""
    , renderPackage "mp-check" m
    , renderPackage "mp-linalg" m
    , renderPackage "mp-lie" m
    , renderPackage "mp-seq" m
    , renderPackage "mp-analytic" m
    , renderPackage "mp-gate" m
    , "## Ledger"
    , ""
    , "Claims with no ID, and so no test: reproduced facts and measured quantities."
    , ""
    , "| Key | Level | Statement | Evidence |"
    , "| --- | --- | --- | --- |"
    , unlines ["| `" <> ledKey e <> "` | `" <> ledLevel e <> "` | " <> ledStatement e <> " | " <> ledEvidence e <> " |" | e <- modelLedger m]
    ]

renderPackage :: String -> Model -> String
renderPackage pkg m =
  unlines
    [ "## " <> pkg
    , ""
    , "| ID | Level | Claim | Checked against |"
    , "| --- | --- | --- | --- |"
    , unlines ["| `" <> rowId r <> "` | `" <> rowLevel r <> "` | " <> rowClaim r <> " | " <> rowOracle r <> " |" | r <- modelIds m, rowPackage r == pkg]
    ]
