module App exposing (..)
import Html exposing (Html, div, text, program)
import Html.Attributes exposing (style)
import Keyboard exposing (..)
import Random as Random
import Time exposing (Time, second, millisecond)
import Char exposing (fromCode)

type alias Part =
  { x: Int
  , y: Int
  }

type alias Stage =
  { w: Int
  , h: Int
  }

type Direction = N | S | E | W

type alias Model =
  { lastKey: Maybe Char
  , direction: Direction
  , hd: Part
  , tl: List Part
  , length: Int
  , stage: Stage
  , target: Part
  , seed: Random.Seed
  }

initialModel : Model
initialModel =
  { lastKey = Nothing
  , direction = S
  , length = 5
  , stage = {w=20, h=20}
  , target = {x=1, y=1}
  , hd = {x=10,y=10}
  , tl = []
  , seed = Random.initialSeed 999
  }

init : (Model, Cmd Msg)
init =
  (initialModel, Cmd.none )

type Msg
  = Downs Char
    | Tick

px : Int -> String
px n = toString n ++ "px"

rect : String -> Int -> Int -> Int -> Int -> Html Msg
rect color x y w h =
  let
    s = style
      [ ("backgroundColor", color)
      , ("position", "absolute")
      , ("width", px w)
      , ("height", px h)
      , ("left", px x)
      , ("top", px y)
      ]
  in
    div [s] []

viewPart : String -> Part -> Html Msg
viewPart color p = rect color (p.x * 10) (p.y * 10) 10 10

viewParts : List Part -> Html Msg
viewParts s = div [] (List.map (viewPart "#002200") s)

viewTarget : Part -> Html Msg
viewTarget = viewPart "#990000"

viewHead : Part -> Html Msg
viewHead = viewPart "#005500"

viewStage : Stage -> Html Msg
viewStage s = rect "#666" 0 0 (s.w * 10) (s.h * 10)

resetTarget : Model -> Model
resetTarget model =
  let
    s0 = model.seed
    (x, s1) = Random.step (Random.int 0 model.stage.w) s0
    (y, s2) = Random.step (Random.int 0 model.stage.h) s1
  in
    { model |
      seed = s2 
    , target = {x = x, y = y}
    }

resetTargetChecked : Model -> Model
resetTargetChecked model =
  let
    m = resetTarget model
  in
    if List.any (part2part m.target) (m.hd :: m.tl) then resetTargetChecked m else model

view : Model -> Html Msg
view model =
  div []
      [ viewStage model.stage
      , viewHead model.hd
      , viewTarget model.target
      , viewParts model.tl
      , div [style [("position", "absolute"), ("top", "250px")]] [text (toString model)]
      ]

updateDirection : Model -> Model
updateDirection model = 
  let
    f key =
        let
          left = key == 'A'
          right = key == 'D'
          up = key == 'W'
          down = key == 'S'
        in
          case model.direction of
            S -> if left then W else if right then E else S
            N -> if left then W else if right then E else N
            E -> if up then N else if down then S else E
            W -> if up then N else if down then S else W
  in
    { model |
      direction = Maybe.withDefault model.direction (Maybe.map f model.lastKey)
    , lastKey = Nothing
    }

stepPart : Direction -> Part -> Part
stepPart direction part =
  case direction of
    S -> { x = part.x, y = part.y + 1 }
    N -> { x = part.x, y = part.y - 1 }
    E -> { x = part.x + 1, y = part.y }
    W -> { x = part.x - 1, y = part.y }

isWithinStage : Stage -> Part -> Bool
isWithinStage {w, h} {x, y} = x >= 0 && y >= 0 && x < w && y < h

part2part : Part -> Part -> Bool
part2part p1 p2 =
  p1.x == p2.x && p1.y == p2.y

stepCollision : Model -> Model
stepCollision model =
  let
    collidesWithStage = not (isWithinStage model.stage model.hd)
    collidesWithSelf = List.any (part2part model.hd) model.tl
  in
    if collidesWithStage || collidesWithSelf then initialModel else model

stepSnake : Model -> Model
stepSnake model =
  let
    hd = stepPart model.direction model.hd
    tl = List.take model.length (model.hd :: model.tl)
  in
    { model | hd = hd, tl = tl }

stepTarget : Model -> Model
stepTarget model =
  if part2part model.hd model.target
  then resetTarget { model | length = model.length + 1 }
  else model
    
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    Downs code ->
      ({model | lastKey = Just code}, Cmd.none )
    Tick ->
      (stepTarget (stepCollision (stepSnake (updateDirection model))), Cmd.none)

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ Keyboard.downs (\code -> Downs (fromCode code))
    , Time.every (millisecond * 250) (\_-> Tick)
    ]

main : Program Never Model Msg
main =
  program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }
