#ifndef POOP_EVENT_H
#define POOP_EVENT_H

#include <Arduino.h>
#include <time.h>

class PoopEvent {
  public:
    String id;
    time_t timestamp;  // Unix timestamp in SECONDS
    
    PoopEvent();
    PoopEvent(time_t ts);
    
    String toFirestoreJson();
    void fromFirestoreJson(String jsonResponse);
    void print();
};

#endif