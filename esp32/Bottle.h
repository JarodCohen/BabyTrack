#ifndef BOTTLE_H
#define BOTTLE_H

#include <Arduino.h>
#include <time.h>

class Bottle {
  public:
    String id;
    time_t createdAt;    // Unix timestamp in SECONDS
    time_t startedAt;    // Unix timestamp in SECONDS
    int quantity;        // in ml
    String source;       // "scale" or "manual"

    Bottle();
    Bottle(String documentId);
    
    String toFirestoreJson();
    void fromFirestoreJson(String jsonResponse);
    void print();
};

#endif