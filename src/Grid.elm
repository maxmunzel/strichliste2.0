module Grid exposing (Model(..), Msg(..), User, getUsers, init, main, subscriptions, update, userDecoder, userListDecoder, userView, view)

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

        ProductView user ->
            div []
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



-- HTTP


getUsers : Cmd Msg
getUsers =
    Http.get
        { url = "/static/users.json"
        , expect = Http.expectJson GotUsers (field "users" userListDecoder)
        }


userDecoder : Decoder User
userDecoder =
    Json.Decode.map3 User
        (field "id" int)
        (field "name" string)
        (field "avatar" string)


userListDecoder : Decoder (List User)
userListDecoder =
    Json.Decode.list userDecoder
