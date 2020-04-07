module Main exposing (Model(..), Msg(..), User, getUsers, init, main, subscriptions, update, userDecoder, userView, view)

import Browser
import Debug
import Design
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing (Decoder, field, int, list, string, value)



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
    | ProductView User (List Order)


type alias Order =
    { product : Product
    , amount : Int
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, getUsers )



-- Update


type Msg
    = GotUsers (Result Http.Error (List User))
    | GotProducts (Result Http.Error (List Product))
    | ClickedUser User
    | ClickedProduct User Order (List Order)
    | GetUsers
    | ResetAmounts User (List Order)


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
                            ( ProductView user (List.map product2order products), Cmd.none )

                        _ ->
                            ( Loading, getUsers )

        GetUsers ->
            ( Loading, getUsers )

        ClickedUser user ->
            ( LoadingProducts user, getProducts )

        ClickedProduct user order orders ->
            let
                newOrders =
                    List.map
                        (\o ->
                            if o.product.id == order.product.id then
                                { o | amount = o.amount + 1 }

                            else
                                o
                        )
                        orders
            in
            ( ProductView user newOrders, Cmd.none )

        ResetAmounts user orders ->
            ( ProductView user (List.map resetAmount orders), Cmd.none )



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
                [ h1 [] [ text "Strichliste 2.0" ]
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

        ProductView user orders ->
            let
                confirmText =
                    if areOrdersEmpty orders then
                        "Zurück"

                    else
                        "Bestätigen"

                resetVisible =
                    if areOrdersEmpty orders then
                        "hidden"

                    else
                        "visible"
            in
            div []
                [ div
                    [ style "flex-direction" "row"
                    , style "display" "flex"
                    , style "align-items" "center"
                    , style "margin" "10px 10px 10px 10px "
                    ]
                    [ img
                        [ src user.avatar
                        , style "border-radius" "50%"
                        , style "width" "50px"
                        , style "height" "50px"
                        ]
                        []
                    , div [ style "width" "20px" ] []
                    , h1 [] [ text user.name ]
                    ]
                , Design.grid
                    (List.map (\o -> productView user o orders) orders
                        ++ [ button [ onClick GetUsers ] [ text confirmText ]
                           , button [ onClick (ResetAmounts user orders), style "visibility" resetVisible ] [ text "Zurücksetzen" ]
                           ]
                    )
                ]


areOrdersEmpty : List Order -> Bool
areOrdersEmpty orders =
    List.sum (List.map (\o -> o.amount) orders) == 0


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


productView : User -> Order -> List Order -> Html Msg
productView user order orders =
    let
        productText =
            if order.amount == 0 then
                order.product.name

            else
                order.product.name ++ " x" ++ String.fromInt order.amount
    in
    div
        [ onClick (ClickedProduct user order orders)
        , style "margin" "10px"
        , style "text-align" "center"
        ]
        [ img
            [ src order.product.image
            , style "height" "200px"
            ]
            []
        , h4 [] [ text productText ]
        , p [] [ text order.product.description ]
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


product2order product =
    Order product 0


resetAmount : Order -> Order
resetAmount order =
    { order | amount = 0 }
