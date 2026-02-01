#include "LoadCellModule.h"
#include "Config.h"
#include <HX711.h>

// Load cell pins
const int LOADCELL_DOUT_PIN = 15;   // DT
const int LOADCELL_SCK_PIN  = 2;    // SCK

static HX711 scale;
static float lastWeight = 0.0f;

void initLoadCell() {
  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  scale.set_scale(LOADCELL_CALIBRATION_FACTOR);
  scale.tare();  // Reset to 0
  Serial.println("✓ Load cell ready (tared)");
}

float readWeight() {
  // Average over 5 readings for stability
  lastWeight = scale.get_units(5);
  return lastWeight;
}

void tareScale() {
  scale.tare();
}
