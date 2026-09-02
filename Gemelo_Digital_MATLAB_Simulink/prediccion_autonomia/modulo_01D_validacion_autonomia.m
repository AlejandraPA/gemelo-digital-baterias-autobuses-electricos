%% MODULO 01D - MODELO MEJORADO DE PREDICCION DE AUTONOMIA
% Este modulo predice la autonomia final usando:
% autonomia inicial real + distancia + factor medio de perdida de autonomia
%
% Objetivo:
% comparar autonomia final prevista contra autonomia final real
% sin volver a usar SOC.

clc

%% 1. Rutas del proyecto y carga de la tabla de validacion

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

resultados_dir = fullfile(project_dir, 'resultados', 'prediccion_autonomia');

if ~isfolder(resultados_dir)
    mkdir(resultados_dir);
end

archivo_validacion = fullfile( ...
    project_dir, ...
    'resultados', ...
    'modelo_energetico', ...
    'validacion_modelo_multidia_estacional.csv');

if isfile(archivo_validacion)
    validacion = readtable(archivo_validacion);
    disp("Tabla validacion cargada desde CSV.")
else
    error(['No se encuentra el archivo de validacion: ', ...
        archivo_validacion, newline, ...
        'Ejecuta primero modelo_energetico/validar_modelo_multidia.m.'])
end

%% 2. Crear Dia_limpio si no existe

if ~ismember('Dia_limpio', validacion.Properties.VariableNames)
    dias = string(validacion.Dia);
    dias = erase(dias, "FULL_SOC_");
    dias = erase(dias, ".xlsx");
    validacion.Dia_limpio = dias;
end

%% 3. Crear Estacion si no existe

if ~ismember('Estacion', validacion.Properties.VariableNames)

    estacion = strings(height(validacion),1);

    for i = 1:height(validacion)
        if contains(validacion.Dia_limpio(i), "ene")
            estacion(i) = "Invierno";
        elseif contains(validacion.Dia_limpio(i), "jul")
            estacion(i) = "Verano";
        else
            estacion(i) = "Desconocida";
        end
    end

    validacion.Estacion = estacion;
end

%% 4. Leer autonomia inicial y final real desde archivos FULL_SOC

soc_dir = fullfile(project_dir, 'datos_entrada', 'full_soc');
soc_files = dir(fullfile(soc_dir, 'FULL_SOC_*.xlsx'));

if isempty(soc_files)
    error(['No se encontraron archivos FULL_SOC_*.xlsx en ', ...
        fullfile('datos_entrada', 'full_soc')]);
end

autonomia_ini_real = nan(height(validacion),1);
autonomia_fin_real = nan(height(validacion),1);

for i = 1:height(validacion)

    dia = validacion.Dia_limpio(i);
    nombre_buscado = "FULL_SOC_" + dia + ".xlsx";

    idx_file = find(strcmp(string({soc_files.name}), nombre_buscado), 1);

    if isempty(idx_file)
        warning("No se encuentra archivo para el dia %s", dia)
        continue
    end

    archivo = soc_files(idx_file).name;

    soc_dia = readtable( ...
        fullfile(soc_files(idx_file).folder, soc_files(idx_file).name));

    if ~ismember('autonomia', soc_dia.Properties.VariableNames)
        warning("El archivo %s no tiene columna autonomia.", archivo)
        continue
    end

    aut = soc_dia.autonomia;

    % Conversión robusta a número
    if iscell(aut) || isstring(aut)
        aut = strrep(string(aut), ",", ".");
        aut = str2double(aut);
    end

    aut = double(aut);
    aut = aut(~isnan(aut));

    if isempty(aut)
        warning("No hay datos validos de autonomia en %s", archivo)
        continue
    end

    autonomia_ini_real(i) = aut(1);
    autonomia_fin_real(i) = aut(end);
end

validacion.Autonomia_ini_real_km = autonomia_ini_real;
validacion.Autonomia_fin_real_km = autonomia_fin_real;

%% 5. Calcular perdida real de autonomia por km recorrido

validacion.Perdida_autonomia_km = validacion.Autonomia_ini_real_km - validacion.Autonomia_fin_real_km;

validacion.Factor_perdida_autonomia = validacion.Perdida_autonomia_km ./ validacion.Dist_km;

