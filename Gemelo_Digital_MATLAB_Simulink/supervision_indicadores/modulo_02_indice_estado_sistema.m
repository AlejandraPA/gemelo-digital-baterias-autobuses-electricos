%% MODULO 02 - INDICE DE ESTADO DEL SISTEMA
% Este script calcula un indice de estado operativo del gemelo digital.
%
% Combina:
% - Error RMSE del SOC
% - Error final del SOC
% - Margen operativo previsto
% - Error de prediccion de autonomia
% - Anomalia detectada
%
% Salidas:
% - indice_estado_sistema.csv
% - fig_04_indice_estado_sistema.png
% - fig_05_penalizaciones_indice_estado.png

clc
close all

%% 1. Rutas del proyecto y archivos necesarios

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

resultados_dir = fullfile( ...
    project_dir, ...
    'resultados', ...
    'supervision_indicadores');

if ~isfolder(resultados_dir)
    mkdir(resultados_dir);
end

archivo_validacion = fullfile( ...
    project_dir, ...
    'resultados', ...
    'modelo_energetico', ...
    'validacion_modelo_multidia_estacional.csv');

archivo_margen = fullfile( ...
    project_dir, ...
    'resultados', ...
    'prediccion_autonomia', ...
    'prediccion_previa_margen_estacional.csv');

archivo_autonomia = fullfile( ...
    project_dir, ...
    'resultados', ...
    'prediccion_autonomia', ...
    'validacion_autonomia_regresion_LOO.csv');

if ~isfile(archivo_validacion)
    error("No se encuentra el archivo de validacion: %s", archivo_validacion)
end

if ~isfile(archivo_margen)
    error("No se encuentra el archivo de margen operativo: %s", archivo_margen)
end

if ~isfile(archivo_autonomia)
    error("No se encuentra el archivo de autonomia: %s", archivo_autonomia)
end

%% 2. Cargar tablas

validacion = readtable(archivo_validacion);
margen = readtable(archivo_margen);
autonomia = readtable(archivo_autonomia);

disp("Archivos cargados correctamente.")

%% 3. Crear Dia_limpio en validacion si no existe

if ~ismember('Dia_limpio', validacion.Properties.VariableNames)
    dias = string(validacion.Dia);
    dias = erase(dias, "FULL_SOC_");
    dias = erase(dias, ".xlsx");
    validacion.Dia_limpio = dias;
else
    validacion.Dia_limpio = string(validacion.Dia_limpio);
end

margen.Dia_limpio = string(margen.Dia_limpio);
autonomia.Dia_limpio = string(autonomia.Dia_limpio);

%% 4. Comprobar columnas necesarias

cols_val = {'Dia_limpio','RMSE_SOC','Error_final_SOC','Dist_km'};
cols_margen = {'Dia_limpio','Margen_previsto_km','Estado_previsto'};
cols_aut = {'Dia_limpio','Error_autonomia_reg_LOO_km', ...
            'Autonomia_fin_real_km','Autonomia_fin_prevista_reg_LOO_km'};

for i = 1:length(cols_val)
    if ~ismember(cols_val{i}, validacion.Properties.VariableNames)
        error("Falta en validacion la columna: %s", cols_val{i})
    end
end

for i = 1:length(cols_margen)
    if ~ismember(cols_margen{i}, margen.Properties.VariableNames)
        error("Falta en margen la columna: %s", cols_margen{i})
    end
end

for i = 1:length(cols_aut)
    if ~ismember(cols_aut{i}, autonomia.Properties.VariableNames)
        error("Falta en autonomia la columna: %s", cols_aut{i})
    end
end

%% 5. Seleccionar columnas necesarias

T_val = validacion(:, cols_val);
T_margen = margen(:, cols_margen);
T_aut = autonomia(:, cols_aut);

%% 6. Unir tablas por Dia_limpio

T = join(T_val, T_margen, 'Keys', 'Dia_limpio');
T = join(T, T_aut, 'Keys', 'Dia_limpio');

disp("Tablas unidas correctamente.")

%% 7. Convertir variables numéricas por seguridad

