-- SPDX-License-Identifier: AGPL-3.0-only
-- Also licensed under the SnapKitty Opaque License (LicenseRef-SnapKitty-Opaque-1.0); see README.md.
-- Copyright (C) 2026 Ahmad Parr

-- | A small TOML reader for the subset the model uses: top-level keys,
-- arrays of tables (@[[name]]@), basic strings with escapes, integers,
-- booleans, and one-line arrays of those. Anything else is a parse error
-- (GT-07).
module MP.Gate.Toml
  ( Value(..)
  , parseToml
  , tablesNamed
  , lookupString
  , lookupStrings
  ) where

import Data.Char (isAlphaNum, isDigit, isSpace)

data Value
  = VString String
  | VInt Integer
  | VBool Bool
  | VArray [Value]
  | VTable [(String, Value)]
  deriving (Eq, Show)

-- | A document is a table whose array-of-tables keys hold every @[[name]]@
-- section in order.
parseToml :: String -> Either String Value
parseToml src = VTable . finish <$> go (zip [1 :: Int ..] (lines src)) [] Nothing
  where
    -- acc: finished top-level pairs (reversed); cur: the open [[name]] section.
    go [] acc cur = Right (close acc cur)
    go ((n, raw) : rest) acc cur =
      let l = stripComment raw
       in case l of
            "" -> go rest acc cur
            ('[' : '[' : more) -> case span (/= ']') more of
              (name, "]]") | validKey (trim name) -> go rest (close acc cur) (Just (trim name, []))
              _ -> Left ("line " <> show n <> ": bad table header")
            ('[' : _) -> Left ("line " <> show n <> ": plain tables are not supported")
            _ -> do
              kv <- either (\e -> Left ("line " <> show n <> ": " <> e)) Right (parseKV l)
              case cur of
                Nothing -> go rest (kv : acc) Nothing
                Just (name, kvs) -> go rest acc (Just (name, kv : kvs))
    close acc Nothing = acc
    close acc (Just (name, kvs)) = (name, VArray [VTable (reverse kvs)]) : acc
    -- Merge repeated [[name]] sections into one array, in order.
    finish acc = merge (reverse acc)
    merge [] = []
    merge ((k, VArray xs) : rest) =
      let same = [ys | (k', VArray ys) <- rest, k' == k]
          others = [p | p@(k', _) <- rest, k' /= k]
       in (k, VArray (xs <> concat same)) : merge others
    merge (p : rest) = p : merge rest

tablesNamed :: String -> Value -> [[(String, Value)]]
tablesNamed name (VTable kvs) = [t | (k, VArray xs) <- kvs, k == name, VTable t <- xs]
tablesNamed _ _ = []

lookupString :: String -> [(String, Value)] -> Maybe String
lookupString k t = case lookup k t of
  Just (VString s) -> Just s
  _ -> Nothing

lookupStrings :: String -> [(String, Value)] -> [String]
lookupStrings k t = case lookup k t of
  Just (VArray xs) -> [s | VString s <- xs]
  _ -> []

validKey :: String -> Bool
validKey k = not (null k) && all (\c -> isAlphaNum c || c == '-' || c == '_') k

parseKV :: String -> Either String (String, Value)
parseKV l =
  case break (== '=') l of
    (k, '=' : v)
      | validKey (trim k) -> do
          (val, rest) <- parseValue (dropWhile isSpace v)
          if all isSpace rest then Right (trim k, val) else Left ("trailing text after value: " <> rest)
      | otherwise -> Left ("bad key " <> show (trim k))
    _ -> Left ("no = in " <> show l)

-- | Parse one value, returning what is left of the line.
parseValue :: String -> Either String (Value, String)
parseValue ('"' : s) = parseString s ""
parseValue ('[' : s) = parseArray (dropWhile isSpace s) []
parseValue s
  | Just r <- dropPrefix "true" s = Right (VBool True, r)
  | Just r <- dropPrefix "false" s = Right (VBool False, r)
parseValue s = case span (\c -> isDigit c || c == '-' || c == '+' || c == '_') s of
  (ds, r) | not (null ds), [(n, "")] <- reads (filter (/= '_') (dropWhile (== '+') ds)) -> Right (VInt n, r)
  _ -> Left ("bad value " <> show s)

parseString :: String -> String -> Either String (Value, String)
parseString [] _ = Left "unterminated string"
parseString ('"' : r) acc = Right (VString (reverse acc), r)
parseString ('\\' : c : r) acc = case c of
  'n' -> parseString r ('\n' : acc)
  't' -> parseString r ('\t' : acc)
  '"' -> parseString r ('"' : acc)
  '\\' -> parseString r ('\\' : acc)
  _ -> Left ("unsupported escape \\" <> [c])
parseString (c : r) acc = parseString r (c : acc)

parseArray :: String -> [Value] -> Either String (Value, String)
parseArray (']' : r) acc = Right (VArray (reverse acc), r)
parseArray s acc = do
  (v, r) <- parseValue s
  case dropWhile isSpace r of
    (',' : r') -> parseArray (dropWhile isSpace r') (v : acc)
    (']' : r') -> Right (VArray (reverse (v : acc)), r')
    _ -> Left "unterminated array"

dropPrefix :: String -> String -> Maybe String
dropPrefix [] s = Just s
dropPrefix (p : ps) (c : cs) | p == c = dropPrefix ps cs
dropPrefix _ _ = Nothing

-- | Remove a comment that starts outside a string, and surrounding space.
stripComment :: String -> String
stripComment = trim . go False
  where
    go _ [] = []
    go False ('#' : _) = []
    go inStr ('\\' : c : r) | inStr = '\\' : c : go inStr r
    go inStr ('"' : r) = '"' : go (not inStr) r
    go inStr (c : r) = c : go inStr r

trim :: String -> String
trim = dropWhileEnd' isSpace . dropWhile isSpace
  where
    dropWhileEnd' p = reverse . dropWhile p . reverse
