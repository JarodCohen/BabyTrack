#include <Arduino.h>

#include "RfidModule.h"
#include "LoadCellModule.h"
#include "ScreenModule.h"
#include "LedModule.h"
#include "ButtonsModule.h"
#include "TempModule.h"

// Rafraîchissement écran (en ms)
const unsigned long SCREEN_REFRESH_MS = 1000;
unsigned long lastScreenUpdate = 0;

// Seuil de luminosité (à ajuster selon ton LDR)
const int LDR_DARK_THRESHOLD = 1500; 


void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println("=== BabyTrack: RFID + LoadCell + Screen + LED/LDR + Buttons + Temp ===");

  initRfid();
  initLoadCell();
  initScreen();
  initLed();
  initButtons();
  initTempSensor();     // <--- MLX90614
}


void loop() {

  // ---------- RFID ----------
  String uid;
  bool hasCard = readRfidUid(uid);

  // ---------- LOAD CELL ----------
  float weight = readWeight();

  // ---------- LDR ----------
  int ldrRaw = readLdrRaw();

  // Gestion LED : mode nuit automatique
  if (ldrRaw > LDR_DARK_THRESHOLD) {
    setLedColor(150, 120, 0);   // nuit = LED orange
  } else {
    setLedOff();
  }

  // ---------- BUTTONS ----------
  bool b1 = isButton1Pressed();   // GPIO 22
  bool b2 = isButton2Pressed();   // GPIO 23

  // ---------- TEMPÉRATURE MLX90614 ----------
  float tempObj = readObjectTemp();
  float tempAmb = readAmbientTemp();

  // ---------- SERIAL DEBUG ----------
  Serial.print("W=");
  Serial.print(weight, 2);
  Serial.print(" | Card=");
  Serial.print(hasCard ? "YES" : "NO");
  Serial.print(" | UID=");
  Serial.print(uid);
  Serial.print(" | LDR=");
  Serial.print(ldrRaw);
  Serial.print(" | B1=");
  Serial.print(b1 ? "PRESSED" : "released");
  Serial.print(" | B2=");
  Serial.print(b2 ? "PRESSED" : "released");
  Serial.print(" | T_obj=");
  Serial.print(tempObj);
  Serial.print("°C | T_amb=");
  Serial.println(tempAmb);


  // ---------- ÉCRAN : on affiche seulement le poids ----------
  unsigned long now = millis();
  if (now - lastScreenUpdate >= SCREEN_REFRESH_MS) {
    screenShowStatus(weight);   // <-- Seulement le poids
    lastScreenUpdate = now;
  }

  delay(50);
}