T.RMSE_SOC = double(T.RMSE_SOC);
T.Error_final_SOC = double(T.Error_final_SOC);
T.Dist_km = double(T.Dist_km);
T.Margen_previsto_km = double(T.Margen_previsto_km);
T.Error_autonomia_reg_LOO_km = double(T.Error_autonomia_reg_LOO_km);
T.Autonomia_fin_real_km = double(T.Autonomia_fin_real_km);
T.Autonomia_fin_prevista_reg_LOO_km = double(T.Autonomia_fin_prevista_reg_LOO_km);

T.Estado_previsto = string(T.Estado_previsto);

%% 8. Parámetros del índice

% Umbrales principales
umbral_rmse_anomalia = 6;       % [%]
umbral_error_final = 8;         % [%]
umbral_error_autonomia = 80;    % [km], valor para penalizacion maxima aproximada

% Pesos máximos de penalización
peso_rmse = 25;
peso_error_final = 20;
peso_margen = 25;
peso_autonomia = 20;
peso_anomalia = 10;

%% 9. Detección de anomalía

T.Anomalia = T.RMSE_SOC > umbral_rmse_anomalia;

%% 10. Penalización por RMSE

T.Penalizacion_RMSE = min(T.RMSE_SOC ./ 15, 1) .* peso_rmse;

%% 11. Penalización por error final SOC

T.Penalizacion_ErrorFinal = min(abs(T.Error_final_SOC) ./ 25, 1) .* peso_error_final;

%% 12. Penalización por margen operativo

pen_margen = zeros(height(T),1);

for i = 1:height(T)

    margen_i = T.Margen_previsto_km(i);

    if isnan(margen_i)
        pen_margen(i) = 0;

    elseif margen_i >= 30
        % Margen suficiente
        pen_margen(i) = 0;

    elseif margen_i >= 0 && margen_i < 30
        % Zona de aviso: penaliza hasta 15 puntos
        pen_margen(i) = (30 - margen_i) / 30 * 15;

    else
        % Margen negativo: crítico, penaliza entre 15 y 25 puntos
        pen_margen(i) = 15 + min(abs(margen_i) / 50, 1) * 10;
    end
end

T.Penalizacion_Margen = pen_margen;

%% 13. Penalización por error de autonomía

T.Penalizacion_Autonomia = ...
    min(abs(T.Error_autonomia_reg_LOO_km) ./ umbral_error_autonomia, 1) .* peso_autonomia;

%% 14. Penalización por anomalía

T.Penalizacion_Anomalia = double(T.Anomalia) .* peso_anomalia;

%% 15. Índice final

T.Indice_estado = 100 ...
    - T.Penalizacion_RMSE ...
    - T.Penalizacion_ErrorFinal ...
    - T.Penalizacion_Margen ...
    - T.Penalizacion_Autonomia ...
    - T.Penalizacion_Anomalia;

% Limitar entre 0 y 100
T.Indice_estado(T.Indice_estado < 0) = 0;
T.Indice_estado(T.Indice_estado > 100) = 100;

%% 16. Clasificación del estado del sistema

estado_sistema = strings(height(T),1);

for i = 1:height(T)

    if T.Indice_estado(i) >= 75
        estado_sistema(i) = "Normal";

    elseif T.Indice_estado(i) >= 50
        estado_sistema(i) = "Aviso";

    else
        estado_sistema(i) = "Critico";
    end
end

T.Estado_sistema = estado_sistema;

%% 17. Tabla final ordenada

T = sortrows(T, 'Indice_estado', 'ascend');

tabla_indice = T(:, {'Dia_limpio','RMSE_SOC','Error_final_SOC', ...
    'Margen_previsto_km','Error_autonomia_reg_LOO_km', ...
    'Anomalia','Penalizacion_RMSE','Penalizacion_ErrorFinal', ...
    'Penalizacion_Margen','Penalizacion_Autonomia', ...
    'Penalizacion_Anomalia','Indice_estado','Estado_sistema'});

disp("=== INDICE DE ESTADO DEL SISTEMA ===")
disp(tabla_indice)

archivo_indice = fullfile( ...
    resultados_dir, ...
    'indice_estado_sistema.csv');

writetable(tabla_indice, archivo_indice);

fprintf("Archivo guardado: %s\n", archivo_indice)

%% 18. Resumen de estados

num_normales = sum(tabla_indice.Estado_sistema == "Normal");
num_avisos = sum(tabla_indice.Estado_sistema == "Aviso");
num_criticos = sum(tabla_indice.Estado_sistema == "Critico");

