port module Main exposing (BuyState, Model(..), Msg(..), Persistance, State, SyncState(..), areNewOrdersEmpty, init, main, productView, setPersistance, subscriptions, update, userView, view)

import Browser
import Common exposing (NewOrder, Product, User, getProducts, getUsers, hostname, product2order, resetAmount, user2str, userDecoder)
import Debug
import Design
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed
import Http
import Json.Decode exposing (Decoder, field, int, list, string, value)
import Json.Encode
import Round exposing (round)
import Time



-- Main


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- Model


type alias State =
    { users : List User
    , products : List Product
    , offline : Bool
    , persistance : Persistance
    , sync : SyncState
    }


type
    SyncState
    -- Tracks, if we are currently attempting to commit an order
    = Idle -- no, we are not
    | Sending -- yes, we are


type alias BuyState =
    { user : User
    , orders : List NewOrder
    }


type Model
    = Failure Persistance
    | AskForJwt Persistance
    | LoadingUsers Persistance
    | LoadingProducts Persistance (List User)
    | Loaded State
    | ProductView State BuyState


type alias Persistance =
    -- Everything we want to be in LocalStorage
    { jwtToken : String
    , orders : List NewOrder
    , location : String
    }


init : Persistance -> ( Model, Cmd Msg )
init persistance =
    if persistance.jwtToken == "" then
        ( AskForJwt persistance, Cmd.none )

    else
        ( LoadingUsers persistance, getUsers GotUsers )



-- Update


