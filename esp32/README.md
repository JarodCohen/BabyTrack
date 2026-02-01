# BabyTrack v3.0 - Smart Baby Bottle Feeding Tracker

An ESP32-based IoT device for automatically tracking baby bottle feeding sessions using RFID identification and weight measurement.

## Features

- **RFID-based baby identification** - Each bottle has an RFID tag linked to a baby profile
- **Automatic meal tracking** - Measures milk consumption by weight difference
- **Temperature monitoring** - IR sensor checks bottle temperature with LED feedback
- **Firebase cloud sync** - All data stored in Firestore for multi-device access
- **OLED display** - Real-time status showing baby name, weight, temperature, and feeding state
- **Event buttons** - Quick logging of diaper changes and vitamin supplements
- **Night light mode** - Warm LED in dark environments

## Hardware Components

| Component | Description | GPIO Pins |
|-----------|-------------|-----------|
| ESP32 | Main microcontroller | - |
| MFRC522 | RFID reader (SPI) | SS:5, SCK:18, MOSI:23, MISO:19, RST:22 |
| HX711 | Load cell amplifier | DOUT:4, SCK:2 |
| SH1106 | OLED display 128x64 (I2C) | SDA:25, SCL:33 |
| MLX90614 | IR temperature sensor (I2C) | SDA:25, SCL:33 |
| NeoPixel | RGB LED | Data:32 |
| LDR | Light sensor | Analog:34 |
| Button 1 | Poop event | GPIO:26 |
| Button 2 | Vitamin event | GPIO:13 |

## Session Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    FEEDING SESSION FLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. SCAN RFID          2. WAIT 4 SEC         3. START CAPTURED  │
│  ┌──────────┐          ┌──────────┐          ┌──────────┐       │
│  │  Place   │  ──────> │ Waiting  │  ──────> │  START   │       │
│  │  bottle  │          │  4 sec   │          │  150g    │       │
│  └──────────┘          └──────────┘          └──────────┘       │
│                                                    │             │
│                                                    ▼             │
│  6. MEAL SAVED         5. WAIT 4 SEC         4. FEEDING        │
│  ┌──────────┐          ┌──────────┐          ┌──────────┐       │
│  │   MEAL   │  <────── │ Waiting  │  <────── │  Remove  │       │
│  │   45ml   │          │  4 sec   │          │  bottle  │       │
│  └──────────┘          └──────────┘          └──────────┘       │
│                                                                  │
│  Consumption = StartWeight (150g) - EndWeight (105g) = 45ml     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Firebase Structure

```
Firestore Database
│
├── /Babies/{babyId}
│   ├── firstName: "Emma"
│   ├── lastName: "Smith"
│   ├── birthDate: timestamp
│   ├── ownerId: "user123"
│   │
│   ├── /Bottles/{bottleId}           # Feeding records
│   │   ├── quantity: 45              # ml consumed
│   │   ├── source: "scale"           # or "manual"
│   │   ├── createdAt: timestamp
│   │   └── startedAt: timestamp
│   │
│   ├── /PoopEvents/{eventId}         # Diaper changes
│   │   └── timestamp: timestamp
│   │
│   └── /VitaminEvents/{eventId}      # Vitamin supplements
│       └── timestamp: timestamp
│
└── /RfidMappings/{rfidUuid}          # RFID → Baby links
    ├── babyId: "abc123"
    ├── status: "mapped"              # or "pending"
    ├── idealTempMin: 35.0
    ├── idealTempMax: 40.0
    └── ldrThreshold: 500
```

## Configuration

Edit `Config.h` to customize:

```cpp
// WiFi
#define WIFI_SSID "your_wifi"
#define WIFI_PASSWORD "your_password"

// Firebase
#define API_KEY "your_firebase_api_key"
#define FIREBASE_PROJECT_ID "your_project_id"

// Session timing
#define SESSION_STABILIZE_MS 4000    // Wait time for weight capture
#define MEAL_MIN_CONSUMPTION 5.0f    // Minimum ml to save

// Temperature (per-baby, stored in Firebase)
// Default: 35-40°C ideal range

// Night light
#define LDR_DARK_THRESHOLD 1500      // ADC threshold for dark
#define NIGHT_LED_R 150              // Warm white color
#define NIGHT_LED_G 120
#define NIGHT_LED_B 0
```

## File Structure

```
main/
├── main.ino              # Main program and loop
├── Config.h              # Configuration constants
├── FeedingSession.h      # Session state machine
│
├── Modules/
│   ├── RfidModule.*      # MFRC522 RFID reader
│   ├── LoadCellModule.*  # HX711 weight sensor
│   ├── ScreenModule.*    # SH1106 OLED display
│   ├── TempModule.*      # MLX90614 temperature
│   ├── LedModule.*       # NeoPixel LED + LDR
│   ├── ButtonsModule.*   # Push button inputs
│   └── TimeUtils.*       # NTP time sync
│
├── Data Models/
│   ├── Baby.*            # Baby profile
│   ├── Bottle.*          # Feeding record
│   ├── PoopEvent.*       # Diaper event
│   └── VitaminEvent.*    # Vitamin event
│
└── FirebaseService.*     # Firestore operations
```

## LED Temperature Feedback

| Temperature | LED Color | Meaning |
|-------------|-----------|---------|
| < idealMin - 1°C | 🔵 Blue | Too cold |
| idealMin to idealMax | 💛 Warm white | Ideal (night mode) |
| > idealMax + 1°C | 🔴 Red | Too hot |

## Troubleshooting

### NTP Sync Failed
- iPhone hotspots often block NTP (UDP port 123)
- System sets fallback time (Jan 2025) for SSL to work
- Timestamps may not be accurate

### Firebase SSL Errors
- Ensure NTP syncs before Firebase init
- Check WiFi stability
- Firebase reconnects automatically after WiFi recovery

### Weight Reading Issues
- Calibrate LOADCELL_CALIBRATION_FACTOR in Config.h
- Scale auto-tares when empty (<5g)
- Avoid vibrations during measurement

## License

MIT License - Feel free to use and modify for your projects.
