module Backend exposing (Model, Msg(..), View(..), main, update, view)

import Browser
import Common exposing (NewUser, Order, Product, User, createUser, getProducts, getUsers, updateUser)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http


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
    | GotUsers (Result Http.Error (List User))
    | GotProducts (Result Http.Error (List Product))
    | CreateNewUser
    | NewUserCreated (Result Http.Error ())
    | NewUserNameChange String
    | NewUserAvatarChange String


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
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { jwtToken = "", view = EditOrders, products = [], users = [], new_user = NewUser "" "" }, Cmd.batch [ getUsers GotUsers, getProducts GotProducts ] )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
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

        UpdateUser user ->
            ( model, Cmd.batch [ updateUser model.jwtToken user UpdatedUser ] )

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
            ( {model | new_user ={name= "", avatar= ""} }, createUser model.jwtToken model.new_user NewUserCreated )



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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- HTTP
