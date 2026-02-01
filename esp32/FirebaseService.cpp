#include "FirebaseService.h"
#include <time.h>

FirebaseService::FirebaseService(FirebaseData* firebaseData, String firebaseProjectId) {
  fbdo = firebaseData;
  projectId = firebaseProjectId;
}

bool FirebaseService::getBabyById(String babyId, Baby& baby) {
  String documentPath = "Babies/" + babyId;
  
  if (Firebase.Firestore.getDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), "")) {
    baby.id = babyId;
    baby.fromFirestoreJson(fbdo->payload());
    return true;
  }
  return false;
}

bool FirebaseService::updateBabyById(String babyId, Baby& baby) {
  String documentPath = "Babies/" + babyId;
  String content = baby.toFirestoreJson();
  
  return Firebase.Firestore.patchDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), content.c_str(), "");
}

bool FirebaseService::createBaby(Baby& baby) {
  String documentPath = "Babies";
  String content = baby.toFirestoreJson();
  
  if (Firebase.Firestore.createDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), content.c_str())) {
    FirebaseJson json;
    json.setJsonData(fbdo->payload());
    FirebaseJsonData result;
    
    if (json.get(result, "name")) {
      String fullPath = result.stringValue;
      int lastSlash = fullPath.lastIndexOf('/');
      baby.id = fullPath.substring(lastSlash + 1);
    }
    return true;
  }
  return false;
}

bool FirebaseService::addBottle(String babyId, Bottle& bottle) {
  String documentPath = "Babies/" + babyId + "/Bottles";
  String content = bottle.toFirestoreJson();
  
  if (Firebase.Firestore.createDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), content.c_str())) {
    FirebaseJson json;
    json.setJsonData(fbdo->payload());
    FirebaseJsonData result;
    
    if (json.get(result, "name")) {
      String fullPath = result.stringValue;
      int lastSlash = fullPath.lastIndexOf('/');
      bottle.id = fullPath.substring(lastSlash + 1);
    }
    return true;
  }
  return false;
}

bool FirebaseService::getBottles(String babyId, std::vector<Bottle>& bottles) {
  String collectionPath = "Babies/" + babyId + "/Bottles";
  
  if (Firebase.Firestore.listDocuments(fbdo, projectId.c_str(), "", collectionPath.c_str(), 
                                        100, "", "", "", false)) {
    FirebaseJson json;
    json.setJsonData(fbdo->payload());
    
    FirebaseJsonData result;
    
    if (json.get(result, "documents")) {
      FirebaseJsonArray arr;
      arr.setJsonArrayData(result.stringValue);
      
      int bottleCount = arr.size();
      bottles.clear();
      
      for (int i = 0; i < bottleCount; i++) {
        FirebaseJsonData docData;
        arr.get(docData, i);
        
        FirebaseJson docJson;
        docJson.setJsonData(docData.stringValue);
        
        FirebaseJsonData nameData;
        if (docJson.get(nameData, "name")) {
          String fullPath = nameData.stringValue;
          int lastSlash = fullPath.lastIndexOf('/');
          String bottleId = fullPath.substring(lastSlash + 1);
          
          Bottle bottle;
          if (getBottle(babyId, bottleId, bottle)) {
            bottles.push_back(bottle);
          }
        }
      }
      return true;
    } else {
      bottles.clear();
      return true;  // Empty is OK
    }
  }
  return false;
}

bool FirebaseService::getBottle(String babyId, String bottleId, Bottle& bottle) {
  String documentPath = "Babies/" + babyId + "/Bottles/" + bottleId;
  
  if (Firebase.Firestore.getDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), "")) {
    bottle.id = bottleId;
    bottle.fromFirestoreJson(fbdo->payload());
    return true;
  }
  return false;
}

bool FirebaseService::addPoopEvent(String babyId, PoopEvent& event) {
  String documentPath = "Babies/" + babyId + "/PoopEvents";
  String content = event.toFirestoreJson();
  
  if (Firebase.Firestore.createDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), content.c_str())) {
    FirebaseJson json;
    json.setJsonData(fbdo->payload());
    FirebaseJsonData result;
    
    if (json.get(result, "name")) {
      String fullPath = result.stringValue;
      int lastSlash = fullPath.lastIndexOf('/');
      event.id = fullPath.substring(lastSlash + 1);
    }
    return true;
  }
  return false;
}