fprintf("\n=== RESUMEN DE ESTADOS ===\n")
fprintf("Dias normales: %d\n", num_normales)
fprintf("Dias en aviso: %d\n", num_avisos)
fprintf("Dias criticos: %d\n", num_criticos)

fprintf("\nIndice medio: %.2f\n", mean(tabla_indice.Indice_estado, 'omitnan'))
fprintf("Indice minimo: %.2f\n", min(tabla_indice.Indice_estado))
fprintf("Indice maximo: %.2f\n", max(tabla_indice.Indice_estado))

%% ============================================================
% FIGURA 1 - INDICE DE ESTADO POR DIA
% ============================================================

dias_ord = tabla_indice.Dia_limpio;
indice_ord = tabla_indice.Indice_estado;
estado_ord = tabla_indice.Estado_sistema;

fig1 = figure('Color','w','Visible','on');
ax1 = axes('Parent', fig1);

b = bar(ax1, indice_ord);
hold(ax1,'on')

yline(ax1, 75, 'k--', 'LineWidth', 1.2)
yline(ax1, 50, 'k:', 'LineWidth', 1.2)

b.FaceColor = 'flat';

for i = 1:length(indice_ord)

    if estado_ord(i) == "Normal"
        b.CData(i,:) = [0 0.45 0.74];    % azul

    elseif estado_ord(i) == "Aviso"
        b.CData(i,:) = [1 0.6 0];        % naranja

    else
        b.CData(i,:) = [1 0 0];          % rojo
    end
end

xticks(ax1, 1:length(dias_ord))
xticklabels(ax1, dias_ord)
xtickangle(ax1, 45)

xlabel(ax1, 'Día')
ylabel(ax1, 'Índice de estado [%]')
title(ax1, 'Índice de estado del gemelo digital')

ylim(ax1, [0 100])
grid(ax1,'on')

h1 = bar(ax1, nan, nan, 'FaceColor', [0 0.45 0.74]);
h2 = bar(ax1, nan, nan, 'FaceColor', [1 0.6 0]);
h3 = bar(ax1, nan, nan, 'FaceColor', [1 0 0]);
h4 = plot(ax1, nan, nan, 'k--', 'LineWidth', 1.2);
h5 = plot(ax1, nan, nan, 'k:', 'LineWidth', 1.2);

legend(ax1, [h1 h2 h3 h4 h5], ...
    {'Normal','Aviso','Crítico','Umbral normal','Umbral crítico'}, ...
    'Location','southwest')

saveas( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_04_indice_estado_sistema.png'))

print( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_04_indice_estado_sistema_300dpi.png'), ...
    '-dpng', '-r300')

%% ============================================================
% FIGURA 2 - CONTRIBUCION DE PENALIZACIONES
% ============================================================

% Para que sea legible, se representan los 10 peores días
n_peores = min(10, height(tabla_indice));

peores = tabla_indice(1:n_peores, :);

mat_pen = [ ...
    peores.Penalizacion_RMSE, ...
    peores.Penalizacion_ErrorFinal, ...
    peores.Penalizacion_Margen, ...
    peores.Penalizacion_Autonomia, ...
    peores.Penalizacion_Anomalia ...
];

fig2 = figure('Color','w','Visible','on');
ax2 = axes('Parent', fig2);

bar(ax2, mat_pen, 'stacked')

xticks(ax2, 1:n_peores)
xticklabels(ax2, peores.Dia_limpio)
xtickangle(ax2, 45)

xlabel(ax2, 'Día')
ylabel(ax2, 'Penalización acumulada')
title(ax2, 'Contribución de penalizaciones en los días de peor estado')

legend(ax2, {'RMSE SOC','Error final SOC','Margen operativo', ...
    'Error autonomía','Anomalía'}, ...
    'Location','northwest')

grid(ax2,'on')

saveas( ...
    fig2, ...
    fullfile(resultados_dir, 'fig_05_penalizaciones_indice_estado.png'))

print( ...
    fig2, ...
    fullfile(resultados_dir, 'fig_05_penalizaciones_indice_estado_300dpi.png'), ...
    '-dpng', '-r300')

disp("Figuras generadas correctamente:")
disp(fullfile(resultados_dir, 'fig_04_indice_estado_sistema_300dpi.png'))
disp(fullfile(resultados_dir, 'fig_05_penalizaciones_indice_estado_300dpi.png'))