% Limpiar factores no validos
validacion.Factor_perdida_autonomia(validacion.Factor_perdida_autonomia < 0) = NaN;
validacion.Factor_perdida_autonomia(validacion.Factor_perdida_autonomia > 3) = NaN;

%% 6. Calcular factor medio por estacion

factor_inv = mean(validacion.Factor_perdida_autonomia(validacion.Estacion == "Invierno"), 'omitnan');
factor_ver = mean(validacion.Factor_perdida_autonomia(validacion.Estacion == "Verano"), 'omitnan');
factor_global = mean(validacion.Factor_perdida_autonomia, 'omitnan');

fprintf("\n=== FACTORES DE PERDIDA DE AUTONOMIA ===\n")
fprintf("Factor medio invierno: %.3f km autonomia / km recorrido\n", factor_inv)
fprintf("Factor medio verano: %.3f km autonomia / km recorrido\n", factor_ver)
fprintf("Factor medio global: %.3f km autonomia / km recorrido\n", factor_global)

%% 7. Prediccion usando factor estacional

factor_pred = nan(height(validacion),1);

for i = 1:height(validacion)

    if validacion.Estacion(i) == "Invierno"
        factor_pred(i) = factor_inv;

    elseif validacion.Estacion(i) == "Verano"
        factor_pred(i) = factor_ver;

    else
        factor_pred(i) = factor_global;
    end
end

validacion.Factor_pred_autonomia = factor_pred;

validacion.Autonomia_fin_prevista_v2_km = ...
    validacion.Autonomia_ini_real_km - validacion.Factor_pred_autonomia .* validacion.Dist_km;

% No permitimos autonomia negativa por coherencia
validacion.Autonomia_fin_prevista_v2_km(validacion.Autonomia_fin_prevista_v2_km < 0) = 0;

%% 8. Error de prediccion

validacion.Error_autonomia_v2_km = ...
    validacion.Autonomia_fin_prevista_v2_km - validacion.Autonomia_fin_real_km;

RMSE_aut_v2 = sqrt(mean(validacion.Error_autonomia_v2_km.^2, 'omitnan'));
MAE_aut_v2 = mean(abs(validacion.Error_autonomia_v2_km), 'omitnan');
Error_medio_aut_v2 = mean(validacion.Error_autonomia_v2_km, 'omitnan');

fprintf("\n=== VALIDACION AUTONOMIA V2 ===\n")
fprintf("RMSE autonomia V2: %.3f km\n", RMSE_aut_v2)
fprintf("MAE autonomia V2: %.3f km\n", MAE_aut_v2)
fprintf("Error medio autonomia V2: %.3f km\n", Error_medio_aut_v2)

%% 9. Clasificacion segun autonomia final prevista

umbral_aviso_km = 30;
umbral_critico_km = 0;

estado_autonomia_v2 = strings(height(validacion),1);

for i = 1:height(validacion)

    if validacion.Autonomia_fin_prevista_v2_km(i) <= umbral_critico_km
        estado_autonomia_v2(i) = "Critico";

    elseif validacion.Autonomia_fin_prevista_v2_km(i) < umbral_aviso_km
        estado_autonomia_v2(i) = "Aviso";

    else
        estado_autonomia_v2(i) = "Normal";
    end
end

validacion.Estado_autonomia_v2 = estado_autonomia_v2;

%% 10. Tabla resumen

tabla_autonomia_v2 = validacion(:, {'Dia_limpio','Estacion','Dist_km', ...
    'Autonomia_ini_real_km','Autonomia_fin_real_km', ...
    'Factor_perdida_autonomia','Factor_pred_autonomia', ...
    'Autonomia_fin_prevista_v2_km','Error_autonomia_v2_km', ...
    'Estado_autonomia_v2'});

tabla_autonomia_v2 = sortrows(tabla_autonomia_v2, 'Error_autonomia_v2_km', 'ascend');

disp("=== TABLA AUTONOMIA V2 ===")
disp(tabla_autonomia_v2)

archivo_salida = fullfile( ...
    resultados_dir, ...
    'validacion_autonomia_v2.csv');

writetable(tabla_autonomia_v2, archivo_salida);

fprintf("Archivo guardado: %s\n", archivo_salida)