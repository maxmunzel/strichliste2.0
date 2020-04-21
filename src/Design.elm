module Design exposing (grid, gridStyle)

import Html exposing (..)
import Html.Attributes exposing (..)


gridStyle =
    [ style "display" "grid"
    , style "grid-template-columns" "repeat(auto-fill, minmax(120px, 1fr))"
    , style "grid-gap" "10px"
    , style "grid-auto-flow" "dense"
    , style "list-style" "none"
    , style "margin" "1em auto"
    , style "padding" "0"
    , style "max-width" "800px"
    ]


grid =
    div gridStyle
