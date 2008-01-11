//
//  OV534Driver.m
//  macam
//
//  Created by Harald on 1/10/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import "OV534Driver.h"


@implementation OV534Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x3002], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06f8], @"idVendor",
            @"Hercules Blog Webcam", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x3003], @"idProduct", 
            [NSNumber numberWithUnsignedShort:0x06f8], @"idVendor", 
            @"Hercules Dualpix HD Webcam", @"name", NULL],
        
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
    
    driverType = bulkDriver;
    
//    hardwareBrightness = YES;
//    hardwareContrast = YES;
//    hardwareHue = YES;
//    hardwareSaturation = YES;
//    hardwareFlicker = YES;
    
    decodingSkipBytes = 2;
    
    compressionType = quicktimeImage;
    quicktimeCodec = kComponentVideoUnsigned;  // kYUVSPixelFormat
    
	return self;
}

@end


@implementation OV538Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2000], @"idProduct", 
            [NSNumber numberWithUnsignedShort:0x1415], @"idVendor", 
            @"Sony HD Eye for PS3 (SLEH 00201)", @"name", NULL],
        
        NULL];
}

@end
