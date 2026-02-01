/**
 * ============================================================================
 * ButtonsModule.h - Physical Button Input Handler
 * ============================================================================
 * 
 * Handles the two physical push buttons for event tracking.
 * 
 * BUTTON FUNCTIONS:
 * - Button 1: Record poop/diaper change event
 * - Button 2: Record vitamin supplement event
 * 
 * Events are saved to Firebase when a button is pressed while
 * an RFID session is active.
 * 
 * ============================================================================
 */

#ifndef BUTTONSMODULE_H
#define BUTTONSMODULE_H

#include <Arduino.h>

/**
 * Initialize button GPIO pins with internal pull-up resistors.
 */
void initButtons();

/**
 * Check if Button 1 (Poop) is currently pressed.
 * @return true if pressed, false otherwise
 */
bool isButton1Pressed();

/**
 * Check if Button 2 (Vitamin) is currently pressed.
 * @return true if pressed, false otherwise
 */
bool isButton2Pressed();

#endif
