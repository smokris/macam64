//
//  SPCA506Driver.m
//  macam
//
//  Created by Harald on 11/14/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "SPCA506Driver.h"


@implementation SPCA506Driver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0430], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0733], @"idVendor",
            @"Usb Grabber PV321c", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x043b], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0734], @"idVendor",
            @"3DeMON USB Capture", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x8988], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x99FA], @"idVendor",
            @"Grandtec V.cap", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xa190], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06e1], @"idVendor",
            @"ADS Instant VCD", @"name", NULL], 
        
        NULL];
}


#define VIDEO_MODE_PAL                0
#define VIDEO_MODE_NTSC               1
#define VIDEO_MODE_SECAM              2
#define VIDEO_MODE_AUTO               3


#include "spca506.h"

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    cameraOperation = &fspca506;

    spca50x->bridge = BRIDGE_SPCA506;
    spca50x->sensor = SENSOR_SAA7113;
    spca50x->cameratype = YYUV;
    
    compressionType = gspcaCompression;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SPCA506ADriver 

@end

