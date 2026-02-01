# ESP32 Multi-Feature Update Guide

This guide contains all the code changes needed for the ESP32 to support:
1. Multi-baby queue system
2. Temperature monitoring with LED feedback
3. Bottle tare weight calibration
4. Display ml consumed (not raw weight)
5. Configurable LDR threshold
6. Persistent last action display

---

## 1. Create `BabySession.h`

Create a new file `BabySession.h` in your ESP32 project:

```cpp
#ifndef BABY_SESSION_H
#define BABY_SESSION_H

#include <Arduino.h>

struct BabySession {
  String rfidUuid;
  String babyId;
  String babyName;
  float bottleTareWeight;
  float idealTempMin;
  float idealTempMax;
  int ldrThreshold;
  bool needsCalibration;
  unsigned long lastSeen;
  
  BabySession() : 
    rfidUuid(""),
    babyId(""),
    babyName(""),
    bottleTareWeight(0),
    idealTempMin(35.0),
    idealTempMax(40.0),
    ldrThreshold(500),
    needsCalibration(false),
    lastSeen(0) {}
};

#endif
```

---

## 2. Update `FirebaseService.h`

Add these method declarations:

```cpp
// RFID Config methods
bool fetchRfidConfig(const String& rfidUuid, BabySession& session);
bool updateRfidTareWeight(const String& rfidUuid, float tareWeight);
bool clearCalibrationFlag(const String& rfidUuid);
```

---

## 3. Update `FirebaseService.cpp`

Add these methods:

```cpp
bool FirebaseService::fetchRfidConfig(const String& rfidUuid, BabySession& session) {
  String documentPath = "RfidMappings/" + rfidUuid;
  
  Serial.println("Fetching RFID config: " + documentPath);
  
  if (Firebase.Firestore.getDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), "")) {
    FirebaseJson json;
    json.setJsonData(fbdo->payload());
    
    // Check status
    FirebaseJsonData statusData;
    if (json.get(statusData, "fields/status/stringValue")) {
      if (statusData.stringValue != "mapped") {
        Serial.println("RFID not mapped");
        return false;
      }
    }
    
    session.rfidUuid = rfidUuid;
    
    // Get babyId
    FirebaseJsonData babyIdData;
    if (json.get(babyIdData, "fields/babyId/stringValue")) {
      session.babyId = babyIdData.stringValue;
    }
    
    // Get bottleTareWeight
    FirebaseJsonData tareData;
    if (json.get(tareData, "fields/bottleTareWeight/doubleValue")) {
      session.bottleTareWeight = tareData.to<float>();
    } else if (json.get(tareData, "fields/bottleTareWeight/integerValue")) {
      session.bottleTareWeight = tareData.to<float>();
    }
    
    // Get idealTempMin
    FirebaseJsonData tempMinData;
    if (json.get(tempMinData, "fields/idealTempMin/doubleValue")) {
      session.idealTempMin = tempMinData.to<float>();
    } else if (json.get(tempMinData, "fields/idealTempMin/integerValue")) {
      session.idealTempMin = tempMinData.to<float>();
    } else {
      session.idealTempMin = 35.0; // Default
    }
    
    // Get idealTempMax
    FirebaseJsonData tempMaxData;
    if (json.get(tempMaxData, "fields/idealTempMax/doubleValue")) {
      session.idealTempMax = tempMaxData.to<float>();
    } else if (json.get(tempMaxData, "fields/idealTempMax/integerValue")) {
      session.idealTempMax = tempMaxData.to<float>();
    } else {
      session.idealTempMax = 40.0; // Default
    }
    
    // Get ldrThreshold
    FirebaseJsonData ldrData;
    if (json.get(ldrData, "fields/ldrThreshold/integerValue")) {
      session.ldrThreshold = ldrData.to<int>();
    } else {
      session.ldrThreshold = 500; // Default
    }
    
    // Get needsCalibration
    FirebaseJsonData calibData;
    if (json.get(calibData, "fields/needsCalibration/booleanValue")) {
      session.needsCalibration = calibData.to<bool>();
    }
    
    Serial.println("✓ RFID config loaded");
    Serial.println("  babyId: " + session.babyId);
    Serial.println("  tareWeight: " + String(session.bottleTareWeight));
    Serial.println("  tempRange: " + String(session.idealTempMin) + "-" + String(session.idealTempMax));
    Serial.println("  ldrThreshold: " + String(session.ldrThreshold));
    Serial.println("  needsCalibration: " + String(session.needsCalibration));
    
    return true;
  }
  
  Serial.println("✗ Failed to fetch RFID config: " + fbdo->errorReason());
  return false;
}

bool FirebaseService::updateRfidTareWeight(const String& rfidUuid, float tareWeight) {
  String documentPath = "RfidMappings/" + rfidUuid;
  
  // Get current ISO timestamp
  time_t now = time(nullptr);
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);
  char isoBuffer[30];
  strftime(isoBuffer, sizeof(isoBuffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  String isoTimestamp = String(isoBuffer);
  
  FirebaseJson content;
  content.set("fields/bottleTareWeight/doubleValue", tareWeight);
  content.set("fields/needsCalibration/booleanValue", false);
  content.set("fields/lastCalibratedAt/timestampValue", isoTimestamp);
  
  Serial.println("Updating tare weight: " + String(tareWeight) + "g");
  
  if (Firebase.Firestore.patchDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), 
      content.raw(), "bottleTareWeight,needsCalibration,lastCalibratedAt")) {
    Serial.println("✓ Tare weight updated");
    return true;
  }
  
  Serial.println("✗ Failed to update tare weight: " + fbdo->errorReason());
  return false;
}

bool FirebaseService::clearCalibrationFlag(const String& rfidUuid) {
  String documentPath = "RfidMappings/" + rfidUuid;
  
  FirebaseJson content;
  content.set("fields/needsCalibration/booleanValue", false);
  
  return Firebase.Firestore.patchDocument(fbdo, projectId.c_str(), "", documentPath.c_str(), 
      content.raw(), "needsCalibration");
}
```

