//
//  PicoDriver.m
//
//  macam - webcam app and QuickTime driver component
//
//  Created by HXR on 1/4/07.
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

// need to implement some more controls etc

#import "PicoDriver.h"

#include "Resolvers.h"
#include "MiscTools.h"
#include "USB_VendorProductIDs.h"


@interface PicoDriver (Private)

- (void) handleFullChunkWithReadBytes: (UInt32) readSize  error: (IOReturn) err;
- (void) fillNextChunk;

@end



@implementation PicoDriver

//
// Specify which Vendor and Product IDs this driver will work for
// Add these to the USB_VendorProductIDs.h file
//
+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PICO_IMAGE_WEBCAM], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PICO_INSTRUMENTS], @"idVendor",
            @"Pico Instruments iMage webcam", @"name", NULL], 
        
        // More entries can easily be added for more cameras
        
        NULL];
}

- (void) startupCamera
{
//    int rate = 1;
//    [self sendCommand:0xCA value:rate index:0x0];   // frame rate [1,15]
//    [self sendCommand:0xC9 value:0x0 index:0x01];   // frame size
    
    [super startupCamera];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    driverType = bulkDriver;
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    hardwareHue = YES;
    hardwareSaturation = YES;
    hardwareFlicker = YES;
    
    decodingSkipBytes = 2;
    
    compressionType = quicktimeImage;
    compressionType = proprietaryCompression;
    quicktimeCodec = kComponentVideoUnsigned;  // kYUVSPixelFormat
    /*
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    */
    framesize = 0;
    
	return self;
}

- (BOOL) separateControlAndStreamingInterfaces
{
    return YES;
}

- (BOOL) setControl: (UInt16) control  data: (UInt16) data
{
    UInt8 buffer[2];
    UInt16 length = (control != 0x0500) ? 2 : 1;
    
    buffer[0] = 0x00FF & (data);
    buffer[1] = 0x00FF & (data >> 8);
    
    return [self usbControlCmdWithBRequestType:USBmakebmRequestType(kUSBOut, kUSBClass, kUSBInterface) bRequest:0x01 wValue:control wIndex:0x0300 buf:buffer len:length];
}

// [self setControl:0x0200 data:value]; // brightness [1,100] = 50
// [self setControl:0x0300 data:value]; // contrast [1,100] = 50
// [self setControl:0x0600 data:value]; // hue [1,100] = 50
// [self setControl:0x0700 data:value]; // saturation [1,100] = 50
// [self setControl:0x0500 data:value]; // anti-flicker 0, 1, 2

- (BOOL) sendCommand: (UInt8) command  value: (UInt16) value  index: (UInt16) index
{
    UInt8 buffer[4];
    UInt16 length = 0;
    
    if (command == 0xC6)  // Video Start, send transfer size
    {
        UInt32 size = 2 * [self width] * [self height] + 2;
        buffer[0] = 0x00FF & (size >> 0);
        buffer[1] = 0x00FF & (size >> 8);
        buffer[2] = 0x00FF & (size >> 16);
        buffer[3] = 0x00FF & (size >> 24);
        length = 4;
        framesize = size;
    }
    
    if (command == 0xC9)  // Set Frame Size
    {
        UInt16 w = [self width];
        UInt16 h = [self height];
        buffer[2] = 0x00FF & (h);
        buffer[3] = 0x00FF & (h >> 8);
        buffer[0] = 0x00FF & (w);
        buffer[1] = 0x00FF & (w >> 8);
        length = 4;
    }
    
    return [self usbStreamCmdWithBRequestType:USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBInterface) bRequest:command wValue:value wIndex:index buf:buffer len:length];
}

// [self sendCommand:0xCC value:mirror index:0x0]; // mirror == 1 for mirroring, 0 otherwise
// [self sendCommand:0xC9 value:0x0 index:0x01];   // frame size
// [self sendCommand:0xCA value:rate index:0x0];   // frame rate [1,15]
// [self sendCommand:0xC6 value:0x0 index:0x0];    // start video
// [self sendCommand:0xC7 value:0x0 index:0x0];    // stop video

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    if (rate < 1 || 15 < rate) 
        return NO;
    
    switch (res) 
    {
        case ResolutionCIF:
        case ResolutionSIF:
        case ResolutionVGA:
            return YES;
            
        default: 
            return NO;
    }
}

