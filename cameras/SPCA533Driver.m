//
//  SPCA533Driver.m
//  macam
//
//  Created by Harald on 11/14/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "SPCA533Driver.h"


@implementation SPCA533Driver

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



//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    //  [LUT setDefaultOrientation:Rotate180];  // if necessary
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    //  spca50x->desc = ???;
    spca50x->cameratype = JPEG;
    spca50x->bridge = BRIDGE_SPCA533;
    spca50x->sensor = SENSOR_INTERNAL;
    
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
        /*
         [NSDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithUnsignedShort:PRODUCT_DSC_13M_SMART], @"idProduct",
             [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
             @"Genius DSC 1.3M Smart", @"name", NULL], 
         */
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xA051], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x3078], @"idVendor",
            @"VcamNow 2.0", @"name", NULL], 
        
        // Aiptek Pocket DV 3100 0x08ca:0x0106
        
        NULL];
}

@end