bool FirebaseService::addVitaminEvent(String babyId, VitaminEvent& event) {
  String documentPath = "Babies/" + babyId + "/VitaminEvents";
  String content = event.toFirestoreJson();
  
  if (Firebase.Firestore.createDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), content.c_str())) {
    FirebaseJson json;
    json.setJsonData(fbdo->payload());
    FirebaseJsonData result;
    
    if (json.get(result, "name")) {
      String fullPath = result.stringValue;
      int lastSlash = fullPath.lastIndexOf('/');
      event.id = fullPath.substring(lastSlash + 1);
    }
    return true;
  }
  return false;
}

bool FirebaseService::setWeight(String babyId, float weight) {
  String documentPath = "Babies/" + babyId;
  
  FirebaseJson json;
  json.set("fields/weight/doubleValue", weight);
  String content = json.raw();
  
  return Firebase.Firestore.patchDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), content.c_str(), "weight");
}

int FirebaseService::getPoopCountToday(String babyId, time_t todayStart) {
  // Convert todayStart to ISO format
  struct tm timeinfo;
  gmtime_r(&todayStart, &timeinfo);
  char isoBuffer[30];
  strftime(isoBuffer, sizeof(isoBuffer), "%Y-%m-%dT%H:%M:%S.000Z", &timeinfo);
  String todayStartISO = String(isoBuffer);
  
  // Build structured query
  FirebaseJson query;
  query.set("structuredQuery/from/[0]/collectionId", "PoopEvents");
  query.set("structuredQuery/where/fieldFilter/field/fieldPath", "timestamp");
  query.set("structuredQuery/where/fieldFilter/op", "GREATER_THAN_OR_EQUAL");
  query.set("structuredQuery/where/fieldFilter/value/timestampValue", todayStartISO);
  
  String parentPath = "Babies/" + babyId;
  
  if (Firebase.Firestore.runQuery(fbdo, projectId.c_str(), "", parentPath.c_str(), &query)) {
    FirebaseJsonArray arr;
    arr.setJsonArrayData(fbdo->payload());
    
    int count = 0;
    for (size_t i = 0; i < arr.size(); i++) {
      FirebaseJsonData item;
      arr.get(item, i);
      
      FirebaseJson itemJson;
      itemJson.setJsonData(item.stringValue);
      
      FirebaseJsonData docData;
      if (itemJson.get(docData, "document")) {
        count++;
      }
    }
    return count;
  }
  return 0;
}

bool FirebaseService::hadVitaminToday(String babyId, time_t todayStart) {
  // Convert todayStart to ISO format
  struct tm timeinfo;
  gmtime_r(&todayStart, &timeinfo);
  char isoBuffer[30];
  strftime(isoBuffer, sizeof(isoBuffer), "%Y-%m-%dT%H:%M:%S.000Z", &timeinfo);
  String todayStartISO = String(isoBuffer);
  
  // Build structured query - limit to 1
  FirebaseJson query;
  query.set("structuredQuery/from/[0]/collectionId", "VitaminEvents");
  query.set("structuredQuery/where/fieldFilter/field/fieldPath", "timestamp");
  query.set("structuredQuery/where/fieldFilter/op", "GREATER_THAN_OR_EQUAL");
  query.set("structuredQuery/where/fieldFilter/value/timestampValue", todayStartISO);
  query.set("structuredQuery/limit", 1);
  
  String parentPath = "Babies/" + babyId;
  
  if (Firebase.Firestore.runQuery(fbdo, projectId.c_str(), "", parentPath.c_str(), &query)) {
    FirebaseJsonArray arr;
    arr.setJsonArrayData(fbdo->payload());
    
    for (size_t i = 0; i < arr.size(); i++) {
      FirebaseJsonData item;
      arr.get(item, i);
      
      FirebaseJson itemJson;
      itemJson.setJsonData(item.stringValue);
      
      FirebaseJsonData docData;
      if (itemJson.get(docData, "document")) {
        return true;
      }
    }
  }
  return false;
}