//
// Set the resolution and frame rate. 
//
- (void) setResolution: (CameraResolution) res fps: (short) rate 
{
    if (![self supportsResolution:res fps:rate]) 
        return;
    
    [stateLock lock];
    if (!isGrabbing) 
    {
        resolution = res;
        fps = rate;
        
        [self sendCommand:0xC9 value:0x0 index:0x01];   // frame size
        [self sendCommand:0xCA value:rate index:0x0];   // frame rate [1,15]
    }
    [stateLock unlock];
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

- (void) setBrightness:(float) v 
{
    UInt16 value = 100 * v;
    if (value < 1) value = 1;
    if (value > 100) value = 100;
    [self setControl:0x0200 data:value]; // brightness [1,100] = 50
    [super setBrightness:v];
}

- (void) setContrast:(float) v
{
    UInt16 value = 100 * v;
    if (value < 1) value = 1;
    if (value > 100) value = 100;
    [self setControl:0x0300 data:value]; // contrast [1,100] = 50
    [super setContrast:v];
}

- (void) setHue:(float) v
{
    UInt16 value = 100 * v;
    if (value < 1) value = 1;
    if (value > 100) value = 100;
    [self setControl:0x0600 data:value]; // hue [1,100] = 50
    [super setHue:v];
}

- (void) setSaturation:(float) v
{
    UInt16 value = 100 * v;
    if (value < 1) value = 1;
    if (value > 100) value = 100;
    [self setControl:0x0700 data:value]; // saturation [1,100] = 50
    [super setSaturation:v];
}

- (void) setFlicker:(FlickerType) v
{
    UInt16 value = v;
    [self setControl:0x0500 data:value]; // anti-flicker 0, 1, 2
    [super setFlicker:v];
}

- (BOOL) canSetHFlip 
{
    return YES;
}

- (void) setHFlip:(BOOL)v 
{
    UInt16 mirror = (v) ? 0x01 : 0x00;
    [self sendCommand:0xCC value:mirror index:0x0]; // mirror == 1 for mirroring, 0 otherwise
    [super setHFlip:v];
}

- (void) setIsocFrameFunctions
{
    grabContext.chunkBufferLength = 2 * [self width] * [self height] + 2;
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    videoBulkReadsPending = 0;
    
    return [self sendCommand:0xC6 value:0x0 index:0x0];  // Start Video
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    [self sendCommand:0xC7 value:0x0 index:0x0];  // Stop Video
}

//
// This is the method that takes the raw chunk data and turns it into an image
//
- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
    long w, h;
    UInt8 * src = buffer->buffer + decodingSkipBytes;
    UInt8 * dst;
    
	short numColumns  = [self width];
	short numRows = [self height];
    
    for (h = 0; h < numRows; h++) 
    {
        dst = nextImageBuffer + h * nextImageBufferRowBytes;
        
        for (w = 0; w < numColumns; w++) 
        {
            dst[0] = src[0];
            dst[1] = src[0];
            dst[2] = src[0];
            
            dst += nextImageBufferBPP;
            src += 2;
        }
    }
}


static void handleFullChunk(void * refcon, IOReturn result, void * arg0)
{
    PicoDriver * driver = (PicoDriver *) refcon;
    UInt32 size = (UInt32) arg0;
    [driver handleFullChunkWithReadBytes:size error:result];
}

- (void) handleFullChunkWithReadBytes: (UInt32) readSize  error: (IOReturn) err  
{
    videoBulkReadsPending--;
    
#if VERBOSE
    printf("read a chunk with %ld bytes\n", readSize);
#endif
    
    if (err != kIOReturnSuccess) 
    {
        if (err != kIOReturnUnderrun && err != kIOReturnOverrun) 
        {
            CheckError(err, "handleFullChunkWithReadBytes");
            shouldBeGrabbing = NO;
            if (grabContext.contextError == CameraErrorOK) 
                grabContext.contextError = CameraErrorUSBProblem;
        }
    }
    
	if (shouldBeGrabbing && readSize > 0)  // No usb error and no empty chunk
    {
        int j;
        
        // Pass the complete chunk to the full list
        // Move full buffers one up
        
        [grabContext.chunkListLock lock];
        
        for (j = grabContext.numFullBuffers - 1; j >= 0; j--) 
            grabContext.fullChunkBuffers[j + 1] = grabContext.fullChunkBuffers[j];
        
        grabContext.fullChunkBuffers[0] = grabContext.fillingChunkBuffer; // Insert the filling one as newest
        grabContext.numFullBuffers++;				// We have inserted one buffer
                                                    // What if the list was already full? - That is not possible
        grabContext.fillingChunk = false;			// Now we're not filling (still in the lock to be sure no buffer is lost)
        
        [grabContext.chunkReadyLock unlock];		// Wake up the decoding thread
        
        [grabContext.chunkListLock unlock];        // Free access to the chunk buffers
    } 
    else  // Incorrect chunk -> ignore (but back to empty chunks)
    {
        // Put the chunk buffer back to the empty ones
        
        [grabContext.chunkListLock lock];   // Get access to the buffer lists
        
        grabContext.emptyChunkBuffers[grabContext.numEmptyBuffers] = grabContext.fillingChunkBuffer;
        grabContext.numEmptyBuffers++;
        grabContext.fillingChunk = false;			// Now we're not filling (still in the lock to be sure no buffer is lost)
        
        [grabContext.chunkListLock unlock]; // Release access to the buffer lists            
    }
    
//  [self doAutoResetLevel];
    
    if (shouldBeGrabbing) 
        [self fillNextChunk];
    
    // We can only stop if there are no read request left. 
    // If there is an error, no new one was issued.
    
    if (videoBulkReadsPending <= 0) 
        CFRunLoopStop(CFRunLoopGetCurrent());
}


