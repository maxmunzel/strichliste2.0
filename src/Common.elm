module Common exposing (NewOrder, NewProduct, NewUser, Order, Product, User, createProduct, createUser, getOrders, getProducts, getUsers, hostname, orderSetUndone, product2order, productDecoder, resetAmount, updateProduct, updateUser, user2str, userDecoder)

import Http
import Json.Decode exposing (Decoder, bool, field, float, int, list, string, value)
import Json.Encode


hostname =
    "http://localhost:3000"



-- model


type alias User =
    { id : Int
    , name : String
    , avatar : String
    , active : Bool
    , cost_last_30_days : Float
    , cost_this_month : Float
    , cost_last_month : Float
    }


type alias NewUser =
    -- Model for a user we want to create. It therefor lacks technical fields like `id`
    { name : String
    , avatar : String
    }


type alias Product =
    { id : Int
    , name : String
    , description : String
    , image : String
    , active : Bool
    , price : Float
    , alcohol_content : Float
    , volume_in_ml : Float
    }


type alias NewProduct =
    -- Model for a product we want to create. It therefor lacks technical fields like `id`
    { name : String
    , description : String
    , image : String
    , price : Float
    , alcohol_content : Float
    , volume_in_ml : Float
    }


type alias Order =
    -- Model for an order used for display
    { id : Int
    , creation_date : String
    , product : Product
    , user : User
    , amount : Int
    , unDone : Bool
    , location : String
    }


type alias NewOrder =
    { user : User
    , product : Product
    , amount : Int
    }



-- http


getUsers msg =
    Http.get
        { url = hostname ++ "/users_and_costs?order=name.asc"
        , expect = Http.expectJson msg (Json.Decode.list userDecoder)
        }


getProducts msg =
    Http.get
        { url = hostname ++ "/products?order=price.asc&active=eq.true"
        , expect = Http.expectJson msg (Json.Decode.list productDecoder)
        }


getOrders msg =
    Http.get
        { url = hostname ++ "/orders?select=*,user:users(*),product:products(*)&limit=200&order=creation_date.desc"
        , expect = Http.expectJson msg (Json.Decode.list orderDecoder)
        }


updateUser jwtToken user msg =
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" ("Bearer " ++ jwtToken) ]
        , url = hostname ++ "/users?id=eq." ++ String.fromInt user.id
        , body = Http.jsonBody <| userEncoder <| user
        , expect = Http.expectWhatever msg
        , timeout = Nothing
        , tracker = Nothing
        }


updateProduct jwtToken product msg =
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" ("Bearer " ++ jwtToken) ]
        , url = hostname ++ "/products?id=eq." ++ String.fromInt product.id
        , body = Http.jsonBody <| productEncoder <| product
        , expect = Http.expectWhatever msg
        , timeout = Nothing
        , tracker = Nothing
        }


userDecoder : Decoder User
userDecoder =
    Json.Decode.map7 User
        (field "id" int)
        (field "name" string)
        (field "avatar" string)
        (field "active" bool)
        (field "cost_last_30_days" float)
        (field "cost_this_month" float)
        (field "cost_last_month" float)


userEncoder : User -> Json.Encode.Value
userEncoder user =
    Json.Encode.object
        [ ( "name", Json.Encode.string user.name )
        , ( "id", Json.Encode.int user.id )
        , ( "avatar", Json.Encode.string user.avatar )
        , ( "active", Json.Encode.bool user.active )
        ]


newUserEncoder : NewUser -> Json.Encode.Value
newUserEncoder user =
    Json.Encode.object
        [ ( "name", Json.Encode.string user.name )
        , ( "avatar", Json.Encode.string user.avatar )
        ]


productDecoder : Decoder Product
productDecoder =
    Json.Decode.map8 Product
        (field "id" int)
        (field "name" string)
        (field "description" string)
        (field "image" string)
        (field "active" bool)
        (field "price" float)
        (field "alcohol_content" float)
        (field "volume_in_ml" float)


productEncoder : Product -> Json.Encode.Value
productEncoder product =
    Json.Encode.object
        [ ( "id", Json.Encode.int product.id )
        , ( "name", Json.Encode.string product.name )
        , ( "description", Json.Encode.string product.description )
        , ( "image", Json.Encode.string product.image )
        , ( "active", Json.Encode.bool product.active )
        , ( "price", Json.Encode.float product.price )
        , ( "volume_in_ml", Json.Encode.float product.volume_in_ml )
        , ( "alcohol_content", Json.Encode.float product.alcohol_content )
        ]


newProductEncoder : NewProduct -> Json.Encode.Value
newProductEncoder product =
    Json.Encode.object
        [ ( "name", Json.Encode.string product.name )
        , ( "description", Json.Encode.string product.description )
        , ( "image", Json.Encode.string product.image )
        , ( "price", Json.Encode.float product.price )
        , ( "volume_in_ml", Json.Encode.float product.volume_in_ml )
        , ( "alcohol_content", Json.Encode.float product.alcohol_content )
        ]


createProduct jwtToken product msg =
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Bearer " ++ jwtToken) ]
        , url = hostname ++ "/products"
        , body = Http.jsonBody <| newProductEncoder <| product
        , expect = Http.expectWhatever msg
        , timeout = Nothing
        , tracker = Nothing
        }


orderDecoder : Decoder Order
orderDecoder =
    Json.Decode.map7 Order
        (field "id" int)
        (field "creation_date" string)
        (field "product" productDecoder)
        (field "user" userDecoder)
        (field "amount" int)
        (field "undone" bool)
        (field "location" string)


product2order user product =
    NewOrder user product 0


resetAmount : NewOrder -> NewOrder
resetAmount order =
    { order | amount = 0 }


user2str user =
    user.name ++ "$" ++ user.avatar ++ "$" ++ String.fromInt user.id


createUser jwtToken user msg =
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Bearer " ++ jwtToken) ]
        , url = hostname ++ "/users"
        , body = Http.jsonBody <| newUserEncoder <| user
        , expect = Http.expectWhatever msg
        , timeout = Nothing
        , tracker = Nothing
        }


orderSetUndone jwtToken order unDone msg =
    let
        payload =
            Json.Encode.object [ ( "undone", Json.Encode.bool unDone ) ]
    in
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" ("Bearer " ++ jwtToken) ]
        , url = hostname ++ "/orders?id=eq." ++ String.fromInt order.id
        , body = Http.jsonBody payload
        , expect = Http.expectWhatever msg
        , timeout = Nothing
        , tracker = Nothing
        }
