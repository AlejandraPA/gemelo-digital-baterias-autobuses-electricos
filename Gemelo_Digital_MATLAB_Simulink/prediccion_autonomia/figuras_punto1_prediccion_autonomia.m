%% FIGURAS PUNTO 1 - PREDICCION DE AUTONOMIA Y MARGEN OPERATIVO
% Genera:
% 1) Margen operativo previsto con consumo medio estacional
% 2) Autonomia final real vs prevista mediante regresion LOO
% 3) Error de prediccion de autonomia mediante regresion LOO

clc
close all

%% Rutas del proyecto

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

resultados_dir = fullfile(project_dir, 'resultados', 'prediccion_autonomia');

if ~isfolder(resultados_dir)
    mkdir(resultados_dir);
end

%% ============================================================
%  FIGURA 1 - MARGEN OPERATIVO PREVISTO
% ============================================================

archivo_margen = fullfile( ...
    resultados_dir, ...
    'prediccion_previa_margen_estacional.csv');

if ~isfile(archivo_margen)
    error("No se encuentra el archivo prediccion_previa_margen_estacional.csv")
end

tabla_margen = readtable(archivo_margen);

% Extraer variables
dias = string(tabla_margen.Dia_limpio);
margen = double(tabla_margen.Margen_previsto_km);
estado = string(tabla_margen.Estado_previsto);

% Filtrar datos válidos
idx = ~isnan(margen);
dias = dias(idx);
margen = margen(idx);
estado = estado(idx);

% Ordenar de menor a mayor margen
[~, idx_ord] = sort(margen, 'ascend');

dias_ord = dias(idx_ord);
margen_ord = margen(idx_ord);
estado_ord = estado(idx_ord);

% Crear figura
fig1 = figure('Color','w','Visible','on');
ax1 = axes('Parent',fig1);

b = bar(ax1, margen_ord);
hold(ax1,'on')

% Límites de referencia
yline(ax1, 0, 'k--', 'LineWidth', 1.2)
yline(ax1, 30, 'k:', 'LineWidth', 1.2)

% Colores por estado
b.FaceColor = 'flat';

for i = 1:length(margen_ord)

    if estado_ord(i) == "Critico"
        b.CData(i,:) = [1 0 0];          % rojo

    elseif estado_ord(i) == "Aviso"
        b.CData(i,:) = [1 0.6 0];        % naranja

    else
        b.CData(i,:) = [0 0.45 0.74];    % azul
    end
end

xticks(ax1, 1:length(dias_ord))
xticklabels(ax1, dias_ord)
xtickangle(ax1, 45)

xlabel(ax1, 'Día')
ylabel(ax1, 'Margen previsto [km]')
title(ax1, 'Predicción previa del margen operativo con consumo medio estacional')

grid(ax1,'on')

% Leyenda manual
h1 = bar(ax1, nan, nan, 'FaceColor', [0 0.45 0.74]);
h2 = bar(ax1, nan, nan, 'FaceColor', [1 0.6 0]);
h3 = bar(ax1, nan, nan, 'FaceColor', [1 0 0]);
h4 = plot(ax1, nan, nan, 'k--', 'LineWidth', 1.2);
h5 = plot(ax1, nan, nan, 'k:', 'LineWidth', 1.2);

legend(ax1, [h1 h2 h3 h4 h5], ...
    {'Normal','Aviso','Crítico','Límite crítico','Margen de aviso'}, ...
    'Location','northwest')

drawnow

