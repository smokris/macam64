//
//  SPCA505Driver.m
//  macam
//
//  Created by Harald on 11/14/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "SPCA505Driver.h"

#include "USB_VendorProductIDs.h"


enum
{
    Nxultra = 1,
};


@implementation SPCA505Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0430], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0733], @"idVendor",
            @"Intel PC Camera Pro", @"name", NULL], 
        
        NULL];
}


#include "spca505_init.h"


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    cameraOperation = &fspca505;

    spca50x->bridge = BRIDGE_SPCA505;
    spca50x->sensor = SENSOR_INTERNAL;;
    spca50x->cameratype = YYUV;

    compressionType = gspcaCompression;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    
    spca50x->desc = 0;
    
	return self;
}

@end


@implementation SPCA505BDriver 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x401d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Webcam NX ULTRA", @"name", NULL], 
        
        NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Nxultra;
    
	return self;
}

@end

