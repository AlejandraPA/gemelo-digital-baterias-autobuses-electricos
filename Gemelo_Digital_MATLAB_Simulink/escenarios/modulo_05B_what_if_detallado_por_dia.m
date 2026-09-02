%% MODULO 05B - ESCENARIOS WHAT-IF DETALLADOS POR DIA
% Este script genera escenarios detallados a partir de jornadas reales.
%
% Para cada dia se comparan:
% - datos reales al final de la jornada
% - estimacion del gemelo digital
% - escenarios contrafactuales modificando SOC, consumo, distancia y capacidad
%
% Salidas:
% - escenarios_detallados_what_if_por_dia.xlsx
% - fig_15_mapa_escenarios_detallados_margen.png
% - fig_16_soc_real_vs_estimado_dias_representativos.png
% - fig_17_autonomia_real_vs_estimada_dias_representativos.png

clc
close all

%% ============================================================
% 1. ARCHIVOS DE ENTRADA
% ============================================================

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

resultados_dir = fullfile(project_dir, 'resultados', 'escenarios');

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

archivo_indice = fullfile( ...
    project_dir, ...
    'resultados', ...
    'supervision_indicadores', ...
    'indice_estado_sistema.csv');

archivo_soh = fullfile( ...
    project_dir, ...
    'resultados', ...
    'supervision_indicadores', ...
    'capacidad_efectiva_soh_aparente.csv');

if ~isfile(archivo_validacion)
    error("No se encuentra el archivo: %s", archivo_validacion)
end

if ~isfile(archivo_margen)
    error("No se encuentra el archivo: %s", archivo_margen)
end

if ~isfile(archivo_autonomia)
    error("No se encuentra el archivo: %s", archivo_autonomia)
end

validacion = readtable(archivo_validacion);
margen = readtable(archivo_margen);
autonomia = readtable(archivo_autonomia);

disp("Archivos principales cargados correctamente.")

%% ============================================================
% 2. PREPARAR TABLA DE VALIDACION
% ============================================================

if ~ismember('Dia_limpio', validacion.Properties.VariableNames)
    dias = string(validacion.Dia);
    dias = erase(dias, "FULL_SOC_");
    dias = erase(dias, ".xlsx");
    validacion.Dia_limpio = dias;
else
    validacion.Dia_limpio = string(validacion.Dia_limpio);
end

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

% Detectar columna de consumo simulado
nombres = validacion.Properties.VariableNames;
idx_consumo = contains(lower(nombres), 'consumo') & contains(lower(nombres), 'kwh');

