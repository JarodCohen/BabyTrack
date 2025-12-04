#include "LoadCellModule.h"
#include <HX711.h>

// On garde TES pins :
const int LOADCELL_DOUT_PIN = 2;   // DT
const int LOADCELL_SCK_PIN  = 15;   // SCK

static HX711 scale;
static float lastWeight = 0.0f;

void initLoadCell() {
  // Le Serial.begin est déjà fait dans le main, on ne le refait pas ici

  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);

  Serial.println("Before setting up the scale:");
  Serial.print("read: \t\t");
  Serial.println(scale.read());      // raw

  Serial.print("read average: \t\t");
  Serial.println(scale.read_average(20));

  Serial.print("get value: \t\t");
  Serial.println(scale.get_value(5));

  Serial.print("get units: \t\t");
  Serial.println(scale.get_units(5), 1);

  // 👉 Ton facteur de calibration
  scale.set_scale(686);  // calibration factor
  scale.tare();          // reset à 0

  Serial.println("After setting up the scale:");
  Serial.print("read: \t\t");
  Serial.println(scale.read());

  Serial.print("read average: \t\t");
  Serial.println(scale.read_average(20));

  Serial.print("get value: \t\t");
  Serial.println(scale.get_value(5));

  Serial.print("get units: \t\t");
  Serial.println(scale.get_units(5), 1);

  Serial.println("HX711 ready.");
}

// Retourne le poids calibré (comme dans ton loop de test)
float readWeight() {
  // une mesure instantanée
  float oneReading = scale.get_units(1);
  // moyenne sur 10 (comme ton code)
  float avgReading = scale.get_units(10);

  // Tu peux choisir ce que tu préfères renvoyer
  lastWeight = avgReading;  // par exemple, la moyenne

  return lastWeight;
}
