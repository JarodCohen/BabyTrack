#include "TempModule.h"
#include <Wire.h>
#include <Adafruit_MLX90614.h>

Adafruit_MLX90614 mlx = Adafruit_MLX90614();

static bool sensorOk = false;

bool initTempSensor() {
  // Try using the same I2C bus as the screen (already initialized)
  if (!mlx.begin(0x5A, &Wire)) {
    Serial.println("✗ MLX90614 not found on I2C bus");
    sensorOk = false;
    return false;
  }

  Serial.println("✓ MLX90614 ready");
  sensorOk = true;
  return true;
}

float readObjectTemp() {
  if (!sensorOk) return 0.0;
  return mlx.readObjectTempC();
}

float readAmbientTemp() {
  if (!sensorOk) return 0.0;
  return mlx.readAmbientTempC();
}
