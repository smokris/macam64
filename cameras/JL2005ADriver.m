//
//  JL2005ADriver.m
//  macam
//
//  Created by Harald on 3/1/07.
//  Copyright 2007 hxr. All rights reserved.
//


#import "JL2005ADriver.h"

#include "USB_VendorProductIDs.h"


@implementation JL2005ADriver

//
// Specify which Vendor and Product IDs this driver will work for
// Add these to the USB_VendorProductIDs.h file
//
+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_JL2005A_TOY_CAMERA], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_JEILIN], @"idVendor",
            @"Jeilin Toy Camera (JL2005A)", @"name", NULL], 
        
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
    
    /* this might be useful
        bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    or
        
        LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    */
    
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
        case ResolutionCIF:
            if (rate > 18) 
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
        *rate = 5;
    
	return ResolutionCIF;
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
    return [self usbSetAltInterfaceTo:8 testPipe:[self getGrabbingPipe]];
}

//
// This is an example that will have to be tailored to the specific camera or chip
// Scan the frame and return the results
//
IsocFrameResult  jl2005aIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength)
{
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 1) 
        return invalidFrame;
    
    if (buffer[0] == 0xff) 
    {
        *dataStart = 10; // Skip a 10 byte header for example
        *dataLength = frameLength - 10;
        
        return newChunkFrame;
    }
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = jl2005aIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError error = CameraErrorOK;
    
    //  Probably will have a lot of statements kind of like this:
    //	[self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x0041 buf:NULL len:0];
    
    return error == CameraErrorOK;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    //  More of the same
    //  [self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x40 buf:NULL len:0];
    
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
