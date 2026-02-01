/**
 * ============================================================================
 * LedModule.h - RGB LED and LDR Light Sensor
 * ============================================================================
 * 
 * Controls the RGB LED for temperature feedback and reads the LDR
 * (Light Dependent Resistor) for ambient light detection.
 * 
 * LED FUNCTIONS:
 * - Temperature feedback (blue=cold, green=good, red=hot)
 * - Night light mode (warm white when dark and no active session)
 * 
 * LDR FUNCTIONS:
 * - Detect ambient light level (0-4095 ADC value)
 * - Higher values = darker environment
 * - Used to enable/disable LED based on LDR_DARK_THRESHOLD
 * 
 * ============================================================================
 */

#ifndef LEDMODULE_H
#define LEDMODULE_H

#include <Arduino.h>

/**
 * Initialize the RGB LED and LDR sensor.
 */
void initLed();

/**
 * Set the RGB LED to a specific color.
 * @param r Red component (0-255)
 * @param g Green component (0-255)
 * @param b Blue component (0-255)
 */
void setLedColor(uint8_t r, uint8_t g, uint8_t b);

/**
 * Turn off the RGB LED.
 */
void setLedOff();

/**
 * Read the raw LDR (light sensor) value.
 * @return ADC value 0-4095 (higher = darker)
 */
int readLdrRaw();

#endif
