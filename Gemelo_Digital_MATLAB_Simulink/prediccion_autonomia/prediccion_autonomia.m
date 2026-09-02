%% MODULO 01 - PREDICCION DE AUTONOMIA Y MARGEN OPERATIVO
% Version robusta

clc

%% 1. Cargar tabla de validacion

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
    disp("Tabla validacion cargada correctamente desde CSV.")
else
    error(['No se encuentra el archivo de validacion: ', ...
        archivo_validacion, newline, ...
        'Ejecuta primero modelo_energetico/validar_modelo_multidia.m.'])
end

%% 2. Mostrar columnas disponibles

disp("Columnas disponibles en validacion:")
disp(validacion.Properties.VariableNames')

%% 3. Comprobar columnas obligatorias

cols_obligatorias = {'Dia','Dist_km','SOC_ini_real','SOC_fin_real'};

for i = 1:length(cols_obligatorias)
    if ~ismember(cols_obligatorias{i}, validacion.Properties.VariableNames)
        error("Falta la columna obligatoria: %s", cols_obligatorias{i})
    end
end

%% 4. Detectar columna de consumo simulado

nombres = validacion.Properties.VariableNames;

idx_consumo = contains(nombres, 'Consumo') & contains(nombres, 'kWh');

if sum(idx_consumo) == 0
    error("No se ha encontrado una columna de consumo simulado.")
elseif sum(idx_consumo) > 1
    disp("Se han encontrado varias columnas de consumo:")
    disp(nombres(idx_consumo)')
    error("Revisa cuál debe usarse.")
else
    col_consumo = nombres{idx_consumo};
    fprintf("Columna de consumo utilizada: %s\n", col_consumo)
end

consumo_sim = validacion.(col_consumo);

%% 5. Parametros del modulo predictivo

C_kWh_eq = 350;       % capacidad energetica equivalente [kWh]
SOC_min = 20;         % SOC minimo operativo [%]
margen_aviso = 30;    % margen minimo recomendado [km]

%% 6. Limpiar etiquetas de dia

dias = string(validacion.Dia);
dias = erase(dias, "FULL_SOC_");
dias = erase(dias, ".xlsx");

validacion.Dia_limpio = dias;

%% 7. Energia util disponible

validacion.Energia_util_kWh = max(validacion.SOC_ini_real - SOC_min, 0) ./ 100 .* C_kWh_eq;

%% 8. Autonomia predicha

validacion.Autonomia_pred_km = validacion.Energia_util_kWh ./ consumo_sim;

%% 9. Margen operativo

validacion.Margen_operativo_km = validacion.Autonomia_pred_km - validacion.Dist_km;

%% 10. Clasificacion del estado operativo

estado = strings(height(validacion),1);

for i = 1:height(validacion)
    
    if validacion.Margen_operativo_km(i) < 0
        estado(i) = "Critico";
        
    elseif validacion.Margen_operativo_km(i) < margen_aviso
        estado(i) = "Aviso";
        
    else
        estado(i) = "Normal";
    end
end

validacion.Estado_operativo = estado;

%% 11. Crear tabla final del modulo predictivo

tabla_prediccion = validacion(:, {'Dia_limpio','Dist_km','SOC_ini_real','SOC_fin_real', ...
    'Energia_util_kWh','Autonomia_pred_km','Margen_operativo_km','Estado_operativo'});

% Ordenar por margen operativo, de menor a mayor
tabla_prediccion = sortrows(tabla_prediccion, 'Margen_operativo_km', 'ascend');

disp("=== TABLA DE PREDICCION DE AUTONOMIA Y MARGEN OPERATIVO ===")
disp(tabla_prediccion)

%% 12. Guardar resultados

archivo_prediccion = fullfile( ...
    resultados_dir, ...
    'prediccion_autonomia_margen_operativo.csv');

writetable(tabla_prediccion, archivo_prediccion);

fprintf("Archivo guardado: %s\n", archivo_prediccion)

%% GRAFICA - MARGEN OPERATIVO POR DIA

% Reordenar validacion por margen para que la grafica sea mas clara
[~, idx_ord] = sort(validacion.Margen_operativo_km, 'ascend');

dias_ord = validacion.Dia_limpio(idx_ord);
margen_ord = validacion.Margen_operativo_km(idx_ord);
estado_ord = validacion.Estado_operativo(idx_ord);

figure
b = bar(margen_ord);
hold on

yline(0, 'k--', 'Limite critico')
yline(30, 'k:', 'Margen de aviso')

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

xticks(1:length(dias_ord))
xticklabels(dias_ord)
xtickangle(45)

xlabel('Dia')
ylabel('Margen operativo [km]')
title('Prediccion de margen operativo antes de alcanzar el SOC minimo')
grid on

% Crear leyenda manual
h1 = bar(nan, nan, 'FaceColor', [0 0.45 0.74]);
h2 = bar(nan, nan, 'FaceColor', [1 0.6 0]);
h3 = bar(nan, nan, 'FaceColor', [1 0 0]);

legend([h1 h2 h3], {'Normal','Aviso','Critico'}, 'Location','best')

exportgraphics( ...
    gcf, ...
    fullfile(resultados_dir, 'fig_margen_operativo.png'), ...
    'Resolution', 300)

%% MODULO 01B - PREDICCION PREVIA CON CONSUMO MEDIO ESTACIONAL

% Parametros
C_kWh_eq = 350;     % capacidad equivalente [kWh]
SOC_min = 20;       % SOC minimo operativo [%]
margen_aviso = 30;  % km

% Crear etiquetas de dia si no existen
if ~ismember('Dia_limpio', validacion.Properties.VariableNames)
    dias = string(validacion.Dia);
    dias = erase(dias, "FULL_SOC_");
    dias = erase(dias, ".xlsx");
    validacion.Dia_limpio = dias;
end

% Crear estacion si no existe
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

% Detectar columna de consumo simulado
nombres = validacion.Properties.VariableNames;
idx_consumo = contains(nombres, 'Consumo') & contains(nombres, 'kWh');

if sum(idx_consumo) ~= 1
    error("Revisa la columna de consumo simulado.")
end

col_consumo = nombres{idx_consumo};
consumo_sim = validacion.(col_consumo);

% Calcular consumos medios por estacion
consumo_medio_inv = mean(consumo_sim(validacion.Estacion == "Invierno"), 'omitnan');
consumo_medio_ver = mean(consumo_sim(validacion.Estacion == "Verano"), 'omitnan');

fprintf("Consumo medio invierno usado para prediccion: %.3f kWh/km\n", consumo_medio_inv)
fprintf("Consumo medio verano usado para prediccion: %.3f kWh/km\n", consumo_medio_ver)

% Asignar consumo predictivo segun estacion
consumo_pred = zeros(height(validacion),1);

for i = 1:height(validacion)
    if validacion.Estacion(i) == "Invierno"
        consumo_pred(i) = consumo_medio_inv;
    elseif validacion.Estacion(i) == "Verano"
        consumo_pred(i) = consumo_medio_ver;
    else
        consumo_pred(i) = mean(consumo_sim, 'omitnan');
    end
end

validacion.Consumo_pred_kWh_km = consumo_pred;

% Energia util disponible al inicio
validacion.Energia_util_pred_kWh = max(validacion.SOC_ini_real - SOC_min, 0) ./ 100 .* C_kWh_eq;

% Autonomia prevista antes de la jornada
validacion.Autonomia_prevista_km = validacion.Energia_util_pred_kWh ./ validacion.Consumo_pred_kWh_km;

% Margen previsto frente a distancia planificada
% En este trabajo se usa Dist_km como equivalente de distancia prevista/servicio.
validacion.Margen_previsto_km = validacion.Autonomia_prevista_km - validacion.Dist_km;

% Clasificacion
estado_previsto = strings(height(validacion),1);

for i = 1:height(validacion)
    if validacion.Margen_previsto_km(i) < 0
        estado_previsto(i) = "Critico";
    elseif validacion.Margen_previsto_km(i) < margen_aviso
        estado_previsto(i) = "Aviso";
    else
        estado_previsto(i) = "Normal";
    end
end

validacion.Estado_previsto = estado_previsto;

tabla_pred_prev = validacion(:, {'Dia_limpio','Estacion','SOC_ini_real','Dist_km', ...
    'Consumo_pred_kWh_km','Autonomia_prevista_km','Margen_previsto_km','Estado_previsto'});

tabla_pred_prev = sortrows(tabla_pred_prev, 'Margen_previsto_km', 'ascend');

disp("=== PREDICCION PREVIA CON CONSUMO MEDIO ESTACIONAL ===")
disp(tabla_pred_prev)

archivo_prediccion_previa = fullfile( ...
    resultados_dir, ...
    'prediccion_previa_margen_estacional.csv');

writetable(tabla_pred_prev, archivo_prediccion_previa);


%% GRAFICA - MARGEN PREVISTO CON CONSUMO MEDIO ESTACIONAL

[~, idx_ord] = sort(validacion.Margen_previsto_km, 'ascend');

dias_ord = validacion.Dia_limpio(idx_ord);
margen_ord = validacion.Margen_previsto_km(idx_ord);
estado_ord = validacion.Estado_previsto(idx_ord);

figure
b = bar(margen_ord);
hold on

yline(0, 'k--', 'LineWidth', 1.2)
yline(30, 'k:', 'LineWidth', 1.2)

b.FaceColor = 'flat';

for i = 1:length(margen_ord)
    if estado_ord(i) == "Critico"
        b.CData(i,:) = [1 0 0];
    elseif estado_ord(i) == "Aviso"
        b.CData(i,:) = [1 0.6 0];
    else
        b.CData(i,:) = [0 0.45 0.74];
    end
end

xticks(1:length(dias_ord))
xticklabels(dias_ord)
xtickangle(45)

xlabel('Día')
ylabel('Margen previsto [km]')
title('Predicción previa del margen operativo con consumo medio estacional')
grid on

h1 = bar(nan, nan, 'FaceColor', [0 0.45 0.74]);
h2 = bar(nan, nan, 'FaceColor', [1 0.6 0]);
h3 = bar(nan, nan, 'FaceColor', [1 0 0]);
h4 = plot(nan, nan, 'k--');
h5 = plot(nan, nan, 'k:');

legend([h1 h2 h3 h4 h5], ...
    {'Normal','Aviso','Crítico','Límite crítico','Margen de aviso'}, ...
    'Location','northwest')

exportgraphics( ...
    gcf, ...
    fullfile(resultados_dir, 'fig_prediccion_previa_margen_estacional.png'), ...
    'Resolution', 300)