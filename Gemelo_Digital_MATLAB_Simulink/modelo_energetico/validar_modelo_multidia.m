%% VALIDACION MULTIDIA DEL MODELO ENERGETICO
% Version con consumo auxiliar dependiente de la estacion
% Ajuste actual:
% alpha = 1.5
% I0 = 8
% k1 = 2.5
% k2 = 10
% I_aux_invierno = 4
% I_aux_verano = 0

clear; clc;

%% 1) Rutas y archivos de entrada

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

resultados_dir = fullfile(project_dir, 'resultados', 'modelo_energetico');

if ~isfolder(resultados_dir)
    mkdir(resultados_dir);
end

soc_dir = fullfile(project_dir, 'datos_entrada', 'full_soc');
jaltest_dir = fullfile(project_dir, 'datos_entrada', 'jaltest');

soc_files = dir(fullfile(soc_dir, 'FULL_SOC_*.xlsx'));
speed_files = dir(fullfile(jaltest_dir, 'jaltest_sample_*.xlsx'));

if isempty(soc_files)
    error(['No se encontraron archivos FULL_SOC_*.xlsx en ', ...
        fullfile('datos_entrada', 'full_soc')]);
end

if isempty(speed_files)
    error(['No se encontraron archivos jaltest_sample_*.xlsx en ', ...
        fullfile('datos_entrada', 'jaltest')]);
end

num_dias = length(soc_files);

%% 2) Parametros calibrados base
alpha = 1.5;
I0    = 8;
k1    = 2.5;
k2    = 10.0;

%% 3) Consumo auxiliar por estacion
I_aux_invierno = 4.0;
I_aux_verano   = 0.0;

%% 4) Parametros energeticos equivalentes
C_kWh_eq = 350;
V_eq     = 600;
C_Ah_eq  = (C_kWh_eq * 1000) / V_eq;

%% 5) Tabla de resultados
validacion = table();

