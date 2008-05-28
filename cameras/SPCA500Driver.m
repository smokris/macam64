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
    LogitechClickSmart310 = 1,
    
    CreativePCCam300, // same
        IntelPocketPCCamera,
    
    KodakEZ200,
    
    BenqDC1016, // all same
        DLinkDSC350,
        AiptekPocketDV,
        Gsmartmini,
        MustekGsmart300,
        PalmPixDC85,
        Optimedia,
        ToptroIndus,
        AgfaCl20,
    
    LogitechTraveler, // same
        LogitechClickSmart510,
};


@implementation SPCA500Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0103], @"idProduct",  // SPCA500C
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek Pocket DV", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x300c], @"idProduct",  // SPCA500C
            [NSNumber numberWithUnsignedShort:0x04a5], @"idVendor",
            @"BenQ DC 1016", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc200], @"idProduct",  // SPCA500
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Mustek Gsmart 300", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x7333], @"idProduct",  // SPCA500A
            [NSNumber numberWithUnsignedShort:0x04fc], @"idVendor",
            @"Palmpix DC-85", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc220], @"idProduct",  // SPCA500
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Mustek Gsmart mini", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0003], @"idProduct",  // SPCA500A
            [NSNumber numberWithUnsignedShort:0x084d], @"idVendor",
            @"D-Link DSC 350 or Minton S-Cam F5", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0800], @"idProduct",  // SPCA500A
            [NSNumber numberWithUnsignedShort:0x06be], @"idVendor",
            @"Optimedia Techno AME (?)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x012c], @"idProduct",  // SPCA500A
            [NSNumber numberWithUnsignedShort:0x2899], @"idVendor",
            @"Toptro Industrial (?)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0404], @"idProduct",  // SPCA500A
            [NSNumber numberWithUnsignedShort:0x06bd], @"idVendor",
            @"Agfa ePhoto CL20", @"name", NULL], 
        
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
    
    compressionType = gspcaCompression;
    
    spca50x->desc = BenqDC1016;
    
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
        
#if REALLY_VERBOSE
        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [129] = 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
           buffer[0], frameLength, buffer[1], buffer[129], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (buffer[0] == SPCA50X_SEQUENCE_DROP) 
    {
        if (buffer[1] != 0x01) 
        {
            *dataLength = 0;
            return invalidFrame;
        }
        
#if REALLY_VERBOSE
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


@implementation SPCA500DriverIntel1 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0630], @"idProduct",  // SPCA500
            [NSNumber numberWithUnsignedShort:0x8086], @"idVendor",
            @"Intel Pocket PC Camera", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x400a], @"idProduct",  // SPCA500A
            [NSNumber numberWithUnsignedShort:0x041e], @"idVendor",
            @"Creative PC Cam 300", @"name", NULL], 
        
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
    
    spca50x->desc = CreativePCCam300;
    
	return self;
}

@end


@implementation SPCA500DriverLogitech1 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0890], @"idProduct",  // SPCA500A
            [NSNumber numberWithUnsignedShort:0x046d], @"idVendor",
            @"Logitech Traveler", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0901], @"idProduct",  // SPCA500A
            [NSNumber numberWithUnsignedShort:0x046d], @"idVendor",
            @"Logitech ClickSmart 510", @"name", NULL], 
        
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
    
    spca50x->desc = LogitechTraveler;
    
	return self;
}

@end


@implementation SPCA500DriverClickSmart310 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0900], @"idProduct",  // SPCA551A
            [NSNumber numberWithUnsignedShort:0x046d], @"idVendor",
            @"Logitech ClickSmart 310", @"name", NULL], 
        
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
    
    spca50x->desc = LogitechClickSmart310;
    spca50x->sensor = SENSOR_HDCS1020;
    
	return self;
}

@end


@implementation SPCA500DriverKodakEZ200 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_EZ200], @"idProduct",  // SPCA500A
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

