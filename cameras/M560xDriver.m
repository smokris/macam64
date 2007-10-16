//
//  M560xDriver.m
//  macam
//
//  Created by Harald on 3/2/07.
//  Copyright 2007 hxr. All rights reserved.
//


#import "M560xDriver.h"

#include "USB_VendorProductIDs.h"


@implementation M560xDriver

//
// Specify which Vendor and Product IDs this driver will work for
// Add these to the USB_VendorProductIDs.h file
//
+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        

        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x4055], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Live! Cam Video IM Pro", @"name", NULL], 
        
        // More entries can easily be added for more cameras
        
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
    
    bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    // Allocate memory
    // Initialize variable and other structures
    
	return self;
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionVGA:
            if (rate > 30) 
                return NO;
            return YES;
            break;
            
        default: 
            return NO;
    }
}

//
// Return the default resolution and rate
//
- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 15;
    
	return ResolutionVGA;
}

//
// Returns the pipe used for grabbing
//
- (UInt8) getGrabbingPipe
{
    return 1;
}

//
// Put in the alt-interface with the highest bandwidth (instead of 8)
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:3];
}

//
// This is an example that will have to be tailored to the specific camera or chip
// Scan the frame and return the results
//
IsocFrameResult  m560xIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                       UInt32 * dataStart, UInt32 * dataLength, 
                                       UInt32 * tailStart, UInt32 * tailLength, 
                                       GenericFrameInfo * frameInfo)
{
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 2) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
        printf("Invalid chunk!\n");
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
#endif
    
    for (position = 0; position < frameLength - 2; position++) 
    {
        if ((buffer[position+0] == 0xFF) && 
            (buffer[position+1] == 0xFF)) 
        {
#if REALLY_VERBOSE
            printf("New chunk! (position = %d, then 0x%02x 0x%02x 0x%02x)\n", position, buffer[position+2], buffer[position+3], buffer[position+4]);
#endif
            if (position > 0) 
            {
                *tailStart = 0;
                *tailLength = position;
            }
            
            *dataStart = position;
            *dataLength = frameLength - position;
            
            return newChunkFrame;
        }
    }
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = m560xIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError error = CameraErrorOK;
    
    // started when the alt interface was set
    
    return error == CameraErrorOK;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]]; // Must set alt interface to normal
}

//
// This is the method that takes the raw chunk data and turns it into an image
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
    BOOL ok = YES;
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
	// Decode the bytes
    
    //  Much decoding to be done here
    
    // Turn the Bayer data into an RGB image
    
    [bayerConverter setSourceFormat:3]; // This is probably different
    [bayerConverter setSourceWidth:rawWidth height:rawHeight];
    [bayerConverter setDestinationWidth:rawWidth height:rawHeight];
    [bayerConverter convertFromSrc:buffer->buffer
                            toDest:nextImageBuffer
                       srcRowBytes:rawWidth
                       dstRowBytes:nextImageBufferRowBytes
                            dstBPP:nextImageBufferBPP
                              flip:hFlip
                         rotate180:NO]; // This might be different too
    
    return ok;
}

@end
