/*
  Lectura básica del MAX30102 para visualizar la señal PPG
  (variaciones del volumen sanguíneo periférico) en el Serial Plotter.
  Librería: SparkFun MAX3010x
  Conexión: SDA->A4, SCL->A5, VIN->5V, GND->GND
*/

#include <Wire.h>
#include "MAX30105.h"  // Nombre de archivo de la librería SparkFun, aunque el chip es el MAX30102

MAX30105 particleSensor;

void setup() {
  Serial.begin(115200);

  // Inicializa el sensor por I2C
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 no encontrado. Revisa el cableado.");
    while (1); // Se detiene si no lo detecta
  }

  // Configuración básica: LED en modo IR únicamente (suficiente para PPG)
  //byte ledBrightness = 200;   // 0-255, ajusta si la señal se satura o es muy débil
  //byte sampleAverage = 4;    // Promedio de muestras (reduce ruido)
  //byte ledMode = 2;          // 2 = Rojo + IR
  //int sampleRate = 100;      // Muestras por segundo
  //int pulseWidth = 411;      // Ancho de pulso del LED (más ancho = más resolución)
  //int adcRange = 4096;       // Rango del ADC

  byte ledBrightness = 40;   // baja bastante, empieza aquí
  byte sampleAverage = 4;
  byte ledMode = 2;
  int sampleRate = 100;
  int pulseWidth = 411;
  int adcRange = 16384;      // sube el rango del ADC para más margen dinámico

  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
}

void loop() {
  long irValue = particleSensor.getIR();  // Valor crudo del canal IR (aquí está la onda de pulso)

  // Imprime solo el valor IR para verlo en el Serial Plotter (Ctrl+Shift+L)
  Serial.println(irValue);

  delay(10); // ~100 Hz aprox, ajusta según sampleRate
}
