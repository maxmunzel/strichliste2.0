port module Main exposing (BuyState, Model(..), Msg(..), Persistance, State, areNewOrdersEmpty, init, main, productView, setPersistance, subscriptions, update, userView, view)

import Browser
import Common exposing (NewOrder, Product, User, UserName, getProducts, getUsers, get_jwt_token, hostname, product2order, resetAmount, user2str, userDecoder)
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
    }


type alias BuyState =
    { user : User
    , orders : List NewOrder
    }


type alias AskForJwtState =
    { persistance : Persistance
    , password : String
    }


type Model
    = Failure Persistance
    | AskForJwt AskForJwtState
    | LoadingUsers Persistance
    | LoadingProducts Persistance (List User)
    | Loaded State
    | Blank State -- Flush Screen before showing Loaded State (because the Fire Tables are slow)
    | ProductView State BuyState


type alias Persistance =
    -- Everything we want to be in LocalStorage
    { jwtToken : String
    , orders : List NewOrder
    , location : String
    , device_id : String -- randomly generated string that should be unique for each client i.e. sufficiently long
    , order_counter : Int -- count of all orders that have been sent using the current device_id
    }


init : Persistance -> ( Model, Cmd Msg )
init persistance =
    if persistance.jwtToken == "" then
        ( AskForJwt { persistance = persistance, password = "" }, Cmd.none )

    else
        ( LoadingUsers persistance, getUsers persistance.jwtToken GotUsers )



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
    | SentNewOrder Int (Result Http.Error ())
    | GetJwt
    | GotJwt (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetJwt ->
            case model of
                AskForJwt state ->
                    ( model, get_jwt_token Common.OrderUser state.password GotJwt )

                _ ->
                    ( model, Cmd.none )

        GotJwt result ->
            case result of
                Ok jwtToken ->
                    let
                        persistance =
                            get_persistance model

                        new_persistance =
                            { persistance | jwtToken = jwtToken }
                    in
                    ( LoadingUsers new_persistance, Cmd.batch [ getUsers jwtToken GotUsers, setPersistance new_persistance ] )

                Err _ ->
                    ( AskForJwt { persistance = get_persistance model, password = "" }, Cmd.none )

        GotUsers result ->
            case result of
                Ok users ->
                    case model of
                        LoadingUsers persistance ->
                            ( LoadingProducts persistance users, getProducts persistance.jwtToken GotProducts )

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
                                }
                            , Cmd.none
                            )

                        Loaded state ->
                            ( Loaded { state | offline = False, products = products }, Cmd.none )

                        ProductView state buyState ->
                            if areNewOrdersEmpty buyState.orders then
                                let
                                    orders =
                                        products
                                            |> List.filter (showProduct state.persistance.location)
                                            |> List.map (product2order buyState.user)
                                in
                                ( ProductView state
                                    { buyState | orders = orders }
                                , Cmd.none
                                )

                            else
                                ( model, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

        GetUsers persistance ->
            ( LoadingUsers persistance, getUsers persistance.jwtToken GotUsers )

        ClickedUser state user ->
            case model of
                Loaded _ ->
                    let
                        orders =
                            state.products
                                |> List.filter (showProduct state.persistance.location)
                                |> List.map (product2order user)
                    in
                    ( ProductView state { user = user, orders = orders }, scrollToTop () )

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
            case model of
                ProductView _ _ ->
                    ( model, Cmd.batch [ getUsers (get_persistance model).jwtToken GotUsers, getProducts (get_persistance model).jwtToken GotProducts ] )

                Loaded _ ->
                    ( model, Cmd.batch [ getUsers (get_persistance model).jwtToken GotUsers, getProducts (get_persistance model).jwtToken GotProducts ] )

                _ ->
                    ( model, Cmd.none )

        SyncTick timestamp ->
            let
                packNewOrder : Persistance -> NewOrder -> Json.Encode.Value
                packNewOrder persistance order =
                    Json.Encode.object
                        [ ( "user_id", Json.Encode.int order.user.id )
                        , ( "product_id", Json.Encode.int order.product.id )
                        , ( "amount", Json.Encode.int order.amount )
                        , ( "location", Json.Encode.string persistance.location )
                        , ( "idempotence_token", Json.Encode.string (persistance.device_id ++ "_" ++ String.fromInt persistance.order_counter) )
                        ]

                updateSync : State -> ( State, Cmd Msg )
                updateSync state =
                    case state.persistance.orders of
                        [] ->
                            ( state, Cmd.none )

                        order :: _ ->
                            ( state
                            , Http.request
                                { url = hostname ++ "/orders?on_conflict=idempotence_token"
                                , method = "POST"
                                , headers =
                                    [ Http.header "Authorization" ("Bearer " ++ state.persistance.jwtToken)
                                    , Http.header "Prefer" "resolution=ignore-duplicates"
                                    ]
                                , body = Http.jsonBody <| packNewOrder state.persistance <| order
                                , expect = Http.expectWhatever (SentNewOrder state.persistance.order_counter)
                                , timeout = Just 900.0
                                , tracker = Nothing
                                }
                            )

                -- are we in a model with a `State`? If not, ignore this tick...
            in
            case model of
                Blank state ->
                    ( Loaded
                        (Tuple.first <| updateSync <| state)
                    , Tuple.second <| updateSync <| state
                    )

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
                AskForJwt state ->
                    ( AskForJwt { state | password = text }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        AskForJwtLocationUpdate text ->
            case model of
                AskForJwt state ->
                    let
                        persistance =
                            state.persistance
                    in
                    let
                        new_persistance =
                            { persistance | location = text }
                    in
                    ( AskForJwt { state | persistance = new_persistance }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetPersistance persistance ->
            ( LoadingUsers persistance, Cmd.batch [ setPersistance persistance, getUsers persistance.jwtToken GotUsers ] )

        SentNewOrder _ (Err (Http.BadStatus 401)) ->
            -- 401: Unauthorized
            ( AskForJwt { persistance = get_persistance model, password = "" }, Cmd.none )

        SentNewOrder count result ->
            if count /= (model |> get_persistance |> .order_counter) then
                ( model, Cmd.none )

            else
                case result of
                    Err _ ->
                        ( model, Cmd.none )

                    Ok _ ->
                        let
                            persistance =
                                get_persistance model

                            new_orders =
                                case persistance.orders of
                                    [] ->
                                        []

                                    _ :: tail ->
                                        tail

                            new_order_count =
                                persistance.order_counter + 1

                            new_persistance =
                                { persistance | orders = new_orders, order_counter = new_order_count }
                        in
                        case model of
                            Failure _ ->
                                ( Failure new_persistance, setPersistance new_persistance )

                            AskForJwt state ->
                                ( AskForJwt { state | persistance = new_persistance }, setPersistance new_persistance )

                            LoadingUsers _ ->
                                ( LoadingUsers new_persistance, setPersistance new_persistance )

                            LoadingProducts _ users ->
                                ( LoadingProducts new_persistance users, setPersistance new_persistance )

                            Blank state ->
                                ( Loaded { state | persistance = new_persistance }, setPersistance new_persistance )

                            Loaded state ->
                                ( Loaded { state | persistance = new_persistance }, setPersistance new_persistance )

                            ProductView state buyState ->
                                ( ProductView { state | persistance = new_persistance } buyState, setPersistance new_persistance )



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every 1100 Tick
        , Time.every 1000 SyncTick
        ]



-- View


view : Model -> Html Msg
view model =
    case model of
        AskForJwt persistance ->
            div []
                [ h2 [] [ text "Please Enter Setup password: " ]
                , input [ onInput AskForJwtTextUpdate ] []
                , h2 [] [ text "Please enter location (e.g. \"Bar\", \"Kühlschrank\", …)" ]
                , input [ onInput AskForJwtLocationUpdate ] []
                , button [ onClick GetJwt ]
                    [ text "Save" ]
                ]

        Blank _ ->
            h1 [] [ text "Loading..." ]

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
                , br [] []
                , p [] [ text <| "Ort dieses Tablets: " ++ state.persistance.location ]
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
                , div [ class "stats" ]
                    [ h2 [] [ text "Kosten in den letzten 30 Tagen" ]
                    , p [] [ text <| Round.round 2 buyState.user.cost_last_30_days ++ "€" ]
                    , h2 [] [ text "Kosten in diesem Monat" ]
                    , p [] [ text <| Round.round 2 buyState.user.cost_this_month ++ "€" ]
                    , h2 [] [ text "Kosten im vergangenen Monat" ]
                    , p [] [ text <| Round.round 2 buyState.user.cost_last_month ++ "€" ]
                    , h2 [] [ text "Liter Bieräquivalent in den letzten 30 Tagen" ]
                    , p [] [ text <| Round.round 2 ((buyState.user.alc_ml_last_30_days / 0.05) / 1000) ]
                    ]
                ]


strip : String -> String
strip string =
    -- strips spaces from both sides
    string
        |> stripLeft
        |> stripRight


stripLeft string =
    if String.startsWith " " string then
        string |> String.dropLeft 1 |> stripLeft

    else
        string


stripRight string =
    if String.endsWith " " string then
        string |> String.dropRight 1 |> stripRight

    else
        string


showProduct : String -> Product -> Bool
showProduct location product =
    -- whether or not to show a product at a given location
    product.location
        |> String.split ","
        |> List.map strip
        |> List.map String.toLower
        |> List.member (location |> String.toLower |> strip)


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
        countText =
            if order.amount == 0 then
                ""

            else
                "x" ++ String.fromInt order.amount
    in
    div
        [ onClick (ClickedProduct state buyState order)
        , class "gridItem"
        , class
            (if order.amount == 0 then
                "notSelected"

             else
                "selected"
            )
        ]
        [ div [ class "imgContainer" ]
            [ img
                [ src order.product.image
                ]
                []
            , p [] [ text countText ]
            ]
        , b [] [ text order.product.name ]
        , br [] []
        , span [ class "productPrice" ] [ text (Round.round 2 order.product.price ++ "€") ]
        , br [] []
        , span [ class "productDescription" ] [ text order.product.description ]
        ]


get_persistance : Model -> Persistance
get_persistance model =
    case model of
        Failure persistance ->
            persistance

        AskForJwt state ->
            state.persistance

        LoadingUsers persistance ->
            persistance

        LoadingProducts persistance users ->
            persistance

        Blank state ->
            state.persistance

        Loaded state ->
            state.persistance

        ProductView state buyState ->
            state.persistance


port setPersistance : Persistance -> Cmd msg


port scrollToTop : () -> Cmd msg
