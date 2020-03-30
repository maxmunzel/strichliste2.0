module Main exposing (Model(..), Msg(..), getRandomCatGif, gifDecoder, init, main, subscriptions, update, view, viewGif)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing (Decoder, field, string)



-- Main


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- Model


type Model
    = Failure
    | Loading
    | Success String


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, getRandomCatGif )



-- Update


type Msg
    = MorePlease
    | GotGif (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MorePlease ->
            ( Loading, getRandomCatGif )

        GotGif result ->
            case result of
                Ok url ->
                    ( Success url, Cmd.none )

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
        , viewGif model
        ]


viewGif : Model -> Html Msg
viewGif model =
    case model of
        Failure ->
            div []
                [ h2 [] [ text "Something went wrong" ]
                , button [ onClick MorePlease ] [ text "Try Again" ]
                ]

        Loading ->
            h2 [] [ text "Loading" ]

        Success url ->
            div []
                [ img [ src url ] []
                , button [ onClick MorePlease ] [ text "More, please" ]
                ]



-- HTTP


getRandomCatGif =
    Http.get
        { url = "https://api.giphy.com/v1/gifs/random?api_key=dc6zaTOxFJmzC&tag=cat"
        , expect = Http.expectJson GotGif gifDecoder
        }


gifDecoder : Decoder String
gifDecoder =
    field "data" (field "image_url" string)