if sum(idx_consumo) == 0
    disp(nombres')
    error("No se ha encontrado columna de consumo simulado en validacion.")
elseif sum(idx_consumo) > 1
    posibles = nombres(idx_consumo);
    idx_sim = contains(lower(posibles), 'sim');

    if sum(idx_sim) >= 1
        col_consumo = posibles{find(idx_sim,1)};
    else
        col_consumo = posibles{1};
    end
else
    col_consumo = nombres{idx_consumo};
end

fprintf("Columna de consumo usada desde validacion: %s\n", col_consumo)

T_val = table;
T_val.Dia_limpio = string(validacion.Dia_limpio);
T_val.Estacion = string(validacion.Estacion);
T_val.Dist_km = double(validacion.Dist_km);
T_val.SOC_ini_real = double(validacion.SOC_ini_real);
T_val.SOC_fin_real = double(validacion.SOC_fin_real);
T_val.RMSE_SOC = double(validacion.RMSE_SOC);
T_val.Error_final_SOC = double(validacion.Error_final_SOC);
T_val.Consumo_modelo_kWh_km = double(validacion.(col_consumo));

%% ============================================================
% 3. PREPARAR TABLA DE MARGEN OPERATIVO
% ============================================================

margen.Dia_limpio = string(margen.Dia_limpio);

T_margen = table;
T_margen.Dia_limpio = string(margen.Dia_limpio);

if ismember('Consumo_pred_kWh_km', margen.Properties.VariableNames)
    T_margen.Consumo_pred_kWh_km = double(margen.Consumo_pred_kWh_km);
else
    T_margen.Consumo_pred_kWh_km = nan(height(margen),1);
end

T_margen.Margen_previsto_km = double(margen.Margen_previsto_km);
T_margen.Estado_previsto = string(margen.Estado_previsto);

%% ============================================================
% 4. PREPARAR TABLA DE AUTONOMIA
% ============================================================

autonomia.Dia_limpio = string(autonomia.Dia_limpio);

T_aut = table;
T_aut.Dia_limpio = string(autonomia.Dia_limpio);
T_aut.Autonomia_ini_real_km = double(autonomia.Autonomia_ini_real_km);
T_aut.Autonomia_fin_real_km = double(autonomia.Autonomia_fin_real_km);
T_aut.Autonomia_fin_prevista_reg_LOO_km = double(autonomia.Autonomia_fin_prevista_reg_LOO_km);
T_aut.Error_autonomia_reg_LOO_km = double(autonomia.Error_autonomia_reg_LOO_km);

%% ============================================================
% 5. TABLAS OPCIONALES: INDICE Y SOH APARENTE
% ============================================================

if isfile(archivo_indice)
    indice = readtable(archivo_indice);
    indice.Dia_limpio = string(indice.Dia_limpio);

    T_ind = table;
    T_ind.Dia_limpio = string(indice.Dia_limpio);
    T_ind.Indice_estado = double(indice.Indice_estado);
    T_ind.Estado_sistema = string(indice.Estado_sistema);
else
    T_ind = table;
    T_ind.Dia_limpio = T_val.Dia_limpio;
    T_ind.Indice_estado = nan(height(T_val),1);
    T_ind.Estado_sistema = strings(height(T_val),1);
end

if isfile(archivo_soh)
    soh = readtable(archivo_soh);
    soh.Dia_limpio = string(soh.Dia_limpio);

    T_soh = table;
    T_soh.Dia_limpio = string(soh.Dia_limpio);
    T_soh.Capacidad_efectiva_aparente_kWh = double(soh.Capacidad_efectiva_kWh);
    T_soh.SOH_aparente_pct = double(soh.SOH_aparente_pct);
    T_soh.Estado_capacidad = string(soh.Estado_capacidad);
else
    T_soh = table;
    T_soh.Dia_limpio = T_val.Dia_limpio;
    T_soh.Capacidad_efectiva_aparente_kWh = nan(height(T_val),1);
    T_soh.SOH_aparente_pct = nan(height(T_val),1);
    T_soh.Estado_capacidad = strings(height(T_val),1);
end

%% ============================================================
% 6. UNIR TODAS LAS TABLAS
% ============================================================

T = join(T_val, T_margen, 'Keys', 'Dia_limpio');
T = join(T, T_aut, 'Keys', 'Dia_limpio');
T = join(T, T_ind, 'Keys', 'Dia_limpio');
T = join(T, T_soh, 'Keys', 'Dia_limpio');

% Si falta consumo predictivo, usar consumo del modelo
idx_nan_consumo = isnan(T.Consumo_pred_kWh_km);
T.Consumo_pred_kWh_km(idx_nan_consumo) = T.Consumo_modelo_kWh_km(idx_nan_consumo);

disp("Tabla maestra creada correctamente.")

%% ============================================================
% 7. PARAMETROS GENERALES
% ============================================================

SOC_min = 20;          % SOC minimo operativo [%]
margen_aviso = 30;     % margen minimo [km]

% Capacidad usada para prediccion.
% Se toma la capacidad efectiva media si existe; si no, se usa 350 kWh.
if any(~isnan(T.Capacidad_efectiva_aparente_kWh))
    C_plan_kWh = mean(T.Capacidad_efectiva_aparente_kWh, 'omitnan');
else
    C_plan_kWh = 350;
end

fprintf("Capacidad usada para escenarios: %.2f kWh\n", C_plan_kWh)

%% ============================================================
% 8. DEFINICION DE ESCENARIOS POR DIA
% ============================================================

NombreSituacion = [
    "Base registrada"
    "SOC inicial -10 puntos"
    "Consumo +15%"
    "Distancia +20 km"
    "Capacidad -10%"
    "Escenario severo"
];

DescripcionSituacion = [
    "Jornada real registrada y estimada por el gemelo digital con las condiciones iniciales del dia."
    "Se mantiene la distancia real, pero el autobus inicia la jornada con 10 puntos menos de SOC."
    "Se mantiene el SOC y la distancia real, pero aumenta el consumo estimado un 15%."
    "Se mantiene el SOC inicial, pero la distancia prevista aumenta 20 km."
    "Se mantiene SOC y distancia, pero la capacidad efectiva disponible se reduce un 10%."
    "Combinacion desfavorable: SOC inicial 10 puntos menor, consumo +15%, distancia +20 km y capacidad -10%."
];

delta_SOC = [0, -10, 0, 0, 0, -10];
factor_consumo = [1, 1, 1.15, 1, 1, 1.15];
delta_distancia = [0, 0, 0, 20, 0, 20];
factor_capacidad = [1, 1, 1, 1, 0.90, 0.90];

nDias = height(T);
nEsc = length(NombreSituacion);
nRows = nDias * nEsc;

%% ============================================================
% 9. PREASIGNAR TABLA DE ESCENARIOS
% ============================================================

Dia_limpio = strings(nRows,1);
Estacion = strings(nRows,1);
Situacion = strings(nRows,1);
Descripcion = strings(nRows,1);
Tipo_comparacion = strings(nRows,1);

SOC_ini_real = nan(nRows,1);
Dist_real_km = nan(nRows,1);
SOC_fin_real = nan(nRows,1);
Autonomia_fin_real_km = nan(nRows,1);

SOC_ini_escenario = nan(nRows,1);
Distancia_escenario_km = nan(nRows,1);
Consumo_escenario_kWh_km = nan(nRows,1);
Capacidad_escenario_kWh = nan(nRows,1);

SOC_fin_estimado = nan(nRows,1);
Autonomia_fin_estimada_km = nan(nRows,1);
Autonomia_util_restante_km = nan(nRows,1);
Margen_operativo_estimado_km = nan(nRows,1);
Estado_estimado = strings(nRows,1);

Error_SOC_fin_base = nan(nRows,1);
Autonomia_fin_prevista_reg_LOO_km = nan(nRows,1);
Error_autonomia_reg_LOO_km = nan(nRows,1);

RMSE_SOC = nan(nRows,1);
Error_final_SOC = nan(nRows,1);
Indice_estado = nan(nRows,1);
Estado_sistema = strings(nRows,1);
SOH_aparente_pct = nan(nRows,1);
Estado_capacidad = strings(nRows,1);

%% ============================================================
% 10. CALCULAR ESCENARIOS
% ============================================================

r = 0;

for i = 1:nDias

    for j = 1:nEsc

        r = r + 1;

        Dia_limpio(r) = T.Dia_limpio(i);
        Estacion(r) = T.Estacion(i);
        Situacion(r) = NombreSituacion(j);
        Descripcion(r) = DescripcionSituacion(j);

        if j == 1
            Tipo_comparacion(r) = "Comparacion real-estimado";
        else
            Tipo_comparacion(r) = "Contrafactual sin dato real";
        end

        % Datos reales de la jornada original
        SOC_ini_real(r) = T.SOC_ini_real(i);
        Dist_real_km(r) = T.Dist_km(i);
        SOC_fin_real(r) = T.SOC_fin_real(i);
        Autonomia_fin_real_km(r) = T.Autonomia_fin_real_km(i);

        % Variables del escenario
        SOC_ini_esc = T.SOC_ini_real(i) + delta_SOC(j);
        SOC_ini_esc = max(min(SOC_ini_esc, 100), 0);

        dist_esc = T.Dist_km(i) + delta_distancia(j);
        consumo_esc = T.Consumo_pred_kWh_km(i) * factor_consumo(j);
        cap_esc = C_plan_kWh * factor_capacidad(j);

        SOC_ini_escenario(r) = SOC_ini_esc;
        Distancia_escenario_km(r) = dist_esc;
        Consumo_escenario_kWh_km(r) = consumo_esc;
        Capacidad_escenario_kWh(r) = cap_esc;

        % Estimaciones del gemelo digital
        E_consumida = dist_esc * consumo_esc;

        SOC_fin_est = SOC_ini_esc - (E_consumida / cap_esc) * 100;

        SOC_fin_estimado(r) = SOC_fin_est;

        % Autonomia total restante estimada hasta SOC 0
        Autonomia_fin_estimada_km(r) = max(SOC_fin_est, 0) / 100 * cap_esc / consumo_esc;

        % Autonomia util restante por encima del SOC minimo
        Autonomia_util_restante_km(r) = max(SOC_fin_est - SOC_min, 0) / 100 * cap_esc / consumo_esc;

        % Margen operativo desde el inicio del escenario hasta SOC minimo
        E_util = max(SOC_ini_esc - SOC_min, 0) / 100 * cap_esc;
        Autonomia_prevista = E_util / consumo_esc;
        margen_est = Autonomia_prevista - dist_esc;

        Margen_operativo_estimado_km(r) = margen_est;

        if margen_est < 0
            Estado_estimado(r) = "Critico";
        elseif margen_est < margen_aviso
            Estado_estimado(r) = "Aviso";
        else
            Estado_estimado(r) = "Normal";
        end

        % Comparacion real-estimado solo para la jornada base
        if j == 1
            Error_SOC_fin_base(r) = SOC_fin_est - T.SOC_fin_real(i);
            Autonomia_fin_prevista_reg_LOO_km(r) = T.Autonomia_fin_prevista_reg_LOO_km(i);
            Error_autonomia_reg_LOO_km(r) = T.Error_autonomia_reg_LOO_km(i);
        end

        % Metricas ya calculadas de la jornada
        RMSE_SOC(r) = T.RMSE_SOC(i);
        Error_final_SOC(r) = T.Error_final_SOC(i);
        Indice_estado(r) = T.Indice_estado(i);
        Estado_sistema(r) = T.Estado_sistema(i);
        SOH_aparente_pct(r) = T.SOH_aparente_pct(i);
        Estado_capacidad(r) = T.Estado_capacidad(i);

    end
end

%% ============================================================
% 11. TABLA FINAL DE ESCENARIOS
% ============================================================

escenarios = table(Dia_limpio, Estacion, Situacion, Descripcion, Tipo_comparacion, ...
    SOC_ini_real, Dist_real_km, SOC_fin_real, Autonomia_fin_real_km, ...
    SOC_ini_escenario, Distancia_escenario_km, Consumo_escenario_kWh_km, ...
    Capacidad_escenario_kWh, SOC_fin_estimado, Autonomia_fin_estimada_km, ...
    Autonomia_util_restante_km, Margen_operativo_estimado_km, Estado_estimado, ...
    Error_SOC_fin_base, Autonomia_fin_prevista_reg_LOO_km, Error_autonomia_reg_LOO_km, ...
    RMSE_SOC, Error_final_SOC, Indice_estado, Estado_sistema, ...
    SOH_aparente_pct, Estado_capacidad);

disp("=== TABLA DE ESCENARIOS DETALLADOS ===")
disp(head(escenarios, 12))

%% ============================================================
% 12. SELECCION DE DIAS REPRESENTATIVOS PARA EL TFG
% ============================================================

dias_sel = strings(0,1);

% Dia con mejor indice
if any(~isnan(T.Indice_estado))
    [~, idx] = max(T.Indice_estado);
    dias_sel(end+1) = T.Dia_limpio(idx);

    [~, idx] = min(T.Indice_estado);
    dias_sel(end+1) = T.Dia_limpio(idx);
end

% Dia con mayor error de autonomia
if any(~isnan(T.Error_autonomia_reg_LOO_km))
    [~, idx] = max(abs(T.Error_autonomia_reg_LOO_km));
    dias_sel(end+1) = T.Dia_limpio(idx);
end

% Dia con menor margen previsto
if any(~isnan(T.Margen_previsto_km))
    [~, idx] = min(T.Margen_previsto_km);
    dias_sel(end+1) = T.Dia_limpio(idx);
end

% Dia con menor SOH aparente
if any(~isnan(T.SOH_aparente_pct))
    [~, idx] = min(T.SOH_aparente_pct);
    dias_sel(end+1) = T.Dia_limpio(idx);

    [~, idx] = max(T.SOH_aparente_pct);
    dias_sel(end+1) = T.Dia_limpio(idx);
end

dias_sel = unique(dias_sel, 'stable');

% Si salen menos de 6, completar con los primeros dias disponibles
if length(dias_sel) < 6
    for i = 1:nDias
        if ~ismember(T.Dia_limpio(i), dias_sel)
            dias_sel(end+1) = T.Dia_limpio(i);
        end

        if length(dias_sel) >= 6
            break
        end
    end
end

fprintf("\nDias seleccionados para el TFG:\n")
disp(dias_sel')

escenarios_TFG = escenarios(ismember(escenarios.Dia_limpio, dias_sel), :);

base_TFG = escenarios_TFG(escenarios_TFG.Situacion == "Base registrada", :);

%% ============================================================
% 13. RESUMEN DE ESTADOS POR ESCENARIO
% ============================================================

estados_unicos = ["Normal"; "Aviso"; "Critico"];
conteos = zeros(length(estados_unicos),1);

for i = 1:length(estados_unicos)
    conteos(i) = sum(escenarios.Estado_estimado == estados_unicos(i));
end

resumen_estados = table(estados_unicos, conteos, ...
    'VariableNames', {'Estado','Numero_escenarios'});

disp("=== RESUMEN DE ESTADOS EN TODOS LOS ESCENARIOS ===")
disp(resumen_estados)

%% ============================================================
% 14. EXPORTAR A EXCEL
% ============================================================

archivo_salida = fullfile( ...
    resultados_dir, ...
    'escenarios_detallados_what_if_por_dia.xlsx');

writetable(escenarios, archivo_salida, 'Sheet', 'Todos_los_escenarios')
writetable(escenarios_TFG, archivo_salida, 'Sheet', 'Seleccion_TFG')
writetable(base_TFG, archivo_salida, 'Sheet', 'Real_vs_estimado')
writetable(resumen_estados, archivo_salida, 'Sheet', 'Resumen_estados')

disp("Archivo Excel guardado:")
disp(archivo_salida)

%% ============================================================
% 15. FIGURA - MAPA DIA VS ESCENARIO DEL MARGEN OPERATIVO
% ============================================================

nSel = length(dias_sel);
M = nan(nSel, nEsc);

for i = 1:nSel
    for j = 1:nEsc

        idx = escenarios_TFG.Dia_limpio == dias_sel(i) & ...
              escenarios_TFG.Situacion == NombreSituacion(j);

        if any(idx)
            M(i,j) = escenarios_TFG.Margen_operativo_estimado_km(find(idx,1));
        end
    end
end

fig1 = figure('Color','w','Visible','on');
ax1 = axes('Parent', fig1);

imagesc(ax1, M)
colorbar

xticks(ax1, 1:nEsc)
xticklabels(ax1, NombreSituacion)
xtickangle(ax1, 35)

yticks(ax1, 1:nSel)
yticklabels(ax1, dias_sel)

xlabel(ax1, 'Escenario')
ylabel(ax1, 'Día')
title(ax1, 'Margen operativo estimado por día y escenario')

% Añadir valores sobre cada celda
for i = 1:nSel
    for j = 1:nEsc
        if ~isnan(M(i,j))
            text(j, i, sprintf('%.1f', M(i,j)), ...
                'HorizontalAlignment','center', ...
                'Color','k', ...
                'FontWeight','bold')
        end
    end
end

saveas( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_15_mapa_escenarios_detallados_margen.png'))

print( ...
    fig1, ...
    fullfile(resultados_dir, 'fig_15_mapa_escenarios_detallados_margen_300dpi.png'), ...
    '-dpng', '-r300')

%% ============================================================
% 16. FIGURA - SOC FINAL REAL VS ESTIMADO EN DIAS REPRESENTATIVOS
% ============================================================

% Ordenar base_TFG según dias_sel
[~, orden] = ismember(base_TFG.Dia_limpio, dias_sel);
[~, idx_sort] = sort(orden);
base_TFG = base_TFG(idx_sort,:);

fig2 = figure('Color','w','Visible','on');
ax2 = axes('Parent', fig2);

Y_soc = [base_TFG.SOC_fin_real, base_TFG.SOC_fin_estimado];

bar(ax2, Y_soc)

xticks(ax2, 1:height(base_TFG))
xticklabels(ax2, base_TFG.Dia_limpio)
xtickangle(ax2, 45)

ylabel(ax2, 'SOC final [%]')
xlabel(ax2, 'Día')
title(ax2, 'SOC final real frente a SOC final estimado por el gemelo digital')
legend(ax2, {'SOC final real','SOC final estimado'}, 'Location','best')
grid(ax2,'on')

saveas( ...
    fig2, ...
    fullfile(resultados_dir, 'fig_16_soc_real_vs_estimado_dias_representativos.png'))

print( ...
    fig2, ...
    fullfile(resultados_dir, 'fig_16_soc_real_vs_estimado_dias_representativos_300dpi.png'), ...
    '-dpng', '-r300')

%% ============================================================
% 17. FIGURA - AUTONOMIA FINAL REAL VS ESTIMADA
% ============================================================

fig3 = figure('Color','w','Visible','on');
ax3 = axes('Parent', fig3);

Y_aut = [ ...
    base_TFG.Autonomia_fin_real_km, ...
    base_TFG.Autonomia_fin_prevista_reg_LOO_km, ...
    base_TFG.Autonomia_fin_estimada_km ...
];

bar(ax3, Y_aut)

xticks(ax3, 1:height(base_TFG))
xticklabels(ax3, base_TFG.Dia_limpio)
xtickangle(ax3, 45)

ylabel(ax3, 'Autonomía final [km]')
xlabel(ax3, 'Día')
title(ax3, 'Autonomía final real y estimada en días representativos')
legend(ax3, {'Real','Regresión LOO','Estimación energética'}, 'Location','best')
grid(ax3,'on')

saveas( ...
    fig3, ...
    fullfile(resultados_dir, 'fig_17_autonomia_real_vs_estimada_dias_representativos.png'))

print( ...
    fig3, ...
    fullfile(resultados_dir, 'fig_17_autonomia_real_vs_estimada_dias_representativos_300dpi.png'), ...
    '-dpng', '-r300')

disp("Figuras generadas correctamente:")
disp(fullfile(resultados_dir, 'fig_15_mapa_escenarios_detallados_margen_300dpi.png'))
disp(fullfile(resultados_dir, 'fig_16_soc_real_vs_estimado_dias_representativos_300dpi.png'))
disp(fullfile(resultados_dir, 'fig_17_autonomia_real_vs_estimada_dias_representativos_300dpi.png'))