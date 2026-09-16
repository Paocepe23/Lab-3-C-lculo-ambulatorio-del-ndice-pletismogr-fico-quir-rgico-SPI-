# Laboratorio 3: Cálculo ambulatorio del índice pletismográfico quirúrgico (SPI)

**Integrantes:**
- Porras Rodríguez, José Daniel
- López Duarte, Juan Sebastián
- Cepeda Castro, Paola Andrea

-----
## 1. Introducción 
### 1.1 Contexto teórico

Una gran cantidad de procedimientos quirúrgicos producen daño tisular, por lo que entre el 20% y el 80% de los pacientes se quejan de dolor posoperatorio agudo, de moderado a intenso [1]. Por esta razón, es fundamental evaluar con precisión la nocicepción intraoperatoria en pacientes sometidos a cirugía bajo anestesia general y administrar la analgesia adecuada para reducir el dolor posoperatorio.
Entre los diversos métodos desarrollados para la monitorización cuantitativa y objetiva de la nocicepción durante la cirugía bajo anestesia general [2], se destaca el *índice pletismográfico quirúrgico o SPI* (Surgical Pleth Index, GE Healthcare). Este índice emplea la onda de pulso, también conocida como señal fotopletismográfica (PPG), para detectar el equilibrio entre la activación nociceptiva y la analgesia durante la anestesia general [3].
El SPI varía entre 0 y 100; los valores más altos indican una mayor respuesta nociceptiva (estrés). El rango objetivo para una analgesia intraoperatoria adecuada durante la anestesia general suele ser de 20 a 50 [4]. Por lo tanto, los valores de SPI deben mantenerse por debajo de 50, y deben evitarse incrementos del SPI superiores a 10 [5].
Trabajos posteriores han reforzado esta evidencia: Oh et al. (2024) [6] revisan de forma exhaustiva la utilidad y limitaciones del SPI en el manejo del dolor perioperatorio, señalando que factores como la edad, el volumen circulante, la posición del paciente, la medicación concomitante y el nivel de conciencia pueden confundir la interpretación del índice. En población latinoamericana, Dávila-Zenteno y Meza-Ruiz (2024) [7] encontraron un valor de corte de SPI de 36 como predictor de dolor posoperatorio moderado a severo, con un valor predictivo positivo del 88.7% y negativo del 80%. Por su parte, Van Santvliet y Vereecke (2024) [8] ubican al SPI entre los monitores de nocicepción con mayor nivel de validación clínica disponible actualmente.

### 1.2 Importancia de la práctica

La relevancia de esta práctica reside en la extracción y cálculo de características derivadas de la onda de pulso (amplitud pletismográfica e intervalo entre latidos) para estimar el balance nocicepción-analgesia, replicando en condiciones ambulatorias y de bajo costo el principio de funcionamiento de un monitor clínico comercial.

## 2. Objetivos

*Objetivo general:* Desarrollar un sistema de medición continua del índice pletismográfico quirúrgico (SPI) en condiciones ambulatorias.

*Objetivos específicos:*
- Reconocer las características fundamentales de la onda de pulso a partir de las cuales se obtiene el SPI.
- Construir un sistema que calcule el SPI en tiempo real y bajo condiciones ambulatorias.
- Validar el funcionamiento del sistema desarrollado mediante un método que induzca una respuesta fisiológica similar a la que produce el dolor agudo (Cold Pressor Test, CPT).

## 3. Materiales, software y hardware utilizados

| Descripción | Cantidad |
|---|---|
| Arduino UNO / Nano | 1 |
| Sensor de pulso MAX30102 (SparkFun MAX3010x) | 1 |
| Computador con MATLAB (sin Signal Processing Toolbox) | 1 |
| Cable USB | 1 |


> *Nota sobre el sensor elegido:* se utilizó el módulo *MAX30102*, un sensor óptico integrado de pulsioximetría/PPG con salida digital vía I2C, en lugar del circuito análogo (fototransistor + amplificación discreta) propuesto en la guía. Esto simplifica la etapa de acondicionamiento analógico, trasladando la responsabilidad de filtrado y ganancia al procesamiento digital en MATLAB.

## 4. Descripción del sistema

El sistema consta de dos partes:

