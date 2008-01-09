//
//  Controller.m
//  macam
//
//  Created by Harald on 10/29/07.
//  Copyright 2007 hxr. All rights reserved.
//


#import "ControllerInterface.h"
#import "Sensor.h"


@implementation MyCameraDriver (ControllerInterface)

static id defaultSensor = NULL;

- (id) getSensor
{
    if (defaultSensor == NULL) 
        defaultSensor = [[Sensor alloc] init];
    
    return defaultSensor;
}

- (int) setupSensorCommunication:(Class)sensor
{
    NSLog(@"MyCameraDriver(ControllerInterface):setupSensorCommunication: not implemented");
    return -1;
}

- (int) getSensorRegister:(UInt8)reg
{
    NSLog(@"MyCameraDriver(ControllerInterface):getSensorRegister: not implemented");
    return -1;
}

- (int) setSensorRegister:(UInt8)reg toValue:(UInt8)val
{
    NSLog(@"MyCameraDriver(ControllerInterface):setSensorRegister:toValue: not implemented");
    return -1;
}

@end
