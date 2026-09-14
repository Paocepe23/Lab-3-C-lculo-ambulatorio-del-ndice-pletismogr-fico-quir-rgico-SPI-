%% SPI_ambulatorio_mejorado.m
% Captura PPG desde un MAX30102 (via MAX30102_SPI_lectura.ino), valida y
% parsea correctamente los datos, remuestrea a una malla uniforme, filtra
% con un pasa-banda fisiologico, detecta latidos de forma robusta
% (findpeaks), normaliza contra la linea base y calcula el SPI (suavizado).
%
% Este script espera que el Arduino mande, por cada muestra, una linea:
%     t_ms,IR
% (t_ms = millis() del Arduino, IR = lectura cruda del MAX30102)
% tal como hace MAX30102_SPI_lectura.ino. Lineas que no tengan ese
% formato (avisos de texto como "Sin dedo detectado", "MAX30102
% detectado...", "ERROR: ...") se ignoran automaticamente.
%
% DIAGNOSTICO DEL BUG ORIGINAL (valores ~1e10 en la senal cruda):
%   El Arduino manda "t_ms,IR" con una coma. El codigo original hacia
%   valor = str2double(linea) sobre la LINEA COMPLETA. MATLAB interpreta
%   una coma dentro de un numero como separador de MILES (no como
%   separador de campos), asi que "123456,78000" se leia como el numero
%   unico 12345678000 (~1.2e10). De ahi salian esos valores absurdos.
%   La solucion es separar t_ms e IR ANTES de convertirlos a numero.
%
% CAMBIOS PRINCIPALES respecto a la version original:
%   1) Parseo correcto de "t_ms,IR" con sscanf (separa los dos campos
%      antes de convertir a numero; ya no se confunde la coma).
%   2) Se usa el timestamp real del Arduino (millis(), mas fiel que el
%      tic/toc de MATLAB) como base de tiempo de cada muestra.
%   3) Validacion de rango del IR (sanity check, ajustable) para
%      descartar lineas corruptas puntuales.
%   4) Remuestreo a tiempo uniforme antes de filtrar (necesario porque
%      el muestreo real vía serial + callback es irregular).
%   5) Filtro pasa-banda Butterworth (0.5-4 Hz) con filtfilt en vez de
%      doble movmean: aisla la componente pulsatil sin desfase.
%   6) Deteccion de picos/valles con findpeaks (MinPeakDistance +
%      MinPeakProminence) en vez de un detector local ingenuo.
%   7) Grafica intermedia de la senal filtrada para verificar
%      visualmente que SI se ve como un PPG antes de calcular el SPI.
%   8) Suavizado exponencial (EMA) de PPGAnorm/HBInorm antes del SPI,
%      como se hace en la implementacion clinica real, para evitar que
%      el indice salte erraticamente latido a latido.

clear; clc; close all;
clearvars -global bufferTiempos bufferSenal t0Arduino offsetTiempo ultimoTmsCrudo

global bufferTiempos bufferSenal t0Arduino offsetTiempo ultimoTmsCrudo
bufferTiempos = [];   % tiempo de cada muestra, en segundos, ya continuo (ver FIX 2b)
bufferSenal = [];
t0Arduino = [];        % t_ms del Arduino al inicio del "tramo" (epoca) actual
offsetTiempo = 0;      % segundos acumulados de tramos anteriores (antes de un reinicio)
ultimoTmsCrudo = [];   % ultimo t_ms crudo recibido, para detectar si el Arduino se reinicio

%% ---------- CONFIGURACION ----------
puerto = "COM6";
baudrate = 115200;
duracionTotal = 120;
duracionBaseline = 40;

% %% FIX (3): rango valido de IR para el MAX30102.
% El sketch ya filtra "sin dedo" con UMBRAL_DEDO = 50000, asi que con
% dedo puesto se espera IR bastante por encima de eso. El limite superior
% es solo un sanity check generoso para descartar una linea corrupta
% puntual (ajustalo si ves que tus lecturas reales llegan mas alto/bajo,
% mira el "Rango crudo" que imprime el script al terminar la captura).
irMin = 30000;
irMax = 300000;

