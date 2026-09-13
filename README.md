# Laboratorio: Monitorización de la Nocicepción y Detección de Picos Fotopletismográficos (PPG)

**Integrantes:**
* Juan Sebastián López Duarte
* Paola Andrea Cepeda Castro
* José Daniel Porras Rodríguez

---

## 1. Introducción y Marco Teórico

El Índice Pletismográfico Quirúrgico (SPI) es una herramienta no invasiva que evalúa la respuesta autonómica al estímulo nociceptivo combinando el intervalo latido a latido ($\text{HBI}$) y la amplitud de la onda fotopletismográfica ($\text{PPGA}$).

### Determinantes del SPI
La formulación matemática del SPI está representada por:

$$\text{SPI} = 100 - (0.33 \times \text{HBI} + 0.67 \times \text{PPGA})$$

Ante un estímulo quirúrgico, el aumento del tono simpático incrementa la frecuencia cardíaca (disminuyendo el $\text{HBI}$) y genera vasoconstricción periférica (disminuyendo la $\text{PPGA}$), lo que resulta en un incremento del valor de SPI.

---

## 2. Detección de Picos: El Método del Alpinista (MMPD)

Para la extracción de características de la señal PPG, se implementó el **Método del Alpinista** (Argüello-Prada, 2019), cuyo pseudocódigo se encuentra en las **líneas 1 a 47 del Algoritmo 1** del artículo de referencia.

### Ecuaciones del Algoritmo
1. **Condición de Ascenso (Pendiente Positiva):**
   $$f(t_{i+1}) > f(t_i) \quad \text{si } t_{i+1} > t_i$$

2. **Umbral Adaptativo:**
   $$\text{threshold} = 0.6 \times \text{num\_upsteps}$$

### Evaluación del Desempeño Diagnóstico
El rendimiento del algoritmo se determinó mediante:

$$\text{Sensibilidad (SE)} = \frac{\text{TP}}{\text{TP} + \text{FN}}$$

$$\text{Valor Predictivo Positivo (+P)} = \frac{\text{TP}}{\text{TP} + \text{FP}}$$

$$\text{Tasa de Detección Fallida (FDR)} = \frac{\text{FN} + \text{FP}}{\text{TP}}$$

---

## 3. Resultados y Discusión

* **Valor de Corte del SPI:** Un umbral intraoperatorio de $\text{SPI} = 36$ demostró ser el discriminador óptimo para predecir dolor postoperatorio moderado a severo ($\text{ENA} \ge 4$), obteniendo un Valor Predictivo Positivo (VPP) del $88.7\%$ y un Valor Predictivo Negativo (VPN) del $80\%$.
* **Robustez del MMPD:** El algoritmo mantuvo una sensibilidad $\text{SE} > 98\%$ y un $\text{FDR} < 3\%$ ante caídas drásticas de la amplitud de la señal hasta $0.2\text{ V}$.

---

## 4. Conclusiones

La monitorización objetiva de la nocicepción y el dolor perioperatorio mediante señales fotopletismográficas (PPG) representa un desafío debido a la variabilidad fisiológica y la interferencia de artefactos en el entorno clínico. El procesamiento de la onda del pulso mediante el cálculo del índice pletismográfico quirúrgico (SPI) permite predecir el dolor postoperatorio de moderado a severo con un valor de corte óptimo de 36. Asimismo, la implementación del Método del Alpinista (MMPD) garantiza una detección de picos sistólicos robusta con una sensibilidad superior al 98%, incluso en señales de baja amplitud (hasta 0.2 V).

La adopción de esta metodología reduce de forma significativa la sobredosificación y subdosificación de opioides intraoperatorios, optimiza los tiempos de extubación y minimiza la tasa de eventos adversos en las salas de recuperación postanestésica. Estudios posteriores deben enfocarse en optimizar la robustez del algoritmo MMPD ante artefactos por movimiento severos mediante filtros adaptativos de bajo costo computacional, así como validar el punto de corte del SPI en pacientes bajo anestesia total intravenosa (TIVA).

---

## 5. Referencias Bibliográficas

1. Argüello-Prada, E. J. (2019). The mountaineer's method for peak detection in photoplethysmographic signals. *Revista Facultad de Ingeniería Universidad de Antioquia*, (90), 42-50.
2. Dávila-Zenteno, M. A., & Meza-Ruiz, R. (2024). Utilidad del Surgical Pleth Index como factor predictor de dolor en el postoperatorio. *Revista Mexicana de Anestesiología*, 47(2), 81-87.
3. Oh, S. K., Ju Won, Y., & Lim, B. G. (2024). Surgical pleth index monitoring in perioperative pain management: usefulness and limitations. *Korean Journal of Anesthesiology*, 77(1), 31-45.
4. Van Santvliet, H., & Vereecke, H. E. M. (2024). Progress in the validation of nociception monitoring in guiding intraoperative analgesic therapy. *Current Opinion in Anaesthesiology*, 37(4), 352-361.
