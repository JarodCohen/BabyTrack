#ifndef TEMPMODULE_H
#define TEMPMODULE_H

#include <Arduino.h>

bool initTempSensor();
float readObjectTemp();
float readAmbientTemp();

#endif
