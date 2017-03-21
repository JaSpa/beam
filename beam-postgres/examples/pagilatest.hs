{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# OPTIONS_GHC -fglasgow-exts #-}
module Main where

import Database.Beam
import Database.Beam.Postgres

import qualified Database.PostgreSQL.Simple as Pg

import qualified Control.Exception as E

import Data.Text (Text)
import Data.ByteString (ByteString)
import Data.Time.LocalTime (LocalTime)

import Data.Conduit ((=$=), runConduit)
import qualified Data.Conduit.List as CL (mapM_)

-- Address table

data AddressT f
  = AddressT
  { addressId         :: Columnar f Int
  , addressAddress1   :: Columnar f Text
  , addressAddress2   :: Columnar f (Maybe Text)
  , addressDistrict   :: Columnar f Text
  , addressCity       :: PrimaryKey CityT f
  , addressPostalCode :: Columnar f Text
  , addressPhone      :: Columnar f Text
  , addressLastUpdate :: Columnar f LocalTime
  } deriving Generic
type Address = AddressT Identity
deriving instance Show Address
deriving instance Eq Address

instance Table AddressT where
  data PrimaryKey AddressT f = AddressId (Columnar f Int) deriving Generic
  primaryKey = AddressId . addressId
type AddressId = PrimaryKey AddressT Identity
deriving instance Show AddressId
deriving instance Eq AddressId

-- City table

data CityT f
  = CityT
  { cityId         :: Columnar f Int
  , cityName       :: Columnar f Text
  , cityCountryId  :: PrimaryKey CountryT f
  , cityLastUpdate :: Columnar f LocalTime
  } deriving Generic
type City = CityT Identity
deriving instance Show City
deriving instance Eq City

instance Table CityT where
  data PrimaryKey CityT f = CityId (Columnar f Int) deriving Generic
  primaryKey = CityId . cityId
type CityId = PrimaryKey CityT Identity
deriving instance Show CityId
deriving instance Eq CityId

-- Country table

data CountryT f
  = CountryT
  { countryId          :: Columnar f Int
  , countryName        :: Columnar f Text
  , countryLastUpdated :: Columnar f LocalTime
  } deriving Generic
type Country = CountryT Identity
deriving instance Show Country
deriving instance Eq Country

instance Table CountryT where
  data PrimaryKey CountryT f = CountryId (Columnar f Int) deriving Generic
  primaryKey = CountryId . countryId
type CountryId = PrimaryKey CountryT Identity
deriving instance Show CountryId
deriving instance Eq CountryId

-- Actor

data ActorT f
  = ActorT
  { actorId :: Columnar f Int
  , actorFirstName :: Columnar f Text
  , actorLastName :: Columnar f Text
  , actorLastUpdate :: Columnar f LocalTime
  } deriving Generic
type Actor = ActorT Identity
deriving instance Show Actor; deriving instance Eq Actor

instance Table ActorT where
  data PrimaryKey ActorT f = ActorId (Columnar f Int) deriving Generic
  primaryKey = ActorId . actorId
type ActorId = PrimaryKey ActorT Identity
deriving instance Show ActorId; deriving instance Eq ActorId

-- Category

data CategoryT f
  = CategoryT
  { categoryId :: Columnar f Int
  , categoryName :: Columnar f Int
  , categoryLastUpdate :: Columnar f LocalTime
  } deriving Generic
type Category = CategoryT Identity
deriving instance Show Category; deriving instance Eq Category

instance Table CategoryT where
  data PrimaryKey CategoryT f = CategoryId (Columnar f Int) deriving Generic
  primaryKey = CategoryId . categoryId
type CategoryId = PrimaryKey CategoryT Identity
deriving instance Show CategoryId; deriving instance Eq CategoryId

-- Customer

data CustomerT f
  = CustomerT
  { customerId        :: Columnar f Int
  , customerStore     :: PrimaryKey StoreT f
  , customerFirstName :: Columnar f Text
  , customerLastName  :: Columnar f Text
  , customerEmail     :: Columnar f Text
  , customerAddress   :: PrimaryKey AddressT f
  , customerActive    :: Columnar f Bool
  , customerCreateDate :: Columnar f LocalTime
  , customerLastUpdate :: Columnar f LocalTime
  } deriving Generic
type Customer = CustomerT Identity
deriving instance Show Customer; deriving instance Eq Customer

instance Table CustomerT where
  data PrimaryKey CustomerT f = CustomerId (Columnar f Int) deriving Generic
  primaryKey = CustomerId . customerId
type CustomerId = PrimaryKey CustomerT Identity
deriving instance Show CustomerId; deriving instance Eq CustomerId

-- Store

data StoreT f
  = StoreT
  { storeId      :: Columnar f Int
  , storeManager :: PrimaryKey StaffT f
  , storeAddress :: PrimaryKey AddressT f
  , lastUpdate   :: Columnar f LocalTime
  } deriving Generic
type Store = StoreT Identity
deriving instance Show Store; deriving instance Eq Store

instance Table StoreT where
  data PrimaryKey StoreT f = StoreId (Columnar f Int) deriving Generic
  primaryKey = StoreId . storeId
type StoreId = PrimaryKey StoreT Identity
deriving instance Show StoreId; deriving instance Eq StoreId

-- Staff

data StaffT f
  = StaffT
  { staffId        :: Columnar f Int
  , staffFirstName :: Columnar f Text
  , staffLastName  :: Columnar f Text
  , staffAddress   :: PrimaryKey AddressT f
  , staffEmail     :: Columnar f Text
  , staffStore     :: PrimaryKey StoreT f
  , staffActive    :: Columnar f Bool
  , staffUsername  :: Columnar f Text
  , staffPassword  :: Columnar f ByteString
  , staffLastUpdate :: Columnar f LocalTime
  , staffPicture   :: Columnar f ByteString
  } deriving Generic
type Staff = StaffT Identity
deriving instance Eq Staff; deriving instance Show Staff

instance Table StaffT where
  data PrimaryKey StaffT f = StaffId (Columnar f Int) deriving Generic
  primaryKey = StaffId . staffId
type StaffId = PrimaryKey StaffT Identity
deriving instance Eq StaffId; deriving instance Show StaffId

-- Pagila db

data PagilaDb f
  = PagilaDb
  { actors     :: f ActorT
  , addresses  :: f AddressT
  , cities     :: f CityT
  , countries  :: f CountryT
  , categories :: f CategoryT
  , stores     :: f StoreT
  , staff      :: f StaffT
  } deriving Generic
instance Database PagilaDb

pagilaDb :: DatabaseSettings PagilaDb
pagilaDb = defaultDbSettings `withDbModification`
           dbModification
           { actors = modifyTable (const "actor") (tableModification { actorId = fieldNamed "actor_id" })
           , addresses = modifyTable (const "address")
                         (AddressT (fieldNamed "address_id") (fieldNamed "address") (fieldNamed "address2") (fieldNamed "district")
                                   (CityId (fieldNamed "city_id")) (fieldNamed "postal_code") (fieldNamed "phone") (fieldNamed "last_update"))
           , cities    = modifyTable (const "city")
                         (CityT (fieldNamed "city_id") (fieldNamed "city") (CountryId (fieldNamed "country_id")) (fieldNamed "last_update"))
           , countries = modifyTable (const "country")
                         (CountryT (fieldNamed "country_id") (fieldNamed "country") (fieldNamed "last_updated"))
           , categories = modifyTable (const "category") (tableModification { categoryId = fieldNamed "category_id" })
           , stores = modifyTable (const "store")
                      (StoreT (fieldNamed "store_id") (StaffId (fieldNamed "store_manager_id")) (AddressId (fieldNamed "address_id")) (fieldNamed "last_update"))
           , staff = modifyTable (const "staff")
                     (tableModification { staffId = fieldNamed "staff_id"
                                        , staffAddress = AddressId (fieldNamed "address_id")
                                        , staffStore = StoreId (fieldNamed "store_id") })
           }

-- Beamable instances

instance Beamable (PrimaryKey AddressT)
instance Beamable AddressT
instance Beamable (PrimaryKey CityT)
instance Beamable CityT
instance Beamable (PrimaryKey CountryT)
instance Beamable CountryT
instance Beamable (PrimaryKey ActorT)
instance Beamable ActorT
instance Beamable (PrimaryKey CategoryT)
instance Beamable CategoryT
instance Beamable (PrimaryKey CustomerT)
instance Beamable CustomerT
instance Beamable (PrimaryKey StoreT)
instance Beamable StoreT
instance Beamable (PrimaryKey StaffT)
instance Beamable StaffT

main :: IO ()
main =
  E.bracket (Pg.connectPostgreSQL "dbname=pagila") Pg.close $ \conn ->
  do let q = do AddressT { .. } <- all_ (addresses pagilaDb)
                CityT { .. } <- related_ (cities pagilaDb) addressCity
                CountryT { .. } <- related_ (countries pagilaDb) cityCountryId
                guard_ (isJust_ addressAddress2)
                pure (addressAddress1, addressDistrict, cityName, addressPostalCode, countryName, addressPhone, addressLastUpdate)
     runConduit (runSelect conn (select q) =$= CL.mapM_ (putStrLn . show))

     let q = do store@StoreT { .. } <- all_ (stores pagilaDb)
                manager <- related_ (staff pagilaDb) storeManager
                pure (store, manager)
     runConduit (runSelect conn (select q) =$= CL.mapM_ (putStrLn . show))