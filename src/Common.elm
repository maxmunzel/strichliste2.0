module Common exposing (NewUser, Order, Product, User, createUser, getProducts, getUsers, product2order, productDecoder, resetAmount, updateUser, user2str, userDecoder)

import Http
import Json.Decode exposing (Decoder, bool, field, int, list, string, value)
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
    Json.Decode.map4 Product
        (field "id" int)
        (field "name" string)
        (field "description" string)
        (field "image" string)


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
