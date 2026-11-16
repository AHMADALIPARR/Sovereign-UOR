-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | Finite crystallographic root systems, from vectors to Weyl group orders.
--
-- Nothing about a root system is typed in by hand beyond its vectors. Simple
-- roots are extracted from a generic linear functional, the Cartan matrix is
-- computed from them, and the Weyl group order is computed from the Cartan
-- matrix by orbit–stabilizer. The tests then compare against the
-- classification tables, which are the authority, not an input.
--
-- Vectors are integral. Where the usual coordinates have halves (E8, F4) the
-- whole system is scaled by 2; every quantity used here is a ratio of inner
-- products, so the scale cancels.
module MP.RootSystem
  ( Vec
  , dot
  , reflect
  , axiomViolations
    -- * The classical and exceptional systems
  , typeA
  , typeB
  , typeD
  , typeG2
  , typeF4
  , typeE8
  , orthogonalSubsystem
    -- * Structure
  , positiveRoots
  , simpleRoots
  , cartanMatrix
  , weylOrder
  , weightOrbit
  ) where

import Data.List (nub, sortOn)
import qualified Data.Set as Set

type Vec = [Integer]

dot :: Vec -> Vec -> Integer
dot x y = sum (zipWith (*) x y)

-- | @2(b, a) / (a, a)@ when it is an integer, which is the crystallographic
-- condition.
cartanInteger :: Vec -> Vec -> Maybe Integer
cartanInteger b a =
  let num = 2 * dot b a
      den = dot a a
   in if den /= 0 && num `rem` den == 0 then Just (num `quot` den) else Nothing

-- | The reflection of @b@ in the hyperplane orthogonal to @a@.
reflect :: Vec -> Vec -> Maybe Vec
reflect a b = (\c -> zipWith (\bi ai -> bi - c * ai) b a) <$> cartanInteger b a

-- | Every way the input fails to be a reduced crystallographic root system.
-- Empty means it is one.
axiomViolations :: [Vec] -> [String]
axiomViolations rs =
  concat
    [ ["empty" | null rs]
    , ["contains the zero vector" | any (all (== 0)) rs]
    , ["contains a repeated vector" | length (nub rs) /= length rs]
    , [ "not crystallographic at " <> show (a, b)
      | a <- rs, b <- rs, cartanInteger b a == Nothing
      ]
    , [ "not closed: s_" <> show a <> " " <> show b
      | a <- rs, b <- rs, Just r <- [reflect a b], not (Set.member r set)
      ]
    , [ "not reduced: " <> show (a, b)
      | a <- rs, b <- rs, a /= b, a /= map negate b, parallel a b
      ]
    ]
  where
    set = Set.fromList rs
    parallel a b = dot a b * dot a b == dot a a * dot b b

------------------------------------------------------------------------------
-- Constructions

unit :: Int -> Int -> Integer -> Vec
unit n i c = [if k == i then c else 0 | k <- [0 .. n - 1]]

plus :: Vec -> Vec -> Vec
plus = zipWith (+)

-- | @e_i - e_j@ in @R^(n+1)@.
typeA :: Int -> [Vec]
typeA n = [plus (unit (n + 1) i 1) (unit (n + 1) j (-1)) | i <- [0 .. n], j <- [0 .. n], i /= j]

-- | @±e_i@ and @±e_i ± e_j@ in @R^n@.
typeB :: Int -> [Vec]
typeB n = [unit n i s | i <- [0 .. n - 1], s <- [1, -1]] ++ typeD n

-- | @±e_i ± e_j@, @i < j@, in @R^n@.
typeD :: Int -> [Vec]
typeD n =
  [ plus (unit n i s) (unit n j t)
  | i <- [0 .. n - 1], j <- [i + 1 .. n - 1], s <- [1, -1], t <- [1, -1]
  ]

-- | In the plane @x + y + z = 0@: short roots @e_i - e_j@ and long roots
-- @±(2e_i - e_j - e_k)@.
typeG2 :: [Vec]
typeG2 =
  typeA 2
    ++ [ map (* s) (plus (unit 3 i 2) (plus (unit 3 j (-1)) (unit 3 k (-1))))
       | (i, j, k) <- [(0, 1, 2), (1, 0, 2), (2, 0, 1)], s <- [1, -1]
       ]

-- | Scaled by 2: @±2e_i@, @±2e_i ± 2e_j@, and @(±1, ±1, ±1, ±1)@.
typeF4 :: [Vec]
typeF4 = map (map (* 2)) (typeB 4) ++ signs 4

