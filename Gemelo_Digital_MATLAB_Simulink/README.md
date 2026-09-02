
# Gemelo digital MATLAB/Simulink

Este directorio contiene el bloque MATLAB/Simulink desarrollado para el seguimiento, validación y apoyo al mantenimiento predictivo de baterías en autobuses eléctricos.

El núcleo del proyecto es un modelo integrado en Simulink, complementado por scripts MATLAB para validación energética multidía, predicción de autonomía, generación de indicadores de supervisión y evaluación de escenarios.

## Estructura

```text
Gemelo_Digital_MATLAB_Simulink/
├── ejecutar_gemelo_digital.m
├── simulink/
│   ├── modelo_gemelo_digital.slx
│   ├── cargar_datos_dia.m
│   └── generar_I_eq_signal.m
├── modelo_energetico/
│   └── validar_modelo_multidia.m
├── prediccion_autonomia/
│   ├── prediccion_autonomia.m
│   ├── modulo_01D_validacion_autonomia.m
│   ├── modulo_01F_autonomia_leave_one_out.m
│   ├── modulo_01G_autonomia_regresion_LOO.m
│   └── figuras_punto1_prediccion_autonomia.m
├── supervision_indicadores/
│   ├── modulo_02_indice_estado_sistema.m
│   └── modulo_03_capacidad_efectiva_soh.m
├── escenarios/
│   ├── modulo_05A_what_if_monte_carlo.m
│   └── modulo_05B_what_if_detallado_por_dia.m
├── datos_entrada/
├── resultados/
└── documentacion/
    └── DATOS.md
```

## Modelo Simulink

El archivo principal es:

`simulink/modelo_gemelo_digital.slx`

El modelo integra los principales bloques funcionales del gemelo digital, incluyendo el tratamiento de la demanda de corriente, el comportamiento equivalente de la batería, la sensorización y la lógica de supervisión.

La corriente utilizada como entrada del modelo se construye a partir de una corriente de demanda intermedia:

`I_demanda`

sobre la que se aplican el factor de ajuste y la corriente auxiliar:

`I_eq = α · I_demanda + I_aux`

La señal final utilizada por Simulink se almacena como:

`I_eq_signal`

Por tanto:

* `I_demanda` representa la corriente intermedia previa a los ajustes.
* `I_eq` representa la corriente equivalente final.
* `I_eq_signal` es la señal temporal de `I_eq` utilizada como entrada del modelo Simulink.

## Ejecución del gemelo digital

El punto de entrada recomendado es:

```matlab
ejecutar_gemelo_digital
```

Este script:

1. configura las rutas del proyecto;
2. selecciona una jornada;
3. carga los archivos `FULL_SOC` y Jaltest correspondientes al mismo día;
4. genera `I_eq_signal`;
5. abre `modelo_gemelo_digital.slx`.

Por defecto se utiliza:

```matlab
indice_dia = 1;
```

Para seleccionar otra jornada puede definirse previamente otro índice válido en el workspace.

El script abre el modelo, pero no inicia automáticamente la simulación.

## Datos de entrada

Los datos originales no se distribuyen en el repositorio público.

Deben colocarse localmente en:

```text
datos_entrada/full_soc/
datos_entrada/jaltest/
```

con los patrones:

```text
FULL_SOC_*.xlsx
jaltest_sample_*.xlsx
```

Los archivos se emparejan mediante el identificador de jornada incluido en el nombre y no únicamente por su posición dentro de las carpetas.

La descripción detallada de los datos y de su organización se encuentra en:

`documentacion/DATOS.md`

## Validación del modelo energético

El script:

`modelo_energetico/validar_modelo_multidia.m`

realiza la validación multidía del modelo utilizando los registros reales disponibles.

El resultado principal se genera en:

```text
resultados/modelo_energetico/validacion_modelo_multidia_estacional.csv
```

Este archivo sirve posteriormente como entrada para otros módulos del proyecto.

## Predicción de autonomía

Los scripts incluidos en `prediccion_autonomia/` desarrollan diferentes etapas del análisis de autonomía:

* estimación del margen operativo;
* validación frente a la autonomía real;
* validación Leave-One-Out;
* regresión Leave-One-Out;
* generación de las figuras finales asociadas.

Las salidas se almacenan en:

```text
resultados/prediccion_autonomia/
```

## Supervisión e indicadores

Los scripts de `supervision_indicadores/` generan indicadores derivados de los resultados del modelo y de la predicción de autonomía.

Incluyen:

* índice de estado del sistema;
* penalizaciones asociadas;
* capacidad efectiva estimada;
* indicador de SOH aparente.

El SOH incluido en este bloque debe interpretarse como un indicador derivado del comportamiento observado y de las hipótesis adoptadas en el modelo, no como una medición electroquímica certificada del estado de salud real de la batería.

Las salidas se almacenan en:

```text
resultados/supervision_indicadores/
```

## Escenarios

El directorio `escenarios/` incluye dos niveles de análisis:

### Monte Carlo

`modulo_05A_what_if_monte_carlo.m`

Genera 10.000 escenarios para evaluar la respuesta del sistema ante variaciones de las condiciones consideradas.

### Escenarios detallados por jornada

`modulo_05B_what_if_detallado_por_dia.m`

Combina los resultados de validación, autonomía, índice de estado y SOH aparente para estudiar escenarios específicos por jornada.

Las salidas se almacenan en:

```text
resultados/escenarios/
```

## Requisitos

El modelo fue desarrollado con MATLAB y Simulink.

El archivo `.slx` utilizado en esta versión del proyecto fue guardado con MATLAB/Simulink R2026a.

Para reproducir completamente el proyecto se requiere:

* MATLAB;
* Simulink;
* acceso a los datos de entrada originales no incluidos en el repositorio.

Algunos scripts emplean funciones estándar de tratamiento de tablas, regresión, generación de figuras y análisis estadístico disponibles en MATLAB.

## Resultados generados

Los resultados no se versionan por defecto.

Las carpetas:

```text
resultados/modelo_energetico/
resultados/prediccion_autonomia/
resultados/supervision_indicadores/
resultados/escenarios/
```

se mantienen mediante archivos `.gitkeep`, mientras que `.gitignore` evita incorporar automáticamente los archivos generados.

## Confidencialidad

Los datos originales empleados para validar el gemelo digital proceden de registros reales y no forman parte de la versión pública del repositorio.

El código se publica de forma separada de dichos datos para permitir revisar la metodología, la arquitectura y la lógica de cálculo sin distribuir información de origen privado.

## Relación con el proyecto Streamlit

Este bloque MATLAB/Simulink y el proyecto Streamlit forman parte del mismo Trabajo Fin de Grado, pero cumplen funciones diferentes.

El bloque MATLAB/Simulink contiene el gemelo digital, la validación energética, la predicción de autonomía, los indicadores y los escenarios.

El proyecto Streamlit constituye una aplicación independiente orientada al análisis de ruta, velocidad, paradas, SOC y visualización geográfica.

Ambos bloques se mantienen separados dentro del repositorio para reflejar correctamente su función y sus dependencias.
