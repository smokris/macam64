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

//
// Scan the frame and return the results
//
IsocFrameResult  spca536IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength, 
                                         GenericFrameInfo * frameInfo)
{
    int frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    
    if (frameLength < 1) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
//        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [129] = 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
//           buffer[0], frameLength, buffer[1], buffer[129], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (buffer[0] == SPCA50X_SEQUENCE_DROP) // start a new image
    {
#if REALLY_VERBOSE
//        printf("New image start!\n");
#endif
        *dataStart = 4; //  SPCA536_OFFSET_DATA;
        *dataLength = frameLength - *dataStart;
        
        return newChunkFrame;
    }
    
    *dataStart = 2;
    *dataLength = frameLength - *dataStart;
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = spca536IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
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