---

## 4. Update `main.ino`

### Replace global variables section:

```cpp
#include "BabySession.h"
#include <vector>

// ============================================================================
// GLOBAL VARIABLES
// ============================================================================

// Firebase (unchanged)
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
FirebaseService* firebaseService;

// Multi-baby queue system
std::vector<BabySession> babyQueue;
int activeBabyIndex = -1;  // Which baby's bottle is currently on the scale

// Meal tracking
MealTracker mealTracker;
float lastMilkConsumed = 0.0f;

// Last action display
String lastActionText = "Ready";
unsigned long lastActionTime = 0;

// Today's events (for active baby)
int poopCountToday = 0;
bool hadVitaminToday = false;
unsigned long lastEventsSyncTime = 0;

// Timing
unsigned long lastScreenUpdate = 0;
unsigned long lastRfidMappingSync = 0;
const unsigned long RFID_MAPPING_SYNC_INTERVAL = 60000; // Refresh mappings every 60s

// RFID UID to Baby mapping - loaded from Firestore
std::map<String, String> uidToBabyId;
```

### Add helper functions:

```cpp
// ============================================================================
// MULTI-BABY QUEUE FUNCTIONS
// ============================================================================

BabySession* findBabyInQueue(const String& rfidUuid) {
  for (auto& session : babyQueue) {
    if (session.rfidUuid == rfidUuid) {
      return &session;
    }
  }
  return nullptr;
}

BabySession* findBabyByBabyId(const String& babyId) {
  for (auto& session : babyQueue) {
    if (session.babyId == babyId) {
      return &session;
    }
  }
  return nullptr;
}

int findBabyIndexByTareWeight(float currentWeight, float tolerance = 20.0) {
  // Find which baby's bottle is likely on the scale based on tare weight
  for (size_t i = 0; i < babyQueue.size(); i++) {
    if (babyQueue[i].bottleTareWeight > 0) {
      // Check if current weight is close to or above tare weight
      if (currentWeight >= babyQueue[i].bottleTareWeight - tolerance) {
        return i;
      }
    }
  }
  return -1;
}

void addBabyToQueue(const String& rfidUuid) {
  // Check if already in queue
  if (findBabyInQueue(rfidUuid) != nullptr) {
    Serial.println("Baby already in queue: " + rfidUuid);
    return;
  }
  
  BabySession session;
  
  // Fetch config from Firestore
  if (firebaseService->fetchRfidConfig(rfidUuid, session)) {
    // Load baby name
    Baby baby;
    if (firebaseService->getBabyById(session.babyId, baby)) {
      session.babyName = baby.firstName;
    } else {
      session.babyName = "Baby";
    }
    
    session.lastSeen = millis();
    babyQueue.push_back(session);
    
    Serial.println("=== Added to queue: " + session.babyName + " ===");
    Serial.println("  Queue size: " + String(babyQueue.size()));
    
    // Set as active if first in queue
    if (babyQueue.size() == 1) {
      activeBabyIndex = 0;
      syncTodayEventsForBaby(session.babyId);
    }
    
    setLastAction("Added: " + session.babyName);
  }
}

void setLastAction(const String& action) {
  lastActionText = action;
  lastActionTime = millis();
  Serial.println("Last action: " + action);
}

// ============================================================================
// TEMPERATURE LED FEEDBACK
// ============================================================================

void updateTemperatureLed(float objectTemp) {
  if (activeBabyIndex < 0 || activeBabyIndex >= babyQueue.size()) {
    // No active baby - check ambient darkness for night light
    int ldrRaw = readLdrRaw();
    if (ldrRaw > LDR_DARK_THRESHOLD) {
      setLedColor(NIGHT_LED_R, NIGHT_LED_G, NIGHT_LED_B);
    } else {
      setLedOff();
    }
    return;
  }
  
  BabySession& baby = babyQueue[activeBabyIndex];
  int ldrRaw = readLdrRaw();
  
  // Check darkness using baby's custom threshold
  if (ldrRaw > baby.ldrThreshold) {
    // It's dark - show temperature status
    if (objectTemp < baby.idealTempMin - 1.0) {
      setLedColor(0, 0, 255);  // Blue = too cold
    } else if (objectTemp > baby.idealTempMax + 1.0) {
      setLedColor(255, 0, 0);  // Red = too hot
    } else {
      setLedColor(0, 255, 0);  // Green = good temperature
    }
  } else {
    setLedOff();
  }
}

// ============================================================================
// ML DISPLAY (not raw weight)
// ============================================================================

float getMlConsumed(float currentWeight, float tareWeight) {
  if (tareWeight <= 0) return 0;
  float consumed = tareWeight - currentWeight;
  return consumed > 0 ? consumed : 0;
}

// ============================================================================
// BOTTLE CALIBRATION
// ============================================================================

void handleBottleCalibration(int babyIndex, float currentWeight) {
  if (babyIndex < 0 || babyIndex >= babyQueue.size()) return;
  
  BabySession& baby = babyQueue[babyIndex];
  
  if (baby.needsCalibration && currentWeight > 50) {  // Minimum 50g to be a bottle
    Serial.println("=== CALIBRATING BOTTLE ===");
    Serial.println("  Baby: " + baby.babyName);
    Serial.println("  Tare weight: " + String(currentWeight) + "g");
    
    baby.bottleTareWeight = currentWeight;
    baby.needsCalibration = false;
    
    // Save to Firestore
    firebaseService->updateRfidTareWeight(baby.rfidUuid, currentWeight);
    
    setLastAction("Calibrated: " + String((int)currentWeight) + "g");
  }
}

// ============================================================================
// SYNC EVENTS FOR SPECIFIC BABY
// ============================================================================

void syncTodayEventsForBaby(const String& babyId) {
  time_t todayStart = getTodayStartTimestamp();
  
  Serial.println("Syncing today's events for baby: " + babyId);
  
  poopCountToday = firebaseService->getPoopCountToday(babyId, todayStart);
  hadVitaminToday = firebaseService->hadVitaminToday(babyId, todayStart);
  
  Serial.println("  Poop count: " + String(poopCountToday));
  Serial.println("  Vitamin today: " + String(hadVitaminToday ? "yes" : "no"));
  
  lastEventsSyncTime = millis();
}
```

