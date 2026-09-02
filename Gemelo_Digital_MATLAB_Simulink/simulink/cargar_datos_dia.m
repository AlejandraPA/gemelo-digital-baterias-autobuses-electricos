
%% Rutas del proyecto

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

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

%% Seleccionar día

if ~exist('indice_dia', 'var')
    indice_dia = 1;
end

if ~isscalar(indice_dia) || indice_dia < 1 || indice_dia ~= floor(indice_dia)
    error('indice_dia debe ser un número entero positivo.');
end

if indice_dia > length(soc_files)
    error('El indice_dia seleccionado supera el número de archivos FULL_SOC disponibles.');
end

nombre_soc = soc_files(indice_dia).name;

dia_token = erase(string(nombre_soc), "FULL_SOC_");
dia_token = erase(dia_token, ".xlsx");

nombre_speed = "jaltest_sample_" + dia_token + ".xlsx";

idx_speed = find( ...
    strcmpi(string({speed_files.name}), nombre_speed), ...
    1);

if isempty(idx_speed)
    error('No se encontró el archivo Jaltest correspondiente a %s.', nombre_soc);
end

%% Cargar el día seleccionado

soc = readtable( ...
    fullfile(soc_files(indice_dia).folder, soc_files(indice_dia).name));

soc.date = datetime(soc.date, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
soc = sortrows(soc, 'date');

[~, idx_soc] = unique(soc.date, 'stable');
soc = soc(idx_soc, :);

speed = readtable( ...
    fullfile(speed_files(idx_speed).folder, speed_files(idx_speed).name), ...
    'ReadVariableNames', false);

speed.Properties.VariableNames = {'lat','lon','direccion','speed','date','extra'};
speed = speed(:, {'lat','lon','speed','date'});

speed.lat = str2double(speed.lat);
speed.lon = str2double(speed.lon);
speed.speed = str2double(speed.speed);
speed.date = datetime(speed.date, 'InputFormat','dd/MM/yyyy HH:mm:ss');

speed = sortrows(speed, 'date');

[~, idx_speed] = unique(speed.date, 'stable');
speed = speed(idx_speed, :);

speed = rmmissing(speed);

%% SOC real

SOC_real_full = soc.SOC;
t_soc_real = seconds(soc.date - soc.date(1));