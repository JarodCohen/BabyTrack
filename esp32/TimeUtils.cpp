#include "TimeUtils.h"
#include <WiFi.h>
#include <sys/time.h>

static bool timeSynced = false;

void initNTP() {
  // Try multiple NTP servers for better reliability
  configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, 
             "pool.ntp.org", "time.google.com", "time.cloudflare.com");
  
  Serial.print("NTP syncing");
  
  // Wait for sync (max 15 seconds)
  int attempts = 0;
  while (!isTimeSynced() && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();
  
  if (isTimeSynced()) {
    timeSynced = true;
    struct tm timeinfo;
    if (getLocalTime(&timeinfo)) {
      char buffer[30];
      strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M", &timeinfo);
      Serial.println("✓ Time: " + String(buffer));
    }
  } else {
    // NTP failed - set fallback time (required for SSL to work)
    Serial.println("✗ NTP failed - setting fallback time");
    struct timeval tv;
    tv.tv_sec = 1737417600;  // Jan 21, 2025 UTC
    tv.tv_usec = 0;
    settimeofday(&tv, NULL);
    timeSynced = true;
    Serial.println("✓ Fallback time set: Jan 2025");
  }
}

bool isTimeSynced() {
  time_t now;
  time(&now);
  return now > 1577836800; // After Jan 1, 2020
}

time_t getCurrentTimestamp() {
  time_t now;
  time(&now);
  return now;
}

time_t getTodayStartTimestamp() {
  time_t now = getCurrentTimestamp();
  struct tm timeinfo;
  localtime_r(&now, &timeinfo);
  
  timeinfo.tm_hour = 0;
  timeinfo.tm_min = 0;
  timeinfo.tm_sec = 0;
  
  return mktime(&timeinfo);
}

String timestampToISO(time_t timestampSec) {
  if (timestampSec == 0) return "";
  
  struct tm timeinfo;
  gmtime_r(&timestampSec, &timeinfo);
  
  char buffer[30];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S.000Z", &timeinfo);
  
  return String(buffer);
}