### Update the main loop:

```cpp
void loop() {
  unsigned long now = millis();
  
  // ---------- PERIODIC RFID MAPPING SYNC ----------
  if (now - lastRfidMappingSync >= RFID_MAPPING_SYNC_INTERVAL) {
    loadRfidMappings();
  }
  
  // ---------- RFID ----------
  String uid;
  bool hasCard = readRfidUid(uid);
  
  if (hasCard && uid != "") {
    auto it = uidToBabyId.find(uid);
    if (it != uidToBabyId.end()) {
      // Known RFID - add to queue if not already
      addBabyToQueue(uid);
      
      // Update lastSeen for this baby
      BabySession* session = findBabyInQueue(uid);
      if (session) {
        session->lastSeen = now;
        
        // Make this the active baby
        for (size_t i = 0; i < babyQueue.size(); i++) {
          if (babyQueue[i].rfidUuid == uid) {
            if (activeBabyIndex != (int)i) {
              activeBabyIndex = i;
              syncTodayEventsForBaby(session->babyId);
              setLastAction("Active: " + session->babyName);
            }
            break;
          }
        }
      }
    } else {
      // Unknown RFID - create pending mapping
      static String lastUnknownUid = "";
      static unsigned long lastUnknownCheck = 0;
      
      if (uid != lastUnknownUid || (now - lastUnknownCheck > 10000)) {
        Serial.println("⚠ Unknown RFID: " + uid);
        
        // Check if it was just mapped
        String mappedBabyId;
        if (firebaseService->getRfidMapping(uid, mappedBabyId)) {
          uidToBabyId[uid] = mappedBabyId;
          addBabyToQueue(uid);
        } else {
          firebaseService->createPendingRfidMapping(uid);
          setLastAction("New RFID pending");
        }
        
        lastUnknownUid = uid;
        lastUnknownCheck = now;
      }
    }
  }
  
  // ---------- LOAD CELL ----------
  float weight = readWeight();
  
  // ---------- DETECT ACTIVE BABY BY WEIGHT ----------
  if (babyQueue.size() > 0 && weight > 50) {
    int detectedIndex = findBabyIndexByTareWeight(weight);
    if (detectedIndex >= 0 && detectedIndex != activeBabyIndex) {
      activeBabyIndex = detectedIndex;
      syncTodayEventsForBaby(babyQueue[activeBabyIndex].babyId);
      setLastAction("Detected: " + babyQueue[activeBabyIndex].babyName);
    }
  }
  
  // ---------- BOTTLE CALIBRATION ----------
  if (activeBabyIndex >= 0 && activeBabyIndex < babyQueue.size()) {
    handleBottleCalibration(activeBabyIndex, weight);
  }
  
  // ---------- MEAL TRACKING ----------
  float milkConsumed = 0.0f;
  bool hasBabyActive = (activeBabyIndex >= 0 && activeBabyIndex < babyQueue.size());
  bool mealEnded = mealTracker.update(weight, hasBabyActive, milkConsumed);
  
  if (mealEnded && milkConsumed > 0 && hasBabyActive) {
    lastMilkConsumed = milkConsumed;
    saveMealToFirebase(babyQueue[activeBabyIndex].babyId, milkConsumed);
    setLastAction("Meal: " + String((int)milkConsumed) + "ml");
  }
  
  // ---------- TEMPERATURE + LED ----------
  float tempObj = readObjectTemp();
  updateTemperatureLed(tempObj);
  
  // ---------- BUTTONS ----------
  static bool lastB1State = false;
  static bool lastB2State = false;
  
  bool b1 = isButton1Pressed();
  bool b2 = isButton2Pressed();
  
  if (hasBabyActive) {
    if (b1 && !lastB1State) {
      handlePoopButton(babyQueue[activeBabyIndex].babyId);
      setLastAction("Poop: " + String(poopCountToday));
    }
    
    if (b2 && !lastB2State) {
      handleVitaminButton(babyQueue[activeBabyIndex].babyId);
      setLastAction("Vitamin given");
    }
  }
  
  lastB1State = b1;
  lastB2State = b2;
  
  // ---------- PERIODIC EVENT SYNC ----------
  if (hasBabyActive && (now - lastEventsSyncTime) >= FIREBASE_SYNC_INTERVAL_MS) {
    syncTodayEventsForBaby(babyQueue[activeBabyIndex].babyId);
  }
  
  // ---------- SCREEN UPDATE ----------
  if (now - lastScreenUpdate >= SCREEN_REFRESH_MS) {
    if (hasBabyActive) {
      BabySession& baby = babyQueue[activeBabyIndex];
      
      // Calculate ml consumed (not raw weight)
      float mlDisplay = 0;
      if (mealTracker.isMealInProgress()) {
        mlDisplay = getMlConsumed(weight, baby.bottleTareWeight);
      } else {
        mlDisplay = lastMilkConsumed;
      }
      
      updateScreenWithLastAction(
        baby.babyName,
        mlDisplay,
        hadVitaminToday,
        poopCountToday,
        mealTracker.isMealInProgress(),
        lastActionText
      );
    } else {
      showWaitingScreen();
    }
    lastScreenUpdate = now;
  }
  
  delay(50);
}

// Updated save meal function
void saveMealToFirebase(const String& babyId, float milkConsumed) {
  Serial.println("--- Saving meal for " + babyId + " ---");
  
  Bottle bottle;
  bottle.quantity = (int)milkConsumed;
  bottle.source = "scale";
  
  time_t timestamp = getCurrentTimestamp();
  bottle.createdAt = timestamp;
  bottle.startedAt = timestamp;
  
  if (firebaseService->addBottle(babyId, bottle)) {
    Serial.println("✓ Meal saved: " + String(milkConsumed, 0) + " ml");
  } else {
    Serial.println("✗ Failed to save meal");
  }
}

// Updated button handlers
void handlePoopButton(const String& babyId) {
  Serial.println("--- Recording poop for " + babyId + " ---");
  
  time_t timestamp = getCurrentTimestamp();
  PoopEvent poopEvent(timestamp);
  
  if (firebaseService->addPoopEvent(babyId, poopEvent)) {
    poopCountToday++;
    Serial.println("✓ Poop recorded! Total: " + String(poopCountToday));
  }
}

void handleVitaminButton(const String& babyId) {
  Serial.println("--- Recording vitamin for " + babyId + " ---");
  
  time_t timestamp = getCurrentTimestamp();
  VitaminEvent vitaminEvent(timestamp);
  
  if (firebaseService->addVitaminEvent(babyId, vitaminEvent)) {
    hadVitaminToday = true;
    Serial.println("✓ Vitamin recorded!");
  }
}
```

