//
//  SPCA500Driver.m
//  macam
//
//  Created by Harald on 11/14/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "SPCA500Driver.h"

#include "USB_VendorProductIDs.h"


enum 
{
    LogitechClickSmart310,
    
    CreativePCCam300,
    IntelPocketPCCamera,
    
    KodakEZ200,
    
    BenqDC1016,
    DLinkDSC350,
    AiptekPocketDV,
    Gsmartmini,
    MustekGsmart300,
    PalmPixDC85,
    Optimedia,
    ToptroIndus,
    AgfaCl20,
    
    LogitechTraveler,
    LogitechClickSmart510,
};


@implementation SPCA500Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        /*
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_DSC_13M_SMART], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
            @"Genius DSC 1.3M Smart", @"name", NULL], 
        */
        NULL];
}


#include "jpeg_qtables.h"
#include "spca500_init.h"


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
    unsigned char (* dummy)[2][64];
    
    dummy = &qtable_spca504_default;
    
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    cameraOperation = &fspca500;
    
    spca50x->bridge = BRIDGE_SPCA500;
    spca50x->sensor = SENSOR_INTERNAL;;
    spca50x->cameratype = JPEG;
    
    spca50x->desc = BenqDC1016;
    
    compressionType = gspcaCompression;
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  spca500IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
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
        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
#ifdef REALLY_VERBOSE
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [129] = 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
           buffer[0], frameLength, buffer[1], buffer[129], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (buffer[0] == SPCA50X_SEQUENCE_DROP) 
    {
        if (buffer[1] != 0x01) 
            return invalidFrame;
    
        // start a new image
#ifdef REALLY_VERBOSE
        printf("New image start!\n");
#endif
        *dataStart = SPCA500_OFFSET_DATA;
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
    grabContext.isocFrameScanner = spca500IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

@end


@implementation SPCA500ADriver 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_EZ200], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_KODAK], @"idVendor",
            @"Kodak EZ200 (gspca)", @"name", NULL], 
        
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
    
    spca50x->desc = KodakEZ200;
    
	return self;
}

@end


@implementation SPCA500CDriver 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        NULL];
}

@end