### 4.1 Firmware (Arduino) — MAX30102_SPI_lectura.ino

- Inicializa el sensor MAX30102 vía I2C (400 kHz) con sampleRate = 100 Hz, sampleAverage = 4, ledMode = 2 (Red+IR), adcRange = 4096.
- Lee el FIFO del sensor de forma *no bloqueante* en cada iteración de loop() (evita que el programa se cuelgue si el dedo se retira o el sensor falla).
- Filtra localmente las lecturas sin dedo puesto mediante un umbral (UMBRAL_DEDO = 50000).
- Transmite cada muestra válida por puerto serial (115200 baudios) en el formato:
  t_ms,IR
  donde t_ms es el timestamp de Arduino (millis()) e IR es la lectura cruda de infrarrojo del sensor.

### 4.2 Procesamiento (MATLAB) — SPI_ambulatorio_mejorado.m
El script realiza, en orden:

1. *Adquisición en vivo* vía serialport con callback por terminador, graficando la señal cruda en tiempo real durante los 120 s de captura (40 s de reposo + 40 s de Cold Pressor Test + 40 s de recuperación).
2. *Parseo robusto* del formato t_ms,IR (separando ambos campos antes de convertirlos a número).
3. *Reparación de timestamps duplicados*, producto de que millis() solo tiene resolución de 1 ms y el sensor puede entregar varias muestras por milisegundo.
4. *Remuestreo a malla de tiempo uniforme* (necesario porque la llegada de datos vía serial es irregular).
5. *Filtrado pasa-banda fisiológico (0.5–4 Hz)* para aislar la componente pulsátil del PPG y remover la deriva de línea base.
6. *Detección de picos y valles con un algoritmo propio (sin findpeaks).* Por instrucción explícita del docente, no se permite usar findpeaks —ni ningún otro método de detección de picos ya implementado en un toolbox de MATLAB— como solución a este requisito de la práctica; el algoritmo debe ser propio (p. ej., el método del alpinista de Argüello-Prada [9], o cualquier otro, siempre que sea implementado por el estudiante). Se optó por un detector de extremos locales hecho a mano (función local detectarExtremosSimple), con dos criterios explícitos:
   - *Distancia mínima entre picos:* basada en una frecuencia cardiaca máxima fisiológicamente razonable (180 lpm → 0.33 s).
   - *Prominencia mínima:* un máximo local solo se acepta si supera en amplitud a sus valles vecinos más cercanos por al menos un umbral proporcional a la desviación estándar de la señal filtrada.

  > El filtrado pasa-banda (paso 5) sí puede apoyarse en funciones base de MATLAB como movmean, ya que la restricción del docente aplica específicamente al algoritmo de detección de picos —el objetivo central de la práctica—, no al preprocesamiento de la señal.
7.*Extracción de PPGA y HBI* por latido, con filtros de validez fisiológica (intervalos entre 0.33 s y 2.0 s) y rechazo de valores atípicos de amplitud mediante la mediana y la desviación absoluta mediana (MAD).
8.*Normalización contra la línea base*(percentiles 10–90 de los primeros 40 s de reposo).
9.*Suavizado exponencial (EMA)*de las variables normalizadas, replicando el procesamiento latido-a-latido que usan los monitores clínicos reales (evita que el índice salte erráticamente por ruido de un solo latido).
10.*Cálculo del SPI* y graficación de su evolución en el tiempo, señalando el inicio y fin del CPT.

## 5. Definición matemática del SPI
Para cada latido detectado i, el algoritmo extrae dos variables continuas a partir de la morfo-fisiología de la onda pletismográfica (PPG):

Amplitud pletismográfica de pulso (PPGA): Diferencia de tensión/amplitud entre el pico sistólico actual y el valle diastólico que lo precede:
PPGA(i) = x(t_pico, i) - x(t_valle, i)

Intervalo entre latidos (HBI, Heartbeat Interval): Tiempo transcurrido entre dos picos sistólicos consecutivos:
HBI(i) = t_pico(i) - t_pico(i-1)

