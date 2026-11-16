-- SPDX-License-Identifier: AGPL-3.0-or-later

module Main (main) where

import Data.Ratio (denominator)
import qualified Data.Map.Strict as Map
import MP.Check
import MP.Hcalc.Smt
import MP.Lambda.Refine
import MP.Lambda.Simple hiding (Term)
import qualified MP.Lambda.Simple as L

main :: IO ()
main =
  runSuite "mp-lambda" $
    [ prop "LM-01" "generated terms have the type they were generated at" genClosed $ \(ty, t) ->
        typeOf [] t === Just ty
    , prop "LM-02" "progress: a closed well-typed term is a value or steps" genClosed $ \(_, t) ->
        allOf [assert ("stuck: " <> show u) (isValue u || step u /= Nothing) | u <- trace 200 t]
    , prop "LM-03" "preservation: every step keeps the type" genClosed $ \(ty, t) ->
        allOf [typeOf [] u === Just ty | u <- trace 200 t]
    , prop "LM-04" "evaluation of a closed well-typed term reaches a value" genClosed $ \(_, t) ->
        assert "did not reach a value within 10000 steps" (maybe False isValue (evaluate 10000 t))
    , prop "LM-05" "substitution preserves types, for open terms under binders" genSubstitution $ \(g, s, sTy, t, tTy) ->
        -- G, x:S |- t : T and G |- s : S give G |- t[x := s] : T. With G
        -- non-empty, s is open, and every binder in t it passes under must
        -- shift it.
        assert ("ill-typed: " <> show s) (typeOf g s == Just sTy)
          .&&. typeOf g (shift (-1) 0 (subst 0 (shift 1 0 s) t)) === Just tTy
    , unit "LM-06" "ill-typed terms are rejected" $
        allOf
          [ typeOf [] (App (Lit 1) (Lit 2)) === Nothing
          , typeOf [] (Add (BoolLit True) (Lit 1)) === Nothing
          , typeOf [] (Lam (TInt `TArr` TInt) (App (Var 0) (Var 0))) === Nothing
          , typeOf [] (If (BoolLit True) (Lit 1) (BoolLit False)) === Nothing
          , typeOf [] (Var 0) === Nothing
          ]
    , unit "LM-07" "abs, max, clamp, addNat and absTwice are accepted" $
        either (\(n, e) -> failWith (n <> ": " <> show e)) (const pass) (checkProgram accepted)
    ]
      ++ [ prop "LM-07" (name <> ": on inputs meeting its precondition, the output meets its postcondition") (listOfLength 4 (integerIn (-20) 20)) $
             \args -> soundRun name args
         | (name, _, _) <- accepted
         ]
      ++ [ unit "LM-08" (name <> " is rejected, with a counter-model that falsifies the VC") $
             case checkProgram (prelude ++ [(name, t, body)]) of
               Left (_, NotSubtype vc m) -> assert ("model " <> show m <> " satisfies the VC") (not (evalFormula m vc))
               other -> failWith ("expected a rejection with a counter-model, got " <> show other)
         | (name, t, body) <- rejected
         ]
      ++ [ unit "LM-09" "substitution into a type avoids capture" $
             either (\(n, e) -> failWith (n <> ": " <> show e)) (const pass) (checkProgram captureProgram)
         , unit "LM-09" "shadowing and underscore names are rejected as ill-formed" $
             allOf
               [ isIllFormed (checkTop [] (ELam "x" int (ELam "x" int (EVar "x"))) (RFun "a" int (RFun "b" int int)))
               , isIllFormed (checkTop [] (ELam "_v" int (EVar "_v")) (RFun "a" int int))
               ]
         , unit "LM-10" "valid over Z but not over Q: rejected, with a non-integral counter-model" $
             case checkTop [] succBody succType of
               Left (NotSubtype _ m) ->
                 assert "the counter-model is integral" (any ((/= 1) . denominator) (Map.elems (realModel m)))
               other -> failWith ("expected a rejection over Q, got " <> show other)
         ]

------------------------------------------------------------------------------
-- Simply typed terms

