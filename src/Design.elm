module Design exposing (button, green, grid, gridStyle, red, yellow)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


gridStyle =
    [ class "grid"
    ]


grid : List (Html msg) -> Html msg
grid =
    div gridStyle


type ButtonColor
    = ButtonColor String String -- Background Text



-- taken from https://getbootstrap.com/docs/4.0/components/buttons/ – they know a thing or two about design :)


yellow =
    ButtonColor "#FDB60D" "#212529"


red =
    ButtonColor "#CF1E36" "#FFFFFF"


green =
    ButtonColor "#1B6525" "#FFFFFF"


button : ButtonColor -> String -> msg -> Html msg
button (ButtonColor background textColor) label msg =
    div
        [ onClick msg
        , style "border-radius" "4px"
        , style "marin" "10px"
        , style "background-color" background
        ]
        [ p [ style "color" textColor, style "margin" "15px" ] [ text label ] ]