1. Normalización Adaptativa contra la Línea Base
Ambas variables se normalizan en relación con el periodo de reposo del sujeto (línea base, primeros 40 s) para ajustar la escala a la variabilidad interindividual de tono vascular. Se utilizan los percentiles 10 (P10) y 90 (P90) de la línea base como límites robustos ante artefactos:

PPGAnorm(i) = 100 * (PPGA(i) - P10_base) / (P90_base - P10_base)

HBInorm(i) = 100 * (HBI(i) - P10_base) / (P90_base - P10_base)

Nota de implementación (clipping): Ambas variables normalizadas se acotan estrictamente al rango [0, 100] mediante la función:
X_norm_clipped = min(max(X_norm, 0), 100)

2. Suavizado Exponencial Latido a Latido (EMA)
Para atenuar variaciones bruscas de alta frecuencia causadas por la arritmia de la respiración y ruido no estacionario, se aplica un filtro de media móvil exponencial (EMA) con factor de olvido alpha = 0.2:

PPGAsuave(i) = alpha * PPGAnorm(i) + (1 - alpha) * PPGAsuave(i-1)

HBIsuave(i) = alpha * HBInorm(i) + (1 - alpha) * HBIsuave(i-1)

3. Ecuación Final del SPI e Interpretación Fisiológica
El Índice Pletismográfico Quirúrgico (SPI) combina ponderadamente ambas componentes según el modelo propuesto por Huiku et al. (2007) [4]:

SPI(i) = 100 - (0.33 * HBIsuave(i) + 0.67 * PPGAsuave(i))

Comportamiento Fisiológico del Modelo:
Reposo / Confort: Predominio Parasimpático - HBI alto (bradicardia) y PPGA alto (vasodilatación) -> HBInorm ≈ 100 y PPGAnorm ≈ 100 -> SPI < 50 (Bajo)

Estresor / CPT (Hielo): Activación Simpática - HBI bajo (taquicardia) y PPGA bajo (vasoconstricción) -> HBInorm -> 0 y PPGAnorm -> 0 -> SPI >= 50 (Elevado)

Un incremento del tono simpático debido a un estímulo nociceptivo provoca vasoconstricción periférica (caída de PPGA) y taquicardia (caída de HBI). Como ambas variables disminuyen dentro del paréntesis de la fórmula, el término sustraendo se reduce y provoca una elevación neta del SPI, lo cual concuerda con lo reportado por Oh et al. (2024) [6].


## 6. Procedimiento realizado

### vaso con hielo (para colocar la mano).

<img width="420" height="228" alt="image" src="https://github.com/user-attachments/assets/f8623ce5-c340-4762-a255-953044d73710" />

### Circuito utilizado.

<img width="377" height="542" alt="image" src="https://github.com/user-attachments/assets/531a86b0-c8e5-4373-839c-8c3d7402c7bb" />



1. Se construyó el sistema de adquisición con el sensor MAX30102 conectado por I2C al Arduino, siguiendo el firmware descrito en la Sección 4.1.
2. Se depuró la comunicación serial hasta lograr una captura estable y sin corrupción de datos (ver Sección 8 — *Problemas encontrados y solución*).
3. Se verificó, mediante la gráfica intermedia de la señal filtrada, que la componente pulsátil fuera claramente visible antes de proceder al cálculo del SPI.
4. Se realizó una captura de 120 segundos con un integrante del grupo como voluntario:
   - 0–40 s: reposo (línea base).
   - 40–80 s: maniobra *Cold Pressor Test* (mano sumergida en agua con hielo).
   - 80–120 s: recuperación.
5. Se calculó el SPI latido a latido y se graficó su evolución completa, señalando el inicio y fin del CPT.

---

## 7. Resultados

### Datos tomados sin protocolo (sin hielo).

#### Señal en crudo

<img width="450" height="300" alt="image" src="https://github.com/user-attachments/assets/728e5403-4fc9-4413-8b11-179288c61ae7" />

#### Señal filtrada

<img width="450" height="300" alt="image" src="https://github.com/user-attachments/assets/6a35ca9a-9a9a-4658-9122-9b41d08934e9" />

#### Señal SPI

<img width="450" height="300" alt="image" src="https://github.com/user-attachments/assets/cc3d1f35-7404-41f2-9224-4265dc29e2ca" />

