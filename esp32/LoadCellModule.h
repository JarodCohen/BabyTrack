/**
 * ============================================================================
 * LoadCellModule.h - HX711 Load Cell Weight Sensor
 * ============================================================================
 * 
 * Controls the HX711 ADC for reading weight from the load cell.
 * Used to measure bottle weight before and after feeding.
 * 
 * HARDWARE CONNECTIONS:
 * - DOUT: GPIO 4
 * - SCK:  GPIO 2
 * 
 * CALIBRATION:
 * - Set LOADCELL_CALIBRATION_FACTOR in Config.h
 * - Default: 686 (may need adjustment for your load cell)
 * 
 * AUTO-TARE:
 * - Scale automatically tares when weight is near zero (<5g)
 * - Prevents drift from affecting measurements
 * 
 * ============================================================================
 */

#ifndef LOADCELLMODULE_H
#define LOADCELLMODULE_H

#include <Arduino.h>

/**
 * Initialize the HX711 load cell.
 * Applies calibration factor and performs initial tare.
 */
void initLoadCell();

/**
 * Read current weight from the scale.
 * @return Weight in grams (can be negative if scale drifted)
 */
float readWeight();

/**
 * Tare (zero) the scale.
 * Call when scale is empty to reset the baseline.
 */
void tareScale();

#endif
