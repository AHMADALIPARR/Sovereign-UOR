{-# LANGUAGE DataKinds #-}

module Main (main) where

import Data.Proxy (Proxy (..))
import Data.Ratio ((%))
import GHC.TypeNats (KnownNat)
import MP.Algebra
import MP.Check
import MP.Matrix
import MP.Participation
import Numeric.Natural (Natural)

main :: IO ()
main =
  runSuite
    "mp-linalg"
    [ prop "LA-01" "semiring axioms hold for Integer" (triple (integerIn (-50) 50)) semiringLaws
    , prop "LA-01" "semiring axioms hold for Rational" (triple (rationalIn (-20) 20 9)) semiringLaws
    , prop "LA-01" "semiring axioms hold for GF2" (triple gf2) semiringLaws
    , prop "LA-01" "semiring axioms hold for MinPlus" (triple minPlus) semiringLaws
    , prop "LA-02" "multiplication is associative, distributive, unital" genAssoc assocLaws
    , propN "LA-03" "Strassen equals the definition over Integer" 120 (genPair (integerIn (-9) 9) 20) strassenAgrees
    , propN "LA-03" "Strassen equals the definition over Rational" 60 (genPair (rationalIn (-5) 5 4) 12) strassenAgrees
    , propN "LA-03" "Strassen equals the definition over GF2" 120 (genPair gf2 20) strassenAgrees
    , prop "LA-04" "Bareiss equals the Leibniz expansion over Integer" (genSquare 6 (integerIn (-20) 20)) bareissAgrees
    , prop "LA-04" "Bareiss equals the Leibniz expansion over GF2" (genSquare 6 gf2) bareissAgrees
    , unit "LA-04" "Bareiss on a matrix needing a row swap" $
        withSquare [[0, 1, 2], [3, 0, 4], [5, 6, 0 :: Integer]] (\a -> det a === 56 .&&. detLeibniz a === 56)
    , prop "LA-05" "det is multiplicative and transpose-invariant" genDetPair detLaws
    , prop "LA-06" "inverse exists exactly when det /= 0, and inverts" (genSquare 5 (rationalIn (-3) 3 2)) inverseLaws
    , prop "LA-06" "rank A = rank A^T, and rank = n exactly when det /= 0" (genSquare 5 (integerIn (-2) 2)) rankLaws
    , propN "LA-07" "min-plus matrix powers compute shortest paths" 150 genGraph shortestPaths
    , prop "LA-08" "Kish k_eff is the participation ratio of diag(w)" (listUpTo 8 (integerIn 0 1000)) kishIsPR
    , unit "LA-08" "Kish k_eff of [2^32, 2^32] is exactly 2 (no saturation)" $
        let w = [2 ^ (32 :: Int), 2 ^ (32 :: Int)]
         in kishEffective w === Just 2
              .&&. assert "accepted k_eff >= 3" (not (kishAtLeast 3 w))
              .&&. assert "rejected k_eff >= 2" (kishAtLeast 2 w)
    , prop "LA-09" "1 <= PR(A^T A) <= rank(A^T A)" (genRect 6 6 (integerIn (-4) 4)) prBounds
    , prop "LA-10" "2x2 symmetric: tr(G^2) = tr^2 - 2 det, and PR = 2 iff G = cI" genSym2 sym2Laws
    ]

------------------------------------------------------------------------------
-- Generators

gf2 :: Gen GF2
gf2 = GF2 <$> boolG

minPlus :: Gen MinPlus
minPlus = do
  inf <- intIn 0 4
  v <- integerIn 0 30
  pure (MinPlus (if inf == 0 then Nothing else Just v))

triple :: Gen a -> Gen (a, a, a)
triple g = (,,) <$> g <*> g <*> g

grid :: Int -> Int -> Gen a -> Gen [[a]]
grid r c g = listOfLength r (listOfLength c g)

genRect :: Int -> Int -> Gen a -> Gen [[a]]
genRect mr mc g = do
  r <- intIn 1 mr
  c <- intIn 1 mc
  grid r c g

genSquare :: Int -> Gen a -> Gen [[a]]
genSquare mn g = intIn 1 mn >>= \n -> grid n n g

genPair :: Gen a -> Int -> Gen ([[a]], [[a]], Int)
genPair g mx = do
  r <- intIn 1 mx
  k <- intIn 1 mx
  c <- intIn 1 mx
  cutoff <- elements 1 [2, 4]
  (,,) <$> grid r k g <*> grid k c g <*> pure cutoff

genAssoc :: Gen ([[Integer]], [[Integer]], [[Integer]], [[Integer]])
genAssoc = do
  p <- intIn 1 6
  q <- intIn 1 6
  r <- intIn 1 6
  s <- intIn 1 6
  let e = integerIn (-9) 9
  (,,,) <$> grid p q e <*> grid q r e <*> grid r s e <*> grid q r e

genDetPair :: Gen ([[Integer]], [[Integer]])
genDetPair = do
  n <- intIn 1 6
  (,) <$> grid n n (integerIn (-9) 9) <*> grid n n (integerIn (-9) 9)

-- | A weighted digraph as an adjacency matrix; Nothing is "no edge".
genGraph :: Gen [[Maybe Integer]]
genGraph = do
  n <- intIn 1 7
  grid n n $ do
    e <- intIn 0 2
    w <- integerIn 0 20
    pure (if e == 0 then Nothing else Just w)

genSym2 :: Gen (Integer, Integer, Integer)
genSym2 = (,,) <$> integerIn (-6) 6 <*> integerIn (-6) 6 <*> integerIn (-6) 6

------------------------------------------------------------------------------
-- Bringing runtime shapes into the type

withSquare :: forall a. [[a]] -> (forall n. KnownNat n => Matrix n n a -> Result) -> Result
withSquare xss k = withSize (fromIntegral (length xss)) $ \(_ :: Proxy n) ->
  maybe (failWith "not square") k (fromLists xss :: Maybe (Matrix n n a))

withRect :: forall a. [[a]] -> (forall m n. (KnownNat m, KnownNat n) => Matrix m n a -> Result) -> Result
withRect xss k =
  withSize (fromIntegral (length xss)) $ \(_ :: Proxy m) ->
    withSize (fromIntegral (maybe 0 length (firstRow xss))) $ \(_ :: Proxy n) ->
      maybe (failWith "ragged") k (fromLists xss :: Maybe (Matrix m n a))
  where
    firstRow (r : _) = Just r
    firstRow [] = Nothing

------------------------------------------------------------------------------
-- Properties

semiringLaws :: (Semiring a, Eq a, Show a) => (a, a, a) -> Result
semiringLaws (a, b, c) =
  allOf
    [ (a .+. b) .+. c === a .+. (b .+. c)
    , a .+. b === b .+. a
    , a .+. zero === a
    , (a .*. b) .*. c === a .*. (b .*. c)
    , a .*. one === a
    , one .*. a === a
    , a .*. (b .+. c) === (a .*. b) .+. (a .*. c)
    , (a .+. b) .*. c === (a .*. c) .+. (b .*. c)
    , a .*. zero === zero
    , zero .*. a === zero
    ]

assocLaws :: ([[Integer]], [[Integer]], [[Integer]], [[Integer]]) -> Result
assocLaws (xa, xb, xc, xb') =
  withRect xa $ \(a :: Matrix p q Integer) ->
    withRect xc $ \(c :: Matrix r s Integer) ->
      case (fromLists xb :: Maybe (Matrix q r Integer), fromLists xb' :: Maybe (Matrix q r Integer)) of
        (Just b, Just b') ->
          allOf
            [ mul (mul a b) c === mul a (mul b c)
            , mul a (add b b') === add (mul a b) (mul a b')
            , mul identity a === a
            , mul a identity === a
            ]
        _ -> failWith "inner dimensions did not line up"

strassenAgrees :: forall a. (Ring a, Eq a, Show a) => ([[a]], [[a]], Int) -> Result
strassenAgrees (xa, xb, cutoff) =
  withRect xa $ \(a :: Matrix m k a) ->
    withSize (fromIntegral (maybe 0 length (case xb of r : _ -> Just r; [] -> Nothing))) $ \(_ :: Proxy n) ->
      case fromLists xb :: Maybe (Matrix k n a) of
        Just b -> mulStrassen cutoff a b === mul a b
        Nothing -> failWith "inner dimensions did not line up"

bareissAgrees :: (Domain a, Eq a, Show a) => [[a]] -> Result
bareissAgrees xs = withSquare xs (\a -> det a === detLeibniz a)

detLaws :: ([[Integer]], [[Integer]]) -> Result
detLaws (xa, xb) =
  withSquare xa $ \(a :: Matrix n n Integer) ->
    case fromLists xb :: Maybe (Matrix n n Integer) of
      Just b -> det (mul a b) === det a * det b .&&. det (transpose a) === det a
      Nothing -> failWith "sizes differ"

inverseLaws :: [[Rational]] -> Result
inverseLaws xs = withSquare xs $ \a -> case inverse a of
  Nothing -> det a === 0
  Just ai -> allOf [det a =/= 0, mul a ai === identity, mul ai a === identity]

rankLaws :: [[Integer]] -> Result
rankLaws xs = withSquare (map (map fromInteger) xs) $ \(a :: Matrix n n Rational) ->
  rank a === rank (transpose a) .&&. (rank a == rows a) === (det a /= 0)

shortestPaths :: [[Maybe Integer]] -> Result
shortestPaths adj = withSquare (map (map MinPlus) adj) $ \a ->
  let n = rows a
      withLoops = add identity a -- distance 0 from a vertex to itself
      viaPowers = power withLoops (fromIntegral (max 0 (n - 1)))
   in map (map (\(MinPlus d) -> d)) (toLists viaPowers) === floydWarshall adj

-- | Floyd–Warshall written independently of the matrix code.
floydWarshall :: [[Maybe Integer]] -> [[Maybe Integer]]
floydWarshall adj = foldl relax start [0 .. n - 1]
  where
    n = length adj
    start = [[if i == j then Just 0 else w | (j, w) <- zip [0 ..] row] | (i, row) <- zip [0 :: Int ..] adj]
    relax d k =
      [ [best (cell d i j) ((+) <$> cell d i k <*> cell d k j) | j <- [0 .. n - 1]]
      | i <- [0 .. n - 1]
      ]
    cell d i j = case drop j <$> safeIx i d of
      Just (v : _) -> v
      _ -> Nothing
    safeIx i d = case drop i d of
      (r : _) -> Just r
      [] -> Nothing
    best Nothing y = y
    best x Nothing = x
    best (Just x) (Just y) = Just (min x y)

kishIsPR :: [Integer] -> Result
kishIsPR ws0 =
  let ws = map fromInteger ws0 :: [Natural]
      nonZero = length (filter (/= 0) ws)
   in withSize (fromIntegral (length ws)) $ \(_ :: Proxy n) ->
        let d = diagonal (\i -> fromIntegral (sum (take 1 (drop i ws)))) :: Matrix n n Rational
         in case kishEffective ws of
              Nothing -> assert "zero weights but PR defined" (participationRatio d == Nothing)
              Just k ->
                allOf
                  [ participationRatio d === Just k
                  , assert "k_eff < 1" (k >= 1)
                  , assert "k_eff exceeds the number of non-zero weights" (k <= fromIntegral nonZero)
                  ]

prBounds :: [[Integer]] -> Result
prBounds xs = withRect (map (map fromInteger) xs) $ \(a :: Matrix m n Rational) ->
  let g = mul (transpose a) a
   in case participationRatio g of
        Nothing -> assert "PR undefined but A /= 0" (all (all (== 0)) xs)
        Just pr ->
          allOf
            [ assert ("PR < 1: " <> show pr) (pr >= 1)
            , assert ("PR > rank: " <> show pr) (pr <= fromIntegral (rank g))
            , frobeniusSq g === trace (mul g g)
            ]

sym2Laws :: (Integer, Integer, Integer) -> Result
sym2Laws (p, q, r) =
  -- G = B^T B for B = [[p, q], [0, r]] is positive semi-definite.
  withSquare [[p % 1, q % 1], [0, r % 1]] $ \b ->
    let g = mul (transpose b) b
        t = trace g
        scalar = case toLists g of
          [[g11, g12], [g21, g22]] -> g11 == g22 && g12 == 0 && g21 == 0
          _ -> False
     in allOf
          [ trace (mul g g) === t * t - 2 * det g
          , case participationRatio g of
              Nothing -> pass
              Just pr ->
                assert "PR outside [1, 2]" (pr >= 1 && pr <= 2)
                  .&&. (pr == 2) === scalar
          ]
