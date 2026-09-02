
# Datos de entrada

Los datos originales utilizados para la validación del gemelo digital proceden de registros reales del vehículo de referencia y no se distribuyen en la versión pública del repositorio.

Para ejecutar los módulos que dependen de dichos datos, los archivos deben colocarse localmente en las carpetas indicadas a continuación.

## Datos FULL_SOC

Ruta esperada:

`datos_entrada/full_soc/`

Patrón de nombres:

`FULL_SOC_*.xlsx`

Estos archivos contienen la información diaria utilizada como referencia para la evolución del estado de carga y otras variables asociadas a cada jornada.

El identificador situado después de `FULL_SOC_` se utiliza para emparejar cada archivo con el registro Jaltest correspondiente.

Ejemplo:

`FULL_SOC_15ene.xlsx`

debe disponer de:

`jaltest_sample_15ene.xlsx`

## Datos Jaltest

Ruta esperada:

`datos_entrada/jaltest/`

Patrón de nombres:

`jaltest_sample_*.xlsx`

Estos archivos contienen los registros utilizados para reconstruir el perfil de velocidad y las variables necesarias para la simulación y validación del modelo.

## Emparejamiento de jornadas

Los scripts no emparejan los archivos únicamente por su posición dentro de la carpeta. El identificador del día incluido en el nombre del archivo se utiliza para relacionar cada `FULL_SOC` con su correspondiente archivo Jaltest.

Por ejemplo:

`FULL_SOC_15ene.xlsx`

se empareja con:

`jaltest_sample_15ene.xlsx`

Si no existe el archivo Jaltest correspondiente, el script informa del problema y no procesa esa jornada.

## Confidencialidad

Los archivos originales `FULL_SOC_*.xlsx` y `jaltest_sample_*.xlsx` no forman parte del repositorio público.

Las carpetas de entrada se conservan mediante archivos `.gitkeep`, mientras que `.gitignore` impide incorporar accidentalmente los datos originales al control de versiones.

## Resultados generados

Los scripts almacenan sus salidas en:

`resultados/modelo_energetico/`

`resultados/prediccion_autonomia/`

`resultados/supervision_indicadores/`

`resultados/escenarios/`

Estas carpetas contienen resultados generados durante la ejecución y no son necesarias para disponer del código fuente del proyecto.
