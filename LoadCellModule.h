#ifndef LOADCELLMODULE_H
#define LOADCELLMODULE_H

#include <Arduino.h>

void initLoadCell();
float readWeight();   // retourne le poids en unités "réelles" (déjà calibré)

#endif
