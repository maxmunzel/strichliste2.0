module Grid exposing (Model(..), Msg(..), User, getUsers, init, main, subscriptions, update, userDecoder, userListDecoder, userView, view, viewUsers)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing (Decoder, field, list, string)



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
    { name : String }


type Model
    = Failure
    | Loading
    | Loaded (List User)


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, getUsers )



-- Update


type Msg
    = GotUsers (Result Http.Error (List User))
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

        GetUsers ->
            ( Loading, getUsers )



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- View


view : Model -> Html Msg
view model =
    div []
        [ h2 [] [ text "Random Cats" ]
        , viewUsers model
        ]


viewUsers : Model -> Html Msg
viewUsers model =
    case model of
        Failure ->
            div []
                [ h2 [] [ text "Something went wrong" ]
                , button [ onClick GetUsers ] [ text "Try Again" ]
                ]

        Loading ->
            h2 [] [ text "Loading" ]

        Loaded users ->
            div []
                (List.map
                    userView
                    users
                )


userView : User -> Html Msg
userView user =
    div [ style "margin" "10px" ]
        [ p [] [ text user.name ]
        , br [] []
        ]



-- HTTP


getUsers : Cmd Msg
getUsers =
    Http.get
        { url = "http://www.mocky.io/v2/5e8258722f00002c002fbb12"
        , expect = Http.expectJson GotUsers (field "users" userListDecoder)
        }


userDecoder : Decoder User
userDecoder =
    Json.Decode.map User (field "name" string)


userListDecoder : Decoder (List User)
userListDecoder =
    Json.Decode.list userDecoder
