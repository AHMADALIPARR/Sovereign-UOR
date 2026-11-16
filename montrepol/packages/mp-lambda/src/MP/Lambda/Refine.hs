-- SPDX-License-Identifier: AGPL-3.0-or-later

-- | Refinement types over the lambda calculus, checked by Hcalc.
--
-- A refinement type @{v : Int | p}@ is the integers satisfying @p@, a formula
-- of linear arithmetic over @v@ and the integer variables in scope. Checking
-- is bidirectional, as in Liquid Haskell but without inference: lambdas and
-- top-level definitions carry their types. Each subtyping step
-- @G |- {v | p} <: {v | q}@ becomes the verification condition
-- @[G] /\ p ==> q@, which Hcalc decides.
--
-- Hcalc's answers are not trusted: a VC is accepted only when its
-- unsatisfiability certificate checks ('checkUnsat'), and a rejection
-- reports Hcalc's counter-model, which the tests check falsifies the VC.
--
-- Hcalc decides over the rationals. A VC valid over the rationals is valid
-- over the integers, so acceptance is sound for integer programs; the
-- converse fails, so some correct integer programs are rejected. The tests
-- include one.
module MP.Lambda.Refine
  ( RType (..)
  , Cmp (..)
  , Expr (..)
  , RefineError (..)
  , checkProgram
  , checkTop
  , Value (..)
  , run
  , satisfiesType
  ) where

import qualified Data.Map.Strict as Map
import MP.Hcalc.Smt

-- | @RInt v p@ is @{v : Int | p}@; @RFun x a b@ is @(x : a) -> b@, where @b@
-- may mention @x@.
data RType = RInt String Formula | RFun String RType RType
  deriving (Eq, Show)

data Cmp = CLe Expr Expr | CLt Expr Expr | CEq Expr Expr
  deriving (Eq, Show)

-- | Applications take a variable (A-normal form): name an argument with a
-- let first. That keeps every substitution into a refinement a variable for
-- a variable.
data Expr
  = EVar String
  | ENum Integer
  | EAdd Expr Expr
  | ESub Expr Expr
  | EMul Integer Expr
  | EIf Cmp Expr Expr
  | ELet String Expr Expr
  | ELam String RType Expr
  | EApp Expr String
  | EAnn Expr RType
  deriving (Eq, Show)

data RefineError
  = -- | The VC, and a model of its negation: a counterexample.
    NotSubtype Formula Model
  | -- | Hcalc said valid, but its certificate did not check.
    BadCertificate Formula
  | IllFormed String
  deriving (Eq, Show)

data Env = Env {bindings :: [(String, RType)], guards :: [Formula]}

------------------------------------------------------------------------------
-- Formulas

substTerm :: String -> Term -> Term -> Term
substTerm x s t = case t of
  TVar y -> if y == x then s else t
  TConst _ -> t
  TAdd a b -> TAdd (substTerm x s a) (substTerm x s b)
  TSub a b -> TSub (substTerm x s a) (substTerm x s b)
  TScale k a -> TScale k (substTerm x s a)

substF :: String -> Term -> Formula -> Formula
substF x s f = case f of
  FLe a b -> FLe (sub a) (sub b)
  FLt a b -> FLt (sub a) (sub b)
  FEq a b -> FEq (sub a) (sub b)
  FNot g -> FNot (substF x s g)
  FAnd gs -> FAnd (map (substF x s) gs)
  FOr gs -> FOr (map (substF x s) gs)
  FImp a b -> FImp (substF x s a) (substF x s b)
  _ -> f
  where
    sub = substTerm x s

