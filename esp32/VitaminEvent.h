#ifndef VITAMIN_EVENT_H
#define VITAMIN_EVENT_H

#include <Arduino.h>
#include <time.h>

class VitaminEvent {
  public:
    String id;
    time_t timestamp;  // Unix timestamp in SECONDS
    
    VitaminEvent();
    VitaminEvent(time_t ts);
    
    String toFirestoreJson();
    void fromFirestoreJson(String jsonResponse);
    void print();
};

#endif