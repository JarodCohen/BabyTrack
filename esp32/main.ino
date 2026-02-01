/**
 * ============================================================================
 * BabyTrack v3.0 - Smart Baby Bottle Feeding Tracker
 * ============================================================================
 * 
 * An ESP32-based IoT device for tracking baby bottle feeding sessions.
 * 
 * FEATURES:
 * - RFID-based baby identification (each bottle has an RFID tag)
 * - Automatic meal tracking via weight measurement
 * - Temperature monitoring with LED feedback
 * - Firebase Firestore integration for data storage
 * - OLED display showing real-time status
 * - Button inputs for tracking poop and vitamin events
 * 
 * HARDWARE COMPONENTS:
 * - ESP32 microcontroller
 * - MFRC522 RFID reader
 * - HX711 load cell (weight sensor)
 * - SH1106 OLED display (128x64)
 * - MLX90614 IR temperature sensor
 * - RGB LED for temperature feedback
 * - 2x push buttons (poop/vitamin)
 * - LDR for ambient light detection
 * 
 * SESSION FLOW:
 * 1. Scan RFID tag on bottle → wait 4 seconds → capture startWeight
 * 2. Remove bottle (feeding in progress)
 * 3. Return bottle → wait 4 seconds → capture endWeight
 * 4. Calculate consumption (startWeight - endWeight) → save to Firebase
 * 
 * @author  BabyTrack Team
 * @version 3.0
 * ============================================================================
 */

#include <Arduino.h>
#include <map>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"

// Configuration - WiFi, Firebase, timing constants
#include "Config.h"

// Hardware Modules
#include "RfidModule.h"      // MFRC522 RFID reader
#include "LoadCellModule.h"  // HX711 weight sensor
#include "ScreenModule.h"    // SH1106 OLED display
#include "LedModule.h"       // RGB LED control
#include "ButtonsModule.h"   // Push button inputs
#include "TempModule.h"      // MLX90614 temperature sensor
#include "TimeUtils.h"       // NTP time synchronization

// Data Models
#include "Baby.h"            // Baby profile data
#include "Bottle.h"          // Feeding record data
#include "FirebaseService.h" // Firebase Firestore operations
#include "PoopEvent.h"       // Diaper change tracking
#include "VitaminEvent.h"    // Vitamin supplement tracking
#include "FeedingSession.h"  // RFID-based session state machine

// ============================================================================
// GLOBAL VARIABLES
// ============================================================================

// Firebase
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
FirebaseService* firebaseService;

// Active feeding sessions (keyed by RFID UUID)
std::map<String, FeedingSession> activeSessions;

// Currently detected RFID (for display purposes)
String currentRfidUid = "";

// Today's events tracking
int poopCountToday = 0;
bool hadVitaminToday = false;
unsigned long lastEventsSyncTime = 0;

// Timing
unsigned long lastScreenUpdate = 0;
unsigned long lastRfidMappingSync = 0;
unsigned long lastAutoTareCheck = 0;
unsigned long lastWifiCheck = 0;
const unsigned long RFID_MAPPING_SYNC_INTERVAL = 60000;
const unsigned long AUTO_TARE_CHECK_INTERVAL = 5000;
const unsigned long WIFI_RETRY_INTERVAL = 20000;  // Retry WiFi every 20s
const float EMPTY_SCALE_THRESHOLD = 5.0f;

// WiFi status
bool wifiConnected = false;

// RFID UID to Baby mapping - loaded from Firestore
std::map<String, String> uidToBabyId;

// ============================================================================
// INITIALIZATION FUNCTIONS
// ============================================================================

void initWifi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500);
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✓ WiFi: " + WiFi.localIP().toString());
    wifiConnected = true;
  } else {
    Serial.println("✗ WiFi failed");
    wifiConnected = false;
  }
}

void checkWifiConnection() {
  // Try to reconnect
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  // Wait briefly for connection attempt
  delay(100);
}

