%% MODULO 01G - PREDICCION DE AUTONOMIA CON REGRESION LEAVE-ONE-OUT
% Predice la autonomia final usando variables conocidas al inicio:
% - autonomia inicial real
% - distancia prevista/recorrida
% - estacion
%
% Se usa validacion leave-one-out:
% cada dia se predice con un modelo entrenado con los demas dias.

clc

%% 1. Rutas del proyecto y carga de tabla base

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

resultados_dir = fullfile(project_dir, 'resultados', 'prediccion_autonomia');

if ~isfolder(resultados_dir)
    mkdir(resultados_dir);
end

archivo_v2 = fullfile( ...
    resultados_dir, ...
    'validacion_autonomia_v2.csv');

if ~isfile(archivo_v2)
    error(['No se encuentra el archivo: ', archivo_v2, newline, ...
        'Ejecuta primero modulo_01D_validacion_autonomia.m.'])
end

tabla = readtable(archivo_v2);

disp("Archivo validacion_autonomia_v2.csv cargado correctamente.")
%% 2. Comprobar columnas necesarias

cols_necesarias = {'Dia_limpio','Estacion','Dist_km', ...
    'Autonomia_ini_real_km','Autonomia_fin_real_km'};

for i = 1:length(cols_necesarias)
    if ~ismember(cols_necesarias{i}, tabla.Properties.VariableNames)
        error("Falta la columna necesaria: %s", cols_necesarias{i})
    end
end

%% 3. Preparar variables

tabla.Dia_limpio = string(tabla.Dia_limpio);
tabla.Estacion = string(tabla.Estacion);

aut_ini = double(tabla.Autonomia_ini_real_km);
dist = double(tabla.Dist_km);
aut_fin_real = double(tabla.Autonomia_fin_real_km);

% Variable binaria de estacion
% Invierno = 1, Verano = 0
es_invierno = double(tabla.Estacion == "Invierno");

%% 4. Filtrar filas validas

idx_valid = ~isnan(aut_ini) & ~isnan(dist) & ~isnan(aut_fin_real);

tabla = tabla(idx_valid,:);
aut_ini = aut_ini(idx_valid);
dist = dist(idx_valid);
aut_fin_real = aut_fin_real(idx_valid);
es_invierno = es_invierno(idx_valid);

n = height(tabla);

fprintf("Dias validos para regresion: %d\n", n)

%% 5. Validacion leave-one-out

aut_fin_prev_reg = nan(n,1);
error_aut_reg = nan(n,1);

for i = 1:n

    % Datos de entrenamiento: todos menos el dia i
    idx_train = true(n,1);
    idx_train(i) = false;

    X_train = [ ...
        ones(sum(idx_train),1), ...
        aut_ini(idx_train), ...
        dist(idx_train), ...
        es_invierno(idx_train) ...
    ];

    y_train = aut_fin_real(idx_train);

    % Ajuste por minimos cuadrados
    beta = X_train \ y_train;

    % Datos del dia a predecir
    X_test = [1, aut_ini(i), dist(i), es_invierno(i)];

    % Prediccion
    aut_fin_prev_reg(i) = X_test * beta;

    % Limitar a valores fisicamente coherentes
    if aut_fin_prev_reg(i) < 0
        aut_fin_prev_reg(i) = 0;
    end

    error_aut_reg(i) = aut_fin_prev_reg(i) - aut_fin_real(i);

end

tabla.Autonomia_fin_prevista_reg_LOO_km = aut_fin_prev_reg;
tabla.Error_autonomia_reg_LOO_km = error_aut_reg;

%% 6. Metricas

RMSE_aut_reg_LOO = sqrt(mean(error_aut_reg.^2, 'omitnan'));
MAE_aut_reg_LOO = mean(abs(error_aut_reg), 'omitnan');
Error_medio_aut_reg_LOO = mean(error_aut_reg, 'omitnan');

fprintf("\n=== VALIDACION AUTONOMIA REGRESION LOO ===\n")
fprintf("RMSE autonomia regresion LOO: %.3f km\n", RMSE_aut_reg_LOO)
fprintf("MAE autonomia regresion LOO: %.3f km\n", MAE_aut_reg_LOO)
fprintf("Error medio autonomia regresion LOO: %.3f km\n", Error_medio_aut_reg_LOO)

