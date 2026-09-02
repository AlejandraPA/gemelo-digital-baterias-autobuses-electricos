%% MODULO 03 - ESTIMACION PRELIMINAR DE CAPACIDAD EFECTIVA / SOH APARENTE
% Este script estima una capacidad efectiva aparente de la bateria
% a partir de:
% - energia consumida estimada
% - caida real de SOC
%
% No representa un SOH certificado, sino un indicador preliminar
% de coherencia energetica y posible degradacion aparente.

clc
close all

%% 1. Rutas del proyecto y archivo de entrada

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

if ~isfile(archivo_validacion)
    error(['No se encuentra el archivo de validacion: ', ...
        archivo_validacion, newline, ...
        'Ejecuta primero modelo_energetico/validar_modelo_multidia.m.'])
end

validacion = readtable(archivo_validacion);

disp("Archivo de validacion cargado correctamente.")

%% 2. Crear Dia_limpio si no existe

if ~ismember('Dia_limpio', validacion.Properties.VariableNames)
    dias = string(validacion.Dia);
    dias = erase(dias, "FULL_SOC_");
    dias = erase(dias, ".xlsx");
    validacion.Dia_limpio = dias;
else
    validacion.Dia_limpio = string(validacion.Dia_limpio);
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

else
    validacion.Estacion = string(validacion.Estacion);
end

%% 4. Comprobar columnas necesarias

cols_necesarias = {'Dia_limpio','Estacion','Dist_km','SOC_ini_real','SOC_fin_real'};

for i = 1:length(cols_necesarias)
    if ~ismember(cols_necesarias{i}, validacion.Properties.VariableNames)
        error("Falta la columna necesaria: %s", cols_necesarias{i})
    end
end

%% 5. Detectar columna de consumo simulado

nombres = validacion.Properties.VariableNames;

idx_consumo = contains(nombres, 'Consumo') & contains(nombres, 'kWh');

