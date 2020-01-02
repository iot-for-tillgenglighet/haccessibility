{-# LANGUAGE DeriveGeneric        #-}
{-# LANGUAGE TypeFamilies         #-}
{-# LANGUAGE DeriveAnyClass       #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE OverloadedStrings    #-}

-- |
-- Module      : Acessability.Handler.GQL
-- Description : The graphQL API entrypoint
-- Copyright   : (c) Tomas Stenlund, 2019
-- License     : BSD-3
-- Maintainer  : tomas.stenlund@permobil.com
-- Stability   : experimental
-- Portability : POSIX
-- 
-- This module contains the handler for graphQL queries
--
module Accessability.Handler.REST (
    getItemR,
    putItemR,
    deleteItemR,    
    postCreateItemR,
    postItemsR) where

--
-- Import standard libs
--
import Data.Text (Text, pack, unpack, splitOn)
import Data.HexString (HexString(..))
import GHC.Generics (Generic(..))
import Control.Exception (SomeException)  
import qualified UnliftIO.Exception as UIOE

--
-- Yesod and HTTP imports
--
import Yesod
import Network.HTTP.Types (
    status200,
    status400)

--
-- Persist library
--
import Database.Persist
import Database.Persist.TH
import Database.Persist.Sql

--
-- My own imports
--
import Accessability.Foundation (
    Handler,
    Server(..),
    getAuthenticatedUser,
    requireAuthentication)
import qualified Accessability.Model.DB as DB
import Accessability.Model
import Accessability.Model.REST
import qualified Accessability.Model.Database as DBF
import Accessability.Model.Transform

-- | The REST GET handler for an item, i.e. return with the data of an item based on the items
-- key provided in the URL api/item/0000000000000001
--
getItemR::Text      -- ^ The item key
    ->Handler Value -- ^ The item as a JSON response
getItemR key = do
    requireAuthentication
    result <- UIOE.catchAny 
        (((toGenericItem <$>) <$>) <$> (DBF.dbFetchItem (textToKey key)))
        (\e-> pure $ Left $ show e)
    case result of
        Left e -> invalidArgs $ ["Unable to get the item from the database", key] <> (splitOn "\n" $ pack e)
        Right item -> sendStatusJSON status200 item

-- | The REST delete handler, i.e. return with the data of an item based on the items
-- key and delete the item.
deleteItemR::Text      -- ^ The item key
    ->Handler () -- ^ The item as a JSON response
deleteItemR key = do
    requireAuthentication
    result <- UIOE.catchAny
        (DBF.dbDeleteItem $ textToKey key)
        (\e->pure $ Left $ show e)
    case result of
        Left e -> invalidArgs $ ["Unable to delete the item from the database", key] <> (splitOn "\n" $ pack e)
        Right _ -> sendResponseNoContent

-- | The REST put handler, i.e. return with the updated data of the changed item based
-- on the specified key
putItemR::Text      -- ^ The item key
    ->Handler Value -- ^ The item as a JSON response
putItemR key = do
    requireAuthentication
    queryBody <- requireCheckJsonBody::Handler PutItemBody
    result <- UIOE.catchAny
        (((toGenericItem <$>) <$>) <$> (DBF.dbUpdateItem (textToKey key) $
            DBF.changeField DB.ItemName (putItemName queryBody) <>
            DBF.changeField DB.ItemDescription (putItemDescription queryBody) <>
            DBF.changeField DB.ItemLevel (putItemLevel queryBody) <>
            DBF.changeField DB.ItemSource (putItemSource queryBody) <>
            DBF.changeField DB.ItemState (putItemState queryBody) <>
            DBF.changeField DB.ItemLongitude (realToFrac <$> putItemLongitude queryBody) <>
            DBF.changeField DB.ItemLatitude (realToFrac <$> putItemLatitude queryBody)))
        (\e->pure $ Left $ show e)
    case result of
        Left e -> invalidArgs $ ["Unable to update the item in the database", key] <> (splitOn "\n" $ pack e)
        Right item -> sendStatusJSON status200 item

-- | The REST post handler, i.e. creates a new item with the specified data in the body
-- and return with the data as stored in the database.
postCreateItemR::Handler Value -- ^ The item as a JSON response
postCreateItemR = do
    requireAuthentication
    body <- requireCheckJsonBody::Handler PostItemBody
    result <- UIOE.catchAny 
        (((toGenericItem <$>) <$>) <$> DBF.dbCreateItem $ DB.Item { 
            DB.itemName =  postItemName body,
            DB.itemDescription = postItemDescription body,
            DB.itemLevel = postItemLevel body,
            DB.itemSource = postItemSource body,
            DB.itemState = postItemState body,
            DB.itemLongitude = realToFrac $ postItemLongitude body,
            DB.itemLatitude = realToFrac $ postItemLatitude body })
        (\e->pure $ Left $ show e)
    case result of
        Left e -> invalidArgs $ ["Unable to create a new item in the database"] <> (splitOn "\n" $ pack e)
        Right item -> sendStatusJSON status200 item

-- | The REST get handler for items, i.e. a list of items based on a body where the
-- search fields are spceified.
postItemsR::Handler Value    -- ^ The list of items as a JSON response
postItemsR = do
    requireAuthentication
    queryBody <- requireCheckJsonBody::Handler PostItemsBody
    result <- UIOE.catchAny 
        (((toGenericItem <$>) <$>) <$> DBF.dbFetchItems (
            DBF.filter DB.ItemLatitude (<=.) (realToFrac <$> postItemsLatitudeMax queryBody) <>
            DBF.filter DB.ItemLatitude (>=.) (realToFrac <$> postItemsLatitudeMin queryBody) <>
            DBF.filter DB.ItemLongitude (<=.) (realToFrac <$> postItemsLongitudeMax queryBody) <>
            DBF.filter DB.ItemLongitude (>=.) (realToFrac <$> postItemsLongitudeMin queryBody) <>
            ( DBF.filter DB.ItemDescription (DBF.ilike) (postItemsText queryBody) ||.
            DBF.filter DB.ItemName (DBF.ilike) (postItemsText queryBody)) )
            (postItemsLimit queryBody))
        (\e->pure $ Left $ show e)
    case result of
        Left e -> invalidArgs $ ["Unable to find any items in the database"] <> (splitOn "\n" $ pack e)
        Right items -> sendStatusJSON status200 items