%% 7. Guardar tabla

tabla_reg_LOO = tabla(:, {'Dia_limpio','Estacion','Dist_km', ...
    'Autonomia_ini_real_km','Autonomia_fin_real_km', ...
    'Autonomia_fin_prevista_reg_LOO_km','Error_autonomia_reg_LOO_km'});

tabla_reg_LOO = sortrows(tabla_reg_LOO, 'Error_autonomia_reg_LOO_km', 'ascend');

disp("=== TABLA AUTONOMIA REGRESION LOO ===")
disp(tabla_reg_LOO)

archivo_reg_LOO = fullfile( ...
    resultados_dir, ...
    'validacion_autonomia_regresion_LOO.csv');

writetable(tabla_reg_LOO, archivo_reg_LOO);

fprintf("Archivo guardado: %s\n", archivo_reg_LOO)


%% GRAFICA - AUTONOMIA FINAL REAL VS PREVISTA REGRESION LOO

x = double(tabla_reg_LOO.Autonomia_fin_real_km);
y = double(tabla_reg_LOO.Autonomia_fin_prevista_reg_LOO_km);

idx = ~isnan(x) & ~isnan(y);

x = x(idx);
y = y(idx);

fig1 = figure('Color','w','Visible','on');
ax1 = axes('Parent',fig1);

plot(ax1, x, y, 'o', 'MarkerSize', 7, 'LineWidth', 1.5)
hold(ax1,'on')

min_val = min([x; y]);
max_val = max([x; y]);

plot(ax1, [min_val max_val], [min_val max_val], 'k--', 'LineWidth', 1.2)

xlabel(ax1, 'Autonomía final real [km]')
ylabel(ax1, 'Autonomía final prevista [km]')
title(ax1, 'Comparación entre autonomía final real y prevista - regresión LOO')

grid(ax1,'on')

legend(ax1, {'Jornadas analizadas','Predicción perfecta'}, 'Location','best')

xlim(ax1, [min_val-10 max_val+10])
ylim(ax1, [min_val-10 max_val+10])

saveas( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_autonomia_real_vs_prevista_regresion_LOO.png'))

print( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_autonomia_real_vs_prevista_regresion_LOO_300dpi.png'), ...
    '-dpng', '-r300')


%% COMPARACION V3 FACTOR ESTACIONAL vs V4 REGRESION LOO

archivo_v3 = fullfile( ...
    resultados_dir, ...
    'validacion_autonomia_leave_one_out.csv');

if ~isfile(archivo_v3)
    error(['No se encuentra el archivo: ', archivo_v3, newline, ...
        'Ejecuta primero modulo_01F_autonomia_leave_one_out.m.'])
end

tabla_v3 = readtable(archivo_v3);

err_v3 = double(tabla_v3.Error_autonomia_LOO_km);
err_v4 = double(tabla_reg_LOO.Error_autonomia_reg_LOO_km);

RMSE_v3 = sqrt(mean(err_v3.^2, 'omitnan'));
MAE_v3 = mean(abs(err_v3), 'omitnan');

RMSE_v4 = sqrt(mean(err_v4.^2, 'omitnan'));
MAE_v4 = mean(abs(err_v4), 'omitnan');

fprintf("\n=== COMPARACION V3 vs V4 ===\n")
fprintf("RMSE V3 factor estacional LOO: %.3f km\n", RMSE_v3)
fprintf("RMSE V4 regresion LOO: %.3f km\n", RMSE_v4)
fprintf("Mejora RMSE: %.2f %%\n", (RMSE_v3 - RMSE_v4)/RMSE_v3*100)

fprintf("MAE V3 factor estacional LOO: %.3f km\n", MAE_v3)
fprintf("MAE V4 regresion LOO: %.3f km\n", MAE_v4)
fprintf("Mejora MAE: %.2f %%\n", (MAE_v3 - MAE_v4)/MAE_v3*100)