% Frecuencia de muestreo objetivo para el remuestreo uniforme (Hz).
% El sketch esta configurado a sampleRate=100 Hz con sampleAverage=4,
% asi que la tasa efectiva de muestras nuevas es ~25 Hz. Ajusta si
% cambias esos parametros en el .ino.
fsObjetivo = 25;

%% ---------- CONEXION SERIAL ----------
s = serialport(puerto, baudrate);
s.ErrorOccurredFcn = @(src, evt) fprintf("Aviso: error de comunicacion serial (%s), continuando...\n", evt.ErrorMessage);
pause(3);
flush(s);

%% ---------- FIGURA DE VISUALIZACION EN VIVO ----------
figLive = figure('Name', 'Senal PPG en vivo', 'Color', 'w');
axLive = axes(figLive);
hLine = animatedline(axLive, 'Color', [0 0.4470 0.7410], 'LineWidth', 1.2);
xlabel(axLive, 'Tiempo (s)');
ylabel(axLive, 'Valor IR crudo');
title(axLive, 'Captura en vivo - coloca el dedo y mantente quieto');
grid(axLive, 'on');

%% ---------- ADQUISICION POR CALLBACK CON VISTA EN VIVO ----------
disp("Conectado. Coloca el dedo y mantente quieto. Iniciando captura...");
tImpresionInicio = tic;
configureCallback(s, "terminator", @(src, evt) callbackLectura(src, evt, irMin, irMax));

% %% FIX (0): watchdog de reconexion.
% Si el chip USB-serial (tipico en clones con CH340) se "cuelga" en
% silencio -sin lanzar ningun error- MATLAB deja de recibir datos nuevos
% aunque el puerto siga "abierto". Si pasan mas de umbralSinDatos
% segundos sin ninguna muestra nueva, se cierra y reabre el puerto para
% intentar recuperar la conexion sin perder toda la captura.
umbralSinDatos = 5; % segundos sin datos nuevos antes de intentar reconectar
tUltimaMuestra = tic;

ultimoGraficado = 0;
while toc(tImpresionInicio) < duracionTotal
    pause(0.05); % deja que el callback siga recibiendo datos en segundo plano

    nMuestras = length(bufferSenal);
    if nMuestras > ultimoGraficado
        for k = (ultimoGraficado+1):nMuestras
            addpoints(hLine, bufferTiempos(k), bufferSenal(k));
        end
        ultimoGraficado = nMuestras;
        tActual = toc(tImpresionInicio);
        xlim(axLive, [max(0, tActual-10), tActual+0.5]);
        drawnow limitrate;
        tUltimaMuestra = tic; % hubo dato nuevo: reinicia el cronometro del watchdog
    elseif toc(tUltimaMuestra) > umbralSinDatos
        fprintf("Aviso: %d s sin datos nuevos. Reintentando reconexion del puerto serial...\n", umbralSinDatos);
        try
            configureCallback(s, "off");
            clear s;
            pause(1);
            s = serialport(puerto, baudrate);
            s.ErrorOccurredFcn = @(src, evt) fprintf("Aviso: error de comunicacion serial (%s), continuando...\n", evt.ErrorMessage);
            flush(s);
            configureCallback(s, "terminator", @(src, evt) callbackLectura(src, evt, irMin, irMax));
            disp("Reconexion intentada. Si el problema persiste, revisa el puerto USB/driver del Arduino.");
        catch ME
            fprintf("No se pudo reconectar automaticamente: %s\n", ME.message);
        end
        tUltimaMuestra = tic; % evita reintentar en cada vuelta del while
    end
end

configureCallback(s, "off");
tiemposCrudo = bufferTiempos;
senalCruda = bufferSenal;
clear s;

title(axLive, 'Captura finalizada');
disp("Captura finalizada. Procesando senal...");

if length(senalCruda) < 100
    error("Se capturaron muy pocas muestras validas. Revisa: 1) que el dedo este bien puesto, 2) que irMin/irMax coincidan con tus lecturas reales, 3) la conexion I2C del MAX30102.");
end