type Msg
    = GotUsers (Result Http.Error (List User))
    | GotProducts (Result Http.Error (List Product))
    | ClickedUser State User
    | ClickedProduct State BuyState NewOrder
    | GetUsers Persistance
    | ResetAmounts State BuyState
    | CommitNewOrder State BuyState
    | Tick Time.Posix
    | SyncTick Time.Posix
    | AskForJwtTextUpdate String
    | AskForJwtLocationUpdate String
    | SetPersistance Persistance
    | SentNewOrder (Result Http.Error ())


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotUsers result ->
            case result of
                Ok users ->
                    case model of
                        LoadingUsers persistance ->
                            ( LoadingProducts persistance users, getProducts GotProducts )

                        Loaded state ->
                            ( Loaded { state | offline = False, users = users }, Cmd.none )

                        ProductView state buyState ->
                            ( ProductView { state | users = users, offline = False } buyState, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Err _ ->
                    case model of
                        LoadingUsers persistance ->
                            ( Failure persistance, Cmd.none )

                        Loaded state ->
                            ( Loaded { state | offline = True }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

        GotProducts result ->
            case result of
                Err _ ->
                    case model of
                        Loaded state ->
                            ( Loaded { state | offline = True }, Cmd.none )

                        LoadingProducts persistance _ ->
                            ( Failure persistance, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Ok products ->
                    case model of
                        LoadingProducts persistance users ->
                            ( Loaded
                                { users = users
                                , products = products
                                , persistance = persistance
                                , offline = False
                                , sync = Idle -- we start idle – the next SyncTick may begin working on old orders
                                }
                            , Cmd.none
                            )

                        Loaded state ->
                            ( Loaded { state | offline = False, products = products }, Cmd.none )

                        ProductView state buyState ->
                            if areNewOrdersEmpty buyState.orders then
                                ( ProductView state
                                    { buyState | orders = List.map (product2order buyState.user) products }
                                , Cmd.none
                                )

                            else
                                ( model, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

        GetUsers persistance ->
            ( LoadingUsers persistance, getUsers GotUsers )

        ClickedUser state user ->
            case model of
                Loaded _ ->
                    ( ProductView state { user = user, orders = List.map (product2order user) state.products }, scrollToTop () )

                _ ->
                    ( Failure state.persistance, Cmd.none )

        ClickedProduct state buyState order ->
            let
                newNewOrders =
                    List.map
                        (\o ->
                            if o.product.id == order.product.id then
                                { o | amount = o.amount + 1 }

                            else
                                o
                        )
                        buyState.orders
            in
            ( ProductView state { buyState | orders = newNewOrders }, Cmd.none )

        ResetAmounts state buyState ->
            ( ProductView state { buyState | orders = List.map resetAmount buyState.orders }, Cmd.none )

        CommitNewOrder state buyState ->
            -- TODO: Send NewOrder to Backend
            let
                new_orders =
                    List.filter (\o -> o.amount > 0) buyState.orders

                persistance =
                    state.persistance

                new_persistance =
                    { persistance | orders = persistance.orders ++ new_orders }

                user =
                    buyState.user

                cost =
                    new_orders
                        |> List.map (\o -> o.product.price * toFloat o.amount)
                        |> List.sum

                alcohol =
                    new_orders
                        |> List.map (\o -> o.product.volume_in_ml * o.product.alcohol_content * toFloat o.amount)
                        |> List.sum

                user_updated =
                    { user | cost_last_30_days = user.cost_last_30_days + cost, cost_this_month = user.cost_this_month + cost, alc_ml_last_30_days = user.alc_ml_last_30_days + alcohol }

                users_updates =
                    state.users
                        |> List.map
                            (\u ->
                                if u.id == user.id then
                                    user_updated

                                else
                                    u
                            )
            in
            ( Loaded { state | persistance = new_persistance, users = users_updates }, setPersistance new_persistance )

        Tick timestamp ->
            ( model, Cmd.batch [ getUsers GotUsers, getProducts GotProducts ] )

        SyncTick timestamp ->
            let
                packNewOrder : Persistance -> NewOrder -> Json.Encode.Value
                packNewOrder persistance order =
                    Json.Encode.object
                        [ ( "user_id", Json.Encode.int order.user.id )
                        , ( "product_id", Json.Encode.int order.product.id )
                        , ( "amount", Json.Encode.int order.amount )
                        , ( "location", Json.Encode.string persistance.location )
                        ]

                updateSync : State -> ( State, Cmd Msg )
                updateSync state =
                    case state.sync of
                        Sending ->
                            ( state, Cmd.none )

                        -- wait for the current order to finish
                        Idle ->
                            case state.persistance.orders of
                                [] ->
                                    ( state, Cmd.none )

                                order :: _ ->
                                    ( { state | sync = Sending }
                                    , Http.request
                                        { url = hostname ++ "/orders"
                                        , method = "POST"
                                        , headers = [ Http.header "Authorization" ("Bearer " ++ state.persistance.jwtToken) ]
                                        , body = Http.jsonBody <| packNewOrder state.persistance <| order
                                        , expect = Http.expectWhatever SentNewOrder
                                        , timeout = Just 1000.0
                                        , tracker = Nothing
                                        }
                                    )

                -- are we in a model with a `State`? If not, ignore this tick...
            in
            case model of
                LoadingUsers _ ->
                    ( model, Cmd.none )

                LoadingProducts _ _ ->
                    ( model, Cmd.none )

                Failure _ ->
                    ( model, Cmd.none )

                AskForJwt _ ->
                    ( model, Cmd.none )

                Loaded state ->
                    ( Loaded
                        (Tuple.first <| updateSync <| state)
                    , Tuple.second <| updateSync <| state
                    )

                ProductView state buyState ->
                    ( ProductView
                        (Tuple.first <| updateSync <| state)
                        buyState
                    , Tuple.second <| updateSync <| state
                    )

        AskForJwtTextUpdate text ->
            case model of
                AskForJwt persistance ->
                    ( AskForJwt { persistance | jwtToken = text }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        AskForJwtLocationUpdate text ->
            case model of
                AskForJwt persistance ->
                    ( AskForJwt { persistance | location = text }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetPersistance persistance ->
            ( LoadingUsers persistance, Cmd.batch [ setPersistance persistance, getUsers GotUsers ] )

        SentNewOrder result ->
            let
                persistance =
                    case model of
                        Failure persistance_ ->
                            persistance_

                        AskForJwt persistance_ ->
                            persistance_

                        LoadingUsers persistance_ ->
                            persistance_

                        LoadingProducts persistance_ users ->
                            persistance_

                        Loaded state ->
                            state.persistance

                        ProductView state buyState ->
                            state.persistance

                new_orders =
                    case result of
                        Ok _ ->
                            case persistance.orders of
                                [] ->
                                    []

                                _ :: tail ->
                                    tail

                        Err _ ->
                            persistance.orders

                new_persistance =
                    { persistance | orders = new_orders }

                offline =
                    case result of
                        Ok _ ->
                            False

                        Err _ ->
                            True
            in
            case result of
                Err (Http.BadStatus 401) ->
                    -- 401: Unauthorized
                    ( AskForJwt persistance, Cmd.none )

                _ ->
                    case model of
                        Failure _ ->
                            ( Failure new_persistance, setPersistance new_persistance )

                        AskForJwt _ ->
                            ( AskForJwt new_persistance, setPersistance new_persistance )

                        LoadingUsers _ ->
                            ( LoadingUsers new_persistance, setPersistance new_persistance )

                        LoadingProducts _ users ->
                            ( LoadingProducts new_persistance users, setPersistance new_persistance )

                        Loaded state ->
                            ( Loaded { state | persistance = new_persistance, sync = Idle }, setPersistance new_persistance )

                        ProductView state buyState ->
                            ( ProductView { state | persistance = new_persistance, sync = Idle } buyState, setPersistance new_persistance )



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every 10000 Tick
        , Time.every 1000 SyncTick
        ]



-- View


view : Model -> Html Msg
view model =
    case model of
        AskForJwt persistance ->
            div []
                [ h2 [] [ text "Please Enter JWT. If you set up using init.py you will find some in secrets.json" ]
                , input [ onInput AskForJwtTextUpdate ] []
                , h2 [] [ text "Please enter location (e.g. \"Bar\", \"Kühlschrank\", …)" ]
                , input [ onInput AskForJwtLocationUpdate ] []
                , button [ onClick (SetPersistance persistance) ]
                    [ text "Save" ]
                ]

        Loaded state ->
            let
                title =
                    if state.offline then
                        "Strichliste *"

                    else
                        "Strichliste"
            in
            div [ style "margin" "10px 10px 10px 10px " ]
                [ h1 [] [ text title ]
                , state.users
                    |> List.filter .active
                    |> List.sortBy .name
                    |> List.sortBy (\u -> -u.alc_ml_last_30_days)
                    |> List.map (\u -> ( user2str u, userView state u ))
                    |> Html.Keyed.node "div" Design.gridStyle
                ]

        Failure persistance ->
            div []
                [ h2 [] [ text "Something went wrong" ]
                , button [ onClick (GetUsers persistance) ] [ text "Try Again" ]
                ]

        LoadingUsers persistance ->
            div []
                [ h2 [] [ text "Loading Users" ] ]

        LoadingProducts persistance users ->
            div []
                [ h2 [] [ text "Loading Products" ] ]

        ProductView state buyState ->
            let
                confirmButton =
                    if areNewOrdersEmpty buyState.orders then
                        Design.button Design.red "Zurück" (CommitNewOrder state buyState)

                    else
                        Design.button Design.green "Eintragen" (CommitNewOrder state buyState)

                resetButton =
                    if areNewOrdersEmpty buyState.orders then
                        div [] []

                    else
                        Design.button Design.yellow "Zurücksetzen" (ResetAmounts state buyState)
            in
            div []
                [ div
                    [ style "flex-direction" "row"
                    , style "display" "flex"
                    , style "align-items" "center"
                    , style "margin" "10px 10px 10px 10px "
                    ]
                    [ img
                        [ src buyState.user.avatar
                        , style "border-radius" "50%"
                        , style "width" "100px"
                        , style "height" "100px"
                        ]
                        []
                    , div [ style "width" "20px" ] []
                    , h1 [] [ text buyState.user.name ]
                    , div [ style "width" "20px" ] []
                    , confirmButton
                    , div [ style "width" "30px" ] []
                    , resetButton
                    ]
                , Design.grid
                    (List.map (productView state buyState) buyState.orders)
                , h2 [] [ text "Kosten in den letzten 30 Tagen" ]
                , p [] [ text <| Round.round 2 buyState.user.cost_last_30_days ++ "€" ]
                , h2 [] [ text "Kosten in diesem Monat" ]
                , p [] [ text <| Round.round 2 buyState.user.cost_this_month ++ "€" ]
                , h2 [] [ text "Kosten im vergangenen Monat" ]
                , p [] [ text <| Round.round 2 buyState.user.cost_last_month ++ "€" ]
                , h2 [] [ text "Liter Bieräquivalent in den letzten 30 Tagen" ]
                , p [] [ text <| Round.round 2 ((buyState.user.alc_ml_last_30_days / 0.05) / 1000) ]
                ]


areNewOrdersEmpty : List NewOrder -> Bool
areNewOrdersEmpty orders =
    List.sum (List.map (\o -> o.amount) orders) == 0


userView : State -> User -> Html Msg
userView state user =
    div
        [ onClick (ClickedUser state user)
        , style "margin" "10px"
        , style "text-align" "center"
        , style "touch-action" "manipulation"
        ]
        [ img
            [ style "border-radius" "50%"
            , style "width" "80px"
            , style "height" "80px"
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


productView : State -> BuyState -> NewOrder -> Html Msg
productView state buyState order =
    let
        productText =
            if order.amount == 0 then
                order.product.name

            else
                order.product.name ++ " x" ++ String.fromInt order.amount
    in
    div
        [ onClick (ClickedProduct state buyState order)
        , style "margin" "10px"
        , style "text-align" "center"
        , style "touch-action" "manipulation"
        ]
        [ img
            [ src order.product.image
            , style "height" "200px"
            ]
            []
        , br [] []
        , b [] [ text productText ]
        , br [] []
        , text (Round.round 2 order.product.price ++ "€")
        , br [] []
        , text order.product.description
        ]


port setPersistance : Persistance -> Cmd msg


port scrollToTop : () -> Cmd msg
