-- SPDX-License-Identifier: AGPL-3.0-or-later

module Main (main) where

import qualified Data.Map.Strict as Map
import MP.Check
import MP.Hcalc.Linear
import MP.Hcalc.Sat
import MP.Hcalc.Smt

main :: IO ()
main =
  runSuite
    "mp-hcalc"
    [ prop "HC-01" "DPLL agrees with brute force; models satisfy, refutations replay" genCnf $ \cs ->
        case solveSat cs of
          Satisfiable m -> assert "model does not satisfy" (satisfies m cs) .&&. bruteSat cs === True
          Unsatisfiable r -> assert "refutation does not replay" (checkRefutation cs r) .&&. bruteSat cs === False
    , unit "HC-02" "pigeonhole: 3 pigeons in 2 holes is refuted, and the refutation replays" $
        case solveSat pigeonhole of
          Unsatisfiable r -> assert "refutation does not replay" (checkRefutation pigeonhole r)
          Satisfiable _ -> failWith "claimed satisfiable"
    , prop "HC-02" "no refutation of a satisfiable CNF is accepted" genSatAndTree $ \(cs, r) ->
        assert "accepted a refutation of a satisfiable CNF" (not (checkRefutation cs r))
    , prop "HC-03" "Fourier-Motzkin: models satisfy, Farkas certificates check, grid points are never missed" genSystem $ \ks ->
        case solveLinear ks of
          Feasible m -> assert ("model " <> show m <> " fails") (all (holds m) ks)
          Infeasible lam ->
            assert "Farkas certificate does not check" (checkFarkas ks lam)
              .&&. assert "a grid point satisfies a system called infeasible" (not (any (\m -> all (holds m) ks) grid3))
    , prop "HC-04" "no Farkas certificate for a feasible system is accepted" genFeasibleAndLambda $ \(ks, lam) ->
        assert "accepted a certificate for a feasible system" (not (checkFarkas ks lam))
    , unit "HC-04" "negative multipliers are refused: (1, -1) on x <= 0, x - 1 <= 0 would sum to 1 <= 0" $
        let ks = [constraint [("x", 1)] 0 Le, constraint [("x", 1)] (-1) Le]
         in assert "accepted a negative multiplier" (not (checkFarkas ks (Map.fromList [(0, 1), (1, -1)])))
              .&&. assert "x = 0 does not satisfy the system" (all (holds (Map.fromList [("x", 0)])) ks)
    , prop "HC-05" "DPLL(T): models satisfy the formula, certificates check, grid points are never missed" genFormula $ \f ->
        case smt f of
          Sat m -> assert ("model " <> show m <> " does not satisfy") (evalFormula m f)
          Unsat cert ->
            assert "certificate does not check" (checkUnsat f cert)
              .&&. assert "a grid point satisfies a formula called unsatisfiable" (not (any (`evalFormula` f) gridModels))
    , unit "HC-06" "valid over Q: transitivity, antisymmetry, a bounded polytope" $
        allOf
          [ provedValid "x < y /\\ y < z ==> x < z" (FImp (FAnd [FLt x y, FLt y z]) (FLt x z))
          , provedValid "x <= y /\\ y <= x ==> x = y" (FImp (FAnd [FLe x y, FLe y x]) (FEq x y))
          , provedValid
              "2x + 3y <= 6 /\\ x >= 0 /\\ y >= 0 ==> x <= 3"
              (FImp (FAnd [FLe (TScale 2 x `TAdd` TScale 3 y) (c 6), FLe (c 0) x, FLe (c 0) y]) (FLe x (c 3)))
          , provedValid "p \\/ not p" (FOr [FProp "p", FNot (FProp "p")])
          ]
    , unit "HC-06" "x < y ==> x + 1 <= y is invalid over Q, with a checked counter-model" $
        case valid (FImp (FLt x y) (FLe (x `TAdd` c 1) y)) of
          Sat m -> assert "counter-model is not one" (not (evalFormula m (FImp (FLt x y) (FLe (x `TAdd` c 1) y))))
          Unsat _ -> failWith "claimed valid over the rationals"
    , prop "HC-07" "Tseitin is equisatisfiable with the propositional formula" genPropFormula $ \f ->
        let (cs, _) = tseitin f
            sat = case solveSat cs of
              Satisfiable _ -> True
              Unsatisfiable _ -> False
         in sat === any (\m -> evalFormula m f) propModels
    , prop "HC-08" "an unsatisfiability certificate is rejected for a satisfiable formula" genFormula $ \f ->
        case (smt f, smt (FAnd [f, FNot f])) of
          (Sat _, Unsat cert) -> assert "accepted a certificate for a satisfiable formula" (not (checkUnsat f cert))
          (Sat _, Sat _) -> failWith "f /\\ not f was satisfiable"
          (Unsat _, _) -> pass
    ]
  where
    x = TVar "x"
    y = TVar "y"
    z = TVar "z"
    c = TConst
    provedValid name f = case valid f of
      Unsat cert -> assert (name <> ": certificate does not check") (checkUnsat (FNot f) cert)
      Sat m -> failWith (name <> ": counter-model " <> show m)

