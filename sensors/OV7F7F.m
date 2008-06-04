//
//  OV7F7F.m
//  macam
//
//  Created by Harald on 6/3/08.
//  Copyright 2008 HXR. All rights reserved.
//


#import "OV7F7F.h"

#import "OV7670.h"

#include <unistd.h>


@implementation OV7F7F

+ (id) findSensor:(MyCameraDriver *) driver
{
    id sensor = NULL;
    UInt8 msb, lsb;
    int result;
    
    [driver setupSensorCommunication:[OV7F7F class]];
    
    // Reset the sensor
    
    result = [driver setSensorRegister:0x12 toValue:0x80];  // reset
    if (result < 0) 
    {
        NSLog(@"OV7F7F:findSensor: problem resetting the sensor.\n");
        return NULL;
    }
    
    // Wait for it to initialize
    
    usleep(150 * 1000);
    
    msb = [driver getSensorRegister:OMNIVISION_MANUFACTURER_ID_MSB_REG];
    lsb = [driver getSensorRegister:OMNIVISION_MANUFACTURER_ID_LSB_REG];
    
    // could loop here if there is a problem
    
    if (msb != OMNIVISION_MANUFACTURER_ID_MSB_VALUE || lsb != OMNIVISION_MANUFACTURER_ID_LSB_VALUE) 
    {
        NSLog(@"The Manufacturer ID bytes do not match OmniVision.\n");
        return NULL;
    }
    else 
        NSLog(@"The Manufacturer ID bytes match OmniVision.\n");
    
    msb = [driver getSensorRegister:OMNIVISION_PRODUCT_ID_MSB_REG];
    lsb = [driver getSensorRegister:OMNIVISION_PRODUCT_ID_LSB_REG];
    
    if (msb != 0x7f) 
    {
        NSLog(@"The Product ID MSB does not match the OV7F7F sensor (%02x:%02x).\n", msb, lsb);
        return NULL;
    }
    else 
        NSLog(@"The sensor appears to be the OV7F7F (%02x).\n", lsb);
    
    if (lsb == 0x7f) 
        sensor = [[OV7670 alloc] initWithController:driver];
    
    return sensor;
}


@end
