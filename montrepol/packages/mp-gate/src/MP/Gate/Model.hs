-- | The model: the claim register the gate reads.
module MP.Gate.Model
  ( IdRow(..)
  , Authority(..)
  , Mutant(..)
  , LedgerEntry(..)
  , Model(..)
  , loadModel
  , readModel
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
  }
  deriving (Eq, Show)

data Model = Model
  { modelIds :: [IdRow]
  , modelAuthorities :: [Authority]
  , modelMutants :: [Mutant]
  , modelLedger :: [LedgerEntry]
  }
  deriving (Eq, Show)

-- | Alias expected by the CLI.
readModel :: String -> String -> String -> Either String Model
readModel idsSrc ledgerSrc authSrc = loadModel idsSrc authSrc "" ledgerSrc

loadModel :: String -> String -> String -> String -> Either String Model
loadModel idsSrc authSrc mutSrc ledSrc = do
  ids <- parseIds idsSrc
  auths <- parseAuths authSrc
  muts <- parseMuts mutSrc
  leds <- parseLeds ledSrc
  pure (Model ids auths muts leds)

parseIds :: String -> Either String [IdRow]
parseIds src = case parseToml src of
  Left e -> Left e
  Right (VTable tbl) -> Right [row | ("id", VTable r) <- tbl, Just row <- [mkId r]]
  _ -> Left "ids: not a table"

mkId :: [(String, Value)] -> Maybe IdRow
mkId r = IdRow <$> lookupS "id" r <*> lookupS "package" r <*> lookupS "level" r <*> lookupS "claim" r <*> lookupS "oracle" r <*> pure (lookupA "authorities" r)

parseAuths :: String -> Either String [Authority]
parseAuths src = case parseToml src of
  Left e -> Left e
  Right (VTable tbl) -> Right [Authority i t | ("authority", VTable r) <- tbl, Just i <- [lookupS "id" r], Just t <- [lookupS "title" r]]
  _ -> Left "auths: not a table"

parseMuts :: String -> Either String [Mutant]
parseMuts src = case parseToml src of
  Left e -> Left e
  Right (VTable tbl) -> Right [Mutant n p f o nw e | ("mutant", VTable r) <- tbl, Just n <- [lookupS "name" r], Just p <- [lookupS "package" r], Just f <- [lookupS "file" r], Just o <- [lookupS "old" r], Just nw <- [lookupS "new" r], let e = lookupA "expect" r]
  _ -> Left "muts: not a table"

parseLeds :: String -> Either String [LedgerEntry]
parseLeds src = case parseToml src of
  Left e -> Left e
  Right (VTable tbl) -> Right [LedgerEntry k l s e | ("entry", VTable r) <- tbl, Just k <- [lookupS "key" r], Just l <- [lookupS "level" r], Just s <- [lookupS "statement" r], Just e <- [lookupS "evidence" r]]
  _ -> Left "ledger: not a table"

lookupS :: String -> [(String, Value)] -> Maybe String
lookupS k r = case lookup k r of
  Just (VString s) -> Just s
  _ -> Nothing

lookupA :: String -> [(String, Value)] -> [String]
lookupA k r = case lookup k r of
  Just (VArray xs) -> [s | VString s <- xs]
  _ -> []
