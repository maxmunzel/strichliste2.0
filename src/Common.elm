module Common exposing (..)

import File
import Http
import Json.Decode exposing (Decoder, bool, field, float, int, list, string, value)
import Json.Decode.Pipeline exposing (required)
import Json.Encode


hostname =
    "postgrest"



-- model


type alias User =
    { id : Int
    , name : String
    , avatar : String
    , active : Bool
    , cost_last_30_days : Float
    , cost_this_month : Float
    , cost_last_month : Float
    , alc_ml_last_30_days : Float
    }


type alias UserNoStat =
    { id : Int
    , name : String
    , avatar : String
    , active : Bool
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
    , location : String
    }


productDefaultLocation : String
productDefaultLocation =
    "Bar, Kühlschrank EG"


type alias NewProduct =
    -- Model for a product we want to create. It therefor lacks technical fields like `id`
    { name : String
    , description : String
    , image : String
    , price : Float
    , alcohol_content : Float
    , volume_in_ml : Float
    , location : String
    }


type alias Order =
    -- Model for an order used for display
    { id : Int
    , creation_date : String
    , product : Product
    , user : UserNoStat
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


getUsers jwtToken msg =
    Http.request
        { method = "GET"
        , url = hostname ++ "/users_and_costs?order=name.asc"
        , expect = Http.expectJson msg (Json.Decode.list userDecoder)
        , headers = [ Http.header "Authorization" ("Bearer " ++ jwtToken) ]
        , timeout = Nothing
        , body = Http.emptyBody
        , tracker = Nothing
        }


getProducts jwtToken msg =
    Http.request
        { url = hostname ++ "/products?order=price.asc&active=eq.true"
        , expect = Http.expectJson msg (Json.Decode.list productDecoder)
        , headers = [ Http.header "Authorization" ("Bearer " ++ jwtToken) ]
        , method = "GET"
        , timeout = Nothing
        , body = Http.emptyBody
        , tracker = Nothing
        }


getOrders jwtToken msg =
    Http.request
        { url = hostname ++ "/orders?select=*,user:users(*),product:products(*)&limit=200&order=creation_date.desc"
        , expect = Http.expectJson msg (Json.Decode.list orderDecoder)
        , headers = [ Http.header "Authorization" ("Bearer " ++ jwtToken) ]
        , method = "GET"
        , timeout = Nothing
        , body = Http.emptyBody
        , tracker = Nothing
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
    Json.Decode.map8 User
        (field "id" int)
        (field "name" string)
        (field "avatar" string)
        (field "active" bool)
        (field "cost_last_30_days" float)
        (field "cost_this_month" float)
        (field "cost_last_month" float)
        (field "alc_ml_last_30_days" float)


userNoStatDecoder : Decoder UserNoStat
userNoStatDecoder =
    Json.Decode.map4 UserNoStat
        (field "id" int)
        (field "name" string)
        (field "avatar" string)
        (field "active" bool)


userEncoder : User -> Json.Encode.Value
userEncoder user =
    Json.Encode.object
        [ ( "name", Json.Encode.string user.name )
        , ( "id", Json.Encode.int user.id )
        , ( "avatar", Json.Encode.string user.avatar )
        , ( "active", Json.Encode.bool user.active )
        ]


productDecoder : Decoder Product
productDecoder =
    Json.Decode.succeed Product
        |> required "id" int
        |> required "name" string
        |> required "description" string
        |> required "image" string
        |> required "active" bool
        |> required "price" float
        |> required "alcohol_content" float
        |> required "volume_in_ml" float
        |> required "location" string


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
        , ( "location", Json.Encode.string product.location )
        ]



-- createProduct:String -> -> (Result Http.Error () -> msg) -> Cmd msg


createProduct jwtToken product msg =
    Http.request
        { method = "POST"
        , headers = []
        , url = "api/create_product"
        , body =
            Http.multipartBody
                [ Http.stringPart "name" product.name
                , Http.stringPart "description" product.description
                , Http.stringPart "jwt" jwtToken
                , Http.filePart "image" product.image
                , Http.stringPart "price" (String.fromFloat product.price)
                , Http.stringPart "volume_in_ml" (String.fromFloat product.volume_in_ml)
                , Http.stringPart "alcohol_content" (String.fromFloat product.alcohol_content)
                , Http.stringPart "location" product.location
                ]
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
        (field "user" userNoStatDecoder)
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


createUser : String -> String -> File.File -> (Result Http.Error () -> msg) -> Cmd msg
createUser jwtToken name avatar msg =
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Bearer " ++ jwtToken) ]
        , url = "/api/create_user"
        , body =
            Http.multipartBody
                [ Http.stringPart "name" name
                , Http.stringPart "jwt" jwtToken
                , Http.filePart "file" avatar
                ]
        , expect = Http.expectWhatever msg
        , timeout = Nothing
        , tracker = Nothing
        }


type UserName
    = XxxxUser
    | OrderUser


username : UserName -> String
username user =
    case user of
        XxxxUser ->
            "xxxx_user"

        OrderUser ->
            "order_user"


get_jwt_token : UserName -> String -> (Result Http.Error String -> msg) -> Cmd msg
get_jwt_token user password msg =
    Http.request
        { method = "GET"
        , headers = [ Http.header "user" (username user), Http.header "password" password ]
        , url = "auth/get_jwt"
        , body = Http.emptyBody
        , expect = Http.expectString msg
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
