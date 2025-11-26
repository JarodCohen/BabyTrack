#include <SPI.h>
#include <MFRC522.h>

#define RST_PIN 22     // RST du RC522 → GPIO 22
#define SS_PIN  5      // SDA/SS du RC522 → GPIO 5

MFRC522 mfrc522(SS_PIN, RST_PIN);

void setup() {
  Serial.begin(115200);
  SPI.begin(18, 19, 23, SS_PIN);   // SCK=18, MISO=19, MOSI=23, SS=5

  mfrc522.PCD_Init();
  delay(4);

  mfrc522.PCD_DumpVersionToSerial();
  Serial.println(F("Scan PICC to see UID, SAK, type, and data blocks..."));
}

void loop() {
  if (!mfrc522.PICC_IsNewCardPresent()) return;
  if (!mfrc522.PICC_ReadCardSerial()) return;

  mfrc522.PICC_DumpToSerial(&(mfrc522.uid));
}
