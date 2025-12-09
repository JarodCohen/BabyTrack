#ifndef RFIDMODULE_H
#define RFIDMODULE_H

#include <Arduino.h>

void initRfid();

// Retourne true si une carte est (encore) présente,
// met son UID dans uidHex (sinon uidHex = "")
bool readRfidUid(String &uidHex);

#endif
