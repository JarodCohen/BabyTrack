#include "PoopEvent.h"
#include "TimeUtils.h"
#include <Firebase_ESP_Client.h>
#include <time.h>

PoopEvent::PoopEvent() {
  id = "";
  timestamp = 0;
}

PoopEvent::PoopEvent(time_t ts) {
  id = "";
  timestamp = ts;
}

String PoopEvent::toFirestoreJson() {
  FirebaseJson json;
  
  // Timestamp field - use SECONDS, converted to ISO
  if (timestamp > 0) {
    String isoTime = timestampToISO(timestamp);
    json.set("fields/timestamp/timestampValue", isoTime);
    Serial.println("  PoopEvent ISO timestamp: " + isoTime);
  } else {
    Serial.println("  WARNING: PoopEvent timestamp is 0!");
  }
  
  return json.raw();
}

void PoopEvent::fromFirestoreJson(String jsonResponse) {
  FirebaseJson json;
  json.setJsonData(jsonResponse);
  
  FirebaseJsonData result;
  
  // Parse timestamp (for simplicity, storing as 0 - you can parse ISO if needed)
  if (json.get(result, "fields/timestamp/timestampValue")) {
    timestamp = 0; // You can implement ISO to Unix conversion if needed
  }
}

void PoopEvent::print() {
  Serial.println("=== Poop Event ===");
  Serial.println("ID: " + id);
  Serial.println("Timestamp: " + String(timestamp));
  Serial.println("==================");
}