// Fetch all mapped RFIDs from Firestore
bool FirebaseService::fetchRfidMappings(std::map<String, String>& mappings) {
  String collectionPath = "RfidMappings";
  
  if (Firebase.Firestore.listDocuments(fbdo, projectId.c_str(), "", collectionPath.c_str(), 100, "", "", "", false)) {
    FirebaseJson json;
    json.setJsonData(fbdo->payload());
    
    FirebaseJsonData result;
    if (json.get(result, "documents")) {
      FirebaseJsonArray arr;
      arr.setJsonArrayData(result.stringValue);
      
      for (size_t i = 0; i < arr.size(); i++) {
        FirebaseJsonData item;
        arr.get(item, i);
        
        FirebaseJson doc;
        doc.setJsonData(item.stringValue);
        
        FirebaseJsonData statusData;
        if (doc.get(statusData, "fields/status/stringValue")) {
          if (statusData.stringValue == "mapped") {
            FirebaseJsonData nameData;
            if (doc.get(nameData, "name")) {
              String name = nameData.stringValue;
              int lastSlash = name.lastIndexOf('/');
              String rfidUuid = name.substring(lastSlash + 1);
              
              FirebaseJsonData babyIdData;
              if (doc.get(babyIdData, "fields/babyId/stringValue")) {
                mappings[rfidUuid] = babyIdData.stringValue;
              }
            }
          }
        }
      }
    }
    Serial.println("✓ Loaded " + String(mappings.size()) + " RFID mappings");
    return true;
  }
  return false;
}

// Create a pending RFID mapping for unknown RFID
bool FirebaseService::createPendingRfidMapping(const String& rfidUuid) {
  String documentPath = "RfidMappings/" + rfidUuid;
  
  time_t now = time(nullptr);
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);
  char isoBuffer[30];
  strftime(isoBuffer, sizeof(isoBuffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  String isoTimestamp = String(isoBuffer);
  
  FirebaseJson content;
  content.set("fields/rfidUuid/stringValue", rfidUuid);
  content.set("fields/status/stringValue", "pending");
  content.set("fields/scannedAt/timestampValue", isoTimestamp);
  content.set("fields/lastSeenAt/timestampValue", isoTimestamp);
  
  return Firebase.Firestore.patchDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), content.raw(), "");
}

// Get a specific RFID mapping
bool FirebaseService::getRfidMapping(const String& rfidUuid, String& babyId) {
  String documentPath = "RfidMappings/" + rfidUuid;
  
  if (Firebase.Firestore.getDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), "")) {
    FirebaseJson json;
    json.setJsonData(fbdo->payload());
    
    FirebaseJsonData statusData;
    if (json.get(statusData, "fields/status/stringValue")) {
      if (statusData.stringValue == "mapped") {
        FirebaseJsonData babyIdData;
        if (json.get(babyIdData, "fields/babyId/stringValue")) {
          babyId = babyIdData.stringValue;
          return true;
        }
      }
    }
  }
  return false;
}

// ============================================================================
// RFID CONFIG METHODS
// ============================================================================

bool FirebaseService::fetchRfidConfig(const String& rfidUuid, FeedingSession& session) {
  String documentPath = "RfidMappings/" + rfidUuid;
  
  if (Firebase.Firestore.getDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), "")) {
    FirebaseJson json;
    json.setJsonData(fbdo->payload());
    
    FirebaseJsonData statusData;
    if (json.get(statusData, "fields/status/stringValue")) {
      if (statusData.stringValue != "mapped") {
        return false;
      }
    }
    
    session.rfidUuid = rfidUuid;
    
    FirebaseJsonData babyIdData;
    if (json.get(babyIdData, "fields/babyId/stringValue")) {
      session.babyId = babyIdData.stringValue;
    }
    
    FirebaseJsonData tempMinData;
    if (json.get(tempMinData, "fields/idealTempMin/doubleValue")) {
      session.idealTempMin = tempMinData.to<float>();
    } else if (json.get(tempMinData, "fields/idealTempMin/integerValue")) {
      session.idealTempMin = tempMinData.to<float>();
    } else {
      session.idealTempMin = 35.0;
    }
    
    FirebaseJsonData tempMaxData;
    if (json.get(tempMaxData, "fields/idealTempMax/doubleValue")) {
      session.idealTempMax = tempMaxData.to<float>();
    } else if (json.get(tempMaxData, "fields/idealTempMax/integerValue")) {
      session.idealTempMax = tempMaxData.to<float>();
    } else {
      session.idealTempMax = 40.0;
    }
    
    FirebaseJsonData ldrData;
    if (json.get(ldrData, "fields/ldrThreshold/integerValue")) {
      session.ldrThreshold = ldrData.to<int>();
    } else {
      session.ldrThreshold = 500;
    }
    
    return true;
  }
  return false;
}
