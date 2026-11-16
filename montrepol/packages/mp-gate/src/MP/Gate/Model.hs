-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | The claim register, the ledger and the authorities, read from
-- @model/*.toml@.
module MP.Gate.Model
  ( Level (..)
  , levelName
  , Row (..)
  , Claim (..)
  , Authority (..)
  , Model (..)
  , readModel
  ) where

import MP.Gate.Toml

-- | The honesty levels (R2).
--
-- * 'SomeTrue': reproduced from an authority; not established here.
-- * 'Build': constructed here and checked against an oracle; evidence, not proof.
-- * 'Open': measured and reported, never asserted.
-- * 'Proved': machine-checked by Agda under @--safe@; the evidence names the
--   file and the lemmas. Trusts Agda's kernel.
-- * 'Refined': checked by Liquid Haskell; the evidence names a core source
--   file and the functions whose @{-\@ ... \@-}@ specs were checked. Trusts
--   Liquid Haskell and Z3, a larger base than 'Proved', so kept apart.
data Level = SomeTrue | Build | Open | Proved | Refined
  deriving (Eq, Show)

levelName :: Level -> String
levelName l = case l of
  SomeTrue -> "some-true"
  Build -> "build"
  Open -> "open"
  Proved -> "proved"
  Refined -> "refined"

parseLevel :: String -> Maybe Level
parseLevel s = case s of
  "some-true" -> Just SomeTrue
  "build" -> Just Build
  "open" -> Just Open
  "proved" -> Just Proved
  "refined" -> Just Refined
  _ -> Nothing

-- | A row of @model/ids.toml@: one conformance ID.
data Row = Row
  { rowId :: String
  , rowPackage :: String
  , rowLevel :: Level
  , rowClaim :: String
  , rowOracle :: String
  , rowAuthorities :: [String]
  }
  deriving (Eq, Show)

-- | A row of @model/ledger.toml@: a claim with no ID and so no test.
data Claim = Claim
  { claimKey :: String
  , claimLevel :: Level
  , claimStatement :: String
  , claimEvidence :: String
  , claimAuthorities :: [String]
  }
  deriving (Eq, Show)

data Authority = Authority {authKey :: String, authCite :: String}
  deriving (Eq, Show)

data Model = Model
  { modelRows :: [Row]
  , modelClaims :: [Claim]
  , modelAuthorities :: [Authority]
  }
  deriving (Eq, Show)

-- | Parse the three files, or say which one is malformed and how.
readModel :: String -> String -> String -> Either String Model
readModel ids ledger authorities = do
  idsDoc <- inFile "model/ids.toml" (parseToml ids)
  ledgerDoc <- inFile "model/ledger.toml" (parseToml ledger)
  authDoc <- inFile "model/authorities.toml" (parseToml authorities)
  rows <- inFile "model/ids.toml" (traverse row (tables "id" idsDoc))
  claims <- inFile "model/ledger.toml" (traverse claim (tables "claim" ledgerDoc))
  auths <- inFile "model/authorities.toml" (traverse authority (tables "authority" authDoc))
  pure (Model rows claims auths)
  where
    inFile f = either (\e -> Left (f <> ": " <> e)) Right
    tables name doc = maybe [] id (lookup name (docArrays doc))
    field k t = maybe (Left ("missing field " <> show k <> " in " <> show t)) Right (lookupString k t)
    level t = field "level" t >>= \s -> maybe (Left ("unknown level " <> show s)) Right (parseLevel s)
    row t =
      Row <$> field "id" t <*> field "package" t <*> level t <*> field "claim" t <*> field "oracle" t
        <*> pure (lookupStrings "authorities" t)
    claim t =
      Claim <$> field "key" t <*> level t <*> field "statement" t <*> field "evidence" t
        <*> pure (lookupStrings "authorities" t)
    authority t = Authority <$> field "key" t <*> field "cite" t
