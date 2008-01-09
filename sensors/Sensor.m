//
//  Sensor.m
//  macam
//
//  Created by Harald on 10/29/07.
//  Copyright 2007 hxr. All rights reserved.
//


#import "Sensor.h"
#import "OmniVisionSensor.h"


@implementation Sensor


+ (id) findSensor:(MyCameraDriver*)driver
{
    id sensor = NULL;
    
    if (sensor == NULL) 
        sensor = [OmniVisionSensor findSensor:driver];
    
    return sensor;
}


+ (UInt8) i2cReadAddress
{
    return 0x00;  //  return i2cAddress + 1;
}


+ (UInt8) i2cWriteAddress
{
    return 0x00;  //  return i2cAddress;
}


- (id) init
{
    self = [super init];
    
    return self;
}


- (int) configure
{
    return 0;
}

/*
registerStart
registerEnd
registerValid
registerWriteable
*/


- (int) getRegister:(UInt8)reg
{
    return [controller getSensorRegister:reg];
}


- (int) setRegister:(UInt8)reg toValue:(UInt8)val
{
    return [controller setSensorRegister:reg toValue:val];
}


- (int) setRegister:(UInt8)reg toValue:(UInt8)val withMask:(UInt8)mask
{
    int result = [self getRegister:reg];
    UInt8 actualVal = result;
    
    if (result < 0) 
        return result;
    
    actualVal &= ~mask;  // clear out bits
    val &= mask;         // only set bits allowed by mask
    actualVal |= val;    // combine them
    
    return [self setRegister:reg toValue:actualVal];
}


- (int) reset
{
    // Not implemented
    
    NSLog(@"Sensor:reset not implemented");
    
    return -1;
}


- (void) setResolution:(CameraResolution)r fps:(short)fr
{
}


- (BOOL) canSetBrightness
{
    return NO;
}


- (void) setBrightness:(float)v
{
}


- (BOOL) canSetSaturation
{
    return NO;
}


- (void) setSaturation:(float)v
{
}


- (BOOL) canSetGain
{
    return NO;
}


- (void) setGain:(float)v
{
}

@end
