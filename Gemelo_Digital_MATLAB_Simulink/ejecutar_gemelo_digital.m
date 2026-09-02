
%% EJECUTAR GEMELO DIGITAL
% Punto de entrada para preparar los datos de una jornada y abrir
% el modelo integrado MATLAB/Simulink.

clc

%% 1. Rutas del proyecto

project_dir = fileparts(mfilename('fullpath'));
simulink_dir = fullfile(project_dir, 'simulink');

addpath(simulink_dir);

%% 2. Selección de la jornada

% Cambiar este valor para seleccionar otro día disponible.
if ~exist('indice_dia', 'var')
    indice_dia = 1;
end

%% 3. Cargar datos reales de la jornada

run(fullfile(simulink_dir, 'cargar_datos_dia.m'));

%% 4. Generar corriente equivalente de entrada

run(fullfile(simulink_dir, 'generar_I_eq_signal.m'));

%% 5. Abrir el modelo Simulink

modelo = fullfile(simulink_dir, 'modelo_gemelo_digital.slx');

if ~isfile(modelo)
    error('No se encuentra el modelo Simulink: %s', modelo);
end

open_system(modelo);

%% 6. Resumen

fprintf('\nGemelo digital preparado correctamente.\n');
fprintf('Día seleccionado: %s\n', string(dia_token));
fprintf('Modelo abierto: modelo_gemelo_digital.slx\n');
fprintf('La simulación puede iniciarse desde Simulink.\n');