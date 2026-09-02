let
    // ============================================================
    // API PGP - COORDINADOR ELÉCTRICO NACIONAL
    //
    // Obtiene solicitudes IRS desde:
    // https://pgp.coordinador.cl/api/request/irs
    //
    // Optimizado para:
    // - Reducir uso de memoria
    // - Evitar expansiones innecesarias
    // - Manejar errores de conexión
    // - Consultar únicamente las páginas existentes
    // ============================================================


    // ============================================================
    // CONFIGURACIÓN
    // ============================================================
    BaseUrl = "https://pgp.coordinador.cl",
    Endpoint = "api/request/irs",

    // Cantidad de registros solicitados por página.
    // 1000 es un buen equilibrio entre memoria y número de llamadas.
    PageSize = 1000,


    // ============================================================
    // ESTRUCTURA DE TABLA VACÍA
    // ============================================================
    EmptyTable =
        #table(
            type table [
                correlativo = nullable text,
                id = nullable text,
                name = nullable text
            ],
            {}
        ),


    // ============================================================
    // FUNCIÓN: ITEMS -> TABLA
    //
    // Extrae solamente:
    // - correlativo
    // - id
    // - name
    //
    // Esto evita convertir y expandir todas las propiedades
    // disponibles en el JSON.
    // ============================================================
    ItemsToTable = (Items as any) as table =>
        let
            SafeItems =
                if Value.Is(Items, type list) then
                    Items
                else
                    {},

            ReducedRecords =
                List.Transform(
                    SafeItems,
                    each
                        if Value.Is(_, type record) then
                            [
                                correlativo =
                                    try
                                        Text.From(
                                            Record.FieldOrDefault(
                                                _,
                                                "correlativo",
                                                null
                                            )
                                        )
                                    otherwise
                                        null,

                                id =
                                    try
                                        Text.From(
                                            Record.FieldOrDefault(
                                                _,
                                                "id",
                                                null
                                            )
                                        )
                                    otherwise
                                        null,

                                name =
                                    try
                                        Text.From(
                                            Record.FieldOrDefault(
                                                _,
                                                "name",
                                                null
                                            )
                                        )
                                    otherwise
                                        null
                            ]
                        else
                            null
                ),

            ValidRecords =
                List.RemoveNulls(
                    ReducedRecords
                ),

            Result =
                if List.Count(ValidRecords) > 0 then
                    Table.FromRecords(
                        ValidRecords,
                        type table [
                            correlativo = nullable text,
                            id = nullable text,
                            name = nullable text
                        ]
                    )
                else
                    EmptyTable
        in
            Result,


    // ============================================================
    // FUNCIÓN: CONSULTAR UNA PÁGINA
    //
    // Si ocurre:
    // - error DNS
    // - timeout
    // - error HTTP
    // - respuesta JSON inválida
    //
    // devuelve null y permite continuar.
    // ============================================================
    GetPage = (PageNumber as number) as nullable record =>
        let
            Response =
                try
                    Json.Document(
                        Web.Contents(
                            BaseUrl,
                            [
                                RelativePath = Endpoint,

                                Query = [
                                    page = Text.From(PageNumber),
                                    page_size = Text.From(PageSize)
                                ],

                                Headers = [
                                    Accept = "application/json"
                                ],

                                Timeout = #duration(
                                    0,
                                    0,
                                    2,
                                    0
                                )
                            ]
                        ),
                        65001
                    )
                otherwise
                    null,

            ValidResponse =
                if
                    Response <> null
                    and Value.Is(Response, type record)
                then
                    Response
                else
                    null
        in
            ValidResponse,


    // ============================================================
    // PRIMERA CONSULTA
    //
    // Se utiliza para:
    // 1. Obtener los primeros registros
    // 2. Obtener total_pages
    //
    // Así evitamos consultar la página 1 dos veces.
    // ============================================================
    FirstResponse =
        GetPage(1),


    // ============================================================
    // TOTAL DE PÁGINAS
    // ============================================================
    TotalPages =
        if FirstResponse <> null then
            try
                Number.From(
                    Record.FieldOrDefault(
                        FirstResponse,
                        "total_pages",
                        0
                    )
                )
            otherwise
                0
        else
            0,


    // ============================================================
    // PRIMERA PÁGINA -> TABLA
    // ============================================================
    FirstPageTable =
        if FirstResponse <> null then
            ItemsToTable(
                Record.FieldOrDefault(
                    FirstResponse,
                    "items",
                    {}
                )
            )
        else
            EmptyTable,


    // ============================================================
    // LISTA DE PÁGINAS RESTANTES
    //
    // Página 1 ya fue procesada.
    // ============================================================
    RemainingPages =
        if TotalPages > 1 then
            {2..TotalPages}
        else
            {},


    // ============================================================
    // DESCARGAR Y PROCESAR CADA PÁGINA
    //
    // Cada JSON se reduce inmediatamente a tres columnas.
    // De esta manera evitamos almacenar todos los JSON completos
    // antes de procesarlos.
    // ============================================================
    OtherPageTables =
        List.Transform(
            RemainingPages,

            (CurrentPage as number) =>
                let
                    Response =
                        GetPage(CurrentPage),

                    Items =
                        if Response <> null then
                            Record.FieldOrDefault(
                                Response,
                                "items",
                                {}
                            )
                        else
                            {},

                    PageTable =
                        ItemsToTable(Items)
                in
                    PageTable
        ),


    // ============================================================
    // UNIR TODAS LAS PÁGINAS
    // ============================================================
    TablesToCombine =
        List.Combine(
            {
                {FirstPageTable},
                OtherPageTables
            }
        ),

    Combined =
        if List.Count(TablesToCombine) > 0 then
            Table.Combine(
                TablesToCombine
            )
        else
            EmptyTable,


    // ============================================================
    // FILTRAR FILAS COMPLETAMENTE VACÍAS
    // ============================================================
    FilteredRows =
        Table.SelectRows(
            Combined,
            each
                [id] <> null
                or [correlativo] <> null
                or [name] <> null
        ),


    // ============================================================
    // ELIMINAR DUPLICADOS
    //
    // Si el ID es único, evita duplicados producidos por
    // solapamientos entre páginas o cambios durante la consulta.
    // ============================================================
    RemoveDuplicates =
        Table.Distinct(
            FilteredRows,
            {"id"}
        ),


    // ============================================================
    // ORDEN FINAL DE COLUMNAS
    // ============================================================
    Result =
        Table.ReorderColumns(
            RemoveDuplicates,
            {
                "correlativo",
                "id",
                "name"
            }
        )

in
    Result
