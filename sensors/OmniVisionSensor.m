//
//  OmniVisionSensor.m
//  macam
//
//  Created by Harald on 11/2/07.
//  Copyright 2007 HXR. All rights reserved.
//

#import "OmniVisionSensor.h"
#import "OV76xx.h"


@implementation OmniVisionSensor


+ (id) findSensor:(MyCameraDriver*)driver
{
    id sensor = NULL;
    
    // check manufacturer?
    
    if (sensor == NULL) 
        sensor = [OV76xx findSensor:driver];
    
    return sensor;
}


@end