fprintf("Muestras validas capturadas: %d | Rango crudo IR: [%.0f, %.0f]\n", ...
    length(senalCruda), min(senalCruda), max(senalCruda));
fprintf("Duracion real cubierta por timestamps de Arduino: %.1f s\n", tiemposCrudo(end));

%% ---------- FIX (4a): REPARAR TIMESTAMPS DUPLICADOS ----------
% millis() del Arduino solo tiene resolucion de 1 ms. Como el sketch lee
% el FIFO del MAX30102 en rafaga (varias muestras por vuelta de loop()),
% es normal que varias muestras compartan el mismo t_ms. interp1 exige
% tiempos estrictamente crecientes, asi que aqui se distribuyen esas
% muestras "empatadas" uniformemente dentro de su tramo de tiempo, sin
% descartar ningun dato.
tiemposCrudo = repararTiemposDuplicados(tiemposCrudo(:));

%% ---------- FIX (4b): REMUESTREO A TIEMPO UNIFORME ----------
% Aunque ahora usamos el timestamp real del Arduino (mas confiable que
% tic/toc de MATLAB), el intervalo entre muestras sigue sin ser
% perfectamente constante (jitter de USB/callback). Filtrar en
% frecuencia (Butterworth) requiere una fs constante y conocida.
tUniforme = tiemposCrudo(1):(1/fsObjetivo):tiemposCrudo(end);
senal = interp1(tiemposCrudo, senalCruda, tUniforme, 'linear');
tiempos = tUniforme;
fs = fsObjetivo;

fprintf("Remuestreado a fs = %d Hz | %d muestras\n", fs, length(senal));

%% ---------- FIX (5): FILTRO PASA-BANDA FISIOLOGICO ----------
% Banda de interes para el pulso cardiaco: 0.5-4 Hz (30-240 lpm).
% Se intenta usar un Butterworth + filtfilt (mejor calidad, sin desfase),
% pero esas funciones requieren el Signal Processing Toolbox. Si no esta
% instalado (como en tu caso), se usa automaticamente un filtro
% equivalente hecho solo con movmean (funcion base de MATLAB, siempre
% disponible): una resta de dos promedios moviles de distinta ventana
% logra el mismo efecto de "pasa-banda" -> quita la deriva lenta
% (frecuencias por debajo de fLow) y suaviza el ruido rapido (por encima
% de fHigh), dejando solo la componente pulsatil.
fLow = 0.5;
fHigh = 4;

try
    ordenFiltro = 3;
    [b, a] = butter(ordenFiltro, [fLow fHigh] / (fs/2), 'bandpass');
    senalFiltrada = filtfilt(b, a, senal);
    disp("Filtro pasa-banda: Butterworth + filtfilt (Signal Processing Toolbox).");
catch
    ventanaBaja = max(3, round(fs / fLow));       % ~2 s: elimina deriva lenta
    ventanaAlta = max(3, round(fs / (2*fHigh)));  % suaviza ruido de alta frecuencia
    tendenciaLenta = movmean(senal, ventanaBaja);
    senalDetrend = senal - tendenciaLenta;
    senalFiltrada = movmean(senalDetrend, ventanaAlta);
    disp("Filtro pasa-banda: promedios moviles (movmean) - Signal Processing Toolbox no disponible.");
end

% Grafica de verificacion: la senal filtrada DEBE verse como una onda de
% pulso (forma periodica clara), no como ruido ni como una rampa. Si no
% se ve asi, el problema esta en la adquisicion (dedo mal puesto,
% movimiento, ledBrightness muy bajo/alto), no en el procesamiento.
figure('Name', 'Verificacion: senal filtrada', 'Color', 'w');
plot(tiempos, senalFiltrada, 'LineWidth', 1);
xlabel('Tiempo (s)'); ylabel('Amplitud (u.a.)');
title('Senal PPG filtrada (0.5-4 Hz) - debe verse pulsatil');
grid on;