%% 6) Bucle principal
for i = 1:num_dias

    fprintf('\nProcesando dia %d de %d...\n', i, num_dias);

    try
        %% ---- Nombre del archivo / deteccion de estacion ----
        nombre_dia = soc_files(i).name;

        % Emparejar cada FULL_SOC con el Jaltest del mismo día
        dia_token = erase(string(nombre_dia), "FULL_SOC_");
        dia_token = erase(dia_token, ".xlsx");

        nombre_speed = "jaltest_sample_" + dia_token + ".xlsx";

        idx_speed = find( ...
            strcmpi(string({speed_files.name}), nombre_speed), ...
            1);

        if isempty(idx_speed)
            warning('No se encontró Jaltest correspondiente a %s.', nombre_dia);
            continue;
        end

        nombre_lower = lower(nombre_dia);

        if contains(nombre_lower, 'ene')
            estacion = "Invierno";
            I_aux = I_aux_invierno;
        elseif contains(nombre_lower, 'jul')
            estacion = "Verano";
            I_aux = I_aux_verano;
        else
            estacion = "Desconocida";
            I_aux = 0;
        end

        %% ---- Cargar SOC ----
        soc = readtable( ...
            fullfile(soc_files(i).folder, soc_files(i).name));
        soc.date = datetime(soc.date, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
        soc = sortrows(soc, 'date');
        [~, idx_soc] = unique(soc.date, 'stable');
        soc = soc(idx_soc, :);
        soc = rmmissing(soc);

        %% ---- Cargar SPEED ----
        speed = readtable( ...
            fullfile(speed_files(idx_speed).folder, speed_files(idx_speed).name), ...
            'ReadVariableNames', false);
        speed.Properties.VariableNames = {'lat','lon','direccion','speed','date','extra'};
        speed = speed(:, {'lat','lon','speed','date'});

        speed.lat   = str2double(speed.lat);
        speed.lon   = str2double(speed.lon);
        speed.speed = str2double(speed.speed);
        speed.date  = datetime(speed.date, 'InputFormat', 'dd/MM/yyyy HH:mm:ss');

        speed = sortrows(speed, 'date');
        [~, idx_speed] = unique(speed.date, 'stable');
        speed = speed(idx_speed, :);
        speed = rmmissing(speed);

        %% ---- Comprobaciones minimas ----
        if height(soc) < 10 || height(speed) < 10
            warning('Dia %s descartado por pocos datos.', nombre_dia);
            continue;
        end

        %% ---- Distancia recorrida ----
        lat = speed.lat;
        lon = speed.lon;

        lat_rad = deg2rad(lat);
        lon_rad = deg2rad(lon);
        R_earth = 6371000;

        dlat = diff(lat_rad);
        dlon = diff(lon_rad);

        a = sin(dlat/2).^2 + cos(lat_rad(1:end-1)) .* cos(lat_rad(2:end)) .* sin(dlon/2).^2;
        c = 2 * atan2(sqrt(a), sqrt(1-a));
        d_m = R_earth * c;

        dist_km = sum(d_m, 'omitnan') / 1000;

        %% ---- Velocidad y aceleracion ----
        v_kmh = double(speed.speed);
        v_ms  = v_kmh / 3.6;

        t_sec = seconds(speed.date - speed.date(1));
        t_sec = double(t_sec);

        a_ms2 = diff(v_ms) ./ diff(t_sec);
        t_acc = t_sec(2:end);

        valid_idx = isfinite(a_ms2) & isfinite(t_acc);

        a_ms2 = a_ms2(valid_idx);
        t_acc = t_acc(valid_idx);

        v_ms_model = v_ms(2:end);
        v_ms_model = v_ms_model(valid_idx);

        t_model = t_acc;

        %% ---- Corriente estimada base ----
        I_demanda = I0 + k1 * v_ms_model + k2 * a_ms2;

        % Limitar regeneracion
        I_demanda(I_demanda < -5) = -5;

        %% ---- Corriente equivalente con ajuste estacional ----
        I_eq = alpha * I_demanda + I_aux;

        %% ---- SOC real ----
        SOC_real_full = soc.SOC;
        t_soc_real = seconds(soc.date - soc.date(1));
        t_soc_real = double(t_soc_real);

        SOC_real_interp = interp1(t_soc_real, SOC_real_full, t_model, 'linear', 'extrap');

        %% ---- SOC simulado ----
        dt = diff(t_model);

        SOC_sim = zeros(size(t_model));
        SOC_sim(1) = SOC_real_interp(1);

        for k = 2:length(t_model)
            SOC_sim(k) = SOC_sim(k-1) - (I_eq(k-1) * dt(k-1)) / (3600 * C_Ah_eq) * 100;
        end

        %% ---- Errores ----
        error_final = SOC_sim(end) - SOC_real_interp(end);
        rmse_soc = sqrt(mean((SOC_sim - SOC_real_interp).^2, 'omitnan'));
        mae_soc  = mean(abs(SOC_sim - SOC_real_interp), 'omitnan');

        %% ---- Consumo equivalente simulado por km ----
        delta_soc_sim = SOC_sim(1) - SOC_sim(end);
        energia_sim_kWh = (delta_soc_sim / 100) * C_kWh_eq;

        if dist_km > 0
            consumo_sim_kWh_km = energia_sim_kWh / dist_km;
        else
            consumo_sim_kWh_km = NaN;
        end

        %% ---- Guardar resultados ----
        fila = table( ...
            string(nombre_dia), ...
            estacion, ...
            I_aux, ...
            dist_km, ...
            SOC_real_interp(1), ...
            SOC_real_interp(end), ...
            SOC_sim(end), ...
            error_final, ...
            rmse_soc, ...
            mae_soc, ...
            consumo_sim_kWh_km, ...
            'VariableNames', { ...
                'Dia', ...
                'Estacion', ...
                'I_aux', ...
                'Dist_km', ...
                'SOC_ini_real', ...
                'SOC_fin_real', ...
                'SOC_fin_sim', ...
                'Error_final_SOC', ...
                'RMSE_SOC', ...
                'MAE_SOC', ...
                'Consumo_sim_kWh_km'} ...
            );

        validacion = [validacion; fila];

    catch ME
        warning('Error en %s: %s', soc_files(i).name, ME.message);
    end
end

%% 7) Limpiar y ordenar
if ~isempty(validacion)
    validacion = rmmissing(validacion);
    validacion = sortrows(validacion, 'RMSE_SOC');
end

%% 8) Mostrar resultados
disp(' ')
disp('===== TABLA VALIDACION =====')
disp(validacion)

