-- SPDX-License-Identifier: AGPL-3.0-or-later
-- | The test harness every package uses.
--
-- A test carries a conformance ID. The gate reads those IDs out of the test
-- sources and requires a bijection with @model/ids.toml@ (R3), so the tag is
-- not decoration: it is how a claim is tied to the code that discharges it.
--
-- There is no shrinking. A failing case is reported with the seed and case
-- number that reproduce it, which is enough to debug and keeps the harness
-- small enough to read in one sitting.
module MP.Check
  ( -- * Generators
    Gen
  , runGen
  , integerIn
  , intIn
  , elements
  , listOfLength
  , listUpTo
  , boolG
  , rationalIn
    -- * Results
  , Result
  , pass
  , failWith
  , assert
  , (===)
  , (=/=)
  , allOf
  , (.&&.)
    -- * Tests
  , Test
  , unit
  , prop
  , propN
  , unitIO
  , runSuite
  , checkProperty
  ) where

import Control.Monad (ap, liftM, replicateM)
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.List (intercalate)
import Data.Ratio ((%))
import Data.Word (Word64)
import MP.Check.Random
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hSetEncoding, stdout, utf8)
import Text.Read (readMaybe)

------------------------------------------------------------------------------
-- Generators

newtype Gen a = Gen (Seed -> (a, Seed))

runGen :: Gen a -> Seed -> (a, Seed)
runGen (Gen f) = f

instance Functor Gen where fmap = liftM

instance Applicative Gen where
  pure x = Gen (\s -> (x, s))
  (<*>) = ap

instance Monad Gen where
  Gen f >>= k = Gen (\s -> let (a, s') = f s in runGen (k a) s')

-- | Uniform in the closed interval; an empty interval yields its lower bound.
integerIn :: Integer -> Integer -> Gen Integer
integerIn lo hi
  | hi <= lo = pure lo
  | otherwise = Gen (\s -> let (x, s') = boundedBelow (hi - lo + 1) s in (lo + x, s'))

intIn :: Int -> Int -> Gen Int
intIn lo hi = fromInteger <$> integerIn (toInteger lo) (toInteger hi)

boolG :: Gen Bool
boolG = (== 1) <$> integerIn 0 1

-- | Pick from a non-empty list given as head and tail, so it cannot be called
-- on an empty one.
elements :: a -> [a] -> Gen a
elements x xs = do
  i <- intIn 0 (length xs)
  pure (pick i (x : xs))
  where
    pick _ [] = x
    pick 0 (y : _) = y
    pick k (_ : ys) = pick (k - 1 :: Int) ys

listOfLength :: Int -> Gen a -> Gen [a]
listOfLength = replicateM

listUpTo :: Int -> Gen a -> Gen [a]
listUpTo n g = intIn 0 n >>= \k -> listOfLength k g

-- | A rational with numerator in the given range and denominator in [1, d].
rationalIn :: Integer -> Integer -> Integer -> Gen Rational
rationalIn lo hi d = do
  p <- integerIn lo hi
  q <- integerIn 1 (max 1 d)
  pure (p % q)

------------------------------------------------------------------------------
-- Results

-- | Either a pass or the list of reasons it failed.
newtype Result = Result [String]

instance Semigroup Result where Result a <> Result b = Result (a <> b)

instance Monoid Result where mempty = pass

pass :: Result
pass = Result []

failWith :: String -> Result
failWith msg = Result [msg]

assert :: String -> Bool -> Result
assert msg ok = if ok then pass else failWith msg

infix 4 ===, =/=
infixr 3 .&&.

-- | Conjunction of results. It binds looser than '===', so
-- @a === b .&&. c === d@ reads the way it looks; '<>' would not.
(.&&.) :: Result -> Result -> Result
(.&&.) = (<>)

(===) :: (Eq a, Show a) => a -> a -> Result
a === b = assert ("expected " <> show b <> ", got " <> show a) (a == b)

(=/=) :: (Eq a, Show a) => a -> a -> Result
a =/= b = assert ("expected a value other than " <> show b) (a /= b)

allOf :: [Result] -> Result
allOf = mconcat

------------------------------------------------------------------------------
-- Tests

data Body
  = Unit Result
  | UnitIO (IO Result)
  | forall a. Show a => Prop Int (Gen a) (a -> Result)

data Test = Test String String Body

-- | A deterministic check. The first argument is the conformance ID.
unit :: String -> String -> Result -> Test
unit i n r = Test i n (Unit r)

unitIO :: String -> String -> IO Result -> Test
unitIO i n r = Test i n (UnitIO r)

-- | A property over 200 generated cases.
prop :: Show a => String -> String -> Gen a -> (a -> Result) -> Test
prop i n = propN i n 200

propN :: Show a => String -> String -> Int -> Gen a -> (a -> Result) -> Test
propN i n k g p = Test i n (Prop k g p)

runOne :: Word64 -> Test -> IO (Maybe String)
runOne seed (Test i n body) = do
  outcome <- case body of
    Unit (Result []) -> pure Nothing
    Unit (Result es) -> pure (Just (intercalate "; " es))
    UnitIO act -> do
      Result es <- act
      pure (if null es then Nothing else Just (intercalate "; " es))
    Prop k g p -> pure (checkProperty k g p seed)
  putStrLn (maybe "  ok   " (const "  FAIL ") outcome <> "[" <> i <> "] " <> n)
  pure ((\e -> "[" <> i <> "] " <> n <> "\n      " <> e) <$> outcome)

-- | Run every test, print a line per test, exit non-zero if any failed.
-- Pass @--seed N@ to reproduce a reported failure.
runSuite :: String -> [Test] -> IO ()
runSuite name tests = do
  hSetEncoding stdout utf8 -- test names are UTF-8 whatever the locale says
  args <- getArgs
  let seed = case args of
        ["--seed", s] | Just v <- readMaybe s -> v
        _ -> 0x5eed
  putStrLn (name <> " (seed " <> show seed <> ")")
  failures <- newIORef []
  mapM_ (\t -> runOne seed t >>= maybe (pure ()) (\f -> modifyIORef' failures (f :))) tests
  fs <- readIORef failures
  if null fs
    then putStrLn ("  " <> show (length tests) <> " passed")
    else do
      putStrLn ("\n" <> show (length fs) <> " of " <> show (length tests) <> " failed:")
      mapM_ (putStrLn . ("  " <>)) (reverse fs)
      exitFailure

-- | Run a property. Returns Nothing on success, or the failing case.
checkProperty :: Show a => Int -> Gen a -> (a -> Result) -> Word64 -> Maybe String
checkProperty k g p seed0 = go 0 (mkSeed seed0)
  where
    go c s
      | c >= k = Nothing
      | otherwise =
          let (x, s') = runGen g s
           in case p x of
                Result [] -> go (c + 1) s'
                Result es -> Just ("case " <> show c <> ": " <> show x <> "\n      " <> intercalate "; " es)
