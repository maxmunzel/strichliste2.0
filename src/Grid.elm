module Grid exposing (Model(..), Msg(..), User, getUsers, init, main, subscriptions, update, userDecoder, userListDecoder, userView, view, viewUsers)

import Browser
import Design
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
    | ProductView User


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, getUsers )



-- Update


type Msg
    = GotUsers (Result Http.Error (List User))
    | ClickedUser User
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

        ClickedUser user ->
            ( ProductView user, Cmd.none )



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- View


view : Model -> Html Msg
view model =
    div []
        [ h2 [] [ text "Random Humans" ]
        , Design.grid (viewUsers model)
        ]


viewUsers : Model -> List (Html Msg)
viewUsers model =
    case model of
        Failure ->
            [ h2 [] [ text "Something went wrong" ]
            , button [ onClick GetUsers ] [ text "Try Again" ]
            ]

        Loading ->
            [ h2 [] [ text "Loading" ] ]

        Loaded users ->
            List.map
                userView
                users

        ProductView user ->
            [ h2 [] [ text ("Clicked on " ++ user.name ++ "!") ]
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
            , style "width" "50px"
            , style "height" "50px"
            , style "align" "center"
            , src "https://thispersondoesnotexist.com/image"
            ]
            []
        , p
            [ style "align" "center"
            ]
            [ text user.name ]
        , br [] []
        ]



-- HTTP


getUsers : Cmd Msg
getUsers =
    Http.get
        { url = "http://www.mocky.io/v2/5e8306332f000095c42fc8b9"
        , expect = Http.expectJson GotUsers (field "users" userListDecoder)
        }


userDecoder : Decoder User
userDecoder =
    Json.Decode.map User (field "name" string)


userListDecoder : Decoder (List User)
userListDecoder =
    Json.Decode.list userDecoder
