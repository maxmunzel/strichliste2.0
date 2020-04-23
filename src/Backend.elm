module Backend exposing (Model, Msg(..), View(..), main, update, view)

import Browser
import Common exposing (NewProduct, NewUser, Order, Product, User, createProduct, createUser, getProducts, getUsers, updateProduct, updateUser)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Parser


hostname =
    "http://localhost:3000"


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
    | UpdateUser User
    | UpdatedUser (Result Http.Error ())
    | UpdateProduct Product
    | UpdatedProduct (Result Http.Error ())
    | GotUsers (Result Http.Error (List User))
    | GotProducts (Result Http.Error (List Product))
    | CreateNewUser
    | CreateNewProduct
    | NewUserCreated (Result Http.Error ())
    | NewUserNameChange String
    | NewUserAvatarChange String
    | NewProductCreated (Result Http.Error ())
    | NewProductNameChange String
    | NewProductImageChange String
    | NewProductPriceChange String


type View
    = EditUsers
    | EditProducts
    | EditOrders
    | Failure


type alias Model =
    { jwtToken : String
    , view : View
    , users : List User
    , products : List Product
    , new_user : NewUser
    , new_product : NewProduct
    , new_product_price : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { jwtToken = ""
      , view = EditOrders
      , products = []
      , users = []
      , new_user = NewUser "" ""
      , new_product = NewProduct "" "" "" 0
      , new_product_price = ""
      }
    , Cmd.batch [ getUsers GotUsers, getProducts GotProducts ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- General
        ShowUsers ->
            ( { model | view = EditUsers }, getUsers GotUsers )

        ShowProducts ->
            ( { model | view = EditProducts }, Cmd.none )

        ShowOrders ->
            ( { model | view = EditOrders }, Cmd.none )

        JwtUpdate text ->
            ( { model | jwtToken = text }, Cmd.none )

        GotUsers result ->
            case result of
                Err _ ->
                    ( { model | view = Failure }, Cmd.none )

                Ok users ->
                    ( { model | users = users }, Cmd.none )

        GotProducts result ->
            case result of
                Err _ ->
                    ( { model | view = Failure }, Cmd.none )

                Ok products ->
                    ( { model | products = products }, Cmd.none )

        -- User View
        UpdateUser user ->
            ( model, updateUser model.jwtToken user UpdatedUser )

        UpdatedUser (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        UpdatedUser (Ok _) ->
            ( model, getUsers GotUsers )

        NewUserCreated (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        NewUserCreated (Ok _) ->
            ( model, getUsers GotUsers )

        NewUserAvatarChange text ->
            let
                new_user =
                    model.new_user

                new_user_updated =
                    { new_user | avatar = text }
            in
            ( { model | new_user = new_user_updated }, Cmd.none )

        NewUserNameChange text ->
            let
                new_user =
                    model.new_user

                new_user_updated =
                    { new_user | name = text }
            in
            ( { model | new_user = new_user_updated }, Cmd.none )

        CreateNewUser ->
            ( { model | new_user = { name = "", avatar = "" } }, createUser model.jwtToken model.new_user NewUserCreated )

        -- Product View
        UpdateProduct product ->
            ( model, updateProduct model.jwtToken product UpdatedProduct )

        UpdatedProduct (Ok _) ->
            ( model, getProducts GotProducts )

        UpdatedProduct (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        CreateNewProduct ->
            let
                stripZero string =
                    -- Elm doesn't parse leading 0s in numbers
                    if String.startsWith "0" string then
                        stripZero <| String.dropLeft 1 string

                    else
                        string

                price =
                    Parser.run Parser.float <| String.replace "," "." <| stripZero <| model.new_product_price

                new_product =
                    model.new_product
            in
            case price of
                Ok price_f ->
                    ( model, createProduct model.jwtToken { new_product | price = price_f } NewProductCreated )

                Err _ ->
                    ( model, Cmd.none )

        NewProductCreated (Ok _) ->
            ( model, getProducts GotProducts )

        NewProductCreated (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        NewProductNameChange text ->
            let
                new_product =
                    model.new_product

                new_product_updated =
                    { new_product | name = text }
            in
            ( { model | new_product = new_product_updated }, Cmd.none )

        NewProductImageChange text ->
            let
                new_product =
                    model.new_product

                new_product_updated =
                    { new_product | image = text }
            in
            ( { model | new_product = new_product_updated }, Cmd.none )

        NewProductPriceChange text ->
            ( { model | new_product_price = text }, Cmd.none )



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

                Failure ->
                    "Failure"
    in
    div [ style "margin" "30px" ]
        [ button [ onClick ShowOrders ] [ text "Edit Orders" ]
        , button [ onClick ShowProducts ] [ text "Edit Products" ]
        , button [ onClick ShowUsers ] [ text "Edit Users" ]
        , input [ placeholder "jwtToken", value model.jwtToken, onInput JwtUpdate ] []
        , h1 [] [ text title ]
        , case model.view of
            EditUsers ->
                viewUsers model

            EditProducts ->
                viewProducts model

            _ ->
                h2 [] [ text "Dummy" ]
        ]


viewUsers model =
    div []
        [ table []
            ([ tr []
                [ th [] [ text "Name" ], th [] [ text "Avatar" ], th [] [ text "Active" ], th [] [] ]
             , tr []
                [ td [] [ input [ placeholder "Name", value model.new_user.name, onInput NewUserNameChange ] [] ]
                , td [] [ input [ placeholder "Avatar", value model.new_user.avatar, onInput NewUserAvatarChange ] [] ]
                , td [] []
                , td [] [ button [ onClick CreateNewUser ] [ text "Create new" ] ]
                ]
             ]
                ++ List.map userRow model.users
            )
        ]


userRow : User -> Html Msg
userRow user =
    tr []
        [ td [] [ text user.name ]
        , td [] [ text user.avatar ]
        , td []
            [ text
                (if user.active then
                    "Yes"

                 else
                    "No"
                )
            ]
        , td []
            [ button [ onClick <| UpdateUser { user | active = not user.active } ]
                [ text
                    (if user.active then
                        " Deactivate"

                     else
                        "Activate"
                    )
                ]
            ]
        ]


viewProducts : Model -> Html Msg
viewProducts model =
    let
        products_ordered =
            model.products
                |> List.sortBy .id
                |> List.sortBy .name
                |> List.sortBy .price
                |> List.sortBy
                    (\p ->
                        if p.active then
                            0

                        else
                            1
                    )
    in
    div []
        [ table []
            ([ tr []
                [ th [] [ text "Name" ], th [] [ text "Image" ], th [] [ text "Active" ], th [] [ text "Price" ], th [] [] ]
             , tr []
                [ td [] [ input [ placeholder "Name", value model.new_product.name, onInput NewProductNameChange ] [] ]
                , td [] [ input [ placeholder "Image", value model.new_product.image, onInput NewProductImageChange ] [] ]
                , td [] []
                , td [] [ input [ placeholder "Price", value model.new_product_price, onInput NewProductPriceChange ] [] ]
                , td [] [ button [ onClick CreateNewProduct ] [ text "Create new" ] ]
                ]
             ]
                ++ List.map productRow products_ordered
            )
        ]


productRow : Product -> Html Msg
productRow product =
    tr []
        [ td [] [ text product.name ]
        , td [] [ text product.image ]
        , td []
            [ text
                (if product.active then
                    "Yes"

                 else
                    "No"
                )
            ]
        , td [] [ text <| String.fromFloat <| product.price ]
        , td []
            [ button [ onClick <| UpdateProduct { product | active = not product.active } ]
                [ text
                    (if product.active then
                        " Deactivate"

                     else
                        "Activate"
                    )
                ]
            ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- HTTP
