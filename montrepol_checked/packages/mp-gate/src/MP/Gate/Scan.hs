-- | The source scanner. It finds test tags, deferral markers and partial
-- functions, ignoring comments and strings (R3, R4, R5).
--
-- Words the scanner looks for are assembled from halves in this file, so the
-- gate does not flag its own word lists.
module MP.Gate.Scan
  ( Tag
  , tagsIn
  , deferrals
  , partials
  , codeOnly
  ) where

import Data.Char (isAlphaNum)

type Tag = (String, String) -- id, file

-- | Tags: the first string literal after one of the test constructors
-- (unit, unitIO, prop, propN) used as a function, outside comments.
tagsIn :: String -> String -> [Tag]
tagsIn file src = [(i, file) | i <- go (blankComments src)]
  where
    go [] = []
    go ('\'' : '\\' : _ : '\'' : r) = go r
    go ('\'' : _ : '\'' : r) = go r
    go s@(c : cs)
      | c == '"' = go (skipString cs)
      | isIdentStart c =
          let (w, rest) = span isIdentChar s
           in if w `elem` constructors
                then case dropWhile (`elem` " \t\n") rest of
                  ('"' : more) -> let (lit, after) = break (== '"') more in lit : go (drop 1 after)
                  other -> go other
                else go rest
      | otherwise = go cs
    constructors = ["unit", "unitIO", "prop", "propN"]

-- | Deferral markers outside comments and strings, as whole words.
deferrals :: String -> String -> [String]
deferrals file src = [file <> ":" <> show n | (n, l) <- numbered (codeOnly src), any (`elem` markers) (wordsOf l)]
  where
    markers = ["TO" <> "DO", "FIX" <> "ME", "X" <> "XX", "HA" <> "CK", "st" <> "ub", "not_" <> "implemented"]

-- | Partial Prelude functions and operators outside comments and strings,
-- as whole identifiers (so primed or longer names do not match).
partials :: String -> String -> [String]
partials file src = [file <> ":" <> show n | (n, l) <- numbered (codeOnly src), hits l]
  where
    names = ["err" <> "or", "he" <> "ad", "fromJ" <> "ust", "maxi" <> "mum", "undef" <> "ined"]
    hits l = any (`elem` names) (wordsOf l) || ("!" <> "!") `elem` operatorsOf l

numbered :: String -> [(Int, String)]
numbered = zip [1 ..] . lines

-- | Identifiers in a line; a prime or digit continues an identifier.
wordsOf :: String -> [String]
wordsOf [] = []
wordsOf s@(c : cs)
  | isIdentStart c = let (w, rest) = span isIdentChar s in w : wordsOf rest
  | otherwise = wordsOf cs

-- | Maximal runs of operator symbols in a line.
operatorsOf :: String -> [String]
operatorsOf [] = []
operatorsOf s@(c : cs)
  | isOp c = let (o, rest) = span isOp s in o : operatorsOf rest
  | otherwise = operatorsOf cs
  where
    isOp x = x `elem` "!#$%&*+./<=>?@\\^|-~:"

isIdentStart :: Char -> Bool
isIdentStart c = isAlphaNum c || c == '_'

isIdentChar :: Char -> Bool
isIdentChar c = isAlphaNum c || c == '_' || c == '\''

-- | Replace comments by spaces, keeping line structure and string literals.
blankComments :: String -> String
blankComments = go 0
  where
    go :: Int -> String -> String
    go _ [] = []
    go 0 ('\'' : '\\' : c : '\'' : r) = '\'' : '\\' : c : '\'' : go 0 r
    go 0 ('\'' : c : '\'' : r) = '\'' : c : '\'' : go 0 r
    go 0 ('"' : r) = '"' : str r
    go d ('{' : '-' : r) = ' ' : ' ' : go (d + 1) r
    go d ('-' : '}' : r) | d > 0 = ' ' : ' ' : go (d - 1) r
    go 0 ('-' : '-' : r) | lineComment r = let (c, rest) = break (== '\n') r in map (const ' ') ("--" <> c) <> go 0 rest
    go d (c : r)
      | d > 0 = (if c == '\n' then '\n' else ' ') : go d r
      | otherwise = c : go d r
    str [] = []
    str ('\\' : c : r) = '\\' : c : str r
    str ('"' : r) = '"' : go 0 r
    str (c : r) = c : str r
    -- "-->" and similar are operators, not comments.
    lineComment r = case dropWhile (== '-') r of
      (c : _) -> not (c `elem` "!#$%&*+./<=>?@\\^|~:")
      [] -> True

-- | Source with comments and string literals blanked out.
codeOnly :: String -> String
codeOnly = go . blankComments
  where
    go [] = []
    go ('\'' : _ : '\'' : r) = ' ' : ' ' : ' ' : go r
    go ('"' : r) = '"' : str r
    go ('\'' : '\\' : _ : '\'' : r) = "    " <> go r
    go (c : r) = c : go r
    str [] = []
    str ('\\' : _ : r) = ' ' : ' ' : str r
    str ('"' : r) = '"' : go r
    str ('\n' : r) = '\n' : str r
    str (_ : r) = ' ' : str r


-- | Drop the rest of a string literal, up to and including its closing quote.
skipString :: String -> String
skipString [] = []
skipString ('\\' : _ : r) = skipString r
skipString ('"' : r) = r
skipString (_ : r) = skipString r
