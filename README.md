# Gemelo digital para baterías de autobuses eléctricos

Repositorio asociado al Trabajo Fin de Grado centrado en el desarrollo de un gemelo digital para el seguimiento de baterías en autobuses eléctricos y el apoyo a tareas de supervisión, análisis operativo y mantenimiento predictivo.

El proyecto combina dos desarrollos complementarios pero independientes:

* un **gemelo digital desarrollado en MATLAB/Simulink**, orientado al modelado energético, validación, predicción de autonomía, generación de indicadores y análisis de escenarios;
* una **aplicación desarrollada en Python/Streamlit**, orientada al análisis de ruta, velocidad, paradas, SOC y visualización geográfica.

Ambos bloques se mantienen separados en el repositorio para reflejar correctamente sus distintas funciones, dependencias y flujos de ejecución.

## Estructura del repositorio

```text
gemelo-digital-baterias-autobuses-electricos/
├── Gemelo_Digital_MATLAB_Simulink/
│   ├── simulink/
│   ├── modelo_energetico/
│   ├── prediccion_autonomia/
│   ├── supervision_indicadores/
│   ├── escenarios/
│   ├── datos_entrada/
│   ├── resultados/
│   ├── documentacion/
│   ├── ejecutar_gemelo_digital.m
│   └── README.md
│
└── Proyecto_Streamlit/
    ├── preprocesado/
    ├── analisis/
    ├── analisis_exploratorios/
    ├── datos_auxiliares/
    ├── datos_entrada/
    ├── resultados/
    ├── documentacion/
    ├── app_streamlit_linea11.py
    ├── requirements.txt
    └── README.md
```

Cada bloque contiene su propio `README.md`, con información detallada sobre estructura, requisitos, datos necesarios y procedimiento de ejecución.

## 1. Gemelo digital MATLAB/Simulink

Directorio:

`Gemelo_Digital_MATLAB_Simulink/`

Este bloque contiene el núcleo del gemelo digital y los scripts MATLAB empleados para su análisis y validación.

El modelo integrado se encuentra en:

`Gemelo_Digital_MATLAB_Simulink/simulink/modelo_gemelo_digital.slx`

El punto de entrada recomendado es:

```matlab
ejecutar_gemelo_digital
```

El flujo principal incluye:

1. carga de los datos correspondientes a una jornada;
2. generación de la corriente equivalente de entrada;
3. apertura del modelo Simulink;
4. validación multidía del comportamiento energético;
5. predicción y validación de autonomía;
6. generación de indicadores de supervisión;
7. estimación de indicadores derivados de capacidad efectiva y SOH aparente;
8. análisis de escenarios y simulación Monte Carlo.

### Corriente equivalente

En el modelo se diferencia expresamente entre:

`I_demanda`

Corriente intermedia calculada a partir de las condiciones de operación.

e:

`I_eq`

Corriente equivalente final utilizada por el modelo tras aplicar los ajustes considerados:

`I_eq = α · I_demanda + I_aux`

La señal temporal utilizada como entrada de Simulink se denomina:

`I_eq_signal`

Esta nomenclatura se mantiene de forma coherente entre los scripts MATLAB y el modelo Simulink.

## 2. Aplicación Python/Streamlit

Directorio:

`Proyecto_Streamlit/`

Este bloque contiene una aplicación independiente para el análisis y visualización de información operativa asociada a la línea estudiada.

Entre sus funcionalidades se incluyen:

* representación de la ruta;
* análisis de velocidad;
* comparación con límites de velocidad obtenidos o derivados de OpenStreetMap;
* análisis de paradas;
* detección de posibles desvíos;
* representación de la evolución del SOC;
* análisis de variaciones de SOC;
* generación de información auxiliar de altitud y límites de velocidad;
* análisis exploratorio de autonomía y SOH.

La aplicación principal se ejecuta mediante:

```bash
streamlit run app_streamlit_linea11.py
```

Las instrucciones detalladas de instalación y uso se encuentran en:

`Proyecto_Streamlit/README.md`

## Datos de entrada

Los datos reales originales utilizados durante el desarrollo y la validación no se distribuyen en la versión pública del repositorio.

Entre ellos se encuentran registros de operación, archivos Jaltest y archivos derivados con información de SOC, autonomía y posicionamiento.

Las carpetas correspondientes se mantienen en la estructura mediante archivos `.gitkeep`, mientras que los respectivos `.gitignore` evitan su incorporación accidental al control de versiones.

La documentación específica de los datos puede consultarse en:

`Gemelo_Digital_MATLAB_Simulink/documentacion/DATOS.md`

y:

`Proyecto_Streamlit/documentacion/DATOS.md`

La ausencia de estos archivos limita la reproducción completa de determinadas validaciones con los datos originales, pero permite consultar la arquitectura, metodología, algoritmos y flujo de procesamiento implementados.

## Resultados y alcance

El desarrollo permite estudiar el comportamiento energético del vehículo, contrastar la evolución estimada y real del SOC, analizar la autonomía disponible y generar indicadores orientados a la supervisión del sistema.

El proyecto incorpora además análisis de escenarios y herramientas de apoyo a la evaluación operativa.

Los indicadores de SOH incluidos en el proyecto deben interpretarse dentro de las hipótesis y procedimientos definidos en cada módulo. No constituyen una medición electroquímica certificada del estado de salud real de la batería.

## Tecnologías utilizadas

### MATLAB/Simulink

* MATLAB
* Simulink
* procesamiento de tablas y series temporales
* regresión y validación Leave-One-Out
* análisis estadístico
* simulación Monte Carlo
* generación de indicadores y figuras

El modelo `.slx` incluido en esta versión fue guardado con MATLAB/Simulink R2026a.

### Python

* Python 3.11 o superior
* Streamlit
* pandas
* GeoPandas
* Folium
* OSMnx
* Shapely
* NumPy
* Matplotlib
* OpenPyXL

## OpenStreetMap

Parte de la información geográfica y de la red viaria utilizada por el proyecto procede de OpenStreetMap y de datos derivados de dicha fuente.

© OpenStreetMap contributors.

Los datos de OpenStreetMap están disponibles bajo la Open Database License (ODbL).

La atribución y las condiciones específicas aplicables a los archivos auxiliares se detallan también en el README del proyecto Streamlit.

## Confidencialidad

Este repositorio separa deliberadamente el código desarrollado de los datos originales utilizados durante el Trabajo Fin de Grado.

La publicación del código tiene como objetivo permitir la revisión de:

* la arquitectura del sistema;
* la metodología;
* los algoritmos;
* las relaciones entre módulos;
* el tratamiento de señales;
* y los procedimientos de validación y análisis.

No se distribuyen datos originales de carácter privado o procedentes de registros reales cuya publicación no resulte necesaria para comprender el desarrollo técnico.

## Trabajo Fin de Grado

**Título:** Gemelo digital para el seguimiento y apoyo al mantenimiento predictivo de baterías en autobuses eléctricos.

Repositorio de código asociado al Trabajo Fin de Grado desarrollado en el ámbito de la Ingeniería Electrónica Industrial y Automática.