genTy :: Int -> Gen Ty
genTy d
  | d <= 0 = elements TInt [TBool]
  | otherwise = do
      k <- intIn 0 3
      if k == 0 then TArr <$> genTy (d - 1) <*> genTy (d - 1) else elements TInt [TBool]

genTermOf :: Int -> [Ty] -> Ty -> Gen L.Term
genTermOf d ctx ty = do
  let vars = [Var i | (i, t) <- zip [0 ..] ctx, t == ty]
  k <- intIn 0 (if d <= 0 then 1 else 6)
  case (k, vars) of
    (0, v : vs) -> elements v vs
    _ | d <= 0 -> base
    (2, _) -> do
      a <- genTy 1
      App <$> genTermOf (d - 1) ctx (TArr a ty) <*> genTermOf (d - 1) ctx a
    (3, _) -> If <$> genTermOf (d - 1) ctx TBool <*> genTermOf (d - 1) ctx ty <*> genTermOf (d - 1) ctx ty
    _ -> case ty of
      TInt -> Add <$> genTermOf (d - 1) ctx TInt <*> genTermOf (d - 1) ctx TInt
      TBool -> Leq <$> genTermOf (d - 1) ctx TInt <*> genTermOf (d - 1) ctx TInt
      TArr a b -> Lam a <$> genTermOf (d - 1) (a : ctx) b
  where
    base = case ty of
      TInt -> Lit <$> integerIn (-9) 9
      TBool -> BoolLit <$> boolG
      TArr a b -> Lam a <$> genTermOf 0 (a : ctx) b

genClosed :: Gen (Ty, L.Term)
genClosed = do
  ty <- genTy 2
  t <- genTermOf 4 [] ty
  pure (ty, t)

genSubstitution :: Gen ([Ty], L.Term, Ty, L.Term, Ty)
genSubstitution = do
  g <- intIn 1 3 >>= \n -> listOfLength n (genTy 1)
  sTy <- genTy 1
  s <- genTermOf 3 g sTy
  tTy <- genTy 1
  t <- genTermOf 3 (sTy : g) tTy
  pure (g, s, sTy, t, tTy)

trace :: Int -> L.Term -> [L.Term]
trace fuel t = t : if fuel <= 0 then [] else maybe [] (trace (fuel - 1)) (step t)

------------------------------------------------------------------------------
-- Refinement programs

int :: RType
int = RInt "v" FTrue

fv, fx, fy, flo, fhi, fa, fb :: Term
fv = TVar "v"
fx = TVar "x"
fy = TVar "y"
flo = TVar "lo"
fhi = TVar "hi"
fa = TVar "a"
fb = TVar "b"

num :: Integer -> Term
num = TConst . fromInteger

nat :: RType
nat = RInt "v" (FLe (num 0) fv)

absType, maxType, clampType, addNatType, absTwiceType :: RType
absType = RFun "x" int (RInt "v" (FAnd [FLe (num 0) fv, FLe fx fv]))
maxType = RFun "x" int (RFun "y" int (RInt "v" (FAnd [FLe fx fv, FLe fy fv, FOr [FEq fv fx, FEq fv fy]])))
clampType = RFun "lo" int (RFun "hi" (RInt "v" (FLe flo fv)) (RFun "x" int (RInt "v" (FAnd [FLe flo fv, FLe fv fhi]))))
addNatType = RFun "a" nat (RFun "b" nat (RInt "v" (FAnd [FLe fa fv, FLe fb fv])))
absTwiceType = RFun "x" int (RInt "v" (FLe (num 0) fv))

absBody, maxBody, clampBody, addNatBody, absTwiceBody :: Expr
absBody = ELam "x" int (EIf (CLt (EVar "x") (ENum 0)) (ESub (ENum 0) (EVar "x")) (EVar "x"))
maxBody = ELam "x" int (ELam "y" int (EIf (CLe (EVar "x") (EVar "y")) (EVar "y") (EVar "x")))
clampBody =
  ELam "lo" int $
    ELam "hi" (RInt "v" (FLe flo fv)) $
      ELam "x" int $
        EIf (CLt (EVar "x") (EVar "lo")) (EVar "lo") (EIf (CLt (EVar "hi") (EVar "x")) (EVar "hi") (EVar "x"))