-- | Scaled by 2: @±2e_i ± 2e_j@ (112) and @(±1, ..., ±1)@ with an even number
-- of minus signs (128).
typeE8 :: [Vec]
typeE8 = map (map (* 2)) (typeD 8) ++ filter (even . length . filter (< 0)) (signs 8)

signs :: Int -> [Vec]
signs n = mapM (const [1, -1]) [1 .. n]

-- | The roots orthogonal to every given vector. A subsystem cut out this way
-- is again a root system; E7 and E6 are obtained from E8 like this.
orthogonalSubsystem :: [Vec] -> [Vec] -> [Vec]
orthogonalSubsystem vs = filter (\r -> all ((== 0) . dot r) vs)

------------------------------------------------------------------------------
-- Positive and simple roots

-- | A functional @x -> sum x_i k^i@ that vanishes on no root, for the least
-- @k >= 2@ that works. 'Nothing' only if none up to 64 does, which would mean
-- the input was not a root system.
genericFunctional :: [Vec] -> Maybe (Vec -> Integer)
genericFunctional rs =
  case [f | k <- [2 .. 64], let f = functional k, all ((/= 0) . f) rs] of
    (f : _) -> Just f
    [] -> Nothing
  where
    functional k v = sum (zipWith (*) v (iterate (* k) 1))

positiveRoots :: [Vec] -> [Vec]
positiveRoots rs = maybe [] (\f -> filter ((> 0) . f) rs) (genericFunctional rs)

-- | Positive roots that are not the sum of two positive roots. Ordered by the
-- functional, so the result is deterministic.
simpleRoots :: [Vec] -> [Vec]
simpleRoots rs = case genericFunctional rs of
  Nothing -> []
  Just f ->
    let pos = filter ((> 0) . f) rs
        posSet = Set.fromList pos
        decomposable a = any (\b -> Set.member (zipWith (-) a b) posSet) pos
     in sortOn f (filter (not . decomposable) pos)

-- | @C_ij = 2(a_i, a_j) / (a_j, a_j)@. Integral for a crystallographic system.
cartanMatrix :: [Vec] -> [[Integer]]
cartanMatrix simple = [[maybe 0 id (cartanInteger ai aj) | aj <- simple] | ai <- simple]

------------------------------------------------------------------------------
-- Weyl group order

-- | The orbit of a weight, given in the basis of fundamental weights, under
-- the Weyl group of the Cartan matrix. In that basis the simple root @a_i@ is
-- row @i@ of the Cartan matrix, and @s_i(l) = l - l_i a_i@.
weightOrbit :: [[Integer]] -> [Integer] -> Set.Set [Integer]
weightOrbit c start = go (Set.singleton start) [start]
  where
    reflections l = [zipWith (\lj aij -> lj - li * aij) l row | (li, row) <- zip l c, li /= 0]
    go seen [] = seen
    go seen (l : rest) =
      let new = filter (`Set.notMember` seen) (nub (reflections l))
       in go (foldl' (flip Set.insert) seen new) (new ++ rest)

-- | @|W| = |W . w_k| * |W_k|@, where @w_k@ is a fundamental weight and @W_k@,
-- its stabilizer, is the parabolic subgroup generated by the other simple
-- reflections, i.e. the Weyl group of the Cartan matrix with node @k@ deleted.
--
-- Any @k@ is correct. A leaf of the Dynkin diagram with the smallest orbit is
-- chosen because it is cheap: for E8 the orbits are 240, 56, 27, 10, 8, 4, 3, 2.
weylOrder :: [[Integer]] -> Integer
weylOrder [] = 1
weylOrder c =
  let n = length c
      degree k = length [() | (j, v) <- zip [0 ..] (row k), j /= k, v /= 0]
      row k = concat (take 1 (drop k c))
      leaves = [k | k <- [0 .. n - 1], degree k <= 1]
      candidates = if null leaves then [0 .. n - 1] else leaves
      sized = [(Set.size (weightOrbit c (fundamental n k)), k) | k <- candidates]
      (orbitSize, k0) = foldl' min (maxBound, 0) sized
   in toInteger orbitSize * weylOrder (deleteNode k0 c)

fundamental :: Int -> Int -> [Integer]
fundamental n k = [if i == k then 1 else 0 | i <- [0 .. n - 1]]

deleteNode :: Int -> [[a]] -> [[a]]
deleteNode k = map dropK . dropK
  where
    dropK xs = [x | (i, x) <- zip [0 :: Int ..] xs, i /= k]