### Datos tomados con protocolo (con hielo).

#### Señal en crudo

<img width="450" height="300" alt="image" src="https://github.com/user-attachments/assets/4da9ea08-423c-4a9c-8b06-45a50cd89328" />

#### Señal filtrada

<img width="450" height="300" alt="image" src="https://github.com/user-attachments/assets/c4e25ea7-1854-467e-ab22-0b76b1203e52" />

#### Señal SPI

<img width="450" height="300" alt="image" src="https://github.com/user-attachments/assets/69807cb1-cef6-40b9-b456-0edd1b31e299" />


## Comparación

<img width="666.5" height="1000" alt="Diseño sin título" src="https://github.com/user-attachments/assets/2804ee23-26f3-4b1b-9b8f-013c5ac37db5" />

Izquierda (orden normal) los pulsos tienen un flanco sistólico bien definido, con subida y bajada marcadas.  Derecha (mano fría ): la onda se ve más aplanada y de menor amplitud relativa, con forma más redondeada. 


Derecha tiene dos picos artefactuales grandes (~3×10⁴ y ~4.5×10⁴). Izquierda tiene uno solo, y más pequeño (~1.1×10⁴). 


Los valores absolutos de SPI entre ambas corridas no son directamente comparables entre sí, aunque la forma o tendencia de la curva sí sea informativa.

Esto conecta directamente con lo que dice Oh et al. (2024) [6] sobre los factores de confusión del SPI (posición, medicación, estado fisiológico previo) aqui tendriamos informacion empirica.

En ambas corridas el SPI sube después del marcador de "Inicio CPT" y llega a valores altos (80-90).

- Un SPI basal  fluctuando aproximadamente entre 30 y 70.
- Un incremento sostenido del SPI durante la maniobra de CPT, alcanzando un pico cercano a 88 justo después de finalizado el estímulo.
- Un retorno gradual del SPI hacia valores cercanos a los de reposo durante el periodo de recuperación.

---

## 8. Problemas encontrados y solución (bitácora de depuración)

Durante el desarrollo se identificaron y corrigieron los siguientes problemas los cuales  documentamos.

1. *Valores de señal cruda del orden de 10¹⁰:* causado por que str2double() en MATLAB interpreta una coma dentro de un número como separador de miles, no como separador de campos. Como el Arduino envía t_ms,IR, la línea completa se interpretaba como un solo número gigante. *Solución:* parsear t_ms e IR como dos campos separados (sscanf) antes de convertir a número.
2. *Error Sample points must be unique en interp1:* causado por que millis() solo tiene resolución de 1 ms y el sensor entrega varias muestras por milisegundo en ráfaga. *Solución:* función repararTiemposDuplicados, que distribuye uniformemente las muestras "empatadas" dentro de su tramo de tiempo.
3. *Corte silencioso de la captura en vivo (sin ningún error) a los ~40–60 s:* causado por la gestión de energía USB de Windows, que suspendía el chip USB-serial (CH340) del Arduino sin notificar a la aplicación. *Solución:* desactivar el ahorro de energía para los concentradores USB en el Administrador de dispositivos de Windows. Adicionalmente, se implementó un watchdog de reconexión automática en el script como respaldo.
4. *Salto en línea recta en la gráfica tras una reconexión:* al reabrir el puerto serial, el Arduino se reinicia automáticamente (mecanismo de auto-reset vía DTR), por lo que millis() vuelve a arrancar desde cero. *Solución:* detección de "retroceso" en el timestamp crudo y acumulación de un offset de tiempo, para que la línea de tiempo interna del experimento siga siendo continua pese al reinicio físico del microcontrolador.
5. *butter, filtfilt y findpeaks no disponibles:* estas funciones requieren el Signal Processing Toolbox, no instalado, y además findpeaks fue explícitamente excluido por el docente como técnica válida para este laboratorio. *Solución:* filtro pasa-banda implementado con movmean (funciones base de MATLAB) y detector de picos/valles propio, basado en reglas de distancia mínima y prominencia mínima, sin depender de ninguna función de toolbox.

## 9. Análisis de resultados

