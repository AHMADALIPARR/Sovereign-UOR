-- | A small TOML reader for the subset the model uses: tables, arrays of
-- tables, strings, integers, booleans, and arrays of strings. Anything else is
-- a parse error (GT-07).
module MP.Gate.Toml
  ( Value(..)
  , parseToml
  ) where

import Data.Char (isSpace)
import Data.List (isPrefixOf)

data Value
  = VString String
  | VInt Integer
  | VBool Bool
  | VArray [Value]
  | VTable [(String, Value)]
  deriving (Eq, Show)

parseToml :: String -> Either String Value
parseToml src = case go (lines src) [] of
  Left e -> Left e
  Right tbl -> Right (VTable tbl)

go :: [String] -> [(String, Value)] -> Either String [(String, Value)]
go [] acc = Right (reverse acc)
go (l : ls) acc
  | all isSpace l || "#" `isPrefixOf` dropWhile isSpace l = go ls acc
  | "[[" `isPrefixOf` dropWhile isSpace l =
      let name = takeWhile (/= ']') (drop 2 (dropWhile isSpace l))
          (body, rest) = span (not . isTable) ls
       in case parseTable body of
            Left e -> Left e
            Right t -> go rest ((name, VArray [VTable t]) : acc)
  | "[" `isPrefixOf` dropWhile isSpace l =
      let name = takeWhile (/= ']') (drop 1 (dropWhile isSpace l))
          (body, rest) = span (not . isTable) ls
       in case parseTable body of
            Left e -> Left e
            Right t -> go rest ((name, VTable t) : acc)
  | otherwise = case parseKV l of
      Left e -> Left e
      Right kv -> go ls (kv : acc)
  where
    isTable s = "[" `isPrefixOf` dropWhile isSpace s

parseTable :: [String] -> Either String [(String, Value)]
parseTable ls = go ls []
  where
    go [] acc = Right (reverse acc)
    go (l : rest) acc
      | all isSpace l || "#" `isPrefixOf` dropWhile isSpace l = go rest acc
      | otherwise = case parseKV l of
          Left e -> Left e
          Right kv -> go rest (kv : acc)

parseKV :: String -> Either String (String, Value)
parseKV l =
  case break (== '=') l of
    (k, '=' : v) ->
      let key = trim k
          val = trim v
       in case parseValue val of
            Left e -> Left e
            Right x -> Right (key, x)
    _ -> Left ("no = in " <> l)

parseValue :: String -> Either String Value
parseValue s
  | "\"" `isPrefixOf` s = Right (VString (takeWhile (/= '"') (drop 1 s)))
  | s == "true" = Right (VBool True)
  | s == "false" = Right (VBool False)
  | "[" `isPrefixOf` s = parseArray s
  | otherwise = case reads s of
      [(n, "")] -> Right (VInt n)
      _ -> Left ("bad value " <> s)

parseArray :: String -> Either String Value
parseArray s =
  let inner = takeWhile (/= ']') (drop 1 s)
      parts = split ',' inner
   in case mapM (parseValue . trim) parts of
        Left e -> Left e
        Right xs -> Right (VArray xs)

split :: Char -> String -> [String]
split _ [] = []
split c s = let (a, b) = break (== c) s in a : if null b then [] else split c (drop 1 b)

trim :: String -> String
trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse
