{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Coq.Value where

import Data.Aeson            (ToJSON)
import Data.Proxy
import GHC.Generics          (Generic)
import Text.XML.Stream.Parse (tagName)

import Coq.StateId
import FromXML
import Utils

type ErrorLocation = Maybe (Int, Int)

data Value a
  = ValueFail StateId ErrorLocation String
  | ValueGood a
  deriving (Generic, Show)

instance Eq a => Eq (Value a) where
  ValueFail s loc msg == ValueFail s' loc' msg' =
    s == s' && loc == loc' && msg == msg'
  ValueGood a == ValueGood b =
    a == b
  _ == _ = False

instance ToJSON a => ToJSON (Value a)

instance FromXML a => FromXML (Value a) where
  instanceName Proxy = "Value"
  parseXML =
    tagName "value"
    (do val <- unpackRequireAttr "val"
        locS <- castAttr "loc_s"
        locE <- castAttr "loc_e"
        return (val, locS, locE))
    $ \ (val, locS, locE) ->
    case val of
    "good" -> ValueGood <$> do
      forceXML
    "fail" -> do
      stateID <- forceXML
      errMsg <- unpackContent
      return $ ValueFail stateID (errorLoc locS locE) errMsg
    _ -> error $ "val was neither some nor none: " ++ val
    where
      errorLoc :: Maybe Int -> Maybe Int -> ErrorLocation
      errorLoc (Just s) (Just e) = Just (s, e)
      errorLoc _        _        = Nothing

instance Functor Value where
  fmap f (ValueGood a) = ValueGood (f a)
  fmap _ (ValueFail s loc msg) = ValueFail s loc msg

instance Applicative Value where
  pure = ValueGood

  (ValueGood f) <*> (ValueGood a) = ValueGood (f a)
  (ValueGood _) <*> (ValueFail s loc msg) = ValueFail s loc msg
  (ValueFail s loc msg) <*> _ = ValueFail s loc msg

instance Monad Value  where
  return = pure

  (ValueGood a)         >>= f = f a
  (ValueFail s loc msg) >>= _ = ValueFail s loc msg
