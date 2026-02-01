#ifndef BABY_H
#define BABY_H

#include <Arduino.h>
#include <time.h>
#include <vector>

class Baby {
  public:
    String id;
    String firstName;
    String lastName;
    String ownerId;
    std::vector<String> memberIds;
    time_t birthDate;    // Unix timestamp in SECONDS
    time_t createdAt;    // Unix timestamp in SECONDS

    Baby();
    Baby(String documentId);
    
    // Convert to Firebase JSON format
    String toFirestoreJson();
    
    // Parse from Firebase response
    void fromFirestoreJson(String jsonResponse);
    
    // Helper to print baby info
    void print();
};

#endif