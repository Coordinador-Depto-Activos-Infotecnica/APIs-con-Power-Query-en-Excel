let
    // Consulta la API de completitud y calidad por empresa
    Origen = Json.Document(
        Web.Contents(
            "http://activos-tx-prod.appspot.com/api/v1/reportes/completitud-calidad-empresa/"
        )
    ),

    // Convierte la respuesta JSON en una tabla
    Tabla = Table.FromList(
        Origen,
        Splitter.SplitByNothing(),
        null,
        null,
        ExtraValues.Error
    ),

    // Expande los campos principales de cada empresa
    Resultado = Table.ExpandRecordColumn(
        Tabla,
        "Column1",
        {
            "id_empresa",
            "nombre_empresa",
            "datos_a_informar",
            "datos_informados",
            "datos_no_informados",
            "datos_certificados",
            "completitud",
            "calidad"
        },
        {
            "id_empresa",
            "nombre_empresa",
            "datos_a_informar",
            "datos_informados",
            "datos_no_informados",
            "datos_certificados",
            "completitud",
            "calidad"
        }
    )
in
    Resultado
