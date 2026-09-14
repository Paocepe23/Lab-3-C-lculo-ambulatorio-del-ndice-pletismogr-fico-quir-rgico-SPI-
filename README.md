# Laboratorio 3: Cálculo ambulatorio del índice pletismográfico quirúrgico (SPI)

**Integrantes:**
- Porras Rodríguez, José Daniel
- López Duarte, Juan Sebastián
- Cepeda Castro, Paola Andrea

---



---

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



