//
//  OmniVisionSensor.h
//  macam
//
//  Created by Harald on 11/2/07.
//  Copyright 2007 hxr. All rights reserved.
//


#define OMNIVISION_MANUFACTURER_ID_MSB_REG  0x1c
#define OMNIVISION_MANUFACTURER_ID_LSB_REG  0x1d

#define OMNIVISION_MANUFACTURER_ID_MSB_VALUE  0x7f
#define OMNIVISION_MANUFACTURER_ID_LSB_VALUE  0xa2


#import <Sensor.h>


@interface OmniVisionSensor : Sensor 
{

}

@end
