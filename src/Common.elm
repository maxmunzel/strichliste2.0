module Common exposing (NewProduct, NewUser, Order, Product, User, createProduct, createUser, getProducts, getUsers, product2order, productDecoder, resetAmount, updateProduct, updateUser, user2str, userDecoder)

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
    }


type alias NewProduct =
    -- Model for a product we want to create. It therefor lacks technical fields like `id`
    { name : String
    , description : String
    , image : String
    , price : Float
    }


type alias Order =
    { user : User
    , product : Product
    , amount : Int
    }



-- http


getUsers msg =
    Http.get
        { url = hostname ++ "/users?order=name.asc"
        , expect = Http.expectJson msg (Json.Decode.list userDecoder)
        }


getProducts msg =
    Http.get
        { url = hostname ++ "/products?order=price.asc"
        , expect = Http.expectJson msg (Json.Decode.list productDecoder)
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
    Json.Decode.map4 User
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


newUserEncoder : NewUser -> Json.Encode.Value
newUserEncoder user =
    Json.Encode.object
        [ ( "name", Json.Encode.string user.name )
        , ( "avatar", Json.Encode.string user.avatar )
        ]


productDecoder : Decoder Product
productDecoder =
    Json.Decode.map6 Product
        (field "id" int)
        (field "name" string)
        (field "description" string)
        (field "image" string)
        (field "active" bool)
        (field "price" float)


productEncoder : Product -> Json.Encode.Value
productEncoder product =
    Json.Encode.object
        [ ( "id", Json.Encode.int product.id )
        , ( "name", Json.Encode.string product.name )
        , ( "description", Json.Encode.string product.description )
        , ( "image", Json.Encode.string product.image )
        , ( "active", Json.Encode.bool product.active )
        , ( "price", Json.Encode.float product.price )
        ]


newProductEncoder : NewProduct -> Json.Encode.Value
newProductEncoder product =
    Json.Encode.object
        [ ( "name", Json.Encode.string product.name )
        , ( "description", Json.Encode.string product.description )
        , ( "image", Json.Encode.string product.image )
        , ( "price", Json.Encode.float product.price )
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


product2order user product =
    Order user product 0


resetAmount : Order -> Order
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