void initFirebase() {
  config.api_key = API_KEY;
  Firebase.signUp(&config, &auth, "", "");
  config.token_status_callback = tokenStatusCallback;
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  firebaseService = new FirebaseService(&fbdo, FIREBASE_PROJECT_ID);
  
  unsigned long startTime = millis();
  while (!Firebase.ready() && (millis() - startTime) < 30000) {
    delay(500);
  }
  
  if (Firebase.ready()) {
    Serial.println("✓ Firebase ready");
    delay(1000);
  } else {
    Serial.println("✗ Firebase timeout");
  }
}

void loadRfidMappings() {
  std::map<String, String> firestoreMappings;
  if (firebaseService->fetchRfidMappings(firestoreMappings) && firestoreMappings.size() > 0) {
    uidToBabyId = firestoreMappings;
  }
  lastRfidMappingSync = millis();
}

// ============================================================================
// SESSION MANAGEMENT FUNCTIONS
// ============================================================================

FeedingSession* getOrCreateSession(const String& rfidUuid, unsigned long now) {
  // Check if session already exists
  auto it = activeSessions.find(rfidUuid);
  if (it != activeSessions.end()) {
    return &it->second;
  }
  
  // Create new session - fetch config from Firebase
  FeedingSession session;
  
  // Fetch RFID config (includes babyId, temp settings, ldr threshold)
  if (firebaseService->fetchRfidConfig(rfidUuid, session)) {
    // Get baby name
    Baby baby;
    if (firebaseService->getBabyById(session.babyId, baby)) {
      session.babyName = baby.firstName;
    } else {
      session.babyName = "Baby";
    }
    
    session.state = SESSION_IDLE;
    activeSessions[rfidUuid] = session;
    Serial.println("✓ Session created for " + session.babyName);
    
    return &activeSessions[rfidUuid];
  }
  
  return nullptr;
}

String getSessionStateStr(SessionState state) {
  switch (state) {
    case SESSION_IDLE: return "IDLE";
    case SESSION_STABILIZING_START: return "WAIT_START";
    case SESSION_STARTED: return "STARTED";
    case SESSION_IN_PROGRESS: return "FEEDING";
    case SESSION_STABILIZING_END: return "WAIT_END";
    default: return "?";
  }
}

// ============================================================================
// EVENT SYNC FOR SPECIFIC BABY
// ============================================================================

void syncTodayEventsForBaby(const String& babyId) {
  time_t todayStart = getTodayStartTimestamp();
  
  int firebasePoopCount = firebaseService->getPoopCountToday(babyId, todayStart);
  bool firebaseHadVitamin = firebaseService->hadVitaminToday(babyId, todayStart);
  
  if (firebasePoopCount > poopCountToday) {
    poopCountToday = firebasePoopCount;
  }
  if (firebaseHadVitamin) {
    hadVitaminToday = true;
  }
  
  lastEventsSyncTime = millis();
}

// ============================================================================
// TEMPERATURE LED FEEDBACK
// ============================================================================

void updateTemperatureLed(float objectTemp, const String& rfidUid) {
  int ldrRaw = readLdrRaw();
  
  // If no active session, use default night light behavior
  if (rfidUid == "" || activeSessions.find(rfidUid) == activeSessions.end()) {
    if (ldrRaw > LDR_DARK_THRESHOLD) {
      setLedColor(NIGHT_LED_R, NIGHT_LED_G, NIGHT_LED_B);
    } else {
      setLedOff();
    }
    return;
  }
  
  FeedingSession& session = activeSessions[rfidUid];
  
  // Log temperature info
  static unsigned long lastTempLog = 0;
  if (millis() - lastTempLog >= 2000) {
    Serial.println("Temp: " + String(objectTemp, 1) + "C | Range: " + 
                   String(session.idealTempMin, 1) + "-" + String(session.idealTempMax, 1) + "C");
    lastTempLog = millis();
  }
  
    if (objectTemp < session.idealTempMin - 1.0) {
      setLedColor(0, 0, 255);  // Blue = too cold
    } else if (objectTemp > session.idealTempMax + 1.0) {
      setLedColor(255, 0, 0);  // Red = too hot
    } else {
      if (ldrRaw > LDR_DARK_THRESHOLD) {
      setLedColor(NIGHT_LED_R, NIGHT_LED_G, NIGHT_LED_B);
    } else {
      setLedOff();
    }
  }
  
}

