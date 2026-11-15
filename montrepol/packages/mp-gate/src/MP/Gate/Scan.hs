-- | The source scanner. It finds test tags, deferral markers and partial
-- functions, ignoring comments and strings (R3, R4, R5).
module MP.Gate.Scan
  ( Tag
  , tagsIn
  , deferrals
  , partials
  ) where

import Data.Char (isAlphaNum)
import Data.List (isPrefixOf)

type Tag = (String, String) -- id, file

tagsIn :: String -> String -> [Tag]
tagsIn file src = [(id, file) | line <- lines src, Just id <- [tagOf line]]

tagOf :: String -> Maybe String
tagOf l
  | "prop " `isPrefixOf` dropWhile (== ' ') l || "unit " `isPrefixOf` dropWhile (== ' ') l || "propN " `isPrefixOf` dropWhile (== ' ') l =
      case words l of
        (_ : quoted : _) | length quoted > 2 && head quoted == '"' && last quoted == '"' -> Just (init (tail quoted))
        _ -> Nothing
  | otherwise = Nothing

deferrals :: String -> String -> [String]
deferrals file src = [file <> ":" <> show n | (n, line) <- zip [1 ..] (lines src), hasDeferral line]

hasDeferral :: String -> Bool
hasDeferral l = any (`isInfixOf` stripCommentsAndStrings l) markers
  where
    markers = ["TODO", "FIXME", "XXX", "HACK", "stub", "not implemented"]

partials :: String -> String -> [String]
partials file src = [file <> ":" <> show n | (n, line) <- zip [1 ..] (lines src), hasPartial line]

hasPartial :: String -> Bool
hasPartial l = any (`isInfixOf` stripCommentsAndStrings l) partialNames
  where
    partialNames = ["error", "head", "fromJust", "maximum", "!!", "undefined"]

stripCommentsAndStrings :: String -> String
stripCommentsAndStrings = go False False
  where
    go _ _ [] = []
    go inStr inCom (c : cs)
      | inCom = if c == '\n' then c : go False False cs else go False True cs
      | inStr = if c == '"' then go False False cs else go True False cs
      | c == '"' = go True False cs
      | c == '-' && take 1 cs == "-" = go False True cs
      | otherwise = c : go False False cs

isInfixOf :: String -> String -> Bool
isInfixOf needle hay = any (needle `isPrefixOf`) (tails hay)
  where
    tails [] = [[]]
    tails xs@(_ : ys) = xs : tails ys
