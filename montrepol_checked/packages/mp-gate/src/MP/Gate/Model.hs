-- | The model: the claim register the gate reads.
module MP.Gate.Model
  ( IdRow(..)
  , Authority(..)
  , Mutant(..)
  , LedgerEntry(..)
  , Model(..)
  , loadModel
  , readModel
  , parseMutants
  ) where

import MP.Gate.Toml

data IdRow = IdRow
  { rowId :: String
  , rowPackage :: String
  , rowLevel :: String
  , rowClaim :: String
  , rowOracle :: String
  , rowAuthorities :: [String]
  }
  deriving (Eq, Show)

data Authority = Authority
  { authId :: String
  , authTitle :: String
  }
  deriving (Eq, Show)

data Mutant = Mutant
  { mutName :: String
  , mutPackage :: String
  , mutFile :: String
  , mutOld :: String
  , mutNew :: String
  , mutExpect :: [String]
  }
  deriving (Eq, Show)

data LedgerEntry = LedgerEntry
  { ledKey :: String
  , ledLevel :: String
  , ledStatement :: String
  , ledEvidence :: String
  , ledAuthorities :: [String]
  }
  deriving (Eq, Show)

data Model = Model
  { modelIds :: [IdRow]
  , modelAuthorities :: [Authority]
  , modelMutants :: [Mutant]
  , modelLedger :: [LedgerEntry]
  }
  deriving (Eq, Show)

-- | ids, ledger, authorities (the order the CLI reads them in). Mutants are
-- read separately by the mutant driver.
readModel :: String -> String -> String -> Either String Model
readModel idsSrc ledgerSrc authSrc = loadModel idsSrc authSrc "" ledgerSrc

loadModel :: String -> String -> String -> String -> Either String Model
loadModel idsSrc authSrc mutSrc ledSrc = do
  ids <- parseIds idsSrc
  auths <- parseAuths authSrc
  muts <- parseMutants mutSrc
  leds <- parseLeds ledSrc
  pure (Model ids auths muts leds)

parseIds :: String -> Either String [IdRow]
parseIds src = do
  doc <- prefix "ids" (parseToml src)
  traverse mkId (tablesNamed "id" doc)
  where
    mkId r =
      maybe (Left ("ids: entry missing a field: " <> show (lookupString "id" r))) Right $
        IdRow <$> lookupString "id" r <*> lookupString "package" r <*> lookupString "level" r
          <*> lookupString "claim" r <*> lookupString "oracle" r <*> pure (lookupStrings "authorities" r)

parseAuths :: String -> Either String [Authority]
parseAuths src = do
  doc <- prefix "authorities" (parseToml src)
  traverse mk (tablesNamed "authority" doc)
  where
    mk r = maybe (Left "authorities: entry missing id or title") Right (Authority <$> lookupString "id" r <*> lookupString "title" r)

parseMutants :: String -> Either String [Mutant]
parseMutants src = do
  doc <- prefix "mutants" (parseToml src)
  traverse mk (tablesNamed "mutant" doc)
  where
    mk r =
      maybe (Left "mutants: entry missing a field") Right $
        Mutant <$> lookupString "name" r <*> lookupString "package" r <*> lookupString "file" r
          <*> lookupString "old" r <*> lookupString "new" r <*> pure (lookupStrings "expect" r)

parseLeds :: String -> Either String [LedgerEntry]
parseLeds src = do
  doc <- prefix "ledger" (parseToml src)
  traverse mk (tablesNamed "entry" doc)
  where
    mk r =
      maybe (Left "ledger: entry missing a field") Right $
        LedgerEntry <$> lookupString "key" r <*> lookupString "level" r <*> lookupString "statement" r
          <*> lookupString "evidence" r <*> pure (lookupStrings "authorities" r)

prefix :: String -> Either String a -> Either String a
prefix name = either (\e -> Left (name <> ": " <> e)) Right
