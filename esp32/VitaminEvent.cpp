#include "VitaminEvent.h"
#include "TimeUtils.h"
#include <Firebase_ESP_Client.h>
#include <time.h>

VitaminEvent::VitaminEvent() {
  id = "";
  timestamp = 0;
}

VitaminEvent::VitaminEvent(time_t ts) {
  id = "";
  timestamp = ts;
}

String VitaminEvent::toFirestoreJson() {
  FirebaseJson json;
  
  // Timestamp field - use SECONDS, converted to ISO
  if (timestamp > 0) {
    String isoTime = timestampToISO(timestamp);
    json.set("fields/timestamp/timestampValue", isoTime);
    Serial.println("  VitaminEvent ISO timestamp: " + isoTime);
  } else {
    Serial.println("  WARNING: VitaminEvent timestamp is 0!");
  }
  
  return json.raw();
}

void VitaminEvent::fromFirestoreJson(String jsonResponse) {
  FirebaseJson json;
  json.setJsonData(jsonResponse);
  
  FirebaseJsonData result;
  
  // Parse timestamp
  if (json.get(result, "fields/timestamp/timestampValue")) {
    timestamp = 0; // You can implement ISO to Unix conversion if needed
  }
}

void VitaminEvent::print() {
  Serial.println("=== Vitamin Event ===");
  Serial.println("ID: " + id);
  Serial.println("Timestamp: " + String(timestamp));
  Serial.println("=====================");
}