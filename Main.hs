module Main
  ( main
  ) where

import qualified Bejnarkli (someFunc)

main :: IO ()
main = do
  putStrLn "Hello, Haskell!"
  Bejnarkli.someFunc