-- | @substType x y t@ replaces the variable @x@ by the variable @y@ in @t@,
-- capture-avoiding: a binder named @y@ is renamed first, so that the
-- substituted @y@ is not captured by it.
substType :: String -> String -> RType -> RType
substType x y t = case t of
  RInt v p
    | v == x -> t
    | v == y -> let v' = freshFrom v t in RInt v' (substF x (TVar y) (substF v (TVar v') p))
    | otherwise -> RInt v (substF x (TVar y) p)
  RFun z a b
    | z == x -> RFun z (substType x y a) b
    | z == y -> let z' = freshFrom z t in RFun z' (substType x y a) (substType x y (substType z z' b))
    | otherwise -> RFun z (substType x y a) (substType x y b)
  where
    -- A name not occurring anywhere in the type, nor equal to x or y.
    freshFrom base ty =
      case [n | k <- [1 :: Int ..], let n = base <> replicate k '\'', n /= x, n /= y, not (occurs n ty)] of
        (n : _) -> n
        [] -> base

occurs :: String -> RType -> Bool
occurs n t = case t of
  RInt v p -> v == n || n `elem` formulaVars p
  RFun z a b -> z == n || occurs n a || occurs n b

formulaVars :: Formula -> [String]
formulaVars f = case f of
  FLe a b -> termVars a ++ termVars b
  FLt a b -> termVars a ++ termVars b
  FEq a b -> termVars a ++ termVars b
  FNot g -> formulaVars g
  FAnd gs -> concatMap formulaVars gs
  FOr gs -> concatMap formulaVars gs
  FImp a b -> formulaVars a ++ formulaVars b
  _ -> []
  where
    termVars t = case t of
      TVar v -> [v]
      TConst _ -> []
      TAdd a b -> termVars a ++ termVars b
      TSub a b -> termVars a ++ termVars b
      TScale _ a -> termVars a

-- | The facts the environment contributes to a VC: each integer binder's
-- refinement, about that binder, and every branch condition taken.
embed :: Env -> [Formula]
embed env = [substF v (TVar x) p | (x, RInt v p) <- bindings env] ++ guards env

-- | Reserved for the value a refinement talks about; user names cannot
-- start with an underscore.
nu :: String
nu = "_v"

------------------------------------------------------------------------------
-- Checking

valid' :: Formula -> Either RefineError ()
valid' vc = case valid vc of
  Unsat cert
    | checkUnsat (FNot vc) cert -> Right ()
    | otherwise -> Left (BadCertificate vc)
  Sat m -> Left (NotSubtype vc m)

subtype :: Env -> RType -> RType -> Either RefineError ()
subtype env (RInt v p) (RInt w q) =
  valid' (FImp (FAnd (embed env ++ [substF v (TVar nu) p])) (substF w (TVar nu) q))
subtype env (RFun x a1 b1) (RFun y a2 b2) = do
  subtype env a2 a1
  subtype env {bindings = (x, a2) : bindings env} b1 (substType y x b2)
subtype _ a b = Left (IllFormed ("shapes differ: " <> show a <> " and " <> show b))

pureTerm :: Env -> Expr -> Either RefineError Term
pureTerm env e = case e of
  EVar x -> case lookup x (bindings env) of
    Just (RInt _ _) -> Right (TVar x)
    _ -> Left (IllFormed (x <> " is not an integer in scope"))
  ENum n -> Right (TConst (fromInteger n))
  EAdd a b -> TAdd <$> pureTerm env a <*> pureTerm env b
  ESub a b -> TSub <$> pureTerm env a <*> pureTerm env b
  EMul k a -> TScale (fromInteger k) <$> pureTerm env a
  _ -> Left (IllFormed ("not a linear integer expression: " <> show e))

condition :: Env -> Cmp -> Either RefineError Formula
condition env c = case c of
  CLe a b -> FLe <$> pureTerm env a <*> pureTerm env b
  CLt a b -> FLt <$> pureTerm env a <*> pureTerm env b
  CEq a b -> FEq <$> pureTerm env a <*> pureTerm env b

synth :: Env -> Expr -> Either RefineError RType
synth env e = case e of
  EVar x -> case lookup x (bindings env) of
    Just (RInt _ _) -> Right (RInt nu (FEq (TVar nu) (TVar x)))
    Just t -> Right t
    Nothing -> Left (IllFormed (x <> " is not in scope"))
  EApp f x -> do
    tf <- synth env f
    case tf of
      RFun y a b -> do
        tx <- synth env (EVar x)
        subtype env tx a
        Right (substType y x b)
      _ -> Left (IllFormed ("applying a non-function: " <> show f))
  EAnn body t -> check env body t >> Right t
  _ -> (\t -> RInt nu (FEq (TVar nu) t)) <$> pureTerm env e

check :: Env -> Expr -> RType -> Either RefineError ()
check env e t = case (e, t) of
  (ELam x a body, RFun y a' b) -> do
    fresh x
    subtype env a' a
    check env {bindings = (x, a) : bindings env} body (substType y x b)
  (EIf c a b, _) -> do
    g <- condition env c
    check env {guards = g : guards env} a t
    check env {guards = FNot g : guards env} b t
  (ELet x e1 e2, _) -> do
    fresh x
    t1 <- synth env e1
    check env {bindings = (x, t1) : bindings env} e2 t
  _ -> synth env e >>= \t' -> subtype env t' t
  where
    fresh x
      | take 1 x == "_" = Left (IllFormed ("names may not start with _: " <> x))
      | x `elem` map fst (bindings env) = Left (IllFormed ("shadowing " <> x))
      | otherwise = Right ()

-- | Check one definition against its type, given earlier definitions.
checkTop :: [(String, RType)] -> Expr -> RType -> Either RefineError ()
checkTop defs = check (Env defs [])

-- | Check definitions in order; each may use the ones before it.
checkProgram :: [(String, RType, Expr)] -> Either (String, RefineError) ()
checkProgram = go []
  where
    go _ [] = Right ()
    go defs ((name, t, body) : rest) = case checkTop defs body t of
      Left err -> Left (name, err)
      Right () -> go ((name, t) : defs) rest

------------------------------------------------------------------------------
-- Running programs, to test what checking promises

data Value = VInt Integer | VFun (Value -> Maybe Value)

-- | Evaluate under an environment of values; 'Nothing' on a type error.
run :: Map.Map String Value -> Expr -> Maybe Value
run env e = case e of
  EVar x -> Map.lookup x env
  ENum n -> Just (VInt n)
  EAdd a b -> arith (+) a b
  ESub a b -> arith (-) a b
  EMul k a -> run env a >>= \v -> case v of
    VInt n -> Just (VInt (k * n))
    _ -> Nothing
  EIf c a b -> do
    holds <- cmp c
    run env (if holds then a else b)
  ELet x e1 e2 -> run env e1 >>= \v -> run (Map.insert x v env) e2
  ELam x _ body -> Just (VFun (\v -> run (Map.insert x v env) body))
  EApp f x -> do
    fv <- run env f
    xv <- Map.lookup x env
    case fv of
      VFun g -> g xv
      _ -> Nothing
  EAnn body _ -> run env body
  where
    ints a b = do
      va <- run env a
      vb <- run env b
      case (va, vb) of
        (VInt m, VInt n) -> Just (m, n)
        _ -> Nothing
    arith op a b = (\(m, n) -> VInt (op m n)) <$> ints a b
    cmp c = case c of
      CLe a b -> uncurry (<=) <$> ints a b
      CLt a b -> uncurry (<) <$> ints a b
      CEq a b -> uncurry (==) <$> ints a b

-- | Whether an integer satisfies @{v | p}@, given values for the other
-- integer variables @p@ mentions.
satisfiesType :: Map.Map String Integer -> Integer -> RType -> Bool
satisfiesType ints n t = case t of
  RInt v p -> evalFormula (Model Map.empty (Map.map fromInteger (Map.insert v n ints))) p
  RFun {} -> False
