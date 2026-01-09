port module Main exposing (main)

import Browser
import Dict exposing (Dict)
import File exposing (File)
import File.Select as Select
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode



-- PORTS


port downloadCsv : Encode.Value -> Cmd msg



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { allHeaders : List String
    , data : List RowData
    , dropdownOptions : DropdownOptions
    , loading : Bool
    , errorMessage : Maybe String
    , showTable : Bool
    , batchShipDate : String
    }


type alias RowData =
    Dict String String


type alias DropdownOptions =
    Dict String (List OptionItem)


type alias OptionItem =
    { value : String
    , text : String
    }


type alias ColumnDef =
    { field : String
    , label : String
    , row : Int
    }


staticDropdownOptions : DropdownOptions
staticDropdownOptions =
    Dict.fromList
        [ ( "送り状種類"
          , [ { value = "0", text = "発払い" }
            , { value = "8", text = "コンパクト" }
            , { value = "A", text = "ネコポス" }
            ]
          )
        , ( "配達時間帯"
          , [ { value = "", text = "指定なし" }
            , { value = "0812", text = "午前中" }
            , { value = "1416", text = "14～16時" }
            , { value = "1618", text = "16～18時" }
            , { value = "1820", text = "18～20時" }
            , { value = "1921", text = "19～21時" }
            ]
          )
        , ( "荷扱い１"
          , [ { value = "", text = "（空白）" }
            , { value = "精密機器", text = "精密機器" }
            , { value = "ワレ物注意", text = "ワレ物注意" }
            , { value = "下積現金", text = "下積現金" }
            , { value = "天地無用", text = "天地無用" }
            , { value = "ナマモノ", text = "ナマモノ" }
            , { value = "水濡厳禁", text = "水濡厳禁" }
            ]
          )
        , ( "荷扱い２"
          , [ { value = "", text = "（空白）" }
            , { value = "精密機器", text = "精密機器" }
            , { value = "ワレ物注意", text = "ワレ物注意" }
            , { value = "下積現金", text = "下積現金" }
            , { value = "天地無用", text = "天地無用" }
            , { value = "ナマモノ", text = "ナマモノ" }
            , { value = "水濡厳禁", text = "水濡厳禁" }
            ]
          )
        ]


init : () -> ( Model, Cmd Msg )
init _ =
    ( { allHeaders = []
      , data = []
      , dropdownOptions = staticDropdownOptions
      , loading = False
      , errorMessage = Nothing
      , showTable = False
      , batchShipDate = ""
      }
    , Cmd.none
    )



-- MESSAGES


type Msg
    = FileRequested
    | FileSelected File
    | FileUploaded (Result Http.Error UploadResponse)
    | UpdateField String String String -- rowId, fieldName, value
    | BatchShipDateChanged String
    | ApplyBatchShipDate
    | SaveClicked


type alias UploadResponse =
    { headers : List String
    , data : List RowData
    }



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FileRequested ->
            ( model, Select.file [ "text/csv" ] FileSelected )

        FileSelected file ->
            ( { model | loading = True, errorMessage = Nothing }
            , uploadFile file
            )

        FileUploaded (Ok response) ->
            ( { model
                | allHeaders = response.headers
                , data = response.data
                , loading = False
                , showTable = True
                , errorMessage = Nothing
              }
            , Cmd.none
            )

        FileUploaded (Err error) ->
            ( { model
                | loading = False
                , errorMessage = Just (httpErrorToString error)
              }
            , Cmd.none
            )

        UpdateField rowId fieldName value ->
            ( { model | data = updateRowField model.data rowId fieldName value }
            , Cmd.none
            )

        BatchShipDateChanged date ->
            ( { model | batchShipDate = date }, Cmd.none )

        ApplyBatchShipDate ->
            if String.isEmpty model.batchShipDate then
                ( model, Cmd.none )

            else
                let
                    formattedDate =
                        String.replace "-" "/" model.batchShipDate

                    updatedData =
                        List.map
                            (\row -> Dict.insert "出荷予定日" formattedDate row)
                            model.data
                in
                ( { model | data = updatedData }, Cmd.none )

        SaveClicked ->
            ( model
            , downloadCsv
                (Encode.object
                    [ ( "headers", Encode.list Encode.string model.allHeaders )
                    , ( "data", Encode.list encodeRowData model.data )
                    ]
                )
            )


updateRowField : List RowData -> String -> String -> String -> List RowData
updateRowField data rowId fieldName value =
    List.map
        (\row ->
            case Dict.get "__id" row of
                Just id ->
                    if id == rowId then
                        Dict.insert fieldName value row

                    else
                        row

                Nothing ->
                    row
        )
        data


httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            "無効なURL: " ++ url

        Http.Timeout ->
            "タイムアウト"

        Http.NetworkError ->
            "ネットワークエラー"

        Http.BadStatus status ->
            "サーバーエラー: " ++ String.fromInt status

        Http.BadBody message ->
            "データ解析エラー: " ++ message



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "min-h-screen bg-base-200" ]
        [ navbar
        , div [ class "container mx-auto p-4" ]
            [ viewUploadSection
            , viewEditorControls model
            , viewError model.errorMessage
            , viewLoading model.loading
            , viewTable model
            ]
        ]


navbar : Html Msg
navbar =
    div [ class "navbar bg-base-100 shadow-lg mb-4" ]
        [ div [ class "flex-1" ]
            [ span [ class "text-xl font-bold" ] [ text "ヤマト運輸B2 CSV変換ツール" ]
            ]
        ]


viewUploadSection : Html Msg
viewUploadSection =
    div [ class "card bg-base-100 shadow-xl mb-4" ]
        [ div [ class "card-body" ]
            [ h2 [ class "card-title" ] [ text "1. CSVファイルをアップロード" ]
            , button
                [ class "btn btn-primary"
                , onClick FileRequested
                ]
                [ text "ファイルを選択" ]
            ]
        ]


viewEditorControls : Model -> Html Msg
viewEditorControls model =
    if not model.showTable then
        text ""

    else
        div [ class "grid grid-cols-1 md:grid-cols-2 gap-4 mb-4" ]
            [ div [ class "card bg-base-100 shadow-xl" ]
                [ div [ class "card-body" ]
                    [ h2 [ class "card-title" ] [ text "2. データ編集" ]
                    , div [ class "form-control" ]
                        [ label [ class "label" ]
                            [ span [ class "label-text" ] [ text "出荷予定日（一括変更）" ]
                            ]
                        , div [ class "flex gap-2" ]
                            [ input
                                [ type_ "date"
                                , class "input input-bordered flex-1"
                                , value model.batchShipDate
                                , onInput BatchShipDateChanged
                                ]
                                []
                            , button
                                [ class "btn btn-secondary"
                                , onClick ApplyBatchShipDate
                                ]
                                [ text "一括適用" ]
                            ]
                        ]
                    ]
                ]
            , div [ class "card bg-base-100 shadow-xl" ]
                [ div [ class "card-body" ]
                    [ h2 [ class "card-title" ] [ text "3. ファイル保存" ]
                    , button
                        [ class "btn btn-success"
                        , onClick SaveClicked
                        ]
                        [ text "CSV形式でダウンロード" ]
                    ]
                ]
            ]


viewError : Maybe String -> Html Msg
viewError maybeError =
    case maybeError of
        Nothing ->
            text ""

        Just error ->
            div [ class "alert alert-error mb-4" ]
                [ text error ]


viewLoading : Bool -> Html Msg
viewLoading isLoading =
    if isLoading then
        div [ class "flex justify-center items-center p-8" ]
            [ span [ class "loading loading-spinner loading-lg" ] []
            ]

    else
        text ""


viewTable : Model -> Html Msg
viewTable model =
    if not model.showTable then
        text ""

    else
        div [ class "space-y-2" ]
            [ viewTableHeader model.allHeaders
            , div [ class "space-y-1" ]
                (List.map (viewDataRow model.dropdownOptions model.allHeaders) model.data)
            ]


viewTableHeader : List String -> Html Msg
viewTableHeader headers =
    let
        activeColumns =
            List.filter (\col -> List.member col.field headers) columnLayout

        row1Cols =
            List.filter (\col -> col.row == 1) activeColumns

        row2Cols =
            List.filter (\col -> col.row == 2) activeColumns
    in
    div [ class "bg-base-200 rounded-lg p-2" ]
        [ div [ class "grid grid-cols-[6rem_8rem_8rem_8rem_1fr_6rem_1fr] gap-x-1" ]
            (List.map viewHeaderCell row1Cols)
        , div [ class "grid grid-cols-[8rem_5rem_1fr_1fr_8rem_8rem] gap-x-1" ]
            (List.map viewHeaderCell row2Cols)
        ]


viewHeaderCell : ColumnDef -> Html Msg
viewHeaderCell col =
    div [ class "text-sm text-center font-semibold py-1 border-b border-collapse border-gray-400" ]
        [ text col.label ]


viewDataRow : DropdownOptions -> List String -> RowData -> Html Msg
viewDataRow options headers row =
    let
        activeColumns =
            List.filter (\col -> List.member col.field headers) columnLayout

        row1Cols =
            List.filter (\col -> col.row == 1) activeColumns

        row2Cols =
            List.filter (\col -> col.row == 2) activeColumns

        rowId =
            Dict.get "__id" row |> Maybe.withDefault ""
    in
    div [ class "bg-base-100 rounded-lg p-2 shadow-sm hover:shadow-md transition-shadow space-y-1" ]
        [ div [ class "grid gap-1 grid-cols-[6rem_8rem_8rem_8rem_1fr_6rem_1fr] " ]
            (List.map (viewDataCell options rowId row) row1Cols)
        , div [ class "grid gap-1 grid-cols-[8rem_5rem_1fr_1fr_8rem_8rem]" ]
            (List.map (viewDataCell options rowId row) row2Cols)
        ]