% Guardar figura
saveas( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_01_margen_operativo_previsto.png'))

print( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_01_margen_operativo_previsto_300dpi.png'), ...
    '-dpng', '-r300')


%% ============================================================
%  FIGURA 2 - AUTONOMIA FINAL REAL VS PREVISTA REGRESION LOO
% ============================================================

archivo_reg = fullfile( ...
    resultados_dir, ...
    'validacion_autonomia_regresion_LOO.csv');

if ~isfile(archivo_reg)
    error("No se encuentra el archivo validacion_autonomia_regresion_LOO.csv")
end

tabla_reg = readtable(archivo_reg);

x = double(tabla_reg.Autonomia_fin_real_km);
y = double(tabla_reg.Autonomia_fin_prevista_reg_LOO_km);

idx = ~isnan(x) & ~isnan(y);

x = x(idx);
y = y(idx);

fig2 = figure('Color','w','Visible','on');
ax2 = axes('Parent',fig2);

plot(ax2, x, y, 'o', ...
    'MarkerSize', 7, ...
    'LineWidth', 1.5)

hold(ax2,'on')

min_val = min([x; y]);
max_val = max([x; y]);

plot(ax2, [min_val max_val], [min_val max_val], ...
    'k--', 'LineWidth', 1.2)

xlabel(ax2, 'Autonomía final real [km]')
ylabel(ax2, 'Autonomía final prevista [km]')
title(ax2, 'Comparación entre autonomía final real y prevista - regresión LOO')

grid(ax2,'on')

legend(ax2, {'Jornadas analizadas','Predicción perfecta'}, ...
    'Location','northwest')

xlim(ax2, [min_val-10 max_val+10])
ylim(ax2, [min_val-10 max_val+10])

drawnow

% Guardar figura
saveas( ...
    fig2, ...
    fullfile(resultados_dir, 'fig_02_autonomia_real_vs_prevista_regresion_LOO.png'))

print( ...
    fig2, ...
    fullfile(resultados_dir, 'fig_02_autonomia_real_vs_prevista_regresion_LOO_300dpi.png'), ...
    '-dpng', '-r300')


%% ============================================================
%  FIGURA 3 - ERROR AUTONOMIA REGRESION LOO
% ============================================================

dias = string(tabla_reg.Dia_limpio);
err = double(tabla_reg.Error_autonomia_reg_LOO_km);

idx = ~isnan(err);

dias = dias(idx);
err = err(idx);

% Ordenar por valor absoluto del error
[~, idx_ord] = sort(abs(err), 'ascend');

dias_ord = dias(idx_ord);
error_ord = err(idx_ord);

fig3 = figure('Color','w','Visible','on');
ax3 = axes('Parent',fig3);

b = bar(ax3, error_ord);
hold(ax3,'on')

yline(ax3, 0, 'k-', 'LineWidth', 1.2)
yline(ax3, 20, 'k:', 'LineWidth', 1.2)
yline(ax3, -20, 'k:', 'LineWidth', 1.2)

b.FaceColor = 'flat';

for i = 1:length(error_ord)

    if abs(error_ord(i)) <= 20
        b.CData(i,:) = [0 0.45 0.74];   % azul

    elseif abs(error_ord(i)) <= 40
        b.CData(i,:) = [1 0.6 0];        % naranja

    else
        b.CData(i,:) = [1 0 0];          % rojo
    end
end

xticks(ax3, 1:length(dias_ord))
xticklabels(ax3, dias_ord)
xtickangle(ax3, 45)

xlabel(ax3, 'Día')
ylabel(ax3, 'Error autonomía final [km]')
title(ax3, 'Error de predicción de la autonomía final - regresión LOO')

grid(ax3,'on')

% Leyenda manual
h1 = bar(ax3, nan, nan, 'FaceColor', [0 0.45 0.74]);
h2 = bar(ax3, nan, nan, 'FaceColor', [1 0.6 0]);
h3 = bar(ax3, nan, nan, 'FaceColor', [1 0 0]);
h4 = plot(ax3, nan, nan, 'k:');

legend(ax3, [h1 h2 h3 h4], ...
    {'|error| <= 20 km','20 km < |error| <= 40 km','|error| > 40 km','Umbral ±20 km'}, ...
    'Location','northwest')

drawnow

% Guardar figura
saveas( ...
    fig3, ...
    fullfile(resultados_dir, 'fig_03_error_autonomia_regresion_LOO.png'))

print( ...
    fig3, ...
    fullfile(resultados_dir, 'fig_03_error_autonomia_regresion_LOO_300dpi.png'), ...
    '-dpng', '-r300')


%% ============================================================
%  RESUMEN FINAL
% ============================================================

disp("Figuras generadas correctamente:")
disp("1) fig_01_margen_operativo_previsto.png")
disp("2) fig_02_autonomia_real_vs_prevista_regresion_LOO.png")
disp("3) fig_03_error_autonomia_regresion_LOO.png")

disp("También se han guardado versiones a 300 dpi.")