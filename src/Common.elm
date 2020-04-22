module Common exposing (Order, Product, User, getProducts, getUsers, product2order, productDecoder, resetAmount, user2str, userDecoder)

import Http
import Json.Decode exposing (Decoder, field, int, list, string, value)
import Json.Encode



-- MODEL


type alias User =
    { id : Int
    , name : String
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



-- HTTP


getUsers msg =
    Http.get
        { url = "http://localhost:3000/users?active=eq.true&order=name.asc"
        , expect = Http.expectJson msg (Json.Decode.list userDecoder)
        }


getProducts msg =
    Http.get
        { url = "http://localhost:3000/products?order=price.asc"
        , expect = Http.expectJson msg (Json.Decode.list productDecoder)
        }


userDecoder : Decoder User
userDecoder =
    Json.Decode.map3 User
        (field "id" int)
        (field "name" string)
        (field "avatar" string)


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
