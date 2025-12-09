#include "ScreenModule.h"
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>

// Tes pins I2C
#define I2C_SDA_PIN 25
#define I2C_SCL_PIN 33

// Paramètres écran SH1106
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
#define I2C_ADDRESS   0x3C   // comme dans ton unit test

static Adafruit_SH1106G display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
static bool screenOk = false;

void initScreen() {
  // I2C sur tes pins
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);

  // Très important : utiliser begin du SH1106G, comme dans ton unit test
  if (!display.begin(I2C_ADDRESS, true)) {
    Serial.println("Erreur: ecran SH1106 non detecte !");
    screenOk = false;
    return;
  }

  screenOk = true;

  // Nettoyer complètement l'écran
  display.clearDisplay();
  display.display();  // pousser le buffer vide vers l'écran

  // Petit texte de démarrage
  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);
  display.setCursor(0, 0);
  display.println("BabyTrack Ready");
  display.display();
}

void screenShowStatus(float weight) {
  if (!screenOk) return;

  display.clearDisplay();

  // Texte bien visible
  display.setTextSize(3);               // gros
  display.setTextColor(SH110X_WHITE);

  // Centrage approximatif vertical
  display.setCursor(0, 20);
  display.print(weight, 1);
  display.println(" g");

  display.display();
}
