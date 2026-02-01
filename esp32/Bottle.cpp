#include "Bottle.h"
#include "TimeUtils.h"
#include <Firebase_ESP_Client.h>
#include <time.h>

Bottle::Bottle() {
  id = "";
  createdAt = 0;
  startedAt = 0;
  quantity = 0;
  source = "";
}

Bottle::Bottle(String documentId) {
  id = documentId;
  createdAt = 0;
  startedAt = 0;
  quantity = 0;
  source = "";
}

String Bottle::toFirestoreJson() {
  FirebaseJson json;
  
  json.set("fields/quantity/integerValue", String(quantity));
  json.set("fields/source/stringValue", source);
  
  // Use SECONDS timestamps, converted to ISO
  if (createdAt > 0) {
    String createdISO = timestampToISO(createdAt);
    json.set("fields/createdAt/timestampValue", createdISO);
    Serial.println("  Bottle createdAt ISO: " + createdISO);
  }
  if (startedAt > 0) {
    String startedISO = timestampToISO(startedAt);
    json.set("fields/startedAt/timestampValue", startedISO);
  }
  
  return json.raw();
}

void Bottle::fromFirestoreJson(String jsonResponse) {
  FirebaseJson json;
  json.setJsonData(jsonResponse);
  
  FirebaseJsonData result;
  
  if (json.get(result, "fields/quantity/integerValue")) {
    quantity = result.intValue;
  }
  
  if (json.get(result, "fields/source/stringValue")) {
    source = result.stringValue;
  }
  
  if (json.get(result, "fields/createdAt/timestampValue")) {
    createdAt = 0; // Simplified - parse ISO if needed
  }
  
  if (json.get(result, "fields/startedAt/timestampValue")) {
    startedAt = 0; // Simplified - parse ISO if needed
  }
}

void Bottle::print() {
  Serial.println("=== Bottle Info ===");
  Serial.println("ID: " + id);
  Serial.println("Quantity: " + String(quantity) + " ml");
  Serial.println("Source: " + source);
  Serial.println("Started At: " + String(startedAt));
  Serial.println("Created At: " + String(createdAt));
  Serial.println("==================");
}