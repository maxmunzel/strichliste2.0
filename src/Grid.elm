module Grid exposing (Model(..), Msg(..), User, getUsers, init, main, subscriptions, update, userDecoder, userView, view)

import Browser
import Design
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing (Decoder, field, int, list, string)



-- Main


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- Model


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


type Model
    = Failure
    | Loading
    | Loaded (List User)
    | LoadingProducts User
    | ProductView User (List Product)


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, getUsers )



-- Update


type Msg
    = GotUsers (Result Http.Error (List User))
    | GotProducts (Result Http.Error (List Product))
    | ClickedUser User
    | ClickedProduct User Product
    | GetUsers


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotUsers result ->
            case result of
                Ok users ->
                    ( Loaded users, Cmd.none )

                Err _ ->
                    ( Failure, Cmd.none )

        GotProducts result ->
            case result of
                Err _ ->
                    ( Failure, Cmd.none )

                Ok products ->
                    case model of
                        LoadingProducts user ->
                            ( ProductView user products, Cmd.none )

                        _ ->
                            ( Loading, getUsers )

        GetUsers ->
            ( Loading, getUsers )

        ClickedUser user ->
            ( LoadingProducts user, getProducts )

        ClickedProduct user product ->
            ( Loading, getUsers )



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- View


view : Model -> Html Msg
view model =
    case model of
        Loaded users ->
            div []
                [ h2 [] [ text "Random Humans" ]
                , Design.grid (List.map userView users)
                ]

        Failure ->
            div []
                [ h2 [] [ text "Something went wrong" ]
                , button [ onClick GetUsers ] [ text "Try Again" ]
                ]

        Loading ->
            div []
                [ h2 [] [ text "Loading" ] ]

        LoadingProducts user ->
            div []
                [ h2 [] [ text "Loading Products" ] ]

        ProductView user products ->
            div []
                [ Design.grid (List.map (\p -> productView user p) products)
                , button [ onClick GetUsers ] [ text "Go Back" ]
                ]


userView : User -> Html Msg
userView user =
    div
        [ onClick (ClickedUser user)
        , style "margin" "10px"
        , style "text-align" "center"
        ]
        [ img
            [ style "border-radius" "50%"
            , style "width" "60px"
            , style "height" "60px"
            , style "align" "center"
            , src user.avatar
            ]
            []
        , p
            [ style "align" "center"
            ]
            [ text user.name ]
        , br [] []
        ]


productView : User -> Product -> Html Msg
productView user product =
    div
        [ onClick (ClickedProduct user product)
        , style "margin" "10px"
        , style "text-align" "center"
        ]
        [ img
            [ src product.image
            , style "height" "200px"
            ]
            []
        , h3 [] [ text product.name ]
        ]



-- HTTP


getUsers : Cmd Msg
getUsers =
    Http.get
        { url = "/static/users.json"
        , expect = Http.expectJson GotUsers (Json.Decode.list userDecoder)
        }


getProducts : Cmd Msg
getProducts =
    Http.get
        { url = "/static/products.json"
        , expect = Http.expectJson GotProducts (Json.Decode.list productDecoder)
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
