module Retry
  ( increment
  , minDelay
  , maxDelay
  , RetryParams(RetryParams)
  , retryQueue
  , retryWithDelay
  ) where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.Chan (newChan, readChan, writeChan)
import Control.Exception (try)
import System.Random (getStdRandom, randomR)

-- This is growing closer to Control.Retry from the "retry" package.
-- Some of this should probably be replaced with that.
data RetryParams =
  RetryParams
    { increment :: Float -- Multiplier for how much longer to wait on each consecutive failure.  Eg: 1.5
    , minDelay :: Float
    , maxDelay :: Float
    }

-- How long to wait
nextBackoff :: RetryParams -> Bool -> Float -> Float
nextBackoff params True _ = minDelay params
nextBackoff params False prevBackoff =
  max (minDelay params) (min (maxDelay params) (prevBackoff * increment params))

retryWithDelay :: RetryParams -> IO Bool -> IO ()
retryWithDelay params action = process (minDelay params)
  where
    process :: Float -> IO ()
    process prevBackoff = do
      success <- (== Right True) <$> (try action :: IO (Either IOError Bool))
      let backoff = nextBackoff params success prevBackoff
       in if success
            then pure ()
            else do
              delay <- getStdRandom (randomR (0, 2 * backoff))
              threadDelay $ round $ 100000 * delay
              process backoff

-- |Apply f to items passed to the returned enqueue function.
-- f returns a bool indicating success.  When f is unsuccessful:
--   * The item is re-enqueued to be attempted again later
--   * Subsequent calls of f are delayed by exponential back-off with jitter
--     until successful again.
--
-- Use one retryQueue per failure domain (eg: one per remote network host)
retryQueue :: RetryParams -> (a -> IO Bool) -> IO (a -> IO ())
retryQueue params f =
  newChan >>=
  (\chan ->
     let process prevBackoff = do
           item <- readChan chan
           success <-
             (== Right True) <$> (try $ f item :: IO (Either IOError Bool))
           let backoff = nextBackoff params success prevBackoff
            in if success
                 then process (minDelay params) :: IO ()
                 else do
                   delay <- getStdRandom (randomR (0, 2 * backoff))
                   threadDelay $ round $ 100000 * delay
                   writeChan chan item
                   process backoff :: IO ()
      in do _ <- forkIO $ process (minDelay params) -- TODO: Allow thread clean-up
            pure $ writeChan chan)
