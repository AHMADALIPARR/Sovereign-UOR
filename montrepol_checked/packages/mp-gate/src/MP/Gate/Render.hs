-- SPDX-License-Identifier: AGPL-3.0-only
-- Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
-- Copyright (C) 2026 Ahmad Parr

-- | Render the model as CONFORMANCE.md.
module MP.Gate.Render
  ( render
  , renderConformance
  ) where

import Data.List (intercalate)
import MP.Gate.Model

-- | Alias used by the CLI.
renderConformance :: Model -> String
renderConformance = render

render :: Model -> String
render m =
  unlines $
    [ "# CONFORMANCE"
    , ""
    , "Generated from `model/` by `cabal run mp-gate -- write`. Do not edit."
    , ""
    ]
      ++ concatMap (renderPackage m) packageOrder
      ++ [ "## Ledger"
         , ""
         , "Claims with no ID, and so no test: reproduced facts and measured quantities."
         , ""
         , "| Key | Level | Statement | Evidence |"
         , "| --- | --- | --- | --- |"
         ]
      ++ ["| `" <> ledKey e <> "` | `" <> ledLevel e <> "` | " <> ledStatement e <> " | " <> ledEvidence e <> cites (ledAuthorities e) <> " |" | e <- modelLedger m]
  where
    packageOrder = ["mp-check", "mp-linalg", "mp-lie", "mp-seq", "mp-analytic", "mp-gate"]

renderPackage :: Model -> String -> [String]
renderPackage m pkg =
  [ "## " <> pkg
  , ""
  , "| ID | Level | Claim | Checked against |"
  , "| --- | --- | --- | --- |"
  ]
    ++ ["| `" <> rowId r <> "` | `" <> rowLevel r <> "` | " <> rowClaim r <> " | " <> rowOracle r <> cites (rowAuthorities r) <> " |" | r <- modelIds m, rowPackage r == pkg]
    ++ [""]

cites :: [String] -> String
cites [] = ""
cites as = " (" <> intercalate ", " as <> ")"
