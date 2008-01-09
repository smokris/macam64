//
//  OV76xx.h
//  macam
//
//  Created by Harald on 11/2/07.
//  Copyright 2007 hxr. All rights reserved.
//


#import <OmniVisionSensor.h>


#define OV76xx_FAMILY_I2C_ADDRESS       0x42


#define OMNIVISION_PRODUCT_ID_MSB_REG   0x0a
#define OMNIVISION_PRODUCT_ID_LSB_REG   0x0b

#define OMNIVISION_PRODUCT_ID_MSB_VALUE 0x76

#define OMNIVISION_OV7630_ID_LSB_VALUE  0x30
#define OMNIVISION_OV7640_ID_LSB_VALUE  0x48    // According to OV7640 Datasheet
#define OMNIVISION_OV7648_ID_LSB_VALUE  0xFF
#define OMNIVISION_OV7660_ID_LSB_VALUE  0x60    // According to OV7660 Datasheet

#define OMNIVISION_OV7670_ID_LSB_VALUE  0x63


@interface OV76xx : OmniVisionSensor 
{}

- (int) configure;

@end
