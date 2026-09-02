let
    // ============================================================
    // API INFOTÉCNICA - ELEMENTOS DE UNA SUBESTACIÓN
    // ============================================================
    // Este ejemplo obtiene los elementos asociados a una
    // subestación desde la API de Infotécnica.
    //
    // ID de subestación utilizado en este ejemplo: 560
    // Para consultar otra subestación, reemplazar el ID.
    // ============================================================

    IdSubestacion = "560",

    // Construcción del endpoint
    Origen = Json.Document(
        Web.Contents(
            "https://api-infotecnica.coordinador.cl",
            [
                RelativePath = 
                    "v1/subestaciones/" 
                    & IdSubestacion 
                    & "/elementos/"
            ]
        )
    ),

    // Obtiene la lista de elementos desde el JSON
    Elementos = Origen[elementos],

    // Convierte la lista en tabla
    Tabla = Table.FromList(
        Elementos,
        Splitter.SplitByNothing(),
        null,
        null,
        ExtraValues.Error
    ),

    // Expande la estructura principal
    ExpandirElemento = Table.ExpandRecordColumn(
        Tabla,
        "Column1",
        {"tipo", "datos", "slug"},
        {"tipo", "datos", "slug"}
    ),

    // Expande la lista de datos
    ExpandirDatosLista = Table.ExpandListColumn(
        ExpandirElemento,
        "datos"
    ),

    // Expande los campos necesarios de cada elemento
    ExpandirDatos = Table.ExpandRecordColumn(
        ExpandirDatosLista,
        "datos",
        {
            "id",
            "nemotecnico",
            "nombre"
        },
        {
            "id",
            "nemotecnico",
            "nombre"
        }
    ),

    // Selecciona las columnas finales
    Resultado = Table.SelectColumns(
        ExpandirDatos,
        {
            "tipo",
            "id",
            "nombre",
            "nemotecnico"
        }
    )

in
    Resultado
