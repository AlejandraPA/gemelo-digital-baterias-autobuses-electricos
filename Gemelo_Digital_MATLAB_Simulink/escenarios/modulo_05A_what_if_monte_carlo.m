%% MODULO 05A - ESCENARIOS WHAT-IF Y SIMULACION MONTE CARLO
% Este script genera 10 000 escenarios hipoteticos de operacion para
% evaluar el SOC final previsto y el margen operativo del autobus.
%
% Variables aleatorias:
% - SOC inicial: 60-95 %
% - Distancia prevista: 120-260 km
% - Consumo estimado: 1.2-1.8 kWh/km
%
% Parametros de referencia:
% - SOC minimo operativo: 20 %
% - Capacidad energetica equivalente: 350 kWh
% - Margen de aviso: 30 km
%
% La semilla del generador aleatorio se fija para que los resultados
% sean exactamente reproducibles.

clc
close all

%% Rutas del proyecto

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

resultados_dir = fullfile(project_dir, 'resultados', 'escenarios');

if ~isfolder(resultados_dir)
    mkdir(resultados_dir);
end

%% 1. PARAMETROS GENERALES

SOC_min = 20;          % SOC minimo operativo [%]
C_bat = 350;           % capacidad energetica equivalente [kWh]
margen_aviso = 30;     % margen minimo para estado Normal [km]

N = 10000;             % numero de escenarios Monte Carlo

% Rangos de entrada
SOC_ini_min = 60;      % [%]
SOC_ini_max = 95;      % [%]

dist_min = 120;        % [km]
dist_max = 260;        % [km]

consumo_min = 1.2;     % [kWh/km]
consumo_max = 1.8;     % [kWh/km]

%% 2. SEMILLA FIJA PARA REPRODUCIBILIDAD

rng(1);

%% 3. GENERACION DE ESCENARIOS ALEATORIOS

SOC_ini = SOC_ini_min + (SOC_ini_max - SOC_ini_min) * rand(N,1);

distancia_prevista = dist_min + ...
    (dist_max - dist_min) * rand(N,1);

consumo_est = consumo_min + ...
    (consumo_max - consumo_min) * rand(N,1);

%% 4. CALCULO ENERGETICO DE CADA ESCENARIO

% Energia necesaria para completar la distancia prevista
E_necesaria = distancia_prevista .* consumo_est;   % [kWh]

% Caida de SOC asociada al consumo previsto
delta_SOC = (E_necesaria ./ C_bat) * 100;          % [puntos porcentuales]

% SOC final estimado
SOC_final = SOC_ini - delta_SOC;                    % [%]

% Energia util disponible hasta alcanzar el SOC minimo
E_util = ((SOC_ini - SOC_min) / 100) * C_bat;      % [kWh]

% Autonomia estimada hasta alcanzar el SOC minimo
autonomia_prevista = E_util ./ consumo_est;        % [km]

% Margen operativo
margen_operativo = autonomia_prevista - distancia_prevista; % [km]

%% 5. CLASIFICACION DEL ESTADO OPERATIVO

estado = strings(N,1);

estado(margen_operativo > margen_aviso) = "Normal";

estado(margen_operativo >= 0 & ...
       margen_operativo <= margen_aviso) = "Aviso";

estado(margen_operativo < 0) = "Critico";

%% 6. RESULTADOS GLOBALES

P_normal = mean(estado == "Normal") * 100;
P_aviso = mean(estado == "Aviso") * 100;
P_critico = mean(estado == "Critico") * 100;
P_SOC_bajo = mean(SOC_final < SOC_min) * 100;

SOC_final_medio = mean(SOC_final);
SOC_final_mediana = median(SOC_final);
margen_medio = mean(margen_operativo);

fprintf('\n=== RESULTADOS MONTE CARLO ===\n');
fprintf('Escenarios simulados: %d\n', N);
fprintf('Proporcion Normal: %.2f %%\n', P_normal);
fprintf('Proporcion Aviso: %.2f %%\n', P_aviso);
fprintf('Proporcion Critico: %.2f %%\n', P_critico);
fprintf('Proporcion SOC final < %.1f %%: %.2f %%\n', ...
    SOC_min, P_SOC_bajo);
