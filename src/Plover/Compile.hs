module Plover.Compile 
  ( writeProgram
  , compileLib
  , testWithGcc
  , printExpr
  , runM
  ) where

import Control.Monad.Trans.Either
import Control.Monad.State

import System.Process

import Plover.Types
import Plover.Reduce
import Plover.Print
import Plover.Macros (externs, seqList)

runM :: M a -> (Either Error a, TypeEnv)
runM m = runState (runEitherT m) initialState

wrapExterns :: M CExpr -> M CExpr
wrapExterns e = do
  e' <- e
  return (externs :> e')

--compileExpr :: M CExpr -> Either Error String
--compileLine :: CExpr -> Either Error String

compileProgram :: [String] -> M CExpr -> Either Error String
compileProgram includes expr = do
  expr' <- fst . runM $ compile =<< wrapExterns expr
  program <- flatten expr'
  return $ ppProgram $ Block (map Include includes ++ [program])

printFailure :: String -> IO ()
printFailure err = putStrLn (err ++ "\nCOMPILATION FAILED")

main' :: M CExpr -> IO ()
main' m = 
  case compileProgram [] m of
    Left err -> printFailure err
    Right str -> putStrLn str

main :: CExpr -> IO ()
main = main' . return

printOutput mp =
  case mp of
    Left err -> printFailure err
    Right p -> do
      putStrLn p

printExpr :: CExpr -> IO ()
printExpr expr = printOutput (compileProgram [] (return expr))

writeProgram :: FilePath -> [String] -> M CExpr -> IO ()
writeProgram fn includes expr =
  let mp = compileProgram includes expr in
  case mp of
    Left err -> printFailure err
    Right p -> do
      putStrLn p
      writeFile fn p

data TestingError = CompileError String | GCCError String
  deriving (Eq)

instance Show TestingError where
  show (GCCError str) = "gcc error:\n" ++ str
  show (CompileError str) = "rewrite compiler error:\n" ++ str

execGcc :: FilePath -> IO (Maybe String)
execGcc fp =  do
  out <- readProcess "gcc" [fp, "-w"] ""
  case out of
    "" -> return Nothing
    _ -> return $ Just out

-- See test/Main.hs for primary tests
testWithGcc :: M CExpr -> IO (Maybe TestingError)
testWithGcc expr =
  case compileProgram ["extern_defs.c"] expr of
    Left err -> return $ Just (CompileError err)
    Right p -> do
      let fp = "testing/compiler_output.c"
      writeFile fp p
      code <- execGcc fp
      case code of
        Nothing -> return $ Nothing
        Just output -> return $ Just (GCCError output)

-- Generates .h and .c file
generateLib :: [(Variable, FunctionType CExpr, CExpr)] -> ([Line], CExpr)
generateLib fns =
  let (decls, defs) = unzip $ map fix fns
  in (decls, seqList defs)
  where
    fix (name, fntype, def) = (ForwardDecl name fntype, FnDef name fntype def)

-- Adds .h, .c to given filename
compileLib :: FilePath -> [String] -> [(Variable, FunctionType CExpr, CExpr)] -> IO ()
compileLib filename includes defs =
  let (decls, defExpr) = generateLib defs
      stuff = do
        cout <- compileProgram includes (return defExpr)
        let hout = ppProgram (Block decls)
        return (hout, cout)
  in
    case stuff of
      Right (hout, cout) -> do
        writeFile (filename ++ ".c") cout
        writeFile (filename ++ ".h") hout