*Análisis 1 — Comparación con valores quirúrgicos típicos:*
Los valores de SPI obtenidos durante el reposo de esta práctica (~30–70) son comparables al rango de referencia utilizado clínicamente para una analgesia intraoperatoria adecuada (20–50) [4], aunque con mayor variabilidad, esperable al tratarse de un voluntario despierto y consciente (y no un paciente bajo anestesia general, condición en la que el tono simpático basal es distinto). El incremento observado durante el CPT (hasta ~88) es consistente con la magnitud de cambio reportada en cirugía ante estímulos nociceptivos significativos, y con el umbral de alerta de "incremento de SPI mayor a 10" mencionado en la guía [5].

*Análisis 2 — Alcance y limitaciones del sistema para cuantificar dolor:*
El sistema desarrollado logra capturar de forma consistente la respuesta autonómica (taquicardia + vasoconstricción) ante un estímulo nociceptivo experimental, pero presenta limitaciones importantes:
- *Especificidad del estímulo:* el CPT es un estímulo de dolor experimental estandarizado, muy distinto en naturaleza al daño tisular quirúrgico real; el SPI mide nocicepción (respuesta autonómica), no dolor (experiencia subjetiva), por lo que no debe interpretarse como una medida directa del dolor percibido, tal como advierten Oh et al. (2024) [6].
- *Sensibilidad a artefactos de movimiento:* se observaron picos aislados de amplitud anómala (ver Sección 8) atribuibles a movimientos del dedo sobre el sensor, filtrados mediante el criterio de mediana ± 5×MAD, pero que evidencian la vulnerabilidad del sistema ante el movimiento del sujeto.
- *Ausencia de calibración clínica:* al no existir anestesia general de por medio, no es posible validar directamente si los umbrales clínicos (20–50) aplican de la misma forma en este contexto ambulatorio.
- *Dependencia del contacto óptico:* la calidad de la señal depende críticamente de la presión y posición del dedo sobre el sensor, un factor no controlado de forma instrumentada en este montaje.

## 10. Conclusiones

Esta práctica permitió construir e implementar de forma exitosa un sistema ambulatorio capaz de estimar el índice pletismográfico quirúrgico (SPI) a partir de una señal fotopletismográfica capturada con un sensor MAX30102 y procesada en tiempo real en MATLAB, replicando la lógica de cálculo empleada por monitores clínicos comerciales de nocicepción.

Los resultados muestran que el SPI calculado responde de forma coherente a un estímulo nociceptivo experimental (Cold Pressor Test), aumentando durante la maniobra y disminuyendo en la fase de recuperación, lo cual confirma que las variables extraídas de la onda de pulso (PPGA y HBI) capturan efectivamente cambios en el balance simpático-vagal asociados a la activación nociceptiva.

Sin embargo, es fundamental distinguir entre *nocicepción* (respuesta fisiológica y autonómica, medible objetivamente por el SPI) y *dolor* (experiencia subjetiva y consciente, que involucra componentes cognitivos y emocionales no capturables por una señal fisiológica periférica). El SPI —y por extensión, el sistema aquí desarrollado— es una herramienta de apoyo para inferir el balance nocicepción-analgesia, particularmente útil bajo anestesia general (donde el paciente no puede reportar dolor verbalmente), pero no reemplaza la evaluación clínica del dolor en un paciente consciente.

Como siguiente paso, sería valioso extender esta práctica incorporando un método de detección de artefactos de movimiento de bajo costo computacional (como se sugiere en la literatura consultada [9]), así como comparar el desempeño del sistema frente a un monitor comercial de SPI bajo condiciones controladas, para cuantificar formalmente su exactitud.

---

## 11. Preguntas para la discusión

*Pregunta 1: ¿Cómo se relacionan las variaciones del volumen sanguíneo periférico con el balance autonómico?*

Las variaciones del volumen sanguíneo periférico, capturadas por la señal PPG, reflejan directamente el tono vascular controlado por el sistema nervioso autónomo. Un aumento de la actividad simpática (p. ej., ante un estímulo doloroso) provoca vasoconstricción periférica, reduciendo la amplitud del pulso (PPGA) y acortando el intervalo entre latidos (HBI) por efecto cronotrópico positivo. Por el contrario, el predominio parasimpático favorece la vasodilatación y aumenta la amplitud pletismográfica. El SPI cuantifica precisamente este equilibrio, combinando ambas variables en un solo índice.

