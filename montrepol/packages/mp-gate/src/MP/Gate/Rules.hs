-- | The rules R1-R6.
module MP.Gate.Rules
  ( Violation
  , check
  ) where

import MP.Gate.Model
import MP.Gate.Scan

type Violation = String

check :: Model -> [(String, String)] -> [String] -> [String] -> [Violation]
check model tags sources cabals =
  r1 model ++ r2 model ++ r3 model tags ++ r4 sources ++ r5 sources cabals ++ r6 cabals

r1 :: Model -> [Violation]
r1 m =
  let ids = map rowId (modelIds m)
      dups = [i | i <- ids, length (filter (== i) ids) > 1]
   in ["R1: duplicate ID " <> i | i <- dups]

r2 :: Model -> [Violation]
r2 m =
  let badLevel = [rowId r | r <- modelIds m, rowLevel r `notElem` ["build", "some-true"]]
      noAuth = [rowId r | r <- modelIds m, rowLevel r == "some-true", null (rowAuthorities r)]
      unknown = [a | r <- modelIds m, a <- rowAuthorities r, a `notElem` map authId (modelAuthorities m)]
   in ["R2: bad level " <> i | i <- badLevel] ++ ["R2: some-true without authority " <> i | i <- noAuth] ++ ["R2: unknown authority " <> a | a <- unknown]

r3 :: Model -> [(String, String)] -> [Violation]
r3 m tags =
  let registered = map rowId (modelIds m)
      tagged = map fst tags
      untested = [i | i <- registered, i `notElem` tagged]
      unregistered = [t | t <- tagged, t `notElem` registered]
   in ["R3: untested ID " <> i | i <- untested] ++ ["R3: unregistered tag " <> t | t <- unregistered]

r4 :: [String] -> [Violation]
r4 srcs = ["R4: deferral " <> d | d <- concatMap (uncurry deferrals) (zip (map show [1 ..]) srcs)]

r5 :: [String] -> [String] -> [Violation]
r5 srcs cabs =
  let parts = ["R5: partial " <> p | p <- concatMap (uncurry partials) (zip (map show [1 ..]) srcs)]
      noWerror = ["R5: missing -Werror in " <> c | c <- cabs, not ("-Werror" `isInfixOf` c)]
   in parts ++ noWerror

r6 :: [String] -> [Violation]
r6 cabs = ["R6: package repository enabled"] -- placeholder; real check reads cabal.project

isInfixOf :: String -> String -> Bool
isInfixOf n h = any (n `isPrefixOf`) (tails h)
  where
    tails [] = [[]]
    tails xs@(_ : ys) = xs : tails ys
