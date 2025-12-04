#include "ButtonsModule.h"

#define BUTTON1_PIN 22
#define BUTTON2_PIN 23

void initButtons() {
  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
}

bool isButton1Pressed() {
  return digitalRead(BUTTON1_PIN) == LOW;   // appuyé = LOW
}

bool isButton2Pressed() {
  return digitalRead(BUTTON2_PIN) == LOW;
}
