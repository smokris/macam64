//
//  OV76xx.m
//  macam
//
//  Created by Harald on 11/2/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "OV76xx.h"
#import "OV7640.h"
#import "OV7660.h"
#import "OV7670.h"

#include <unistd.h>


@implementation OV76xx


+ (id) findSensor:(MyCameraDriver*)driver
{
    id sensor = NULL;
    UInt8 msb, lsb;
    int result;
    
    [driver setupSensorCommunication:[OV76xx class]];
    
    // Reset the sensor
    
    result = [driver setSensorRegister:OV7648_REG_COMA toValue:0x80];  // reset
    if (result < 0) 
    {
        NSLog(@"OV76xx:findSensor: problem resetting the sensor.\n");
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
    
    if (msb != OMNIVISION_PRODUCT_ID_MSB_VALUE) // 0x76
    {
        NSLog(@"The Product ID MSB does not match the OV76xx series.\n");
        return NULL;
    }
    else 
        NSLog(@"The sensor appears to be in the OV76xx series (%02x).\n", lsb);
    
    if (lsb == OMNIVISION_OV7640_ID_LSB_VALUE) // EyeToy etc.
        sensor = [[OV7640 alloc] init];
    
    if (lsb == OMNIVISION_OV7660_ID_LSB_VALUE) 
        sensor = [[OV7660 alloc] init];
    
    if (lsb == OMNIVISION_OV7670_ID_LSB_VALUE) // Creative Labs Live! Cam Vista IM
        sensor = [[OV7670 alloc] init];
    
    return sensor;
}


+ (UInt8) i2cReadAddress
{
    return OV76xx_FAMILY_I2C_ADDRESS + 1;
}


+ (UInt8) i2cWriteAddress
{
    return OV76xx_FAMILY_I2C_ADDRESS;
}


- (id) init
{
    self = [super init];
	if (self == NULL) 
        return NULL;
    
    [self configure];
    
    return self;
}


- (int) configure
{
    int result = 0;
    
    result = [self setRegister:0x12 toValue:0x80]; // reset
    if (result < 0) 
        return result;
    
    result = [self setRegister:0x12 toValue:0x14]; // setup
    if (result < 0) 
        return result;
    
    return result;
}


- (int) reset
{
	return [self setRegister:OV7648_REG_COMA toValue:0x80];
}


@end
