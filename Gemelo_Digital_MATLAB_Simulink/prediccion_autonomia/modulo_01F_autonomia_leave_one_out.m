%% MODULO 01F - VALIDACION REALISTA DE AUTONOMIA (LEAVE-ONE-OUT)
% Predice la autonomia final de cada dia usando el factor medio de perdida
% de autonomia de los demas dias de la misma estacion.
%
% Esto evita usar el mismo dia para calcular el factor con el que se predice.

clc

%% 1. Rutas del proyecto y carga de tabla V2

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
    'Autonomia_ini_real_km','Autonomia_fin_real_km', ...
    'Factor_perdida_autonomia'};

for i = 1:length(cols_necesarias)
    if ~ismember(cols_necesarias{i}, tabla.Properties.VariableNames)
        error("Falta la columna necesaria: %s", cols_necesarias{i})
    end
end

%% 3. Convertir datos por seguridad

tabla.Dia_limpio = string(tabla.Dia_limpio);
tabla.Estacion = string(tabla.Estacion);

dist = double(tabla.Dist_km);
aut_ini = double(tabla.Autonomia_ini_real_km);
aut_fin_real = double(tabla.Autonomia_fin_real_km);
factor_real = double(tabla.Factor_perdida_autonomia);

%% 4. Prediccion leave-one-out

n = height(tabla);

factor_pred_LOO = nan(n,1);
aut_fin_prev_LOO = nan(n,1);
error_aut_LOO = nan(n,1);

for i = 1:n

    estacion_i = tabla.Estacion(i);

    % Usar dias de la misma estacion excepto el propio dia
    idx_train = tabla.Estacion == estacion_i;
    idx_train(i) = false;

    factores_train = factor_real(idx_train);

    % Si no hubiera suficientes datos de esa estacion, usar global sin el dia
    if sum(~isnan(factores_train)) < 2
        idx_train = true(n,1);
        idx_train(i) = false;
        factores_train = factor_real(idx_train);
    end

    factor_pred_LOO(i) = mean(factores_train, 'omitnan');

    aut_fin_prev_LOO(i) = aut_ini(i) - factor_pred_LOO(i) * dist(i);

    if aut_fin_prev_LOO(i) < 0
        aut_fin_prev_LOO(i) = 0;
    end

    error_aut_LOO(i) = aut_fin_prev_LOO(i) - aut_fin_real(i);

end

tabla.Factor_pred_LOO = factor_pred_LOO;
tabla.Autonomia_fin_prevista_LOO_km = aut_fin_prev_LOO;
tabla.Error_autonomia_LOO_km = error_aut_LOO;

%% 5. Metricas

RMSE_aut_LOO = sqrt(mean(tabla.Error_autonomia_LOO_km.^2, 'omitnan'));
MAE_aut_LOO = mean(abs(tabla.Error_autonomia_LOO_km), 'omitnan');
Error_medio_aut_LOO = mean(tabla.Error_autonomia_LOO_km, 'omitnan');

fprintf("\n=== VALIDACION AUTONOMIA LEAVE-ONE-OUT ===\n")
fprintf("RMSE autonomia LOO: %.3f km\n", RMSE_aut_LOO)
fprintf("MAE autonomia LOO: %.3f km\n", MAE_aut_LOO)
fprintf("Error medio autonomia LOO: %.3f km\n", Error_medio_aut_LOO)

%% 6. Guardar tabla

tabla_LOO = tabla(:, {'Dia_limpio','Estacion','Dist_km', ...
    'Autonomia_ini_real_km','Autonomia_fin_real_km', ...
    'Factor_perdida_autonomia','Factor_pred_LOO', ...
    'Autonomia_fin_prevista_LOO_km','Error_autonomia_LOO_km'});

tabla_LOO = sortrows(tabla_LOO, 'Error_autonomia_LOO_km', 'ascend');

disp("=== TABLA AUTONOMIA LOO ===")
disp(tabla_LOO)

archivo_LOO = fullfile( ...
    resultados_dir, ...
    'validacion_autonomia_leave_one_out.csv');

writetable(tabla_LOO, archivo_LOO);

fprintf("Archivo guardado: %s\n", archivo_LOO)


%% GRAFICA - AUTONOMIA FINAL REAL VS PREVISTA LOO

x = double(tabla_LOO.Autonomia_fin_real_km);
y = double(tabla_LOO.Autonomia_fin_prevista_LOO_km);

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
title(ax1, 'Comparación entre autonomía final real y prevista - validación leave-one-out')

grid(ax1,'on')

legend(ax1, {'Jornadas analizadas','Predicción perfecta'}, 'Location','best')

xlim(ax1, [min_val-10 max_val+10])
ylim(ax1, [min_val-10 max_val+10])

saveas( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_autonomia_real_vs_prevista_LOO.png'))

print( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_autonomia_real_vs_prevista_LOO_300dpi.png'), ...
    '-dpng', '-r300')


%% GRAFICA - ERROR AUTONOMIA LOO

dias = string(tabla_LOO.Dia_limpio);
err = double(tabla_LOO.Error_autonomia_LOO_km);

idx = ~isnan(err);

dias = dias(idx);
err = err(idx);

[~, idx_ord] = sort(abs(err), 'ascend');

dias_ord = dias(idx_ord);
error_ord = err(idx_ord);

fig2 = figure('Color','w','Visible','on');
ax2 = axes('Parent',fig2);

b = bar(ax2, error_ord);
hold(ax2,'on')

yline(ax2, 0, 'k-', 'LineWidth', 1.2)
yline(ax2, 20, 'k:', 'LineWidth', 1.2)
yline(ax2, -20, 'k:', 'LineWidth', 1.2)

b.FaceColor = 'flat';

for i = 1:length(error_ord)
    if abs(error_ord(i)) <= 20
        b.CData(i,:) = [0 0.45 0.74];
    elseif abs(error_ord(i)) <= 40
        b.CData(i,:) = [1 0.6 0];
    else
        b.CData(i,:) = [1 0 0];
    end
end

xticks(ax2, 1:length(dias_ord))
xticklabels(ax2, dias_ord)
xtickangle(ax2, 45)

xlabel(ax2, 'Día')
ylabel(ax2, 'Error autonomía final [km]')
title(ax2, 'Error de predicción de la autonomía final - validación leave-one-out')

grid(ax2,'on')

h1 = bar(ax2, nan, nan, 'FaceColor', [0 0.45 0.74]);
h2 = bar(ax2, nan, nan, 'FaceColor', [1 0.6 0]);
h3 = bar(ax2, nan, nan, 'FaceColor', [1 0 0]);

legend(ax2, [h1 h2 h3], ...
    {'|error| <= 20 km','20 km < |error| <= 40 km','|error| > 40 km'}, ...
    'Location','best')

saveas( ...
    fig2, ...
    fullfile(resultados_dir, 'fig_error_autonomia_LOO.png'))

print( ...
    fig2, ...
    fullfile(resultados_dir, 'fig_error_autonomia_LOO_300dpi.png'), ...
    '-dpng', '-r300')