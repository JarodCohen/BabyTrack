#include "RfidModule.h"
#include <SPI.h>
#include <MFRC522.h>

// Tes pins EXACTS :
#define RST_PIN 4     // RST du RC522 → GPIO 4
#define SS_PIN  21     // SDA/SS du RC522 → GPIO 21

static MFRC522 mfrc522(SS_PIN, RST_PIN);

// On mémorise la dernière carte vue + le dernier instant
static String lastUid = "";
static bool cardPresent = false;
static unsigned long lastSeenMs = 0;

// How long to consider the card still present after last read (in ms)
// Must be longer than the longest Firebase operation (~2-3 seconds)
static const unsigned long CARD_STILL_PRESENT_MS = 5000;  // 5 seconds

void initRfid() {
  // On garde TON SPI.begin :
  SPI.begin(19, 5, 18, SS_PIN);   // SCK=22, MISO=19, MOSI=21, SS=23

  mfrc522.PCD_Init();
  delay(4);

  mfrc522.PCD_DumpVersionToSerial();
  Serial.println(F("RFID ready. Passe un tag..."));

  lastUid = "";
  cardPresent = false;
  lastSeenMs = 0;
}

bool readRfidUid(String &uidHex) {
  uidHex = "";

  bool newCardRead = false;

  // 1) Try to read a card
  if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
    // Build UID in hex format
    String uid = "";
    for (byte i = 0; i < mfrc522.uid.size; i++) {
      if (mfrc522.uid.uidByte[i] < 0x10) uid += "0";
      uid += String(mfrc522.uid.uidByte[i], HEX);
      if (i < mfrc522.uid.size - 1) uid += ":";
    }
    uid.toUpperCase();

    // Debug: show when a new card is physically read
    if (uid != lastUid) {
      Serial.println("[RFID] New card read: " + uid);
    }

    lastUid = uid;
    cardPresent = true;
    lastSeenMs = millis();
    newCardRead = true;

    // End communication with the card
    mfrc522.PICC_HaltA();
    mfrc522.PCD_StopCrypto1();
  }

  // 2) Si on n'a pas lu de nouvelle carte maintenant,
  //    on regarde si on considère encore la précédente comme "présente"
  if (!newCardRead) {
    if (cardPresent && (millis() - lastSeenMs) < CARD_STILL_PRESENT_MS) {
      // On considère que la carte est toujours là
      uidHex = lastUid;
      return true;
    } else {
      // Plus de carte
      cardPresent = false;
      lastUid = "";
      uidHex = "";
      return false;
    }
  }

  // 3) Si on a bien lu une nouvelle carte dans ce tour :
  uidHex = lastUid;
  return true;
}
