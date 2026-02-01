/**
 * ============================================================================
 * RfidModule.h - MFRC522 RFID Reader Controller
 * ============================================================================
 * 
 * Controls the MFRC522 RFID reader via SPI.
 * Used to identify baby bottles by their attached RFID tags.
 * 
 * HARDWARE CONNECTIONS (SPI):
 * - SS/SDA: GPIO 5
 * - SCK:    GPIO 18
 * - MOSI:   GPIO 23
 * - MISO:   GPIO 19
 * - RST:    GPIO 22
 * 
 * USAGE:
 *   String uid;
 *   if (readRfidUid(uid) && uid != "") {
 *     // Card detected, uid contains hex string like "A1B2C3D4"
 *   }
 * 
 * ============================================================================
 */

#ifndef RFIDMODULE_H
#define RFIDMODULE_H

#include <Arduino.h>

/**
 * Initialize the MFRC522 RFID reader.
 * Must be called before any RFID operations.
 */
void initRfid();

/**
 * Check for RFID card and read its UID.
 * @param uidHex Output: Card UID as hex string (e.g., "A1B2C3D4")
 *               Empty string if no card detected
 * @return true if a card is currently present, false otherwise
 */
bool readRfidUid(String &uidHex);

#endif
