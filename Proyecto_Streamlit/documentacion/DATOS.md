# Datos utilizados por el proyecto

## 1. Datos auxiliares incluidos

### `linea11.geojson`

Ruta de referencia de la Línea 11.

El archivo conserva los siguientes metadatos:

- generador: Overpass Turbo;
- fuente: OpenStreetMap;
- licencia indicada en el propio archivo: ODbL;
- fecha de extracción registrada: 2025-08-05.

### `stops.csv`

Archivo auxiliar de paradas utilizado por los scripts de análisis.

Columnas esperadas:

- `stop_id`
- `stop_name`
- `lat`
- `lon`
- `seq`

El fichero no conserva metadatos suficientes para determinar con certeza su fuente original, por lo que el repositorio no atribuye una procedencia concreta.

### `velocidades_tramos.csv`

Archivo derivado de la red viaria de OpenStreetMap mediante `preprocesado/generar_velocidades_tramos.py`.

Columnas:

- `id_tramo`
- `lat1`
- `lon1`
- `lat2`
- `lon2`
- `vel_max`

## 2. Datos privados no incluidos

Los registros originales de operación del vehículo no se distribuyen públicamente.

### `datos_entrada/jaltest/`

Patrón esperado:

```text
jaltest_sample_DDmmm.xlsx
```

Columnas utilizadas por la aplicación y los scripts:

- `date`
- `lat`
- `lon`
- `speed`

De forma opcional puede existir una columna:

- `altitude`

El script `generar_altitudes.py` produce archivos con el patrón:

```text
jaltest_sample_DDmmm_con_altitud.xlsx
```

La aplicación Streamlit prioriza esta versión cuando está disponible.

### `datos_entrada/soc/`

Patrón esperado:

```text
SOC_DDmmm.xlsx
```

El script de integración utiliza al menos:

- `date`

y conserva el resto de variables presentes en el archivo, entre ellas las utilizadas posteriormente para SOC y autonomía.

### `datos_entrada/full_soc/`

Patrón generado:

```text
FULL_SOC_DDmmm.xlsx
```

Para el funcionamiento de la visualización VE se utilizan:

- `date`
- `SOC`
- `autonomia`
- `lat`
- `lon`

Los archivos se generan mediante `preprocesado/generar_full_soc.py`, que sincroniza temporalmente los registros SOC con las coordenadas Jaltest mediante `pandas.merge_asof`.

## 3. Resultados

`analisis/analisis_ruta_linea11.py` genera resultados en:

```text
resultados/analisis_ruta/
```

Pueden incluir:

- `paradas_estado_*.xlsx`
- `desvios_*.xlsx`
- `excesos_velocidad_*.xlsx`
- `analisis_paradas_linea11.html`

Los resultados generados localmente no se versionan por defecto en Git.

## 4. Privacidad

Antes de publicar cualquier archivo adicional debe comprobarse que no contiene registros operativos, identificadores internos, trazas GPS no autorizadas u otra información cuya difusión no esté permitida.
