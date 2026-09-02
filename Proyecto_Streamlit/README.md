# Análisis georreferenciado de la Línea 11 de autobuses urbanos de León

Este repositorio recoge un proyecto independiente de análisis y visualización georreferenciada de datos de operación de la Línea 11 de autobuses urbanos de León.

El proyecto combina Python, Streamlit, Folium, GeoPandas y OSMnx para representar rutas, velocidades, paradas, desviaciones, estado de carga (SOC), autonomía y algunos análisis exploratorios derivados de los registros disponibles.

## Relación con el TFG

Este proyecto es independiente del repositorio del gemelo digital desarrollado posteriormente en MATLAB/Simulink. Parte del trabajo de análisis georreferenciado y de las visualizaciones sirvió como apoyo exploratorio y antecedente conceptual, pero ambos desarrollos se mantienen separados.

## Funcionalidades principales

- Visualización interactiva de la ruta en Streamlit.
- Representación de la velocidad registrada por tramos.
- Comparación con límites de velocidad obtenidos a partir de OpenStreetMap.
- Identificación de paradas y pasos sin detención.
- Detección de desviaciones respecto a la ruta de referencia.
- Visualización georreferenciada del SOC y la autonomía.
- Identificación exploratoria de variaciones del SOC.
- Generación opcional de altitudes mediante Open-Elevation.
- Generación de archivos `FULL_SOC` mediante sincronización temporal de registros.
- Análisis exploratorio de un indicador de SOH basado en autonomía.

> El indicador de SOH incluido en este proyecto es únicamente exploratorio. No constituye una estimación física del estado de salud de la batería.

> Para este análisis exploratorio se utiliza una autonomía nominal de referencia de 350 km y únicamente se consideran registros con SOC igual o superior al 90 %. El indicador diario se obtiene a partir de la mediana de la autonomía registrada en esas condiciones, expresada respecto a dicha autonomía de referencia. Estos parámetros forman parte del procedimiento exploratorio y no representan valores certificados del vehículo ni una estimación diagnóstica del SOH de la batería.


## Estructura del repositorio

```text
Proyecto_Streamlit/
├── app_streamlit_linea11.py
├── analisis/
│   └── analisis_ruta_linea11.py
├── analisis_exploratorios/
│   └── soh_autonomia_exploratorio.py
├── preprocesado/
│   ├── generar_altitudes.py
│   ├── generar_full_soc.py
│   └── generar_velocidades_tramos.py
├── datos_auxiliares/
│   ├── linea11.geojson
│   ├── stops.csv
│   └── velocidades_tramos.csv
├── datos_entrada/
│   ├── jaltest/
│   ├── soc/
│   └── full_soc/
├── resultados/
│   └── analisis_ruta/
├── documentacion/
│   └── DATOS.md
├── requirements.txt
└── .gitignore
```

## Datos públicos y datos no distribuidos

El repositorio incluye únicamente los archivos auxiliares necesarios que pueden compartirse públicamente.

Los registros originales de operación del vehículo no se distribuyen en este repositorio. Por este motivo, las carpetas `datos_entrada/jaltest/`, `datos_entrada/soc/` y `datos_entrada/full_soc/` se mantienen vacías en la versión pública.

La estructura y los requisitos de estos archivos se explican en `documentacion/DATOS.md`.

## Instalación

Se recomienda utilizar Python 3.11 o superior y trabajar en un entorno virtual.

### Windows

```bash
python -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

## Ejecución de la aplicación Streamlit

Una vez colocados los datos privados necesarios en las carpetas correspondientes:

```bash
streamlit run app_streamlit_linea11.py
```

La aplicación permite seleccionar el día, la hora y el modo de visualización.

## Preprocesado

### Generar archivos FULL_SOC

Colocar:

- archivos `SOC_*.xlsx` en `datos_entrada/soc/`;
- archivos `jaltest_sample_*.xlsx` en `datos_entrada/jaltest/`.

Después ejecutar:

```bash
python preprocesado/generar_full_soc.py
```

Los archivos generados se guardarán en `datos_entrada/full_soc/`.

### Añadir altitud a los registros Jaltest

```bash
python preprocesado/generar_altitudes.py
```

Este script consulta el servicio público Open-Elevation y genera archivos con sufijo `_con_altitud.xlsx`.

Cuando existe una versión enriquecida con altitud para un día, la aplicación Streamlit la prioriza para el análisis exploratorio.

### Regenerar límites de velocidad

```bash
python preprocesado/generar_velocidades_tramos.py
```

Este script utiliza OSMnx/Overpass para consultar la red viaria próxima a la ruta y reconstruir `datos_auxiliares/velocidades_tramos.csv`.

Cuando OpenStreetMap no proporciona un valor maxspeed interpretable para un tramo, el script asigna 50 km/h como valor por defecto. Por tanto, las detecciones de exceso de velocidad asociadas a estos casos deben interpretarse como resultados del procedimiento de análisis y no como una verificación normativa del límite legal aplicable.

## Análisis de ruta fuera de Streamlit

```bash
python analisis/analisis_ruta_linea11.py
```

Los resultados se guardan en:

```text
resultados/analisis_ruta/
```

Entre los resultados posibles se encuentran:

- estado de las paradas por jornada;
- desviaciones respecto a la ruta;
- excesos de velocidad;
- mapa HTML interactivo.

## Fuentes auxiliares

`datos_auxiliares/linea11.geojson` fue generado mediante Overpass Turbo a partir de datos de OpenStreetMap. El propio archivo conserva la atribución a OpenStreetMap y la referencia a la licencia ODbL.

`datos_auxiliares/velocidades_tramos.csv` es un archivo derivado mediante OSMnx a partir de la red viaria de OpenStreetMap.

`datos_auxiliares/stops.csv` es el archivo auxiliar utilizado por el proyecto para representar y ordenar las paradas. El archivo no conserva metadatos suficientes para atribuir con certeza su fuente original.

## Licencias y atribución de datos

Los datos cartográficos procedentes de OpenStreetMap y los archivos derivados de ellos se utilizan con atribución a OpenStreetMap y sus colaboradores, bajo la Open Database License (ODbL).

© OpenStreetMap contributors.

El código desarrollado específicamente para este proyecto se mantiene separado de las condiciones de licencia aplicables a los datos externos utilizados.

## Limitaciones de reproducibilidad

La versión pública permite revisar el código, la arquitectura y los archivos auxiliares, pero la reproducción completa de los resultados requiere los registros originales de operación, que no se distribuyen públicamente.

Además, los scripts que consultan OpenStreetMap/Overpass u Open-Elevation requieren conexión a Internet y dependen de la disponibilidad de dichos servicios.
