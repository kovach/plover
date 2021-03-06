-- Various expressions and testing utilities --
{-# LANGUAGE OverloadedStrings #-}
module Plover.Expressions where

import Control.Applicative ((<$>))
import Control.Monad.Free
import Control.Arrow (second)

import Plover.Types
import Plover.Macros

-- Simple Test Expressions --
l1, l2 :: CExpr
l1 = Lam "i" 2 1
l2 = Lam "i" 2 (Lam "j" 2 ("i" + "j"))

e, e0, e1, e2, e3, e4, e5, e6, e7, e8, e9, e10, e11, e12 :: CExpr
e = "x" := Lam "i" 1 2
e0 = "x" := Lam "i" 2 (Lam "j" 2 ("i" + "j"))
e1 = "a" := Lam "i" 1 (("x" := 2) :> "x")
e2 = "x" := Lam "i" 1 1 + Lam "i" 1 1
e3 = "x" := Sig (Lam "i" 3 "i")

e4 = seqList [
  "x" := Lam "i" 3 1,
  "y" := Lam "i" 3 1,
  "z" := "x" * "x" + "y",
  "n" := norm "z",
  "xy" := "x" :# "y"
 ]

e5 = "x" := Lam "i" 1 (2 * 3)

e6 = seqList [
  "x" := Lam "i" 1 (2 * 3),
  "y" := (- (normalize "x"))
 ]

e7 = seqList [
  "v" := Lam "i" 1 1,
  "x" := norm "v"
 ]

e8 = "x" := l2 * l2

e9 = "x" := l2 * l2 * l2

e10 = seqList [
  "x" := Lam "i" 2 (Lam "j" 2 1),
  "y" := "x" * "x" * "x"
 ]

e11 = "a" := l1 :# l1
e12 = seqList [
  "x" := l1,
  "y" := (- "x")
 ]

p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12 :: CExpr
p1 = seqList [
  ("x" := Lam "i" 1 (Lam "j" 2 (("temp" := "i" + "j") :> "temp"))),
  ("y" := Lam "i" 2 (Lam "j" 3 ("i" + "j"))),
  ("z" := "x" * "y")
 ]

p2 = seqList [
  "x" := Lam "i" 1 (Lam "j" 2 0),
  "y" := transpose "x" * "x"
 ]
p3 = seqList [
  "y" := 1 / 2
 ]
p4 = seqList [
  "x" := l2,
  "y" := l1,
  "z" := "x" * "y"
 ]
p5 = seqList [
  Free (Extern "sqrt" (FnType $ fnT [numType] numType)),
  "y" := "sqrt" :$ 2
 ]
p6 = seqList [
  "x" := l1,
  "x2" := normalize "x"
 ]
p7 = seqList [
  "x" := 1 + 1 + 1,
  "y" := 3,
  "z" := "x" * "y"
 ]
p8 = "x" := rot_small 22
p9 = seqList [
  "z" := (s (s 1)),
  "x_inv" := s (s 1),
  Free $ App "inverse" ["z", "x_inv"]
 ]

p10 = seqList [
  "z" := (s (s 1)),
  "x" := inverse "z"
 ]

p11 = seqList [
  "r" := rot_small 2,
  "x" := inverse "r"
 ]
p12 = seqList [
  FnDef "foo" (FnT [] [("x", numType), ("y", numType)] numType) $ seqList [
    "z" := "x" * "y",
    Ret "z"],
  Free $ App "foo" [2, 3]
 ]

p13 = seqList [
  "x" := l2,
  "x" :< l1
 ]

p14 = seqList [
  FnDef "test" (FnT [] [("x", ExprType [1,1])] Void) $ seqList [
    "x" :< l1
    ]
 ]

-- Test cases that fail
b1, b2 :: CExpr
b1 = 2 * 3
b2 = "x" := "y"

-- TODO functional test cases
f1 = seqList [
  "x" := l2,
  "y" := inverse "x"
  -- check output
 ]

-- The PVT Example --
-- Current version will live in libswiftnav repository
decls :: CExpr
decls = seqList [
  Ext "GPS_OMEGAE_DOT" numType,
  Ext "GPS_C" numType 
 ]

losLoop :: CExpr
losLoop = Lam "j" (R "n_used") $ seqList [
  "tau" := norm ("rx_state" - "sat_pos" :! "j") / "GPS_C",
  "we_tau" := "GPS_OMEGAE_DOT" * "tau",
  -- TODO rewrite issue forces this onto its own line
  "rot" := rot_small "we_tau",
  "xk_new" := "rot" * ("sat_pos" :! "j"),
  --"xk_new" := rot_small "we_tau" * ("sat_pos" :! "j"),
  "xk_new" - "rx_state"
 ]

pvtSig = FnT
  { ft_imp = [("n_used", IntType)]
  , ft_exp =
      [("sat_pos", ExprType [R "n_used", 3])
      ,("pseudo", ExprType [R "n_used"])
      ,("rx_state", ExprType [3])
      ,("correction", ExprType [4])
      ,("G", ExprType ["n_used", (3+1)])
      ,("X", ExprType [4, "n_used"])
      ]
  , ft_out = Void
  }

pvtBody = seqList [
    decls,
    "los" :=  losLoop,
    "G" :< Lam "j" (R "n_used") (normalize ((- "los") :! "j") :# (Lam "i" 1 1)),
    "omp" := "pseudo" - Lam "j" (R "n_used") (norm ("los" :! "j")),
    "X" :< inverse (transpose "G" * "G") * transpose "G",
    "correction" :< "X" * "omp"
 ]

pvtDef :: (Variable, FunctionType CExpr, CExpr)
pvtDef = ("pvt", pvtSig, pvtBody)

pvt :: CExpr
pvt = FnDef "pvt" pvtSig pvtBody

testPVT = do
  -- Generate random arguments, call "pvt" defined above
  test1 <- generateTestArguments "pvt" pvtSig
  -- Print n_used
  let pnused = ("printInt" :$ "n_used")
  -- Call the wrapped libswiftnav version
  let test2 = Free (App (R "pvt2") (map (R . fst) (ft_exp pvtSig)))
  n <- freshName
  let printer = Lam n 4 ("printDouble" :$ ("correction" :! R n))
  -- Definition of pvt, then main that calls test code
  return
    $ Ext "pvt2" (FnType $ pvtSig )
    :> pvt
    :> (wrapMain $ seqList
         [ test1
         , pnused
         , newline "generated output:"
         , printer
         , test2
         , newline "reference output:"
         , printer
         , newline ""
         ])

-- Test cases.
good_cases :: [(String, M CExpr)]
good_cases = 
  [("pvt", testPVT)] ++ 
  map (second (return . wrapMain)) [
    ("e", e),
    ("e0", e0),
    ("e1", e1),
    ("e2", e2),
    ("e3", e3),
    ("e4", e4),
    ("e5", e5),
    ("e6", e6),
    ("e7", e7),
    ("e8", e8),
    ("e9", e9),
    ("e10", e10),
    ("e11", e11),
    ("e12", e12),

    ("p1", p1),
    ("p2", p2),
    ("p3", p3),
    ("p4", p4),
    ("p5", p5),
    ("p6", p6),
    ("p9", p9),
    ("p10", p10),
    ("p11", p11)]


bad_cases :: [CExpr]
bad_cases = [b1, b2]