%% 9) Estadisticas globales
if ~isempty(validacion)
    fprintf('\n===== ESTADISTICAS DE VALIDACION =====\n');
    fprintf('Dias validados: %d\n', height(validacion));
    fprintf('Error final medio de SOC: %.3f\n', mean(validacion.Error_final_SOC, 'omitnan'));
    fprintf('RMSE medio de SOC: %.3f\n', mean(validacion.RMSE_SOC, 'omitnan'));
    fprintf('MAE medio de SOC: %.3f\n', mean(validacion.MAE_SOC, 'omitnan'));
    fprintf('Consumo simulado medio [kWh/km]: %.3f\n', mean(validacion.Consumo_sim_kWh_km, 'omitnan'));
end

%% 10) Estadisticas por estacion
if ~isempty(validacion)
    inv = validacion(validacion.Estacion == "Invierno", :);
    ver = validacion(validacion.Estacion == "Verano", :);

    fprintf('\n===== RESUMEN POR ESTACION =====\n');

    if ~isempty(inv)
        fprintf('\n-- Invierno --\n');
        fprintf('Dias: %d\n', height(inv));
        fprintf('RMSE medio: %.3f\n', mean(inv.RMSE_SOC, 'omitnan'));
        fprintf('MAE medio: %.3f\n', mean(inv.MAE_SOC, 'omitnan'));
        fprintf('Error final medio: %.3f\n', mean(inv.Error_final_SOC, 'omitnan'));
        fprintf('Consumo medio [kWh/km]: %.3f\n', mean(inv.Consumo_sim_kWh_km, 'omitnan'));
    end

    if ~isempty(ver)
        fprintf('\n-- Verano --\n');
        fprintf('Dias: %d\n', height(ver));
        fprintf('RMSE medio: %.3f\n', mean(ver.RMSE_SOC, 'omitnan'));
        fprintf('MAE medio: %.3f\n', mean(ver.MAE_SOC, 'omitnan'));
        fprintf('Error final medio: %.3f\n', mean(ver.Error_final_SOC, 'omitnan'));
        fprintf('Consumo medio [kWh/km]: %.3f\n', mean(ver.Consumo_sim_kWh_km, 'omitnan'));
    end
end

%% 11) Dias buenos y malos
if ~isempty(validacion)
    dias_buenos = validacion(validacion.RMSE_SOC < 4, :);
    dias_malos  = validacion(validacion.RMSE_SOC > 8, :);

    disp('=== DIAS BUENOS ===')
    disp(dias_buenos(:, {'Dia','Estacion','I_aux','RMSE_SOC','Consumo_sim_kWh_km'}))

    disp('=== DIAS MALOS ===')
    disp(dias_malos(:, {'Dia','Estacion','I_aux','RMSE_SOC','Consumo_sim_kWh_km'}))
end

%% 12) Peores dias
if ~isempty(validacion)
    validacion_peores = sortrows(validacion, 'RMSE_SOC', 'descend');
    disp('=== PEORES 10 DIAS ===')
    disp(head(validacion_peores, 10))
end

%% 13) Graficas resumen
if ~isempty(validacion)

    figure
    bar(validacion.RMSE_SOC)
    xlabel('Dia')
    ylabel('RMSE SOC')
    title('Error RMSE del SOC por dia')
    grid on

    figure
    bar(validacion.Error_final_SOC)
    xlabel('Dia')
    ylabel('Error final SOC')
    title('Error final de SOC por dia')
    grid on

    figure
    bar(validacion.Consumo_sim_kWh_km)
    xlabel('Dia')
    ylabel('Consumo simulado [kWh/km]')
    title('Consumo simulado por dia')
    grid on

    figure
    scatter(validacion.Consumo_sim_kWh_km, validacion.RMSE_SOC, 'filled')
    xlabel('Consumo simulado [kWh/km]')
    ylabel('RMSE SOC')
    title('Error vs consumo')
    grid on

    figure
    scatter(validacion.Dist_km, validacion.RMSE_SOC, 'filled')
    xlabel('Distancia [km]')
    ylabel('RMSE SOC')
    title('Error vs distancia')
    grid on
end

%% 14) Guardar CSV
if ~isempty(validacion)

    archivo_salida = fullfile( ...
        resultados_dir, ...
        'validacion_modelo_multidia_estacional.csv');

    writetable(validacion, archivo_salida);

    fprintf('\nArchivo guardado: %s\n', archivo_salida);
end