%% ---------- FIX (6): DETECCION DE PICOS/VALLES (ALGORITMO PROPIO) ----------
% Por instruccion del docente, no se usa "findpeaks" (funcion de caja
% negra del Signal Processing Toolbox): la deteccion de picos y valles
% debe ser un algoritmo propio, implementado a mano. Se usa la funcion
% local "detectarExtremosSimple" (ver mas abajo), con dos reglas
% explicitas:
%   - Distancia minima entre picos, basada en una frecuencia cardiaca
%     maxima fisiologicamente razonable.
%   - Prominencia minima: un maximo local solo cuenta si sobresale al
%     menos un umbral por encima de sus valles vecinos mas cercanos.
minDistSeg = 0.33; % ~180 lpm maximo fisiologicamente razonable
minDistMuestras = round(minDistSeg * fs);

% %% FIX (6b): umbral de prominencia ROBUSTO (MAD en vez de std).
% std() se ve muy afectada por unos pocos valores extremos (p. ej.
% artefactos de movimiento durante el CPT, que pueden llegar a ser 10-50
% veces mas grandes que un latido normal). Si se usa std() para fijar el
% umbral, esos pocos picos gigantes inflan el umbral para TODA la senal,
% y el algoritmo se vuelve demasiado estricto justo en los tramos
% limpios, perdiendo latidos reales. La desviacion absoluta mediana
% (MAD) es un estadistico robusto: unos pocos valores extremos casi no
% la mueven, porque se basa en la mediana en vez del promedio de
% cuadrados. 1.4826*MAD es el equivalente robusto de la desviacion
% estandar para datos aproximadamente normales.
medianaSenal = median(senalFiltrada);
madSenal = median(abs(senalFiltrada - medianaSenal));
desviacionRobusta = 1.4826 * madSenal;
prominenciaMin = 0.15 * desviacionRobusta;

[picos, idxPicos] = detectarExtremosSimple(senalFiltrada, minDistMuestras, prominenciaMin, true);
[valles, idxValles] = detectarExtremosSimple(senalFiltrada, minDistMuestras, prominenciaMin, false);

tPicos = tiempos(idxPicos);
tValles = tiempos(idxValles);

if length(tPicos) < 5
    error("Se detectaron muy pocos picos (%d). Revisa la calidad de la senal filtrada en la figura de verificacion.", length(tPicos));
end

%% ---------- EXTRACCION DE PPGA Y HBI CON FILTROS DE VALIDEZ ----------
PPGAraw = [];
HBIraw = [];
tLatidoRaw = [];

for i = 2:length(idxPicos)
    valleAntes = valles(find(tValles < tPicos(i), 1, 'last'));
    if isempty(valleAntes)
        continue;
    end
    intervalo = tPicos(i) - tPicos(i-1);
    if intervalo < 0.33 || intervalo > 2.0
        continue;
    end
    PPGAraw(end+1) = picos(i) - valleAntes; %#ok<*AGROW>
    HBIraw(end+1)  = intervalo;
    tLatidoRaw(end+1) = tPicos(i);
end

if isempty(PPGAraw)
    error("No se detectaron latidos fisiologicamente validos. Revisa la senal filtrada.");
end

medAmp = median(PPGAraw);
madAmp = median(abs(PPGAraw - medAmp)) + eps;
esValido = abs(PPGAraw - medAmp) < 5 * madAmp;

PPGA = PPGAraw(esValido);
HBI = HBIraw(esValido);
tLatido = tLatidoRaw(esValido);

fprintf("Latidos detectados: %d | Validos tras filtros: %d\n", length(PPGAraw), length(PPGA));

%% ---------- NORMALIZACION CONTRA LA LINEA BASE (percentiles, robusto) ----------
idxBaseline = tLatido <= duracionBaseline;
if sum(idxBaseline) < 3
    idxBaseline = 1:min(5, length(PPGA));
end

ppgaMin = prctile(PPGA(idxBaseline), 10);
ppgaMax = prctile(PPGA(idxBaseline), 90);
hbiMin  = prctile(HBI(idxBaseline), 10);
hbiMax  = prctile(HBI(idxBaseline), 90);

ppgaRange = max(ppgaMax - ppgaMin, eps);
hbiRange  = max(hbiMax - hbiMin, eps);

