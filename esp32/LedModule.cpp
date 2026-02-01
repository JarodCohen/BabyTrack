#include "LedModule.h"
#include <Adafruit_NeoPixel.h>

// NeoPixel
#define LED_PIN    26
#define LED_COUNT  9

// LDR sur GPIO 32 (ton montage actuel)
#define LDR_PIN    32

static Adafruit_NeoPixel strip(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);

void initLed() {
  // NeoPixel
  strip.begin();
  strip.clear();
  strip.setBrightness(100);
  strip.show();

  // LDR
  pinMode(LDR_PIN, INPUT);
}

void setLedColor(uint8_t r, uint8_t g, uint8_t b) {
  strip.setPixelColor(0, strip.Color(r, g, b));
  strip.fill(strip.Color(r, g, b),0,LED_COUNT);
  strip.show();
}

void setLedOff() {
  setLedColor(0, 0, 0);
}

int readLdrRaw() {
  return analogRead(LDR_PIN);
}