viewDataCell : DropdownOptions -> String -> RowData -> ColumnDef -> Html Msg
viewDataCell options rowId row col =
    let
        value =
            Dict.get col.field row |> Maybe.withDefault ""
    in
    if isEditableField col.field then
        viewEditableInput options rowId col.field value

    else
        div [ class "text-sm" ] [ text value ]


isEditableField : String -> Bool
isEditableField field =
    List.member field editableFields


editableFields : List String
editableFields =
    [ "出荷予定日"
    , "送り状種類"
    , "お届け先電話番号"
    , "お届け予定日"
    , "配達時間帯"
    , "お届け先郵便番号"
    , "お届け先住所"
    , "お届け先アパートマンション名"
    , "お届け先名"
    , "品名１"
    , "荷扱い１"
    , "荷扱い２"
    ]


viewEditableInput : DropdownOptions -> String -> String -> String -> Html Msg
viewEditableInput options rowId fieldName value =
    if fieldName == "出荷予定日" || fieldName == "お届け予定日" then
        input
            [ type_ "date"
            , class "input input-bordered input-sm w-full"
            , Html.Attributes.value (String.replace "/" "-" value)
            , onInput (\v -> UpdateField rowId fieldName (String.replace "-" "/" v))
            ]
            []

    else
        case Dict.get fieldName options of
            Just opts ->
                if fieldName == "荷扱い１" || fieldName == "荷扱い２" then
                    let
                        datalistId =
                            fieldName ++ "-" ++ rowId
                    in
                    div []
                        [ input
                            [ type_ "text"
                            , class "input input-bordered input-sm w-full"
                            , Html.Attributes.value value
                            , onInput (UpdateField rowId fieldName)
                            , attribute "list" datalistId
                            ]
                            []
                        , datalist [ id datalistId ]
                            (List.map
                                (\opt ->
                                    option [ Html.Attributes.value opt.text ] []
                                )
                                opts
                            )
                        ]

                else
                    select
                        [ class "select select-bordered select-sm w-full"
                        , onInput (UpdateField rowId fieldName)
                        ]
                        (List.map
                            (\opt ->
                                option
                                    [ Html.Attributes.value opt.value
                                    , selected (opt.value == value)
                                    ]
                                    [ text opt.text ]
                            )
                            opts
                        )

            Nothing ->
                input
                    [ type_ "text"
                    , class "input input-bordered input-sm w-full"
                    , Html.Attributes.value value
                    , onInput (UpdateField rowId fieldName)
                    ]
                    []


columnLayout : List ColumnDef
columnLayout =
    [ { field = "お客様管理番号", label = "管理番号", row = 1 }
    , { field = "出荷予定日", label = "出荷日", row = 1 }
    , { field = "お届け予定日", label = "配達日", row = 1 }
    , { field = "配達時間帯", label = "配達時間帯", row = 1 }
    , { field = "品名１", label = "品名１", row = 1 }
    , { field = "送り状種類", label = "送り状種類", row = 1 }
    , { field = "お届け先名", label = "お届け先名", row = 1 }

    --
    , { field = "お届け先電話番号", label = "電話番号", row = 2 }
    , { field = "お届け先郵便番号", label = "郵便番号", row = 2 }
    , { field = "お届け先住所", label = "住所", row = 2 }
    , { field = "お届け先アパートマンション名", label = "アパマン名", row = 2 }
    , { field = "荷扱い１", label = "荷扱1", row = 2 }
    , { field = "荷扱い２", label = "荷扱2", row = 2 }
    ]



-- HTTP


uploadFile : File -> Cmd Msg
uploadFile file =
    Http.post
        { url = "/upload"
        , body = Http.multipartBody [ Http.filePart "file" file ]
        , expect = Http.expectJson FileUploaded uploadResponseDecoder
        }



-- DECODERS


uploadResponseDecoder : Decoder UploadResponse
uploadResponseDecoder =
    Decode.map2 UploadResponse
        (Decode.field "headers" (Decode.list Decode.string))
        (Decode.field "data" (Decode.list rowDataDecoder))


rowDataDecoder : Decoder RowData
rowDataDecoder =
    Decode.dict Decode.string



-- ENCODERS


encodeRowData : RowData -> Encode.Value
encodeRowData row =
    Encode.dict identity Encode.string row



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
