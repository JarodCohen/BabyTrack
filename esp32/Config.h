/**
 * ============================================================================
 * Config.h - BabyTrack Configuration Constants
 * ============================================================================
 * 
 * This file contains all configurable parameters for the BabyTrack system.
 * Modify these values to customize behavior without changing code logic.
 * 
 * SECTIONS:
 * - WiFi credentials
 * - Firebase project settings
 * - Session timing parameters
 * - Display settings
 * - Night mode / LED settings
 * - Time zone configuration
 * - Hardware calibration
 * ============================================================================
 */

#ifndef CONFIG_H
#define CONFIG_H

// ============================================================================
// WIFI CONFIGURATION
// ============================================================================
// Network credentials for ESP32 WiFi connection
#define WIFI_SSID "ibk_iphone"
#define WIFI_PASSWORD "soleil55"

// ============================================================================
// FIREBASE CONFIGURATION
// ============================================================================
// Firebase project credentials (from Firebase Console)
#define API_KEY "AIzaSyDFyQbtOKu3f9bd6mAL4axxoJ_yxnFgQq8"
#define FIREBASE_PROJECT_ID "babytrack-3e123"

// ============================================================================
// SESSION CONFIGURATION
// ============================================================================
// Time (ms) RFID must be continuously present to capture weight
// Prevents accidental triggers from brief RFID scans
#define SESSION_STABILIZE_MS 4000

// Minimum consumption (grams/ml) to save as a valid meal
// Smaller amounts are ignored to filter out measurement noise
#define MEAL_MIN_CONSUMPTION 5.0f

// ============================================================================
// SCREEN CONFIGURATION
// ============================================================================
// Time (ms) each info screen is displayed before rotating
#define SCREEN_INFO_ROTATION_MS 5000

// Screen refresh rate (ms)
#define SCREEN_REFRESH_MS 1000

// Number of different screens to rotate through
#define SCREEN_COUNT 5

// ============================================================================
// NIGHT MODE CONFIGURATION
// ============================================================================
// LDR threshold - above this value = dark environment
#define LDR_DARK_THRESHOLD 1500

// Night light color (RGB)
#define NIGHT_LED_R 150
#define NIGHT_LED_G 120
#define NIGHT_LED_B 0

// ============================================================================
// NTP TIME CONFIGURATION
// ============================================================================
#define NTP_SERVER "pool.ntp.org"
#define GMT_OFFSET_SEC 7200        // Israel GMT+2 (in seconds)
#define DAYLIGHT_OFFSET_SEC 3600   // Daylight saving time offset

// ============================================================================
// RFID CONFIGURATION
// ============================================================================
// How long (ms) to consider card still present after last read
#define CARD_STILL_PRESENT_MS 300

// ============================================================================
// FIREBASE SYNC CONFIGURATION
// ============================================================================
// How often (ms) to refresh baby data from Firebase
#define FIREBASE_SYNC_INTERVAL_MS 30000

// ============================================================================
// LOAD CELL CONFIGURATION
// ============================================================================
// Calibration factor for HX711
#define LOADCELL_CALIBRATION_FACTOR 686

// ============================================================================
// DEBUG CONFIGURATION
// ============================================================================
// Set to 1 to enable verbose serial output, 0 to disable
#define DEBUG_ENABLED 1

#endif