addNatBody = ELam "a" nat (ELam "b" nat (EAdd (EVar "a") (EVar "b")))
absTwiceBody = ELam "x" int (ELet "y" (EApp (EVar "abs") "x") (EApp (EVar "abs") "y"))

prelude :: [(String, RType, Expr)]
prelude = [("abs", absType, absBody)]

accepted :: [(String, RType, Expr)]
accepted =
  prelude
    ++ [ ("max", maxType, maxBody)
       , ("clamp", clampType, clampBody)
       , ("addNat", addNatType, addNatBody)
       , ("absTwice", absTwiceType, absTwiceBody)
       ]

rejected :: [(String, RType, Expr)]
rejected =
  [ ("abs claimed >= 1", RFun "x" int (RInt "v" (FLe (num 1) fv)), absBody)
  , ("max claimed = x", RFun "x" int (RFun "y" int (RInt "v" (FEq fv fx))), maxBody)
  , ("clamp without hi >= lo", RFun "lo" int (RFun "hi" int (RFun "x" int (RInt "v" (FAnd [FLe flo fv, FLe fv fhi])))), clampBody')
  , ("addNat on all integers", RFun "a" int (RFun "b" int (RInt "v" (FAnd [FLe fa fv, FLe fb fv]))), addNatBody')
  ]
  where
    clampBody' =
      ELam "lo" int $
        ELam "hi" int $
          ELam "x" int $
            EIf (CLt (EVar "x") (EVar "lo")) (EVar "lo") (EIf (CLt (EVar "hi") (EVar "x")) (EVar "hi") (EVar "x"))
    addNatBody' = ELam "a" int (ELam "b" int (EAdd (EVar "a") (EVar "b")))

-- f returns its first argument. g passes its own argument named fy as f's
-- first argument, whose binder in the rest of f's type is also called fy.
captureProgram :: [(String, RType, Expr)]
captureProgram =
  [ ("f", RFun "x" int (RFun "y" int (RInt "v" (FEq fv fx))), ELam "x" int (ELam "y" int (EVar "x")))
  , ("g", RFun "y" int (RFun "z" int (RInt "v" (FEq fv fy))), ELam "y" int (ELam "z" int (ELet "h" (EApp (EVar "f") "y") (EApp (EVar "h") "z"))))
  ]

-- fy > fx ==> fy >= fx + 1 holds for integers only.
succType :: RType
succType = RFun "x" int (RFun "y" (RInt "v" (FLt fx fv)) (RInt "v" (FLe (fx `TAdd` num 1) fv)))

succBody :: Expr
succBody = ELam "x" int (ELam "y" (RInt "v" (FLt fx fv)) (EVar "y"))

isIllFormed :: Either RefineError () -> Result
isIllFormed r = case r of
  Left (IllFormed _) -> pass
  other -> failWith ("expected IllFormed, got " <> show other)

-- | Run an accepted definition on the first arguments that meet its
-- preconditions, and check its postcondition.
soundRun :: String -> [Integer] -> Result
soundRun name args = case [(t, body) | (n, t, body) <- accepted, n == name] of
  [(t, body)] -> go Map.empty t (run defs body) args
  _ -> failWith ("no definition " <> name)
  where
    defs = foldl (\env (n, _, body) -> maybe env (\val -> Map.insert n val env) (run env body)) Map.empty accepted
    go ints t val as = case (t, val, as) of
      (RFun p dom cod, Just (VFun f), n : rest)
        | satisfiesType ints n dom -> go (Map.insert p n ints) cod (f (VInt n)) rest
        | otherwise -> pass -- precondition not met: nothing is promised
      (RInt _ _, Just (VInt n), _) ->
        assert ("result " <> show n <> " for " <> show (Map.toList ints) <> " violates " <> show t) (satisfiesType ints n t)
      (RFun {}, _, []) -> pass
      _ -> failWith ("did not run: " <> name)