// Get current time as HH:MM string
String getCurrentTimeStr() {
  struct tm timeinfo;
  if (getLocalTime(&timeinfo)) {
    char buffer[6];
    strftime(buffer, sizeof(buffer), "%H:%M", &timeinfo);
    return String(buffer);
  }
  return "--:--";
}

// ============================================================================
// FIREBASE SAVE FUNCTIONS
// ============================================================================

void saveMealToFirebase(const String& babyId, float milkConsumed) {
  if (!wifiConnected || !Firebase.ready()) {
    Serial.println("✗ Cannot save meal - no connection");
    return;
  }
  
  Bottle bottle;
  bottle.quantity = (int)milkConsumed;
  bottle.source = "scale";
  
  time_t timestamp = getCurrentTimestamp();
  bottle.createdAt = timestamp;
  bottle.startedAt = timestamp;
  
  if (firebaseService->addBottle(babyId, bottle)) {
    Serial.println("✓ Meal: " + String((int)milkConsumed) + "ml");
  }
}

void handlePoopButton(const String& babyId) {
  if (!wifiConnected || !Firebase.ready()) {
    Serial.println("✗ Cannot save poop - no connection");
    return;
  }
  
  time_t timestamp = getCurrentTimestamp();
  PoopEvent poopEvent(timestamp);
  
  if (firebaseService->addPoopEvent(babyId, poopEvent)) {
    poopCountToday++;
  }
}

void handleVitaminButton(const String& babyId) {
  if (!wifiConnected || !Firebase.ready()) {
    Serial.println("✗ Cannot save vitamin - no connection");
    return;
  }
  
  time_t timestamp = getCurrentTimestamp();
  VitaminEvent vitaminEvent(timestamp);
  
  if (firebaseService->addVitaminEvent(babyId, vitaminEvent)) {
    hadVitaminToday = true;
  }
}

// ============================================================================
// SETUP
// ============================================================================

void setup() {
  Serial.begin(115200);
  delay(1500);

  Serial.println("=== BabyTrack v3.0 ===");

  initWifi();
  delay(2000);         // Let WiFi stabilize before NTP
  initNTP();           // Sync time BEFORE Firebase (SSL needs correct time)
  initFirebase();
  loadRfidMappings();
  initRfid();
  initLoadCell();
  initScreen();
  initLed();
  initButtons();
  initTempSensor();
  
  Serial.println("=== Ready ===");
}

// ============================================================================
// MAIN LOOP
// ============================================================================