- (void) fillNextChunk 
{
    IOReturn err;
    BOOL newReadPending = YES;
    
    // Get an empty chunk
    
    if (shouldBeGrabbing) 
    {
        [grabContext.chunkListLock lock];
        
        if (grabContext.numEmptyBuffers > 0) 			// There's an empty buffer to use
        {
            grabContext.numEmptyBuffers--;
            grabContext.fillingChunkBuffer = grabContext.emptyChunkBuffers[grabContext.numEmptyBuffers];
        } 
        else // No empty buffer: discard a full one (there are enough, both lists can't be empty)
        {
            grabContext.numFullBuffers--;             // Use the oldest one
            grabContext.fillingChunkBuffer = grabContext.fullChunkBuffers[grabContext.numFullBuffers];
        }
        grabContext.fillingChunk = true;				// Now we're filling (still in the lock to be sure no buffer is lost)
        grabContext.fillingChunkBuffer.numBytes = 0;	// Start with empty buffer
        [grabContext.chunkListLock unlock];			// Free access to the chunk buffers
    }
    
    // Start the bulk read
    
    if (shouldBeGrabbing) 
    {
        err = ((IOUSBInterfaceInterface182*) (*streamIntf))->ReadPipeAsyncTO(streamIntf, [self getGrabbingPipe],
                                                                    grabContext.fillingChunkBuffer.buffer,
                                                                    grabContext.chunkBufferLength, 1000, 2000,
                                                                    (IOAsyncCallback1) (handleFullChunk), self);  // Read one chunk
        
        if ((err == kIOUSBPipeStalled) && (streamIntf != NULL)) 
        {
            newReadPending = NO;
#if VERBOSE
            printf("pipe stalled, clearing\n");
#endif
            if (interfaceID >= 190) 
                err = ((IOUSBInterfaceInterface190*) *streamIntf)->ClearPipeStallBothEnds(streamIntf, [self getGrabbingPipe]);
            else 
                err = (*streamIntf)->ClearPipeStall(streamIntf, [self getGrabbingPipe]);
            
            if (err == kIOReturnSuccess) 
                [self fillNextChunk];
        }
        
        if (err) 
        {
            CheckError(err, "grabbingThread:ReadPipeAsync");
            grabContext.contextError = CameraErrorUSBProblem;
            shouldBeGrabbing = NO;
        } 
        else if (newReadPending) 
            videoBulkReadsPending++;
    }
}


- (void) grabbingThread: (id) data 
{
    NSAutoreleasePool * pool=[[NSAutoreleasePool alloc] init];
    CFRunLoopSourceRef cfSource;
    IOReturn error;
    BOOL ok = YES;
    long i;
    
    if (ok && driverType == isochronousDriver) 
        ChangeMyThreadPriority(10);	// We need to update the isoch read in time, so timing is important for us
    
    // Start the stream
    
    if (ok) 
        ok = [self startupGrabStream];
    
    // Get USB timing info
    
    if (ok && driverType == isochronousDriver) 
    {
        if (![self usbGetSoon:&(grabContext.initiatedUntil)]) 
        {
            ok = NO;
            shouldBeGrabbing = NO;
            if (grabContext.contextError == CameraErrorOK) 
                grabContext.contextError = CameraErrorUSBProblem; // Did the pipe stall perhaps?
        }
    }
    
    // Set up the asynchronous read calls
    
    if (ok) 
    {
        error = (*streamIntf)->CreateInterfaceAsyncEventSource(streamIntf, &cfSource); // Create an event source
        CheckError(error, "CreateInterfaceAsyncEventSource");
        if (error) 
        {
            ok = NO;
            shouldBeGrabbing = NO;
            if (grabContext.contextError == CameraErrorOK) 
                grabContext.contextError = CameraErrorNoMem;
        }
    }
    
    if (ok)
    {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode); // Add it to our run loop
        
        if (driverType == bulkDriver) 
            [self fillNextChunk];
        
        if (driverType == isochronousDriver) 
            for (i = 0; ok && (i < grabContext.numberOfTransfers); i++) // Initiate transfers
                ;
//                ok = startNextIsochRead(&grabContext, i);
    }
    
    // Go into the RunLoop until we are done
    
    if (ok) 
    {
        CFRunLoopRun(); // Do our run loop
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode); // Remove the event source
    }
    
    // Stop the stream, reset the USB, close down 
    
    [self shutdownGrabStream];
    //  [self usbSetAltInterfaceTo:0 testPipe:0]; // Reset to control pipe -- should be done in shutdownGrabStream, normal could be a different alt than 0!
    
    shouldBeGrabbing = NO; // Error in grabbingThread or abort? initiate shutdown of everything else
    [grabContext.chunkReadyLock unlock]; // Give the decodingThread a chance to abort
    
    // Exit the thread cleanly
    
    [pool release];
    grabbingThreadRunning = NO;
    [NSThread exit];
}

@end
