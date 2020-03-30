module Grid exposing (Model(..), Msg(..), getRandomCatGif, gifDecoder, init, main, subscriptions, update, view, viewGif)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing ((:=), Decoder, field, list, object, string)



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
    | Success (List User)


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, GetUsers )



-- Update


type Msg
    = GetUsers
    | GotUsers (Result Http.Error (List User))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetUsers ->
            ( Loading, GetUsers )

        GotUsers result ->
            case result of
                Ok users ->
                    ( Success users, Cmd.none )

                Err _ ->
                    ( Failure, Cmd.none )



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
                , button [ onClick getUsers ] [ text "Try Again" ]
                ]

        Loading ->
            h2 [] [ text "Loading" ]

        Success ->
            div []
                [ List.map userView users
                ]


userView : User -> Html Msg
userView user =
    div []
        [ p [] [ text user.name ]
        , br [] []
        ]



-- HTTP


getUsers =
    Http.get
        { url = "http://www.mocky.io/v2/5e8221442f0000ac602fb8de"
        , expect = Http.expectJson GotUser
        }


userDecoder : Decoder User
userDecoder =
    User (field "name" string)


userListDecoder : Decoder (List User)
userListDecoder =
    object ("userser" := list User)
