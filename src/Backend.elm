module Backend exposing (Model, Msg(..), View(..), main, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)


main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


type Msg
    = ShowUsers
    | ShowProducts
    | ShowOrders
    | JwtUpdate String


type View
    = EditUsers
    | EditProducts
    | EditOrders


type alias Model =
    { jwtToken : String
    , view : View
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { jwtToken = "", view = EditOrders }, Cmd.none )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShowUsers ->
            ( { model | view = EditUsers }, Cmd.none )

        ShowProducts ->
            ( { model | view = EditProducts }, Cmd.none )

        ShowOrders ->
            ( { model | view = EditOrders }, Cmd.none )

        JwtUpdate text ->
            ( { model | jwtToken = text }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    let
        title =
            case model.view of
                EditUsers ->
                    "Users"

                EditProducts ->
                    "Products"

                EditOrders ->
                    "Orders"
    in
    div [ style "margin" "30px" ]
        [ button [ onClick ShowOrders ] [ text "Edit Orders" ]
        , button [ onClick ShowProducts ] [ text "Edit Products" ]
        , button [ onClick ShowUsers ] [ text "Edit Users" ]
        , input [ placeholder "jwtToken", value model.jwtToken, onInput JwtUpdate][]
        , h1 [] [ text title ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
