#include "ScreenModule.h"
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>

// I2C pins
#define I2C_SDA_PIN 25
#define I2C_SCL_PIN 33

// Screen parameters SH1106
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
#define I2C_ADDRESS   0x3C

// Notification duration
#define NOTIFICATION_DURATION_MS 2000

static Adafruit_SH1106G display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
static bool screenOk = false;

// Notification state
static bool notificationActive = false;
static unsigned long notificationStartTime = 0;

void initScreen() {
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);

  if (!display.begin(I2C_ADDRESS, true)) {
    Serial.println("✗ Screen not found");
    screenOk = false;
    return;
  }

  screenOk = true;
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);
  display.setTextSize(2);
  display.setCursor(10, 25);
  display.println("BabyTrack");
  display.display();
  
  Serial.println("✓ Screen ready");
}

void showMainScreen(
    const String& babyName,
    float temperature,
    float weight,
    bool isMeal) {
  
  if (!screenOk) return;
  
  // Check if notification should end
  if (notificationActive && (millis() - notificationStartTime >= NOTIFICATION_DURATION_MS)) {
    notificationActive = false;
  }
  
  // If notification is active, don't overwrite it
  if (notificationActive) return;
  
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);
  
  // Row 1: Baby name (left) + Temperature (right)
  display.setTextSize(2);
  display.setCursor(0, 0);
  String name = babyName;
  if (name.length() > 5) name = name.substring(0, 5);
  display.print(name);
  
  // Temperature on top right
  display.setTextSize(1);
  String tempStr = String(temperature, 1) + "C";
  int tempX = 128 - (tempStr.length() * 6);
  display.setCursor(tempX, 5);
  display.print(tempStr);
  
  // Row 2-3: Weight (large, centered, rounded to nearest 10)
  display.setTextSize(3);
  int roundedWeight = ((int)round(weight / 10.0)) * 10;
  String weightStr = String(roundedWeight);
  int weightWidth = weightStr.length() * 18;
  int weightX = (128 - weightWidth - 12) / 2;
  display.setCursor(weightX > 0 ? weightX : 0, 22);
  display.print(weightStr);
  
  display.setTextSize(2);
  display.print("g");
  
  // Row 4: Meal status (bottom)
  display.setTextSize(2);
  if (isMeal) {
    display.setCursor(20, 48);
    display.print("FEEDING");
  } else {
    display.setCursor(40, 48);
    display.print("IDLE");
  }
  
  display.display();
}

void showNotification(const String& title, const String& value) {
  if (!screenOk) return;
  
  notificationActive = true;
  notificationStartTime = millis();
  
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);
  
  // Title at top
  display.setTextSize(1);
  int titleX = (128 - title.length() * 6) / 2;
  display.setCursor(titleX > 0 ? titleX : 0, 5);
  display.print(title);
  
  // Value in center (large)
  display.setTextSize(3);
  int valueX = (128 - value.length() * 18) / 2;
  display.setCursor(valueX > 0 ? valueX : 0, 25);
  display.print(value);
  
  display.display();
}

void showWaitingScreen() {
  if (!screenOk) return;
  
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);
  
  display.setTextSize(1);
  display.setCursor(35, 10);
  display.print("BabyTrack");
  
  display.setTextSize(2);
  display.setCursor(15, 30);
  display.print("Scan card");
  
  display.display();
}

void showWifiReconnecting() {
  if (!screenOk) return;
  
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);
  
  display.setTextSize(1);
  display.setCursor(45, 5);
  display.print("WiFi");
  
  display.setTextSize(2);
  display.setCursor(0, 25);
  display.print("Reconnect");
  
  display.setTextSize(1);
  display.setCursor(30, 50);
  display.print("Please wait...");
  
  display.display();
}

bool isNotificationActive() {
  if (notificationActive && (millis() - notificationStartTime >= NOTIFICATION_DURATION_MS)) {
    notificationActive = false;
  }
  return notificationActive;
}

void clearNotification() {
  notificationActive = false;
}
