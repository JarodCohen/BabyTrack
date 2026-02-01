/**
 * ============================================================================
 * FeedingSession.h - RFID-Based Feeding Session State Machine
 * ============================================================================
 * 
 * Manages the state of a feeding session for a single baby/bottle.
 * Each RFID tag (bottle) has its own independent FeedingSession.
 * 
 * STATE MACHINE FLOW:
 * 
 *   [IDLE] ─── RFID detected ───> [STABILIZING_START]
 *                                        │
 *              RFID removed before 4s ◄──┤
 *                                        │
 *              4 seconds elapsed ────────> [STARTED] (capture startWeight)
 *                                              │
 *                        RFID removed ─────────> [IN_PROGRESS] (feeding)
 *                                                     │
 *                               Same RFID detected ◄──┤
 *                                                     │
 *                                              [STABILIZING_END]
 *                                                     │
 *              RFID removed before 4s ◄───────────────┤
 *                                                     │
 *              4 seconds elapsed ─────────────────────> [IDLE]
 *                                                (save meal to Firebase)
 * 
 * SPECIAL CASE - Weight Increased:
 *   If endWeight > startWeight, the meal is RESTARTED with new startWeight.
 *   This handles the case where user forgot to close the previous meal.
 * 
 * ============================================================================
 */

#ifndef FEEDING_SESSION_H
#define FEEDING_SESSION_H

#include <Arduino.h>

/**
 * Session states for the RFID-based feeding tracker.
 * Multiple sessions can exist simultaneously (one per RFID/baby).
 */
enum SessionState {
  SESSION_IDLE,              ///< No active session, waiting for RFID
  SESSION_STABILIZING_START, ///< RFID detected, waiting 4s to capture startWeight
  SESSION_STARTED,           ///< startWeight captured, waiting for RFID removal
  SESSION_IN_PROGRESS,       ///< RFID removed, baby is feeding
  SESSION_STABILIZING_END    ///< RFID returned, waiting 4s to capture endWeight
};

/**
 * Represents a feeding session for a single baby/bottle combination.
 * Sessions are keyed by RFID UUID in the activeSessions map.
 */
struct FeedingSession {
  // ─── Identification ───
  String rfidUuid;           ///< Unique RFID tag identifier (hex string)
  String babyId;             ///< Firebase document ID for the baby
  String babyName;           ///< Display name for the baby
  
  // ─── State Machine ───
  SessionState state;        ///< Current session state
  
  // ─── Weight Tracking ───
  float startWeight;         ///< Weight (grams) when meal started
  
  // ─── Timing ───
  unsigned long rfidFirstSeen;  ///< millis() when RFID first detected in current scan
  unsigned long lastRfidSeen;   ///< millis() when RFID was last seen
  
  // ─── Per-Baby Configuration (from Firebase) ───
  float idealTempMin;        ///< Minimum ideal bottle temperature (°C)
  float idealTempMax;        ///< Maximum ideal bottle temperature (°C)
  int ldrThreshold;          ///< LDR threshold for night light activation
  
  /**
   * Default constructor with safe initial values.
   */
  FeedingSession() : 
    rfidUuid(""),
    babyId(""),
    babyName(""),
    state(SESSION_IDLE),
    startWeight(0),
    rfidFirstSeen(0),
    lastRfidSeen(0),
    idealTempMin(35.0),
    idealTempMax(40.0),
    ldrThreshold(500) {}
};

#endif