fprintf('SOC final medio: %.2f %%\n', SOC_final_medio);
fprintf('SOC final mediano: %.2f %%\n', SOC_final_mediana);
fprintf('Margen operativo medio: %.2f km\n\n', margen_medio);

%% 7. GUARDAR RESULTADOS COMPLETOS

resultados = table( ...
    SOC_ini, ...
    distancia_prevista, ...
    consumo_est, ...
    E_necesaria, ...
    SOC_final, ...
    autonomia_prevista, ...
    margen_operativo, ...
    estado, ...
    'VariableNames', { ...
    'SOC_ini_pct', ...
    'Distancia_prevista_km', ...
    'Consumo_estimado_kWh_km', ...
    'Energia_necesaria_kWh', ...
    'SOC_final_pct', ...
    'Autonomia_prevista_km', ...
    'Margen_operativo_km', ...
    'Estado'});

archivo_resultados = fullfile( ...
    resultados_dir, ...
    'resultados_monte_carlo.csv');

writetable(resultados, archivo_resultados);

%% 8. GUARDAR RESUMEN

resumen = table( ...
    N, ...
    C_bat, ...
    SOC_min, ...
    margen_aviso, ...
    P_normal, ...
    P_aviso, ...
    P_critico, ...
    P_SOC_bajo, ...
    SOC_final_medio, ...
    SOC_final_mediana, ...
    margen_medio, ...
    'VariableNames', { ...
    'N_escenarios', ...
    'Capacidad_kWh', ...
    'SOC_min_pct', ...
    'Margen_aviso_km', ...
    'Normal_pct', ...
    'Aviso_pct', ...
    'Critico_pct', ...
    'SOC_final_menor_SOCmin_pct', ...
    'SOC_final_medio_pct', ...
    'SOC_final_mediana_pct', ...
    'Margen_operativo_medio_km'});

archivo_resumen = fullfile( ...
    resultados_dir, ...
    'resumen_monte_carlo.csv');

writetable(resumen, archivo_resumen);

%% 9. FIGURA - DISTRIBUCION DEL SOC FINAL

figure
histogram(SOC_final, 40)
hold on
xline(SOC_min, '--', 'SOC minimo')
hold off

xlabel('SOC final previsto [%]')
ylabel('Numero de escenarios')
title('Distribucion Monte Carlo del SOC final previsto')
grid on

exportgraphics( ...
    gcf, ...
    fullfile(resultados_dir, 'fig_monte_carlo_soc_final.png'), ...
    'Resolution', 300);

%% 10. FIGURA - CLASIFICACION DEL ESTADO OPERATIVO

porcentajes = [P_normal, P_aviso, P_critico];

figure
bar(categorical(["Normal","Aviso","Critico"]), porcentajes)

ylabel('Proporcion de escenarios [%]')
title('Estado operativo en la simulacion Monte Carlo')
ylim([0 100])
grid on

exportgraphics( ...
    gcf, ...
    fullfile(resultados_dir, 'fig_monte_carlo_estado_operativo.png'), ...
    'Resolution', 300);

%% 11. COMPROBACIONES BASICAS

if abs(P_normal + P_aviso + P_critico - 100) > 1e-10
    warning('Las proporciones de estado no suman exactamente 100 %%')
end

if any(estado == "")
    warning('Existen escenarios sin clasificar.')
end

disp("Simulacion Monte Carlo finalizada correctamente.")
disp("Archivos generados:")
disp(fullfile(resultados_dir, 'resultados_monte_carlo.csv'))
disp(fullfile(resultados_dir, 'resumen_monte_carlo.csv'))
disp(fullfile(resultados_dir, 'fig_monte_carlo_soc_final.png'))
disp(fullfile(resultados_dir, 'fig_monte_carlo_estado_operativo.png'))