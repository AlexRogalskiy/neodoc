module Test.Spec.SolverSpec (solverSpec) where

import Prelude
import Debug.Trace
import Data.Either (Either(..))
import Control.Bind ((=<<))
import Control.Apply ((*>))
import Data.List (List(..), toList)
import Control.Plus (empty)
import Data.Foldable (intercalate, for_)
import Control.Monad.Eff.Exception (error, throwException)
import qualified Data.Array as A
import Data.Maybe (Maybe(..))

import Test.Assert (assert)
import Test.Spec (describe, it)
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Assert.Simple

import Test.Support (vliftEff, runEitherEff)
import qualified Test.Support.Usage as U
import qualified Test.Support.Docopt as D
import qualified Test.Support.Desc as Desc

import Docopt
import Docopt.Spec.Solver (solve)
import qualified Docopt.Spec.Parser.Usage as U
import qualified Docopt.Spec.Parser.Desc as D
import Docopt.Spec.Parser.Scanner (scan)
import Docopt.Spec.Parser.Lexer (lex)
import Text.Wrap (dedent)

newtype TestSuite = TestSuite { usages :: Array U.Usage
                              , cases  :: Array TestCase
                              }
newtype TestCase = TestCase { descs    :: Array D.Desc
                            , expected :: Either String (Array Application) }

test :: Array U.Usage -> Array TestCase -> TestSuite
test us cs = TestSuite { usages: us, cases: cs }

pass :: Array D.Desc -> Array Application -> TestCase
pass ds as = TestCase { descs: ds, expected: Right as }

fail :: Array D.Desc -> String -> TestCase
fail ds msg = TestCase { descs: ds, expected: Left msg }

usage :: Array (Array U.Argument) -> U.Usage
usage = U.usage "foo"

application :: Array (Array Argument) -> Application
application xss = Application $ toList $ (\xs -> Branch $ toList xs) <$> xss

solverSpec =
  describe "solver" do
    (flip traverseWithIndex_) (toList [
      test ([ usage [ [ U.co "foo" ] ] ])
        [ pass  ([])
                ([ application [ [ D.co "foo" ] ] ])
        ]
    , test ([ usage [ [ U.po "foo" true ] ] ])
        [ pass  ([])
                ([ application [ [ D.po "foo" true ] ] ])
        ]
    , test ([ usage [ [ U.lo "foo" Nothing true ] ] ])
        [ pass  ([ Desc.opt (Desc.fname 'f' "foo")
                            (Just $ Desc.arg "bar" (Just "qux"))
                ])
                ([ application [
                    [ D.opt (Just 'f')
                            (Just "foo")
                            (Just $ OptionArgument "bar"
                                                   (Just $ StringValue "qux"))
                            true
                    ]
                ] ])
        ]
    , test ([ usage [ [ U.so 'x' ['v', 'z', 'f'] Nothing true ] ] ])
        [ pass  ([ Desc.opt (Desc.fname 'f' "file")
                            (Just $ Desc.arg "FILE" (Just "foo"))
                ])
                ([ application [
                    [ D.opt (Just 'x') Nothing Nothing true
                    , D.opt (Just 'v') Nothing Nothing true
                    , D.opt (Just 'z') Nothing Nothing true
                    , D.opt (Just 'f')
                            (Just "file")
                            (Just $ OptionArgument "FILE"
                                                   (Just $ StringValue "foo"))
                            true
                    ]
                ] ])
        ]

    , test ([ usage [ [ U.so 'f' [] Nothing true ] ] ])
        [ pass  ([ Desc.opt (Desc.fname 'f' "file")
                            (Just $ Desc.arg "FILE" (Just "foo"))
                ])
                ([ application [
                    [ D.opt (Just 'f')
                            (Just "file")
                            (Just $ OptionArgument "FILE"
                                                   (Just $ StringValue "foo"))
                            true
                    ]
                ] ])
        ]

    , test ([ usage [ [ U.so 'f' ['x'] Nothing true ] ] ])
        [ pass  ([ Desc.opt (Desc.fname 'f' "file")
                            (Just $ Desc.arg "FILE" (Just "foo"))
                ])
                ([ application [
                    [ D.opt (Just 'f') Nothing Nothing true
                    , D.opt (Just 'x') Nothing Nothing true
                    ]
                ] ])
        ]

      -- Note: `f` should not adopt `file` as it's full name since it's in an
      -- option stack and not in trailing position (therefore cannot inherit the
      -- description's argument, rendering it an unfit candidate)
    , test ([ usage [ [ U.so 'f' ['v', 'z', 'x'] Nothing true ] ] ])
        [ pass  ([ Desc.opt (Desc.fname 'f' "file")
                            (Just $ Desc.arg "FILE" (Just "foo"))
                ])
                ([ application [
                    [ D.opt (Just 'f') Nothing Nothing true
                    , D.opt (Just 'v') Nothing Nothing true
                    , D.opt (Just 'z') Nothing Nothing true
                    , D.opt (Just 'x') Nothing Nothing true
                    ]
                ] ])
        ]
    ]) runtest

  where

    runtest n (TestSuite { usages, cases }) = do
      describe ("Suite " ++ show (n + 1)) do
        (flip traverseWithIndex_) (toList cases)
          \j (TestCase { descs, expected }) -> do
            it ("case " ++ show (j + 1) ++ "/" ++ (show $ A.length cases)) do
              vliftEff do
                evaltest
                  (solve (toList usages) (toList descs))
                  (toList <$> expected)

    evaltest (Right output) (Right expected)
      = if output == (toList expected)
            then return unit
            else throwException $ error $
              "Unexpected output:\n" ++ show output

    evaltest (Right output) (Left _)
      = throwException $ error $
          "Missing exception! Got:\n" ++ show output

    evaltest (Left err) (Left expected)
      = if (show err) == expected
            then return unit
            else throwException $ error $
              "Unexpected error:\n" ++ show err

    evaltest (Left err) _ = throwException $ error $ show err

    traverseWithIndex_ :: forall a b m. (Applicative m) => (Int -> a -> m b)
                                                        -> (List a)
                                                        -> m Unit
    traverseWithIndex_ f xs = go xs 0
        where go Nil _         = return unit
              go (Cons x xs) i = f i x *> go xs (i + 1)
