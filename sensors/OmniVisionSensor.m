//
//  OmniVisionSensor.m
//  macam
//
//  Created by Harald on 11/2/07.
//  Copyright 2007 HXR. All rights reserved.
//

#import "OmniVisionSensor.h"
#import "OV76xx.h"
#import "OV7F7F.h"


@implementation OmniVisionSensor


+ (id) findSensor:(MyCameraDriver*)driver
{
    id sensor = NULL;
    
    // check manufacturer?
    
    if (sensor == NULL) 
        sensor = [OV76xx findSensor:driver];
    
    if (sensor == NULL) 
        sensor = [OV7F7F findSensor:driver];
    
    return sensor;
}


@end