void loop() {
  unsigned long now = millis();
  
  // ---------- WIFI CONNECTION CHECK ----------
  // Check current status
  bool wifiCurrentlyConnected = (WiFi.status() == WL_CONNECTED);
  
  if (!wifiCurrentlyConnected) {
    // WiFi is disconnected
    if (wifiConnected) {
      // Just disconnected - show reconnect screen once
      wifiConnected = false;
      showWifiReconnecting();
      Serial.println("✗ WiFi disconnected");
    }
    
    // Try to reconnect every 20 seconds
    if (now - lastWifiCheck >= WIFI_RETRY_INTERVAL) {
      Serial.println("WiFi reconnecting...");
      checkWifiConnection();
      lastWifiCheck = now;
    }
  } else {
    // WiFi is connected
    if (!wifiConnected) {
      wifiConnected = true;
      Serial.println("✓ WiFi reconnected: " + WiFi.localIP().toString());
      
      // Reinitialize Firebase connection after WiFi reconnect
      Serial.println("Reconnecting Firebase...");
      Firebase.reconnectWiFi(true);
      
      // Wait for Firebase to be ready
      unsigned long fbStart = millis();
      while (!Firebase.ready() && (millis() - fbStart) < 5000) {
        delay(100);
      }
      
      if (Firebase.ready()) {
        Serial.println("✓ Firebase reconnected");
      } else {
        Serial.println("✗ Firebase reconnect timeout");
      }
    }
  }
  
  // ---------- PERIODIC RFID MAPPING SYNC ----------
  if (wifiConnected && (now - lastRfidMappingSync >= RFID_MAPPING_SYNC_INTERVAL)) {
    loadRfidMappings();
  }
  
  // ---------- LOAD CELL ----------
  float weight = readWeight();
  
  // ---------- AUTO-TARE WHEN SCALE EMPTY ----------
  if (abs(weight) < EMPTY_SCALE_THRESHOLD || weight < -5.0f) {
    if (now - lastAutoTareCheck >= AUTO_TARE_CHECK_INTERVAL) {
      tareScale();
      lastAutoTareCheck = now;
    }
  } else {
    lastAutoTareCheck = now;
  }
  
  // ---------- RFID DETECTION ----------
  String uid;
  bool hasCard = readRfidUid(uid);
  
  // Handle unknown RFID (create pending mapping)
  if (hasCard && uid != "") {
    auto it = uidToBabyId.find(uid);
    if (it == uidToBabyId.end()) {
      // Unknown RFID - check if recently mapped or create pending
      static String lastUnknownUid = "";
      static unsigned long lastUnknownCheck = 0;
      
      if (uid != lastUnknownUid || (now - lastUnknownCheck > 10000)) {
        String mappedBabyId;
        if (firebaseService->getRfidMapping(uid, mappedBabyId)) {
          uidToBabyId[uid] = mappedBabyId;
        } else {
          firebaseService->createPendingRfidMapping(uid);
          showNotification("NEW CARD", uid.substring(0, 8));
        }
        lastUnknownUid = uid;
        lastUnknownCheck = now;
      }
    }
  }
  
  // Update current RFID for display
  if (hasCard && uid != "" && uidToBabyId.find(uid) != uidToBabyId.end()) {
    currentRfidUid = uid;
  }
  
  // ---------- SESSION STATE MACHINE ----------
  // Process all active sessions
  for (auto& pair : activeSessions) {
    FeedingSession& session = pair.second;
    bool isThisCard = (hasCard && uid == session.rfidUuid);
    
    switch (session.state) {
      case SESSION_IDLE:
        // Waiting for RFID to be detected
        if (isThisCard) {
          session.rfidFirstSeen = now;
          session.state = SESSION_STABILIZING_START;
          Serial.println(session.babyName + ": RFID detected, waiting 3s...");
        }
        break;
        
      case SESSION_STABILIZING_START:
        // RFID detected, waiting 3s to capture startWeight
        if (!isThisCard) {
          // Card removed before 3s - go back to idle
          session.state = SESSION_IDLE;
          Serial.println(session.babyName + ": RFID removed before start");
        } else if (now - session.rfidFirstSeen >= SESSION_STABILIZE_MS) {
          // 3s elapsed - check if weight is valid (not near zero)
          if (abs(weight) <= 40.0) {
            // Weight too close to zero - don't start meal
            session.state = SESSION_IDLE;
            Serial.println(session.babyName + ": Weight near zero (" + String(weight, 1) + "g), not starting");
          } else {
            // Valid weight - capture startWeight
            session.startWeight = weight;
            session.state = SESSION_STARTED;
            showNotification("START", String(weight, 1) + "g");
            Serial.println(session.babyName + ": Session STARTED at " + String(weight, 1) + "g");
          }
        }
        break;
        
      case SESSION_STARTED:
        // startWeight captured, waiting for RFID to be removed
        if (!isThisCard) {
          session.state = SESSION_IN_PROGRESS;
          Serial.println(session.babyName + ": RFID removed, feeding in progress");
        }
        break;
        
      case SESSION_IN_PROGRESS:
      
        // RFID removed, feeding in progress, waiting for same RFID to return
        if (isThisCard) {
          session.rfidFirstSeen = now;
          session.state = SESSION_STABILIZING_END;
          Serial.println(session.babyName + ": RFID returned, waiting 3s to end...");
        }
        break;
        
      case SESSION_STABILIZING_END:
        // Same RFID returned, waiting 3s to capture endWeight
        if (!isThisCard) {
          // Card removed before 3s - back to in progress
          session.state = SESSION_IN_PROGRESS;
          Serial.println(session.babyName + ": RFID removed before end");
        } else if (now - session.rfidFirstSeen >= SESSION_STABILIZE_MS) {
          // 3s elapsed - capture endWeight
          float consumed = session.startWeight - weight;
          
          if (weight > session.startWeight) {
            // End weight is GREATER than start weight
            // User forgot to close previous meal - restart with new weight
            session.startWeight = weight;
            session.state = SESSION_STARTED;
            showNotification("RESTART", String(weight, 1) + "g");
            Serial.println(session.babyName + ": RESTART meal at " + String(weight, 1) + "g (weight increased)");
          } else if (consumed >= MEAL_MIN_CONSUMPTION) {
            // Valid consumption - save meal
            saveMealToFirebase(session.babyId, consumed);
            showNotification("MEAL", String(consumed, 1) + "ml");
            Serial.println(session.babyName + ": Session ENDED - " + String(consumed, 1) + "ml consumed");
            
            // Reset session to idle
            session.state = SESSION_IDLE;
            session.startWeight = 0;
          } else {
            // No significant consumption - just end
            Serial.println(session.babyName + ": Session ended (no significant consumption)");
            session.state = SESSION_IDLE;
            session.startWeight = 0;
          }
        }
        break;
    }
    
    // Update last seen time
    if (isThisCard) {
      session.lastRfidSeen = now;
    }
  }
  
  // Create session for known RFID if not exists
  if (hasCard && uid != "" && uidToBabyId.find(uid) != uidToBabyId.end()) {
    if (activeSessions.find(uid) == activeSessions.end()) {
      FeedingSession* session = getOrCreateSession(uid, now);
      if (session) {
        session->rfidFirstSeen = now;
        session->state = SESSION_STABILIZING_START;
        Serial.println(session->babyName + ": New session, RFID detected, waiting 3s...");
      }
    }
  }
  
  // ---------- TEMPERATURE + LED ----------
  float tempObj = readObjectTemp();
  updateTemperatureLed(tempObj, currentRfidUid);
  
  // ---------- BUTTONS ----------
  static bool lastB1State = false;
  static bool lastB2State = false;
  
  bool b1 = isButton1Pressed();
  bool b2 = isButton2Pressed();
  
  // Use current RFID session for button actions
  if (currentRfidUid != "" && activeSessions.find(currentRfidUid) != activeSessions.end()) {
    FeedingSession& session = activeSessions[currentRfidUid];
    
    if (b1 && !lastB1State) {
      handlePoopButton(session.babyId);
      showNotification("POOP", String(poopCountToday) + " today");
    }
    
    if (b2 && !lastB2State) {
      handleVitaminButton(session.babyId);
      showNotification("VITAMIN", "Done!");
    }
  }
  
  lastB1State = b1;
  lastB2State = b2;
  
  // ---------- SCREEN UPDATE ----------
  // Skip normal screen updates if WiFi is disconnected (keep reconnect screen)
  if (wifiConnected && (now - lastScreenUpdate >= SCREEN_REFRESH_MS)) {
    if (currentRfidUid != "" && activeSessions.find(currentRfidUid) != activeSessions.end()) {
      FeedingSession& session = activeSessions[currentRfidUid];
      
      // Check if currently in a meal (feeding in progress)
      bool isMeal = (session.state == SESSION_IN_PROGRESS || session.state == SESSION_STABILIZING_END);
      
      // Show: name, temperature, weight, meal status
      showMainScreen(session.babyName, tempObj, weight, isMeal);
    } else {
      showWaitingScreen();
    }
    lastScreenUpdate = now;
  }
  
  // ---------- DEBUG OUTPUT (every 2s) ----------
  #if DEBUG_ENABLED
  static unsigned long lastDebugPrint = 0;
  if (now - lastDebugPrint >= 2000) {
    if (currentRfidUid != "" && activeSessions.find(currentRfidUid) != activeSessions.end()) {
      FeedingSession& session = activeSessions[currentRfidUid];
      Serial.println(session.babyName + " | " + String(weight, 1) + "g | " + 
                     getSessionStateStr(session.state) + 
                     (session.startWeight > 0 ? " | start:" + String(session.startWeight, 1) + "g" : ""));
    } else {
      Serial.println("--- | " + String(weight, 1) + "g | no session");
    }
    lastDebugPrint = now;
  }
  #endif
  
  delay(50);
}
