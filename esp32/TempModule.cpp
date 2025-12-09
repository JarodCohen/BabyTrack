#include "TempModule.h"
#include <Wire.h>
#include <Adafruit_MLX90614.h>

#define SDA_PIN 14
#define SCL_PIN 27

Adafruit_MLX90614 mlx = Adafruit_MLX90614();

bool initTempSensor() {
  //Wire.begin(SDA_PIN, SCL_PIN);

  if (!mlx.begin()) {
    Serial.println("Erreur : MLX90614 introuvable !");
    return false;
  }

  Serial.println("MLX90614 prêt !");
  return true;
}

float readObjectTemp() {
  return mlx.readObjectTempC();
}

float readAmbientTemp() {
  return mlx.readAmbientTempC();
}
