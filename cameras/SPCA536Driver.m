//
//  SPCA536Driver.m
//  macam
//
//  Created by Harald on 11/14/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "SPCA536Driver.h"

#include "USB_VendorProductIDs.h"


@implementation SPCA536Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->bridge = BRIDGE_SPCA536;
    spca50x->sensor = SENSOR_INTERNAL;
    
	return self;
}

@end


@implementation SPCA536ADriver 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x3261], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_VIEWQUEST], @"idVendor",
            @"Concord 3045", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x3281], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_VIEWQUEST], @"idVendor",
            @"Mercury CyberPix S550V", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc360], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Mustek DV 4000 Mpeg4", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc211], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Kowa BS-888e MicroCamera", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0303], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0d64], @"idVendor",
            @"Sunplus FashionCam DXG 305v", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x5360], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x04fc], @"idVendor",
            @"Sunplus Generic SPCA536A", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2024], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek DV 3500 Mpeg4", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2042], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek Pocket DV 5100", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2040], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek Pocket DV 4100M", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2060], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek Pocket DV 5300", @"name", NULL], 
        
        NULL];
}

@end
