%% Generar I_eq_signal para el día utilizado en Simulink

%% Rutas del proyecto

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

jaltest_dir = fullfile(project_dir, 'datos_entrada', 'jaltest');

speed_files = dir(fullfile(jaltest_dir, 'jaltest_sample_*.xlsx'));

if isempty(speed_files)
    error(['No se encontraron archivos jaltest_sample_*.xlsx en ', ...
        fullfile('datos_entrada', 'jaltest')]);
end

% Utilizar exactamente el mismo día seleccionado en cargar_datos_dia.m
if ~exist('dia_token', 'var')
    error(['No se ha definido el día de simulación. ', ...
        'Ejecuta primero simulink/cargar_datos_dia.m.']);
end

nombre_speed = "jaltest_sample_" + string(dia_token) + ".xlsx";

idx_speed_signal = find( ...
    strcmpi(string({speed_files.name}), nombre_speed), ...
    1);

if isempty(idx_speed_signal)
    error( ...
        'No se encontró el archivo Jaltest correspondiente al día %s.', ...
        string(dia_token));
end

speed = readtable( ...
    fullfile( ...
        speed_files(idx_speed_signal).folder, ...
        speed_files(idx_speed_signal).name), ...
    'ReadVariableNames', false);

speed.Properties.VariableNames = {'lat','lon','direccion','speed','date','extra'};
speed = speed(:, {'lat','lon','speed','date'});

speed.lat   = str2double(speed.lat);
speed.lon   = str2double(speed.lon);
speed.speed = str2double(speed.speed);
speed.date  = datetime(speed.date, 'InputFormat','dd/MM/yyyy HH:mm:ss');

speed = sortrows(speed, 'date');
[~, idx_speed] = unique(speed.date, 'stable');
speed = speed(idx_speed, :);
speed = rmmissing(speed);

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

% Parámetros finales del modelo
alpha = 1.5;
I0    = 8;
k1    = 2.5;
k2    = 10.0;

% Corriente auxiliar equivalente según la estación
mes_dia = month(speed.date(1));

if ismember(mes_dia, [12 1 2])
    I_aux = 4.0;      % Invierno
    estacion = "Invierno";
elseif ismember(mes_dia, [6 7 8])
    I_aux = 0.0;      % Verano
    estacion = "Verano";
else
    I_aux = 0.0;
    estacion = "No definida";
end

% Corriente de demanda intermedia
I_demanda = I0 + k1 * v_ms_model + k2 * a_ms2;

% Limitar regeneración
I_demanda(I_demanda < -5) = -5;

% Corriente equivalente final
I_eq = alpha * I_demanda + I_aux;

% Señal de corriente equivalente utilizada como entrada de Simulink
I_eq_signal = timeseries(I_eq, t_model);

fprintf('Jornada utilizada: %s\n', datestr(speed.date(1)));
fprintf('Estacion: %s\n', estacion);
fprintf('I_aux: %.1f A\n', I_aux);
fprintf('Corriente equivalente: min %.2f A, max %.2f A, media %.2f A\n', ...
    min(I_eq), max(I_eq), mean(I_eq));

whos I_eq_signal