PPGAnorm = 100 * (PPGA - ppgaMin) / ppgaRange;
HBInorm  = 100 * (HBI  - hbiMin)  / hbiRange;

PPGAnorm = min(max(PPGAnorm, 0), 100);
HBInorm  = min(max(HBInorm, 0), 100);

%% ---------- FIX (8): SUAVIZADO EXPONENCIAL (EMA) LATIDO A LATIDO ----------
% La implementacion clinica del SPI no usa el valor crudo de cada latido:
% aplica un promedio movil/exponencial para evitar saltos abruptos por
% ruido de un solo latido. alpha mas bajo = mas suave, mas lento.
alpha = 0.2;
PPGAnormSuave = zeros(size(PPGAnorm));
HBInormSuave = zeros(size(HBInorm));
PPGAnormSuave(1) = PPGAnorm(1);
HBInormSuave(1) = HBInorm(1);
for i = 2:length(PPGAnorm)
    PPGAnormSuave(i) = alpha*PPGAnorm(i) + (1-alpha)*PPGAnormSuave(i-1);
    HBInormSuave(i)  = alpha*HBInorm(i)  + (1-alpha)*HBInormSuave(i-1);
end

%% ---------- CALCULO DEL SPI ----------
% Formula de Huiku et al. (2007): SPI = 100 - (0.33*HBInorm + 0.67*PPGAnorm)
SPI = 100 - (0.33*HBInormSuave + 0.67*PPGAnormSuave);

%% ---------- RESULTADOS EN VENTANA DE COMANDOS ----------
fprintf("\n--- SPI por latido (suavizado) ---\n");
for i = 1:length(SPI)
    fprintf("t = %6.2f s | SPI = %5.1f\n", tLatido(i), SPI(i));
end