*Pregunta 2: ¿Cómo se compara el SPI con otros índices comúnmente empleados en cirugía, como el índice de nocicepción-analgesia (ANI) y el índice de perfusión?*

El *ANI* se basa en el análisis de la variabilidad de la frecuencia cardiaca (componente respiratoria de alta frecuencia), reflejando predominantemente el tono parasimpático, mientras que el SPI integra tanto la variabilidad de la frecuencia cardiaca como la amplitud del pulso periférico (tono simpático vascular). El *índice de perfusión*, por su parte, deriva únicamente de la amplitud de la señal PPG (sin componente de intervalo entre latidos) y se utiliza más como indicador de perfusión tisular que de nocicepción propiamente dicha. Según Van Santvliet y Vereecke (2024) [8], tanto el SPI como el ANI cuentan con niveles de validación clínica comparables, aunque ningún monitor de nocicepción actual constituye un "estándar de oro" definitivo, por lo que su interpretación debe hacerse de forma complementaria al juicio clínico.

---

## 12. Bibliografía

[1] J. L. Apfelbaum, C. Chen, S. S. Mehta y T. J. Gan, "Postoperative pain experience: results from a national survey suggest postoperative pain continues to be undermanaged," Anesthesia & Analgesia, vol. 97, no. 2, pp. 534–540, 2003. https://doi.org/10.1213/01.ANE.0000068822.10113.9E

[2] T. Ledowski, "Objective monitoring of nociception: a review of current commercial solutions," British Journal of Anaesthesia, vol. 123, no. 2, pp. e312–e321, 2019. https://doi.org/10.1016/j.bja.2019.03.024

[3] V. Bonhomme, K. Uutela, G. Hans, I. Maquoi, J. D. Born y J. F. Brichant, "Comparison of the Surgical Pleth Index™️ with haemodynamic variables to assess nociception-anti-nociception balance during general anaesthesia," British Journal of Anaesthesia, vol. 106, no. 1, pp. 101–111, 2011. https://doi.org/10.1093/bja/aeq291

[4] M. Huiku, K. Uutela, M. van Gils, I. Korhonen, M. Kymäläinen, P. Meriläinen, M. Paloheimo, M. Rantanen, P. Takala, H. Viertiö-Oja y A. Yli-Hankala, "Assessment of surgical stress during general anaesthesia," British Journal of Anaesthesia, vol. 98, no. 4, pp. 447–455, 2007. https://doi.org/10.1093/bja/aem004

[5] S. Funcke, S. Sauerlaender, H. O. Pinnschmidt, B. Saugel, K. Bremer, D. A. Reuter, R. Nitzschke y otros, "Validation of innovative techniques for monitoring nociception during general anesthesia: a clinical study using tetanic and intracutaneous electrical stimulation," Anesthesiology, vol. 127, no. 2, pp. 272–283, 2017. https://doi.org/10.1097/ALN.0000000000001670

[6] S. K. Oh, Y. J. Won y B. G. Lim, "Surgical pleth index monitoring in perioperative pain management: usefulness and limitations," Korean Journal of Anesthesiology, vol. 77, no. 1, pp. 31–45, 2024. https://doi.org/10.4097/kja.23158

[7] M. A. Dávila-Zenteno y R. Meza-Ruiz, "Utilidad del Surgical Pleth Index como factor predictor de dolor en el postoperatorio," Revista Mexicana de Anestesiología, 2024. https://scielo.org.mx/scielo.php?pid=S0484-79032024000200081&script=sci_arttext

[8] H. Van Santvliet y H. E. M. Vereecke, "Progress in the validation of nociception monitoring in guiding intraoperative analgesic therapy," Current Opinion in Anaesthesiology, vol. 37, no. 4, pp. 352–361, 2024. https://doi.org/10.1097/ACO.0000000000001390

[9] E. J. Argüello-Prada, "The mountaineer's method for peak detection in photoplethysmographic signals," Revista Facultad de Ingeniería, Universidad de Antioquia, no. 90, pp. 42–50, 2019. https://doi.org/10.17533/udea.redin.n90a06

