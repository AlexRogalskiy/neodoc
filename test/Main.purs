module Test.Main where

import Prelude
import Debug.Trace
import Control.MonadPlus (guard)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Console (log)
import Control.Monad.Eff.Exception (error)
import Control.Monad.Error.Class (throwError)
import Control.Monad.Trans (lift)
import qualified Text.Parsing.Parser as P
import Data.Either (either)
import Data.Either.Unsafe (fromRight)
import Data.List (length, (!!))
import Data.Maybe.Unsafe (fromJust)

import Docopt
import qualified Docopt.Parser.Usage as Usage
import qualified Docopt.Parser.Options as Options
import qualified Docopt.Textwrap as Textwrap
import qualified Docopt.Parser.Lexer as Lexer
import qualified Docopt.Parser.Scanner as Scanner
import Docopt.Parser.Base (debug)

import Test.Assert (assert)
import Test.Spec (describe, it)
import Test.Spec.Runner (run)
import Test.Spec.Reporter.Console (consoleReporter)

runLexer = flip P.runParser

main = run [consoleReporter] do
  describe "scanner" do
    it "should scan sections" do
      let docopt = fromRight $ Scanner.scan $
            Textwrap.dedent
              """
              Usage: foo
              Options: bar
              Advanced Options: qux
              """
      liftEff do
        assert $ docopt.usage == " foo\n"
        assert $ length docopt.options == 2
        assert $ fromJust (docopt.options !! 0) == " bar\n"
        assert $ fromJust (docopt.options !! 1) == " qux\n"
      pure unit