---

## 5. Update `ScreenModule.h` / `ScreenModule.cpp`

Add a new function to display last action:

```cpp
// In ScreenModule.h
void updateScreenWithLastAction(
  String babyName,
  float mlConsumed,
  bool hadVitamin,
  int poopCount,
  bool mealInProgress,
  String lastAction
);

// In ScreenModule.cpp
void updateScreenWithLastAction(
  String babyName,
  float mlConsumed,
  bool hadVitamin,
  int poopCount,
  bool mealInProgress,
  String lastAction
) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  
  // Row 1: Baby name
  display.setTextSize(2);
  display.setCursor(0, 0);
  display.println(babyName);
  
  // Row 2: ML consumed (large)
  display.setTextSize(3);
  display.setCursor(0, 20);
  display.print((int)mlConsumed);
  display.setTextSize(2);
  display.print(" ml");
  
  // Row 3: Status icons
  display.setTextSize(1);
  display.setCursor(0, 48);
  display.print("Vit:");
  display.print(hadVitamin ? "Y" : "N");
  display.print(" Poop:");
  display.print(poopCount);
  if (mealInProgress) {
    display.print(" [FEEDING]");
  }
  
  // Row 4: Last action
  display.setCursor(0, 56);
  display.print(lastAction);
  
  display.display();
}
```

---

## Summary of Changes

1. **BabySession.h** - New struct to hold per-baby config
2. **FirebaseService** - Methods to fetch/update RFID config
3. **main.ino** - Queue system, ml display, temperature LED, last action
4. **ScreenModule** - Display ml and last action

## How It Works

1. When RFID is scanned → Added to queue with config from Firestore
2. Weight detection → Determines which baby's bottle is on scale
3. Temperature sensor → LED shows blue (cold), green (good), red (hot)
4. Screen shows → Baby name, ml consumed, last action
5. Buttons → Record poop/vitamin for active baby
