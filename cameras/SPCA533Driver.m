//
//  SPCA533Driver.m
//  macam
//
//  Created by Harald on 11/14/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "SPCA533Driver.h"


enum 
{
    LogitechClickSmart420,
    AiptekMiniPenCam13,
    MegapixV4, 
    LogitechClickSmart820,
    
};


@implementation SPCA533Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1314], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0733], @"idVendor",
            @"Mercury Peripherals Inc.", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2211], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0733], @"idVendor",
            @"Jenoptik DC 21 LCD", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2221], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0733], @"idVendor",
            @"Mercury Digital Pro 3.1Mp", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1311], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0733], @"idVendor",
            @"Digital Dream Epsilon 1.3", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x5330], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x04fc], @"idVendor",
            @"Securesight VL1 Digital Video Recorder", @"name", NULL], 
        
        NULL];
}


#include "jpeg_qtables.h"
#include "sp5xxfw2.h"


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
    unsigned char (* dummy)[2][64];
    
    dummy = &qtable_kodak_ez200;
    dummy = &qtable_pocketdv;
    
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    cameraOperation = &fsp5xxfw2;

    spca50x->bridge = BRIDGE_SPCA533;
    spca50x->sensor = SENSOR_INTERNAL;
    spca50x->cameratype = JPEG;
    
    compressionType = gspcaCompression;
    
	return self;
}


//
// Scan the frame and return the results
//
IsocFrameResult  spca533IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
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
        
#ifdef REALLY_VERBOSE
//        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
#ifdef REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [129] = 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
//           buffer[0], frameLength, buffer[1], buffer[129], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (buffer[0] == SPCA50X_SEQUENCE_DROP) // possibly start a new image
    {
        if (buffer[1] != 0x01) 
            return invalidFrame;
        
#ifdef REALLY_VERBOSE
//        printf("New image start!\n");
#endif
        *dataStart = 16; //  SPCA533_OFFSET_DATA;
        *dataLength = frameLength - *dataStart;
        
        return newChunkFrame;
    }
    
    *dataStart = 1;
    *dataLength = frameLength - *dataStart;
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = spca533IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


@end


@implementation SPCA533ADriver 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xA051], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x3078], @"idVendor",
            @"VcamNow 2.0", @"name", NULL], 
        
        // Aiptek Pocket DV 3100 0x08ca:0x0106
        
        NULL];
}

@end

