//
//  KworldTV300UDriver.m
//
//  macam - webcam app and QuickTime driver component
//  KworldTV300UDriver - driver for the KWORLD TV-PVR 300U
//
//  Created by HXR on 4/4/06.
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net). 
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA
//


#import "KworldTV300UDriver.h"

#include "unistd.h"
#include "USB_VendorProductIDs.h"


@implementation KworldTV300UDriver
//
// Specify which Vendor and Product IDs this driver will work for
// Add these to the USB_VendorProductIDs.h file
//
+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xe300], @"idProduct", // KWORLD TV-300U
            [NSNumber numberWithUnsignedShort:0xeb1a], @"idVendor", // Empia Technology, Inc
            @"KWORLD PVR-TV 300U", @"name", NULL], 
        
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
        *rate = 20;
    
	return ResolutionVGA;
}

// Return the size needed for an isochronous frame
// Depends on whether it is high-speed device on a high-speed hub
- (int) usbGetIsocFrameSize
{
    return 3072;
}

//
// Returns the pipe used for grabbing
//
- (UInt8) getGrabbingPipe
{
    return 2;
}

//
// Put in the alt-interface with the highest bandwidth (instead of 8)
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbSetAltInterfaceTo:7 testPipe:[self getGrabbingPipe]];
}

//
// This is an example that will have to be tailored to the specific camera or chip
// Scan the frame and return the results
//
IsocFrameResult  empiaIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                       UInt32 * dataStart, UInt32 * dataLength, 
                                       UInt32 * tailStart, UInt32 * tailLength, 
                                       GenericFrameInfo * frameInfo)
{
//  int position;
    int frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
    
    if (frameLength < 1) 
        return invalidFrame;
    
    if (buffer[0] == 0) 
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
    grabContext.isocFrameScanner = empiaIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


- (int) em28xxReadRequest: (UInt8) rqst  withRegister: (UInt16) rgstr
{
    UInt8 value;
    
    if (![self usbReadCmdWithBRequest:rqst wValue:0x0000 wIndex:rgstr buf:&value len:1]) 
        return -1;
    
    return value;
}


- (int) em28xxWriteRequest: (UInt8) rqst  withRegister: (UInt16) rgstr  andBuffer: (unsigned char *) buffer  ofLength: (int) length
{
    BOOL ok = [self usbWriteCmdWithBRequest:rqst wValue:0x0000 wIndex:rgstr buf:buffer len:length];
    
    usleep(5000); // 5 ms
    
    return (ok) ? 0 : -1;
}


- (int) em28xxReadRegister: (UInt16) rgstr
{
    return [self em28xxReadRequest:0x00 withRegister:rgstr];  // USB_REQ_GET_STATUS = 0x00
}


- (int) em28xxWriteRegisters: (UInt16) rgstr  withBuffer: (unsigned char *) buffer  ofLength: (int) length
{
    return [self em28xxWriteRequest:0x00 withRegister:rgstr andBuffer:buffer ofLength:length];
}


- (int) em28xxWriteRegister: (UInt16) rgstr  withValue: (UInt8) value  andBitmask: (UInt8) bitmask
{
    int oldValue = [self em28xxReadRegister:rgstr];
    
    if (oldValue < 0) 
        return oldValue; 
    
    UInt8 newValue = (((UInt8) oldValue) & ~bitmask) | (value & bitmask);
    
    return [self em28xxWriteRegisters:rgstr withBuffer:&newValue ofLength:1];
}


//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError error = CameraErrorOK;
    
    if ([self em28xxWriteRegister:0x0c withValue:0x10 andBitmask:0x10] < 0)  // USBSUSP_REG = 0x0c
        error = CameraErrorUSBProblem;
    
    if ([self em28xxWriteRegisters:0x12 withBuffer:(unsigned char *) "\x67" ofLength:1] < 0)  // VINENABLE_REG = 0x12
        error = CameraErrorUSBProblem;
    
    return error == CameraErrorOK;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    [self em28xxWriteRegister:0x0c withValue:0x00 andBitmask:0x10];
    
    [self em28xxWriteRegisters:0x12 withBuffer:(unsigned char *) "\x27" ofLength:1];
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]];
}

//
// This is the method that takes the raw chunk data and turns it into an image
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
    printf("Need to decode a buffer with %ld bytes.\n", buffer->numBytes);
    
//	short rawWidth  = [self width];
//	short rawHeight = [self height];
    
	// Decode the bytes
    
    //  Much decoding to be done here
    
    // Turn the Bayer data into an RGB image
/*    
    [bayerConverter setSourceFormat:6]; // This is probably different
    [bayerConverter setSourceWidth:rawWidth height:rawHeight];
    [bayerConverter setDestinationWidth:rawWidth height:rawHeight];
    [bayerConverter convertFromSrc:decodingBuffer
                            toDest:nextImageBuffer
                       srcRowBytes:rawWidth
                       dstRowBytes:nextImageBufferRowBytes
                            dstBPP:nextImageBufferBPP
                              flip:hFlip
                         rotate180:NO]; // This might be different too
*/
    return YES;
}

@end
