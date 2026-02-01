/**
 * ============================================================================
 * ScreenModule.h - OLED Display Controller (SH1106 128x64)
 * ============================================================================
 * 
 * Controls the SH1106 OLED display via I2C (pins 25/33).
 * 
 * DISPLAY LAYOUT (Main Screen):
 * ┌────────────────────────┐
 * │ Name           37.5°C  │  <- Baby name + temperature
 * │                        │
 * │       150g             │  <- Weight (large, centered)
 * │                        │
 * │      FEEDING           │  <- Status: FEEDING or IDLE
 * └────────────────────────┘
 * 
 * NOTIFICATION SYSTEM:
 * - Notifications overlay the main screen for 2 seconds
 * - After timeout, main screen automatically restores
 * 
 * ============================================================================
 */

#ifndef SCREENMODULE_H
#define SCREENMODULE_H

#include <Arduino.h>
#include "Config.h"

/**
 * Initialize the OLED display.
 * Must be called before any display functions.
 */
void initScreen();

/**
 * Show the main status screen.
 * @param babyName     Baby's name (truncated to 5 chars)
 * @param temperature  Current bottle temperature (°C)
 * @param weight       Current scale weight (grams, rounded to nearest 10)
 * @param isMeal       True if feeding is in progress
 */
void showMainScreen(
    const String& babyName,
    float temperature,
    float weight,
    bool isMeal
);

/**
 * Show a notification overlay (auto-dismisses after 2 seconds).
 * @param title  Notification title (small text, top)
 * @param value  Notification value (large text, center)
 */
void showNotification(const String& title, const String& value);

/** Show "Scan card" waiting screen when no RFID is detected. */
void showWaitingScreen();

/** Show WiFi reconnecting screen (blocks normal updates). */
void showWifiReconnecting();

/** Check if a notification is currently being displayed. */
bool isNotificationActive();

/** Manually clear the notification (restore main screen). */
void clearNotification();

#endif
