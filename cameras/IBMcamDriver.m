//
//  IBMcamDriver.m
//  macam
//
//  Created by Harald on 11/12/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "IBMcamDriver.h"

#import "MyCameraCentral.h"

#include "Resolvers.h"
#include "USB_VendorProductIDs.h"


@implementation IBMcamDriver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_KSX_MODELS], @"idProduct", 
            [NSNumber numberWithUnsignedShort:VENDOR_VEO], @"idVendor", 
            @"IBM/Xirlink C-it webcam", @"name", NULL], 
        
        NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral:(id)c
{
    short index;
    UInt16 version;
    MyCameraCentral * cent = c;
    
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    // initialize any variables here
    
    // look at USB revision
    
    index = [cent indexOfDriverClass:[self class]];
    
    if (index < 0) 
    {
        // Second time through, call from subclass, everything OK
        return self;
    }
    
    version = [cent versionOfCameraWithIndex:index];
    
#if VERBOSE
    NSLog(@"OK, we've got an IBM camera with release %04x (index=%d)", version, index);
#endif
    
    if (version == 0x0002) 
        return [[IBMcamModel1Driver alloc] initWithCentral:c];
    
    if (version == 0x030A) 
        return [[IBMcamModel2Driver alloc] initWithCentral:c];
    
    if (version == 0x0301) 
        return [[IBMcamModel3Driver alloc] initWithCentral:c];
    
    NSLog(@"This is an unknown model! (%04x) It is unlikely to work.\n", version);
    
	return self;
}


@end


@implementation IBMcamModel1Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // none! instantiated from superclass
        
        NULL];
}


@end


@implementation IBMcamModel2Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_STINGRAY_C], @"idProduct", 
            [NSNumber numberWithUnsignedShort:VENDOR_VEO], @"idVendor", 
            @"Veo Stingray (0x800c)", @"name", NULL], 
        
        NULL];
}


@end


@implementation IBMcamModel3Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // none! instantiated from superclass
        
        NULL];
}


@end


@implementation IBMcamModel4Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_STINGRAY_C], @"idProduct", 
            [NSNumber numberWithUnsignedShort:VENDOR_VEO], @"idVendor", 
            @"IBM NetCamera (0x8002)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_STINGRAY_C], @"idProduct", 
            [NSNumber numberWithUnsignedShort:VENDOR_VEO], @"idVendor", 
            @"Veo Stingray (0x800d)", @"name", NULL], 
        
        NULL];
}


@end