------------------------------------------------------------------------------
-- Propositional

genCnf :: Gen [Clause]
genCnf = do
  n <- intIn 1 7
  m <- intIn 1 24
  listOfLength m (intIn 1 3 >>= \k -> listOfLength k (lit n))
  where
    lit n = do
      v <- intIn 1 n
      s <- boolG
      pure (if s then v else negate v)

bruteSat :: [Clause] -> Bool
bruteSat cs = any (`satisfies` cs) (assignments (variables cs))

assignments :: [Int] -> [Map.Map Int Bool]
assignments vs = map Map.fromList (mapM (\v -> [(v, False), (v, True)]) vs)

-- Pigeon i in hole j is variable 2(i-1) + j; every pigeon somewhere, no hole twice.
pigeonhole :: [Clause]
pigeonhole =
  [[v i 1, v i 2] | i <- [1 .. 3]]
    ++ [[negate (v i j), negate (v k j)] | j <- [1, 2], i <- [1 .. 3], k <- [i + 1 .. 3]]
  where
    v i j = 2 * (i - 1) + j

genSatAndTree :: Gen ([Clause], Refutation)
genSatAndTree = do
  cs <- genCnf
  r <- tree (4 :: Int) (length cs) (maximumVar cs)
  -- Only satisfiable CNFs: no refutation of one can be sound.
  pure (if bruteSat cs then cs else [[1], [1, 2]], r)
  where
    maximumVar cs = foldr max 1 (variables cs)
    tree d m n
      | d <= 0 = Conflict <$> intIn 0 (m - 1)
      | otherwise = do
          leaf <- intIn 0 2
          if leaf == 0 then Conflict <$> intIn 0 (m - 1) else Split <$> intIn 1 n <*> tree (d - 1) m n <*> tree (d - 1) m n

------------------------------------------------------------------------------
-- Linear arithmetic

genSystem :: Gen [Constraint]
genSystem = intIn 1 6 >>= \k -> listOfLength k genConstraint

genConstraint :: Gen Constraint
genConstraint = do
  cs <- mapM (\v -> (,) v . fromInteger <$> integerIn (-3) 3) ["x", "y", "z"]
  k <- fromInteger <$> integerIn (-6) 6
  r <- elements Le [Lt]
  pure (constraint cs k r)

-- Every point of {-4, -7/2, .., 4}^3.
grid3 :: [Map.Map String Rational]
grid3 = [Map.fromList [("x", a), ("y", b), ("z", d)] | a <- axis, b <- axis, d <- axis]

axis :: [Rational]
axis = [fromInteger k / 2 | k <- [-8 .. 8]]

genFeasibleAndLambda :: Gen ([Constraint], Map.Map Int Rational)
genFeasibleAndLambda = do
  ks <- genSystem
  -- Negative weights too: a checker that forgot the sign condition could
  -- otherwise be fooled by them.
  lam <- Map.fromList . zip [0 ..] <$> listOfLength (length ks) (rationalIn (-5) 5 3)
  -- Only systems with a grid model: no Farkas certificate for one can be sound.
  pure (if any (\m -> all (holds m) ks) grid3 then ks else [], lam)

------------------------------------------------------------------------------
-- Formulas

genTerm :: Gen Term
genTerm = do
  a <- integerIn (-2) 2
  b <- integerIn (-2) 2
  k <- integerIn (-3) 3
  pure (TScale (fromInteger a) (TVar "x") `TAdd` TScale (fromInteger b) (TVar "y") `TAdd` TConst (fromInteger k))

genAtom :: Gen Formula
genAtom = do
  kind <- intIn 0 4
  case kind of
    0 -> FLe <$> genTerm <*> genTerm
    1 -> FLt <$> genTerm <*> genTerm
    2 -> FEq <$> genTerm <*> genTerm
    3 -> FProp <$> elements "p" ["q"]
    _ -> elements FTrue [FFalse]

genFormulaWith :: Gen Formula -> Int -> Gen Formula
genFormulaWith atom d
  | d <= 0 = atom
  | otherwise = do
      kind <- intIn 0 5
      case kind of
        0 -> FNot <$> sub
        1 -> FAnd <$> (intIn 1 3 >>= \n -> listOfLength n sub)
        2 -> FOr <$> (intIn 1 3 >>= \n -> listOfLength n sub)
        3 -> FImp <$> sub <*> sub
        _ -> atom
  where
    sub = genFormulaWith atom (d - 1)

genFormula :: Gen Formula
genFormula = genFormulaWith genAtom 3

genPropFormula :: Gen Formula
genPropFormula = genFormulaWith (FProp <$> elements "p" ["q", "r"]) 4

gridModels :: [Model]
gridModels =
  [ Model (Map.fromList [("p", p), ("q", q)]) (Map.fromList [("x", a), ("y", b)])
  | p <- [False, True], q <- [False, True], a <- axis, b <- axis
  ]

propModels :: [Model]
propModels =
  [Model (Map.fromList (zip ["p", "q", "r"] bs)) Map.empty | bs <- mapM (const [False, True]) [1 :: Int, 2, 3]]