if sum(idx_consumo) == 0
    disp(nombres')
    error("No se ha encontrado columna de consumo simulado.")
elseif sum(idx_consumo) > 1
    disp("Columnas de consumo encontradas:")
    disp(nombres(idx_consumo)')
    error("Hay varias columnas de consumo. Revisa cuál debe usarse.")
end

col_consumo = nombres{idx_consumo};

fprintf("Columna de consumo utilizada: %s\n", col_consumo)

consumo_sim = double(validacion.(col_consumo));

%% 6. Parámetros

C_nom_kWh = 350;      % capacidad nominal/equivalente considerada [kWh]
delta_SOC_min = 10;   % mínimo descenso de SOC para considerar fiable la estimación [%]

%% 7. Cálculos principales

validacion.E_consumida_kWh = double(validacion.Dist_km) .* consumo_sim;

validacion.Delta_SOC_real = double(validacion.SOC_ini_real) - double(validacion.SOC_fin_real);

validacion.Capacidad_efectiva_kWh = validacion.E_consumida_kWh ./ (validacion.Delta_SOC_real ./ 100);

validacion.SOH_aparente_pct = validacion.Capacidad_efectiva_kWh ./ C_nom_kWh .* 100;

%% 8. Filtrado de valores poco fiables

% Se considera fiable si:
% - el SOC ha bajado lo suficiente
% - la capacidad calculada es positiva
% - el SOH aparente queda en un rango razonable de análisis

validacion.Estimacion_valida = ...
    validacion.Delta_SOC_real >= delta_SOC_min & ...
    validacion.Capacidad_efectiva_kWh > 0 & ...
    validacion.SOH_aparente_pct >= 50 & ...
    validacion.SOH_aparente_pct <= 150;

%% 9. Clasificación cualitativa del indicador

estado_capacidad = strings(height(validacion),1);

for i = 1:height(validacion)

    if ~validacion.Estimacion_valida(i)
        estado_capacidad(i) = "No fiable";

    elseif validacion.SOH_aparente_pct(i) < 85
        estado_capacidad(i) = "Bajo";

    elseif validacion.SOH_aparente_pct(i) <= 115
        estado_capacidad(i) = "Coherente";

    else
        estado_capacidad(i) = "Alto";
    end
end

validacion.Estado_capacidad = estado_capacidad;

%% 10. Tabla final

tabla_soh = validacion(:, {'Dia_limpio','Estacion','Dist_km', ...
    'SOC_ini_real','SOC_fin_real','Delta_SOC_real', ...
    'E_consumida_kWh','Capacidad_efectiva_kWh', ...
    'SOH_aparente_pct','Estimacion_valida','Estado_capacidad'});

tabla_soh = sortrows(tabla_soh, 'SOH_aparente_pct', 'ascend');

disp("=== TABLA CAPACIDAD EFECTIVA / SOH APARENTE ===")
disp(tabla_soh)

archivo_soh = fullfile( ...
    resultados_dir, ...
    'capacidad_efectiva_soh_aparente.csv');

writetable(tabla_soh, archivo_soh);

fprintf("Archivo guardado: %s\n", archivo_soh)

%% 11. Estadísticas globales

idx_val = tabla_soh.Estimacion_valida == true;

SOH_val = tabla_soh.SOH_aparente_pct(idx_val);
Ceff_val = tabla_soh.Capacidad_efectiva_kWh(idx_val);

fprintf("\n=== ESTADISTICAS SOH APARENTE ===\n")
fprintf("Dias validos: %d\n", sum(idx_val))
fprintf("SOH aparente medio: %.2f %%\n", mean(SOH_val, 'omitnan'))
fprintf("SOH aparente minimo: %.2f %%\n", min(SOH_val))
fprintf("SOH aparente maximo: %.2f %%\n", max(SOH_val))
fprintf("Capacidad efectiva media: %.2f kWh\n", mean(Ceff_val, 'omitnan'))

fprintf("\n=== RESUMEN POR ESTADO ===\n")
fprintf("Coherente: %d\n", sum(tabla_soh.Estado_capacidad == "Coherente"))
fprintf("Bajo: %d\n", sum(tabla_soh.Estado_capacidad == "Bajo"))
fprintf("Alto: %d\n", sum(tabla_soh.Estado_capacidad == "Alto"))
fprintf("No fiable: %d\n", sum(tabla_soh.Estado_capacidad == "No fiable"))

%% ============================================================
% FIGURA 1 - SOH APARENTE POR DIA
% ============================================================

% Ordenar por dia original para visualizar la evolución
tabla_plot = validacion;

dias_plot = tabla_plot.Dia_limpio;
soh_plot = tabla_plot.SOH_aparente_pct;
estado_plot = tabla_plot.Estado_capacidad;

fig1 = figure('Color','w','Visible','on');
ax1 = axes('Parent', fig1);

b = bar(ax1, soh_plot);
hold(ax1,'on')

yline(ax1, 100, 'k--', 'LineWidth', 1.2)
yline(ax1, 85, 'k:', 'LineWidth', 1.2)
yline(ax1, 115, 'k:', 'LineWidth', 1.2)

b.FaceColor = 'flat';

for i = 1:length(soh_plot)

    if estado_plot(i) == "Coherente"
        b.CData(i,:) = [0 0.45 0.74];    % azul

    elseif estado_plot(i) == "Bajo"
        b.CData(i,:) = [1 0.6 0];        % naranja

    elseif estado_plot(i) == "Alto"
        b.CData(i,:) = [0.5 0.5 0.5];    % gris

    else
        b.CData(i,:) = [1 0 0];          % rojo
    end
end

xticks(ax1, 1:length(dias_plot))
xticklabels(ax1, dias_plot)
xtickangle(ax1, 45)

xlabel(ax1, 'Día')
ylabel(ax1, 'SOH aparente [%]')
title(ax1, 'Estimación preliminar del SOH aparente por jornada')

grid(ax1,'on')

h1 = bar(ax1, nan, nan, 'FaceColor', [0 0.45 0.74]);
h2 = bar(ax1, nan, nan, 'FaceColor', [1 0.6 0]);
h3 = bar(ax1, nan, nan, 'FaceColor', [0.5 0.5 0.5]);
h4 = bar(ax1, nan, nan, 'FaceColor', [1 0 0]);
h5 = plot(ax1, nan, nan, 'k--', 'LineWidth', 1.2);

legend(ax1, [h1 h2 h3 h4 h5], ...
    {'Coherente','Bajo','Alto','No fiable','Referencia 100 %'}, ...
    'Location','northwest')

saveas( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_06_soh_aparente_por_dia.png'))

print( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_06_soh_aparente_por_dia_300dpi.png'), ...
    '-dpng', '-r300')

%% ============================================================
% FIGURA 2 - CAPACIDAD EFECTIVA POR DIA
% ============================================================

cap_plot = tabla_plot.Capacidad_efectiva_kWh;

fig2 = figure('Color','w','Visible','on');
ax2 = axes('Parent', fig2);

b2 = bar(ax2, cap_plot);
hold(ax2,'on')

yline(ax2, C_nom_kWh, 'k--', 'LineWidth', 1.2)

b2.FaceColor = 'flat';

for i = 1:length(cap_plot)

    if estado_plot(i) == "Coherente"
        b2.CData(i,:) = [0 0.45 0.74];

    elseif estado_plot(i) == "Bajo"
        b2.CData(i,:) = [1 0.6 0];

    elseif estado_plot(i) == "Alto"
        b2.CData(i,:) = [0.5 0.5 0.5];

    else
        b2.CData(i,:) = [1 0 0];
    end
end

xticks(ax2, 1:length(dias_plot))
xticklabels(ax2, dias_plot)
xtickangle(ax2, 45)

xlabel(ax2, 'Día')
ylabel(ax2, 'Capacidad efectiva aparente [kWh]')
title(ax2, 'Capacidad efectiva aparente estimada por jornada')

grid(ax2,'on')

h1 = bar(ax2, nan, nan, 'FaceColor', [0 0.45 0.74]);
h2 = bar(ax2, nan, nan, 'FaceColor', [1 0.6 0]);
h3 = bar(ax2, nan, nan, 'FaceColor', [0.5 0.5 0.5]);
h4 = bar(ax2, nan, nan, 'FaceColor', [1 0 0]);
h5 = plot(ax2, nan, nan, 'k--', 'LineWidth', 1.2);

legend(ax2, [h1 h2 h3 h4 h5], ...
    {'Coherente','Bajo','Alto','No fiable','Capacidad nominal'}, ...
    'Location','northwest')

saveas( ...
    fig2, ...
    fullfile(resultados_dir, 'fig_07_capacidad_efectiva_por_dia.png'))

print( ...
    fig2, ...
    fullfile(resultados_dir, 'fig_07_capacidad_efectiva_por_dia_300dpi.png'), ...
    '-dpng', '-r300')

%% ============================================================
% FIGURA 3 - SOH APARENTE POR ESTACION
% ============================================================

tabla_validos = validacion(validacion.Estimacion_valida == true, :);

fig3 = figure('Color','w','Visible','on');
ax3 = axes('Parent', fig3);

boxchart(categorical(tabla_validos.Estacion), tabla_validos.SOH_aparente_pct)

hold(ax3,'on')
yline(ax3, 100, 'k--', 'LineWidth', 1.2)

xlabel(ax3, 'Estación')
ylabel(ax3, 'SOH aparente [%]')
title(ax3, 'Distribución del SOH aparente por estación')

grid(ax3,'on')

saveas( ...
    fig3, ...
    fullfile(resultados_dir, 'fig_08_soh_aparente_por_estacion.png'))

print( ...
    fig3, ...
    fullfile(resultados_dir, 'fig_08_soh_aparente_por_estacion_300dpi.png'), ...
    '-dpng', '-r300')

disp("Figuras generadas correctamente:")
disp(fullfile(resultados_dir, 'fig_06_soh_aparente_por_dia_300dpi.png'))
disp(fullfile(resultados_dir, 'fig_07_capacidad_efectiva_por_dia_300dpi.png'))
disp(fullfile(resultados_dir, 'fig_08_soh_aparente_por_estacion_300dpi.png'))