%% ---------- GRAFICA FINAL DE EVOLUCION DEL SPI ----------
figure('Name', 'Evolucion del SPI', 'Color', 'w');
plot(tLatido, SPI, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b', 'MarkerSize', 5);
xlabel('Tiempo (s)');
ylabel('SPI');
title('Evolucion del Indice Pletismografico Quirurgico (SPI)');
yline(20, '--r', 'Limite inferior (20)');
yline(50, '--r', 'Limite superior (50)');
xline(duracionBaseline, '--k', 'Inicio CPT');
xline(duracionBaseline + 40, '--k', 'Fin CPT');
ylim([0 105]);
xlim([0 duracionTotal]);
grid on;

%% ---------- FUNCION LOCAL: DETECCION DE EXTREMOS SIN TOOLBOX ----------
function [valores, indices] = detectarExtremosSimple(x, minDistMuestras, prominenciaMin, buscarMaximos)
    % Reemplazo de findpeaks (Signal Processing Toolbox) hecho solo con
    % funciones base de MATLAB. Aplica las mismas dos reglas:
    %   - MinPeakDistance: dos picos no pueden estar mas cerca que
    %     minDistMuestras; si compiten, se queda el de mayor valor.
    %   - MinPeakProminence: un maximo local solo cuenta si sobresale al
    %     menos prominenciaMin por encima de sus valles vecinos mas
    %     cercanos (a cada lado).
    if ~buscarMaximos
        x = -x;
    end

    n = length(x);
    esMaximoLocal = false(1, n);
    for i = 2:n-1
        if x(i) > x(i-1) && x(i) > x(i+1)
            esMaximoLocal(i) = true;
        end
    end
    candidatos = find(esMaximoLocal);

    % Filtro de prominencia: para cada candidato, busca el valle mas
    % cercano a la izquierda y a la derecha, y exige que el candidato
    % supere a AMBOS por al menos prominenciaMin.
    candidatosValidos = [];
    for idx = candidatos
        izq = idx;
        while izq > 1 && x(izq-1) <= x(izq)
            izq = izq - 1;
        end
        valleIzq = min(x(izq:idx));

        der = idx;
        while der < n && x(der+1) <= x(der)
            der = der + 1;
        end
        valleDer = min(x(idx:der));

        prominencia = x(idx) - max(valleIzq, valleDer);
        if prominencia >= prominenciaMin
            candidatosValidos(end+1) = idx; %#ok<AGROW>
        end
    end

    % Filtro de distancia minima: recorre en orden y, si dos candidatos
    % quedan mas cerca que minDistMuestras, se queda con el de mayor valor.
    indices = [];
    for idx = candidatosValidos
        if isempty(indices)
            indices(end+1) = idx; %#ok<AGROW>
        elseif (idx - indices(end)) >= minDistMuestras
            indices(end+1) = idx; %#ok<AGROW>
        elseif x(idx) > x(indices(end))
            indices(end) = idx;
        end
    end

    valores = x(indices);
    if ~buscarMaximos
        valores = -valores;
    end
end

%% ---------- FUNCION LOCAL: REPARAR TIMESTAMPS DUPLICADOS ----------
function tCorregido = repararTiemposDuplicados(t)
    % Distribuye uniformemente, dentro de cada tramo de timestamps
    % identicos, las muestras que llegaron "empatadas" en el mismo
    % milisegundo, para que el vector de tiempo quede estrictamente
    % creciente (requisito de interp1) sin perder ninguna muestra.
    tCorregido = t;
    n = length(t);
    i = 1;
    while i <= n
        j = i;
        while j < n && t(j+1) == t(i)
            j = j + 1;
        end
        if j > i
            cuantas = j - i + 1;
            if j < n
                siguiente = t(j+1);
            elseif i > 1
                siguiente = t(i) + (t(i) - tCorregido(i-1));
            else
                siguiente = t(i) + cuantas/1000; % 1 ms por muestra, valor por defecto
            end
            paso = (siguiente - t(i)) / cuantas;
            for k = 0:(cuantas-1)
                tCorregido(i+k) = t(i) + k*paso;
            end
        end
        i = j + 1;
    end
end

%% ---------- FUNCION LOCAL: CALLBACK DE LECTURA SERIAL ----------
function callbackLectura(src, ~, irMin, irMax)
    global bufferTiempos bufferSenal t0Arduino offsetTiempo ultimoTmsCrudo
    try
        linea = readline(src);

        % %% FIX (1): parsear "t_ms,IR" como DOS campos, no como un solo
        % numero. Esto es lo que evita el bug de valores gigantes
        % (~1e10) causado por str2double interpretando la coma como
        % separador de miles.
        valores = sscanf(linea, '%f,%f');

        % Si la linea no tiene exactamente el formato "t_ms,IR" (por
        % ejemplo "Sin dedo detectado" o "MAX30102 detectado..."),
        % sscanf no devuelve 2 valores y se descarta silenciosamente.
        if numel(valores) == 2
            t_ms = valores(1);
            irValue = valores(2);

            % %% FIX (3): sanity check del rango de IR.
            if isfinite(irValue) && irValue >= irMin && irValue <= irMax

                if isempty(t0Arduino)
                    % Primera muestra de toda la captura.
                    t0Arduino = t_ms;
                    ultimoTmsCrudo = t_ms;
                elseif t_ms < ultimoTmsCrudo - 50
                    % %% FIX (2b): el Arduino se reinicio (p. ej. al
                    % reabrir el puerto en el watchdog, lo cual dispara
                    % un auto-reset via DTR). millis() volvio a arrancar
                    % desde ~0, asi que en vez de sumar ese tiempo "viejo"
                    % con el nuevo (lo que causaba el salto en linea
                    % recta en la grafica), se acumula el tiempo ya
                    % transcurrido como offset y se arranca una "epoca"
                    % nueva desde este punto, para que el tiempo total
                    % siga avanzando sin saltos ni retrocesos.
                    offsetTiempo = offsetTiempo + (ultimoTmsCrudo - t0Arduino) / 1000;
                    t0Arduino = t_ms;
                end

                ultimoTmsCrudo = t_ms;
                tSeg = offsetTiempo + (t_ms - t0Arduino) / 1000;

                bufferTiempos(end+1) = tSeg;
                bufferSenal(end+1) = irValue;
            end
        end
    catch
        % dato corrupto puntual: se ignora y sigue la captura
    end
end
