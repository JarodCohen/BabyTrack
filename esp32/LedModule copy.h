#ifndef LEDMODULE_H
#define LEDMODULE_H

#include <Arduino.h>

// Initialisation LED + LDR
void initLed();

// Contrôle NeoPixel
void setLedColor(uint8_t r, uint8_t g, uint8_t b);
void setLedOff();

// LDR
int readLdrRaw();        // valeur brute ADC 0–4095

#endif
