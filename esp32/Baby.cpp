#include "Baby.h"
#include "TimeUtils.h"
#include <Firebase_ESP_Client.h>
#include <time.h>

Baby::Baby() {
  id = "";
  firstName = "";
  lastName = "";
  ownerId = "";
  birthDate = 0;
  createdAt = 0;
}

Baby::Baby(String documentId) {
  id = documentId;
  firstName = "";
  lastName = "";
  ownerId = "";
  birthDate = 0;
  createdAt = 0;
}

String Baby::toFirestoreJson() {
  FirebaseJson json;
  
  // String fields
  json.set("fields/firstName/stringValue", firstName);
  json.set("fields/lastName/stringValue", lastName);
  json.set("fields/ownerId/stringValue", ownerId);
  
  // Timestamp fields - use SECONDS, converted to ISO
  if (birthDate > 0) {
    String birthISO = timestampToISO(birthDate);
    json.set("fields/birthDate/timestampValue", birthISO);
  }
  if (createdAt > 0) {
    String createdISO = timestampToISO(createdAt);
    json.set("fields/createdAt/timestampValue", createdISO);
  }
  
  // Array field - memberIds (proper Firestore array format)
  if (memberIds.size() > 0) {
    String arrayJson = "{\"values\":[";
    for (int i = 0; i < memberIds.size(); i++) {
      arrayJson += "{\"stringValue\":\"" + memberIds[i] + "\"}";
      if (i < memberIds.size() - 1) {
        arrayJson += ",";
      }
    }
    arrayJson += "]}";
    
    FirebaseJson memberArray;
    memberArray.setJsonData(arrayJson);
    json.set("fields/memberIds/arrayValue", memberArray);
  }
  
  return json.raw();
}

void Baby::fromFirestoreJson(String jsonResponse) {
  FirebaseJson json;
  json.setJsonData(jsonResponse);
  
  FirebaseJsonData result;
  
  // Parse firstName
  if (json.get(result, "fields/firstName/stringValue")) {
    firstName = result.stringValue;
  }
  
  // Parse lastName
  if (json.get(result, "fields/lastName/stringValue")) {
    lastName = result.stringValue;
  }
  
  // Parse ownerId
  if (json.get(result, "fields/ownerId/stringValue")) {
    ownerId = result.stringValue;
  }
  
  // Parse birthDate timestamp (ISO string to Unix timestamp)
  if (json.get(result, "fields/birthDate/timestampValue")) {
    // For simplicity, store as 0 - you can parse ISO string if needed
    birthDate = 0;
  }
  
  // Parse createdAt timestamp
  if (json.get(result, "fields/createdAt/timestampValue")) {
    createdAt = 0;
  }
  
  // Parse memberIds array
  memberIds.clear();
  
  FirebaseJson fieldsJson;
  if (json.get(result, "fields")) {
    fieldsJson.setJsonData(result.stringValue);
    
    FirebaseJsonData arrayData;
    if (fieldsJson.get(arrayData, "memberIds/arrayValue/values")) {
      FirebaseJsonArray arr;
      arr.setJsonArrayData(arrayData.stringValue);
      
      for (size_t i = 0; i < arr.size(); i++) {
        FirebaseJsonData item;
        arr.get(item, i);
        
        FirebaseJson itemJson;
        itemJson.setJsonData(item.stringValue);
        
        FirebaseJsonData stringVal;
        if (itemJson.get(stringVal, "stringValue")) {
          memberIds.push_back(stringVal.stringValue);
        }
      }
    }
  }
}

void Baby::print() {
  Serial.println("=== Baby Info ===");
  Serial.println("ID: " + id);
  Serial.println("First Name: " + firstName);
  Serial.println("Last Name: " + lastName);
  Serial.println("Owner ID: " + ownerId);
  Serial.println("Birth Date: " + String(birthDate));
  Serial.println("Created At: " + String(createdAt));
  Serial.print("Member IDs: ");
  for (int i = 0; i < memberIds.size(); i++) {
    Serial.print(memberIds[i]);
    if (i < memberIds.size() - 1) Serial.print(", ");
  }
  Serial.println();
  Serial.println("================");
}