//
//  SPCA504Driver.m
//  macam
//
//  Created by Harald on 11/14/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "SPCA504Driver.h"

#include "USB_VendorProductIDs.h"


enum 
{
    LogitechClickSmart420 = 1,
    AiptekMiniPenCam13,
    MegapixV4, 
    LogitechClickSmart820,
    
};


@implementation SPCA504ADriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_MINI_PENCAM13_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SUNPLUS], @"idVendor",
            @"Aiptek Mini PenCam 1.3 (or similar 504A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GSMART_MINI2], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MUSTEK], @"idVendor",
            @"Mustek GSmart Mini 2", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GSMART_MINI3], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MUSTEK], @"idVendor",
            @"Mustek GSmart Mini 3", @"name", NULL], 
        
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
    
    //  [LUT setDefaultOrientation:Rotate180];  // if necessary
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    cameraOperation = &fsp5xxfw2;
    
    spca50x->desc = AiptekMiniPenCam13;
    
    spca50x->cameratype = JPEG;
    spca50x->bridge = BRIDGE_SPCA504;
    spca50x->sensor = SENSOR_INTERNAL;
    
    compressionType = gspcaCompression;
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  spca504AIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
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
        return invalidFrame;
        
    if (buffer[0] == 0xFE) // start a new image
    {
#ifdef REALLY_VERBOSE
        printf("New image start!\n");
#endif
        *dataStart = SPCA50X_OFFSET_DATA;
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
    grabContext.isocFrameScanner = spca504AIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

@end


@implementation SPCA504BDriver 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_MINI_PENCAM13_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SUNPLUS], @"idVendor",
            @"Aiptek Mini PenCam 1.3 (or similar 504B)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GENERIC_SPCA504B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SUNPLUS], @"idVendor",
            @"Generic camera with SPCA504B", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_MINI_PENCAM_2M], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_AIPTEK], @"idVendor",
            @"Aiptek Mini PenCam 2M", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_POCKETCAM_3M], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_AIPTEK], @"idVendor",
            @"Aiptek PocketCam 3M", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_POCKETCAM_2M], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_AIPTEK], @"idVendor",
            @"Aiptek PocketCam 2M", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PENCAM_SD_2M], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_AIPTEK], @"idVendor",
            @"Aiptek PenCam SD 2M", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_DC_1300], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_BENQ], @"idVendor",
            @"Benq DC 1300", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PC_CAM_750], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative PC Cam 750", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_ENIGMA_1_3], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_DIGITAL_DREAM], @"idVendor",
            @"Digital Dream Enigma 1.3", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GC_A50], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_JVC], @"idVendor",
            @"JVC GC-A50", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CLICKSMART_420], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech Clicksmart 420", @"name", NULL], 
        
        // more
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PHILIPS_K_007], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_AIPTEK], @"idVendor",
            @"Philips K 007", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PDC_2030], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_POLAROID], @"idVendor",
            @"Polaroid PDC 2030", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_ION_80], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_POLAROID], @"idVendor",
            @"Polaroid Ion 80", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_DMVC_1300K], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS], @"idVendor",
            @"Philips DMVC 1300K", @"name", NULL], 
        
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
    
    spca50x->desc = LogitechClickSmart420;
    
    spca50x->bridge = BRIDGE_SPCA504B;
    
	return self;
}

@end


@implementation SPCA504B_P3Driver 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_DSC_13M_SMART], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
            @"Genius DSC 1.3M Smart", @"name", NULL], 
        
        NULL];
}

// same as SPCA504BDriver

@end


@implementation SPCA504CDriver 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PC_CAM_600], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative PC Cam 600", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PC_CAM_350], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative PC Cam 350", @"name", NULL], 
        
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
    
    //  [LUT setDefaultOrientation:Rotate180];  // if necessary
    
    //  spca50x->desc = ???;
    spca50x->bridge = BRIDGE_SPCA504C;
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  spca504CIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
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
        return invalidFrame;
    
    if (buffer[0] == SPCA504_PCCAM600_OFFSET_DATA) 
        return invalidFrame;
    
    if (buffer[0] == 0xFE) // start a new image
    {
        *dataStart = SPCA50X_OFFSET_DATA;
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
    grabContext.isocFrameScanner = spca504CIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

@end
