/**
 * ============================================================================
 * FirebaseService.h - Firebase Firestore Database Operations
 * ============================================================================
 * 
 * Provides a high-level interface to Firebase Firestore for all database
 * operations in the BabyTrack system.
 * 
 * FIRESTORE STRUCTURE:
 * 
 *   /Babies/{babyId}
 *       ├── firstName, lastName, birthDate, ownerId, memberIds
 *       └── /Bottles/{bottleId}      - Feeding records
 *       └── /PoopEvents/{eventId}    - Diaper change records
 *       └── /VitaminEvents/{eventId} - Vitamin supplement records
 * 
 *   /RfidMappings/{rfidUuid}
 *       ├── babyId                   - Links RFID to baby
 *       ├── status                   - "pending" or "mapped"
 *       ├── idealTempMin/Max         - Per-baby temperature settings
 *       └── ldrThreshold             - Per-baby night light threshold
 * 
 * ============================================================================
 */

#ifndef FIREBASE_SERVICE_H
#define FIREBASE_SERVICE_H

#include <Arduino.h>
#include <map>
#include <Firebase_ESP_Client.h>
#include "Baby.h"
#include "Bottle.h"
#include "PoopEvent.h"
#include "VitaminEvent.h"
#include "FeedingSession.h"

/**
 * Firebase Firestore service class.
 * Handles all database read/write operations.
 */
class FirebaseService {
  private:
    FirebaseData* fbdo;          ///< Firebase data object for requests
    String projectId;            ///< Firebase project ID
    String getISOTimestamp();    ///< Get current time as ISO 8601 string
    
  public:
    /**
     * Constructor.
     * @param firebaseData Pointer to FirebaseData object
     * @param firebaseProjectId Firebase project ID string
     */
    FirebaseService(FirebaseData* firebaseData, String firebaseProjectId);
    
    // ─── Baby Operations ───
    
    /** Get baby profile by document ID */
    bool getBabyById(String babyId, Baby& baby);
    
    /** Update existing baby profile */
    bool updateBabyById(String babyId, Baby& baby);
    
    /** Create new baby profile */
    bool createBaby(Baby& baby);
    
    // ─── Bottle/Feeding Operations ───
    
    /** Add new feeding record to baby's Bottles subcollection */
    bool addBottle(String babyId, Bottle& bottle);
    
    /** Get single bottle record */
    bool getBottle(String babyId, String bottleId, Bottle& bottle);
    
    /** Get all bottle records for a baby */
    bool getBottles(String babyId, std::vector<Bottle>& bottles);
    
    // ─── Event Tracking ───
    
    /** Record a diaper change event */
    bool addPoopEvent(String babyId, PoopEvent& event);
    
    /** Record a vitamin supplement event */
    bool addVitaminEvent(String babyId, VitaminEvent& event);
    
    /** Update baby's current weight */
    bool setWeight(String babyId, float weight);
    
    // ─── Today's Events Queries ───
    
    /** Count poop events since todayStart timestamp */
    int getPoopCountToday(String babyId, time_t todayStart);
    
    /** Check if vitamin was given since todayStart timestamp */
    bool hadVitaminToday(String babyId, time_t todayStart);

    // ─── RFID Mapping Operations ───
    
    /** Fetch all RFID→Baby mappings from Firestore */
    bool fetchRfidMappings(std::map<String, String>& mappings);
    
    /** Create a pending RFID mapping for unknown card */
    bool createPendingRfidMapping(const String& rfidUuid);
    
    /** Get baby ID for a specific RFID */
    bool getRfidMapping(const String& rfidUuid, String& babyId);
    
    /** Fetch per-baby configuration from RFID mapping document */
    bool fetchRfidConfig(const String& rfidUuid, FeedingSession& session);
};

#endif