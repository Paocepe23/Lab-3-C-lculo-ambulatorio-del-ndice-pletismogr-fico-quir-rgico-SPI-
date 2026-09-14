/*
  MAX30102_SPI_lectura.ino
  ------------------------
  Lectura NO bloqueante del MAX30102 (librería SparkFun MAX3010x) para
  el laboratorio de Cálculo ambulatorio del SPI.


  Conexiones (I2C):
    VIN/VCC -> 5V (o 3.3V si tu módulo lo exige)
    GND     -> GND
    SDA     -> A4 (Arduino UNO/Nano)
    SCL     -> A5 (Arduino UNO/Nano)
    INT     -> no se usa aquí (se hace polling, no interrupción)


  Antes de subir:
    Sketch > Incluir Librería > Administrar Bibliotecas... y busca
    "SparkFun MAX3010x Pulse and Proximity Sensor Library", instálala.


  Formato de salida por Serial (115200 baud), una línea por muestra:
    t_ms,IR
  Ese formato es el que va a leer el script de MATLAB.


  Por qué se "pegaba" antes (causas típicas y cómo se evitan aquí):
    1) Usar while (!particleSensor.available()) { } sin más: si el sensor
       deja de mandar datos (dedo mal puesto, cable flojo, I2C con
       problemas) el Arduino se queda esperando para siempre.
       -> Aquí NO se bloquea: en cada vuelta de loop() se llama a
          particleSensor.check() una sola vez y solo se procesa si
          efectivamente hay muestra nueva.
    2) No inicializar el bus I2C a la velocidad correcta.
       -> Aquí se fija Wire a 400 kHz explícitamente.
    3) No comprobar si el sensor respondió en begin().
       -> Aquí, si no se detecta el MAX30102, el programa avisa por
          Serial en vez de quedarse esperando/colgado.
*/


#include <Wire.h>
#include "MAX30105.h" // Librería SparkFun MAX3010x (compatible con MAX30102)


MAX30105 particleSensor;


// Umbral aproximado de IR para saber si hay un dedo puesto.
// Ajusta este valor viendo qué IR marca "sin dedo" vs "con dedo" en tu módulo.
const long UMBRAL_DEDO = 50000;


unsigned long ultimoAviso = 0;


void setup() {
  Serial.begin(115200);
  while (!Serial) { ; } // en placas con USB nativo; en UNO/Nano no bloquea


  Wire.begin();
  Wire.setClock(400000); // I2C a 400 kHz


  // Intento de inicialización con manejo de error (no queda colgado)
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("ERROR: MAX30102 no detectado. Revisa VCC, GND, SDA(A4), SCL(A5).");
    // No usamos while(1); a propósito: seguimos reintentando en loop()
  } else {
    Serial.println("MAX30102 detectado. Iniciando lectura...");
    configurarSensor();
  }
}


void configurarSensor() {
  byte ledBrightness = 0x1F; // 0-255, sube esto si la señal sale muy plana
  byte sampleAverage = 4;    // 1,2,4,8,16,32 -> más promedio = menos ruido, más retardo
  byte ledMode       = 2;    // 1=Red, 2=Red+IR, 3=Red+IR+Green
  int  sampleRate    = 100;  // Hz: 50,100,200,400,800,1000,1600,3200
  int  pulseWidth    = 411;  // us: 69,118,215,411 (mayor = más resolución, menor tasa máxima)
  int  adcRange      = 4096; // 2048,4096,8192,16384


  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
}


void loop() {
  // Si el sensor no fue detectado en setup(), reintenta cada 2 s sin bloquear
  static bool sensorOK = false;
  static unsigned long ultimoIntento = 0;


  if (!sensorOK) {
    if (millis() - ultimoIntento > 2000) {
      ultimoIntento = millis();
      if (particleSensor.begin(Wire, I2C_SPEED_FAST)) {
        sensorOK = true;
        configurarSensor();
        Serial.println("MAX30102 detectado. Iniciando lectura...");
      } else {
        Serial.println("ERROR: MAX30102 no detectado. Reintentando...");
      }
    }
    return; // no seguimos hasta tener el sensor
  }


  // --- Lectura no bloqueante ---
  particleSensor.check(); // revisa el FIFO del sensor UNA vez por vuelta, sin esperar


  while (particleSensor.available()) {
    long irValue = particleSensor.getFIFOIR();
    unsigned long t = millis();


    if (irValue > UMBRAL_DEDO) {
      Serial.print(t);
      Serial.print(",");
      Serial.println(irValue);
    } else {
      // Sin dedo detectado: avisa como máximo cada 1 s para no saturar el puerto serial
      if (millis() - ultimoAviso > 1000) {
        Serial.println("Sin dedo detectado");
        ultimoAviso = millis();
      }
    }


    particleSensor.nextSample(); // avanza al siguiente dato del FIFO
  }
}
