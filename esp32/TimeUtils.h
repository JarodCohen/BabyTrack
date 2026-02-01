/**
 * ============================================================================
 * TimeUtils.h - NTP Time Synchronization and Utilities
 * ============================================================================
 * 
 * Handles time synchronization via NTP and provides time-related utilities.
 * 
 * NTP SERVERS (in order of preference):
 * - pool.ntp.org
 * - time.google.com
 * - time.cloudflare.com
 * 
 * TIMEZONE:
 * - Configured in Config.h (GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC)
 * - Default: Israel (GMT+2 with DST)
 * 
 * FALLBACK:
 * - If NTP fails, a fallback time (Jan 2025) is set to allow
 *   SSL certificate validation for Firebase.
 * 
 * ============================================================================
 */

#ifndef TIME_UTILS_H
#define TIME_UTILS_H

#include <Arduino.h>
#include <time.h>
#include "Config.h"

/**
 * Initialize NTP time synchronization.
 * Waits up to 15 seconds for sync, then sets fallback time if failed.
 */
void initNTP();

/**
 * Check if time has been synchronized.
 * @return true if current time is after Jan 1, 2020
 */
bool isTimeSynced();

/**
 * Get current Unix timestamp in seconds.
 * @return Seconds since Jan 1, 1970 (UTC)
 */
time_t getCurrentTimestamp();

/**
 * Get Unix timestamp for the start of today (midnight local time).
 * @return Timestamp for 00:00:00 today
 */
time_t getTodayStartTimestamp();

/**
 * Convert Unix timestamp to ISO 8601 format string.
 * @param timestampSec Unix timestamp in seconds
 * @return ISO string like "2025-01-20T15:30:00.000Z"
 */
String timestampToISO(time_t timestampSec);

#endif
