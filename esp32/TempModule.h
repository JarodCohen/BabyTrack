/**
 * ============================================================================
 * TempModule.h - MLX90614 IR Temperature Sensor
 * ============================================================================
 * 
 * Controls the MLX90614 infrared temperature sensor via I2C.
 * Measures bottle temperature without contact.
 * 
 * HARDWARE CONNECTIONS (I2C - same bus as screen):
 * - SDA: GPIO 25
 * - SCL: GPIO 33
 * - I2C Address: 0x5A (default)
 * 
 * TEMPERATURE FEEDBACK:
 * - Blue LED:  Temperature too cold (< idealTempMin - 1°C)
 * - Green LED: Temperature in ideal range
 * - Red LED:   Temperature too hot (> idealTempMax + 1°C)
 * 
 * ============================================================================
 */

#ifndef TEMPMODULE_H
#define TEMPMODULE_H

#include <Arduino.h>

/**
 * Initialize the MLX90614 temperature sensor.
 * @return true if sensor found, false if initialization failed
 */
bool initTempSensor();

/**
 * Read the object (bottle) temperature.
 * @return Temperature in Celsius, or 0 if sensor not available
 */
float readObjectTemp();

/**
 * Read the ambient room temperature.
 * @return Temperature in Celsius, or 0 if sensor not available
 */
float readAmbientTemp();

#endif
