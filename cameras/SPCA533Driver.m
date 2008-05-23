//
//  SPCA533Driver.m
//  macam
//
//  Created by Harald on 11/14/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "SPCA533Driver.h"

#include "USB_VendorProductIDs.h"


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
            @"Generic SPCA533 (Securesight VL1 DVR)", @"name", NULL], 
        
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0104], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek PocketDVII  1.3 MPixels", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0106], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek PocketDV 3100", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc232], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Mustek MDC 3500", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc630], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Mustek MDC 4000", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2020], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek Slim 3000F", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2022], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek Slim 3200", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2028], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek PocketCam 4M", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x3008], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x04a5], @"idVendor",
            @"BenQ DC 1500", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x300a], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x04a5], @"idVendor",
            @"BenQ DC 35 or 3410", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2010], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek PocketCam 3M", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc230], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Mustek Digicam 330K", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc530], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Mustek Gsmart LCD 3", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc440], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Mustek DV 3000", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc540], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Mustek Gsmart D30 (SPCA533)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xc650], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"Mustek MDC5500Z", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0031], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06d6], @"idVendor",
            @"Trust 610 LCD PowerCam Zoom", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PDC_3070], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_POLAROID], @"idVendor",
            @"Polaroid PDC 3070", @"name", NULL], 
        
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
    
    spca50x->bridge = BRIDGE_SPCA533;
    spca50x->sensor = SENSOR_INTERNAL;
    
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
        
#if REALLY_VERBOSE
//        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [129] = 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
//           buffer[0], frameLength, buffer[1], buffer[129], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (buffer[0] == SPCA50X_SEQUENCE_DROP) // possibly start a new image
    {
        if (buffer[1] != 0x01) 
            return invalidFrame;
        
#if REALLY_VERBOSE
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
        
        NULL];
}

@end


@implementation SPCA533ADriverMegapixV4 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1513], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x052b], @"idVendor",
            @"Megapix V4", @"name", NULL], 
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = MegapixV4;
    
	return self;
}

@end


@implementation SPCA533ADriverClickSmart820 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CLICKSMART_820_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech Clicksmart 820 (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CLICKSMART_820_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech Clicksmart 820 (B)", @"name", NULL], 
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = LogitechClickSmart820;
    
	return self;
}

@end
