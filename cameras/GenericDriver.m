//
//  GenericDriver.m
//
//  macam - webcam app and QuickTime driver component
//  GenericDriver - base driver code for many cameras
//
//  Created by HXR on 3/6/06.
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

#import "GenericDriver.h"

#include "MiscTools.h"
#include "Resolvers.h"

#include <unistd.h>

// 
// This driver provides more of the common code that most drivers need, while 
// separating out the code that make cameras different into smaller routines. 
//
// The main methods that get called (points of entry, if you will) are:
//   [initWithCentral]
//   [startupWithUsbLocationId]
//   [dealloc]
//   [decodingThread]
//
// To implement a new driver, subclass this class (GenericDriver) and implement
// all the required methods and any other methods that are necessary for the 
// specific camera. See the ExampleDriver for an example.
//
// These methods *must* be implemented by a subclass:
//  [setGrabInterfacePipe]
//  [startupGrabStream]
//  [shutdownGrabStream]
//  [setIsocFrameFunctions]
//  [decodeBuffer]
//
// The following methods and functions might be implemented by a subclass if necessary:
//  [startupCamera]
//  [getGrabbingPipe]
//  specificIsocDataCopier()   // The existing version should work for most
//  specificIsocFrameScanner() // If a suitable one does not already exist
//

@implementation GenericDriver

//
// Initialize the driver
// This *must* be subclassed
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    grabbingThreadRunning = NO;
	bayerConverter = NULL;
    LUT = NULL;
    
    hardwareBrightness = NO;
    hardwareContrast = NO;
    hardwareSaturation = NO;
    hardwareGamma = NO;
    hardwareSharpness = NO;   
    
    CocoaJPEG.rect = CGRectMake(0, 0, [self width], [self height]);
    CocoaJPEG.imageRep = NULL;
    CocoaJPEG.bitmapGC = NULL;
    CocoaJPEG.imageContext = NULL;
    
    compressionType = unknownCompression;
    jpegVersion = 0;
    
	return self;
}

//
// Avoid subclassing this method if possible
// Instead put functionality into [startupCamera]
//
- (CameraError) startupWithUsbLocationId: (UInt32) usbLocationId
{
	CameraError error;
    
    if (error = [self usbConnectToCam:usbLocationId configIdx:0]) 
        return error; // setup connection to camera
    
    [self startupCamera];
    
	return [super startupWithUsbLocationId:usbLocationId];
}

//
// Subclass this for more functionality
//
- (void) startupCamera
{
	[self setBrightness:0.5];
	[self setContrast:0.5];
	[self setGamma:0.5];
	[self setSaturation:0.5];
	[self setSharpness:0.5];
}

//
// Subclass if needed, don't forget to call [super]
//
- (void) dealloc 
{
	if (bayerConverter) 
        [bayerConverter release];
	bayerConverter = NULL;
    
    if (LUT) 
        [LUT release];
    LUT = NULL;
    
	[self cleanupGrabContext];
    
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////
// The following methods work for drivers that use the BayerConverter
////////////////////////////////////////////////////////////////////////////////

//
// Brightness
//
- (BOOL) canSetBrightness 
{
    return (bayerConverter != NULL || LUT != NULL || hardwareBrightness) ? YES : NO;
}

- (void) setBrightness: (float) v 
{
	[super setBrightness:v];
    
    if (bayerConverter != NULL && !hardwareBrightness) 
        [bayerConverter setBrightness:[self brightness] - 0.5f];
    
    if (LUT != NULL && !hardwareBrightness) 
        [LUT setBrightness:[self brightness] - 0.5f];
}

//
// Contrast
//
- (BOOL) canSetContrast 
{ 
    return (bayerConverter != NULL || LUT != NULL || hardwareContrast) ? YES : NO;
}

- (void) setContrast: (float) v 
{
	[super setContrast:v];
    
    if (bayerConverter != NULL && !hardwareContrast) 
        [bayerConverter setContrast:[self contrast] + 0.5f];
    
    if (LUT != NULL && !hardwareContrast) 
        [LUT setContrast:[self contrast] + 0.5f];
}

//
// Gamma
//
- (BOOL) canSetGamma 
{ 
    return (bayerConverter != NULL || LUT != NULL || hardwareGamma) ? YES : NO;
}

- (void) setGamma: (float) v 
{
    [super setGamma:v];
    
    if (bayerConverter != NULL && !hardwareGamma) 
        [bayerConverter setGamma:[self gamma] + 0.5f];
    
    if (LUT != NULL && !hardwareGamma) 
        [LUT setGamma:[self gamma] + 0.5f];
}

//
// Saturation
//
- (BOOL) canSetSaturation 
{ 
    return (bayerConverter != NULL || LUT != NULL || hardwareSaturation) ? YES : NO;
}

- (void) setSaturation: (float) v 
{
    [super setSaturation:v];
    
    if (bayerConverter != NULL && !hardwareSaturation) 
        [bayerConverter setSaturation:[self saturation] * 2.0f];
    
    if (LUT != NULL && !hardwareSaturation) 
        [LUT setSaturation:[self saturation] * 2.0f];
}

//
// Sharpness
//
- (BOOL) canSetSharpness 
{ 
    return (bayerConverter != NULL || hardwareSharpness) ? YES : NO;
}

- (void) setSharpness: (float) v 
{
    [super setSharpness:v];
    
    if (bayerConverter != NULL && !hardwareSharpness) 
        [bayerConverter setSharpness:[self sharpness]];
}


// Gain and shutter combined
- (BOOL) canSetAutoGain 
{
    return (bayerConverter != NULL) ? YES : NO;
}


- (void) setAutoGain:(BOOL) v
{
    if (v == autoGain) 
        return;
    
    [super setAutoGain:v];
    
    if (bayerConverter != NULL) 
        [bayerConverter setMakeImageStats:v];
}


//
// Horizontal flip (mirror)
// Remember to pass the hFlip value to [BayerConverter convertFromSrc...]
//
- (BOOL) canSetHFlip 
{
    return (bayerConverter != NULL) ? YES : NO;
}

//
// WhiteBalance
//
- (BOOL) canSetWhiteBalanceMode 
{
    return (bayerConverter != NULL || LUT != NULL) ? YES : NO;
}

- (BOOL) canSetWhiteBalanceModeTo: (WhiteBalanceMode) newMode 
{
    BOOL ok = NO;
    
    switch (newMode) 
    {
        case WhiteBalanceLinear:
        case WhiteBalanceIndoor:
        case WhiteBalanceOutdoor:
            ok = bayerConverter != NULL || LUT != NULL;
            break;
            
        case WhiteBalanceAutomatic:
            ok = bayerConverter != NULL;
            break;
            
        default:
            ok = NO;
            break;
    }
    
    return ok;
}

- (void) setWhiteBalanceMode: (WhiteBalanceMode) newMode 
{
    [super setWhiteBalanceMode:newMode];
    
    if (bayerConverter == NULL && LUT == NULL) 
        return;
    
    switch (whiteBalanceMode) 
    {
        case WhiteBalanceLinear:
            if (bayerConverter != NULL) 
            {
                [bayerConverter setGainsDynamic:NO];
                [bayerConverter setGainsRed:1.0f green:1.0f blue:1.0f];
            }
            if (LUT != NULL) 
                [LUT setGainsRed:1.0f green:1.0f blue:1.0f];
            break;
            
        case WhiteBalanceIndoor:
            if (bayerConverter != NULL) 
            {
                [bayerConverter setGainsDynamic:NO];
                [bayerConverter setGainsRed:0.8f green:0.97f blue:1.25f];
            }
            if (LUT != NULL) 
                [LUT setGainsRed:0.8f green:0.97f blue:1.25f];
            break;
            
        case WhiteBalanceOutdoor:
            if (bayerConverter != NULL) 
            {
                [bayerConverter setGainsDynamic:NO];
                [bayerConverter setGainsRed:1.1f green:0.95f blue:0.95f];
            }
            if (LUT != NULL) 
                [LUT setGainsRed:1.1f green:0.95f blue:0.95f];
            break;
            
        case WhiteBalanceAutomatic:
            if (bayerConverter != NULL) 
                [bayerConverter setGainsDynamic:YES];
            break;
    }
}

////////////////////////////////////////////////////////////////////////////////

//
// Returns the pipe used for grabbing
// Subclass if necessary
//
- (UInt8) getGrabbingPipe
{
    return 1;
}

//
// Setup the alt-interface and pipe to use for grabbing
// This *must* be subclassed
//
// Return YES if everything is ok
//
- (BOOL) setGrabInterfacePipe
{
//  return [self usbSetAltInterfaceTo:7 testPipe:[self getGrabbingPipe]]; // copy and change the alt-interface
    return NO;
}

//
// Make the right sequence of USB calls to get the stream going
// If anything goes wrong, return NO
// This *must* be subclassed
//
- (BOOL) startupGrabStream 
{
    return NO;
}

//
// Make the right sequence of USB calls to shut the stream down
// This *must* be subclassed
//
- (void) shutdownGrabStream 
{
}

//
// A new function for scanning the isochronous frames must be provided if a suitable 
// one does not already exist. 
//
IsocFrameResult  genericIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength)
{
    return invalidFrame;
}

//
// This version can probably be used by most cameras
// Headers and footers can be skipped by specifying the proper start and lengths in the scanner
//
// If data needs to be modified (and it cannot be [efficiently] done in the decoder) 
// then this is place to make those modifications
//
int  genericIsocDataCopier(void * destination, const void * source, size_t length, size_t available)
{
    if (length > available-1) 
        length = available-1;
    
    memcpy(destination, source, length);
    
    return length;
}

//
// This *must* be subclassed
// Provide the correct functions for the camera
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = genericIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// Avoid subclassing this method if possible
// Instead put functionality into [setIsocFrameFunctions]
// and of course [startupGrabStream] and [shutdownGrabStream]
//
- (BOOL) setupGrabContext 
{
    BOOL ok = YES;
    int i, j;
    
    grabContext.numberOfTransfers = GENERIC_NUM_TRANSFERS;
    grabContext.numberOfFramesPerTransfer = GENERIC_FRAMES_PER_TRANSFER;
    grabContext.numberOfChunkBuffers = GENERIC_NUM_CHUNK_BUFFERS;
    
    grabContext.imageWidth = [self width];
    grabContext.imageHeight = [self height];
    
    [self setIsocFrameFunctions];  // can also adjust number of transfers, frames, buffers
    
    if (grabContext.numberOfTransfers > GENERIC_MAX_TRANSFERS) 
        grabContext.numberOfTransfers = GENERIC_MAX_TRANSFERS;
    
    if (grabContext.numberOfFramesPerTransfer > GENERIC_FRAMES_PER_TRANSFER) 
        grabContext.numberOfFramesPerTransfer = GENERIC_FRAMES_PER_TRANSFER;
    
    if (grabContext.numberOfChunkBuffers > GENERIC_NUM_CHUNK_BUFFERS) 
        grabContext.numberOfChunkBuffers = GENERIC_NUM_CHUNK_BUFFERS;
    
    // Clear things that have to be set back if init() fails
    
    grabContext.chunkReadyLock = NULL;
    grabContext.chunkListLock = NULL;
    
    for (i = 0; i < grabContext.numberOfTransfers; i++) 
        grabContext.transferContexts[i].buffer = NULL;
    
    // Setup simple things
    
    grabContext.intf = intf;
    grabContext.grabbingPipe = [self getGrabbingPipe];
    grabContext.bytesPerFrame = [self usbGetIsocFrameSize];
    
    grabContext.shouldBeGrabbing = &shouldBeGrabbing;
    grabContext.contextError = CameraErrorOK;
    
    grabContext.initiatedUntil = 0; // Will be set later (directly before start)
    grabContext.finishedTransfers = 0;
    grabContext.framesSinceLastChunk = 0;
    
    grabContext.numFullBuffers = 0;
    grabContext.numEmptyBuffers = 0;
    grabContext.fillingChunk = false;
    grabContext.chunkBufferLength = [self width] * [self height] * 4 + 10000; // That should be more than enough, but should include any JPEG header
    
    // Setup JPEG header stuff here in the future
    
    // Setup things that have to be set back if init fails
    
    if (ok) 
    {
        grabContext.chunkReadyLock = [[NSLock alloc] init];
        if (grabContext.chunkReadyLock == NULL) 
            ok = NO;
    }
    
    if (ok) 
    {
        grabContext.chunkListLock = [[NSLock alloc] init];
        if (grabContext.chunkListLock == NULL) 
            ok = NO;
    }
    
    // Initialize transfer contexts
    
    if (ok) 
    {
        for (i = 0; ok && (i < grabContext.numberOfTransfers); i++) 
        {
            for (j = 0; j < grabContext.numberOfFramesPerTransfer; j++) 
            {
                grabContext.transferContexts[i].frameList[j].frStatus = 0;
                grabContext.transferContexts[i].frameList[j].frReqCount = grabContext.bytesPerFrame;
                grabContext.transferContexts[i].frameList[j].frActCount = 0;
            }
            
            MALLOC(grabContext.transferContexts[i].buffer, UInt8 *,
                   grabContext.numberOfFramesPerTransfer * grabContext.bytesPerFrame, "isoc transfer buffer");
            
            if (grabContext.transferContexts[i].buffer == NULL) 
                ok = NO;
        }
    }
    
    // Initialize chunk buffers
    
    for (i = 0; ok && (i < grabContext.numberOfChunkBuffers); i++) 
    {
        MALLOC(grabContext.emptyChunkBuffers[i].buffer, UInt8 *, grabContext.chunkBufferLength, "Chunk buffer");
        
        if (grabContext.emptyChunkBuffers[i].buffer == NULL) 
            ok = NO;
        else 
            grabContext.numEmptyBuffers = i + 1;
    }
    
    // Cleanup if anything went wrong
    
    if (!ok) 
    {
        NSLog(@"setupGrabContext failed");
        [self cleanupGrabContext];
    }
    
    return ok;
}

//
// Avoid subclassing this method if possible
//
- (void) cleanupGrabContext 
{
    int i;
    
    // Cleanup chunk ready lock
    
    if (grabContext.chunkReadyLock != NULL) 
    {
        [grabContext.chunkReadyLock release];
        grabContext.chunkReadyLock = NULL;
    }
    
    // Cleanup chunk list lock
    
    if (grabContext.chunkListLock != NULL) 
    {
        [grabContext.chunkListLock release];
        grabContext.chunkListLock = NULL;
    }
    
    // Cleanup isoc buffers
    
    for (i = 0; i < grabContext.numberOfTransfers; i++) 
    {
        if (grabContext.transferContexts[i].buffer) 
        {
            FREE(grabContext.transferContexts[i].buffer, "isoc data buffer");
            grabContext.transferContexts[i].buffer = NULL;
        }
    }
    
    // Cleanup empty chunk buffers
    
    for (i = grabContext.numEmptyBuffers - 1; i >= 0; i--) 
    {
        if (grabContext.emptyChunkBuffers[i].buffer != NULL) 
        {
            FREE(grabContext.emptyChunkBuffers[i].buffer, "empty chunk buffer");
            grabContext.emptyChunkBuffers[i].buffer = NULL;
        }
    }
    
    grabContext.numEmptyBuffers = 0;
    
    // Cleanup full chunk buffers
    
    for (i = grabContext.numFullBuffers - 1; i >= 0; i--) 
    {
        if (grabContext.fullChunkBuffers[i].buffer != NULL) 
        {
            FREE(grabContext.fullChunkBuffers[i].buffer, "full chunk buffer");
            grabContext.fullChunkBuffers[i].buffer = NULL;
        }
    }
    
    grabContext.numFullBuffers = 0;
    
    // Cleanup filling chunk buffer
    
    if (grabContext.fillingChunk) 
    {
        if (grabContext.fillingChunkBuffer.buffer != NULL) 
        {
            FREE(grabContext.fillingChunkBuffer.buffer, "filling chunk buffer");
            grabContext.fillingChunkBuffer.buffer = NULL;
        }
        
        grabContext.fillingChunk = false;
    }
}

//
// Forward declaration because both isocComplete() and startNextIsochRead() refer to each other
//
static bool startNextIsochRead(GenericGrabContext * grabbingContext, int transferIndex);

//
// Avoid recreating this function if possible
//
static void isocComplete(void * refcon, IOReturn result, void * arg0) 
{
    GenericGrabContext * gCtx = (GenericGrabContext *) refcon;
    IOUSBIsocFrame * myFrameList = (IOUSBIsocFrame *) arg0;
    short transferIdx = 0;
    bool frameListFound = false;
    UInt8 * frameBase;
    int i;
    
    static int droppedFrames = 0;
    static int droppedChunks = 0;
    
    // Handle result from isoc transfer
    
    switch (result) 
    {
        case kIOReturnSuccess: // No error -> alright
        case kIOReturnUnderrun: // Data hickup - not so serious
            result = 0;
            break;
            
        case kIOReturnOverrun:
        case kIOReturnTimeout:
            *gCtx->shouldBeGrabbing = NO;
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorTimeout;
            break;
            
        default:
            *gCtx->shouldBeGrabbing = NO;
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorUSBProblem;
            break;
    }
    CheckError(result, "isocComplete"); // Show errors (really needed here? -- actually yes!)

    // Look up which transfer we are
    
    if (*gCtx->shouldBeGrabbing) 
    {
        while (!frameListFound && (transferIdx < gCtx->numberOfTransfers)) 
        {
            if (gCtx->transferContexts[transferIdx].frameList == myFrameList) 
                frameListFound = true;
            else 
                transferIdx++;
        }
        
        if (!frameListFound) 
        {
            NSLog(@"isocComplete: Didn't find my frameList, very strange.");
            *gCtx->shouldBeGrabbing = NO;
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorInternal;
        }
    }

    // Parse returned data
    
    if (*gCtx->shouldBeGrabbing) 
    {
        for (i = 0; i < gCtx->numberOfFramesPerTransfer; i++) // Let's have a look into the usb frames we got
        {
            UInt32 dataStart, dataLength, tailStart, tailLength;
            
            frameBase = gCtx->transferContexts[transferIdx].buffer + gCtx->bytesPerFrame * i; // Is this right? It assumes possibly non-contiguous writing, if actual count < requested count [yes, seems to work, look at USB spec?]
            
            IsocFrameResult frameResult = (*gCtx->isocFrameScanner)(&myFrameList[i], frameBase, 
                                                &dataStart, &dataLength, &tailStart, &tailLength);
            
            if (frameResult == invalidFrame || myFrameList[i].frActCount == 0) 
            {
                droppedFrames++;
            }
            else if (frameResult == invalidChunk) 
            {
                droppedFrames = 0;
                droppedChunks++;
                gCtx->fillingChunkBuffer.numBytes = 0;
            }
            else if (frameResult == newChunkFrame) 
            {
                droppedFrames = 0;
                droppedChunks = 0;
                
                // When the new chunk starts in the middle of a frame, we must copy the tail
                
                if (gCtx->fillingChunk && tailLength > 0) 
                {
                    int add = (*gCtx->isocDataCopier)(gCtx->fillingChunkBuffer.buffer + gCtx->fillingChunkBuffer.numBytes, frameBase + tailStart, tailLength, gCtx->chunkBufferLength - gCtx->fillingChunkBuffer.numBytes);
                    gCtx->fillingChunkBuffer.numBytes += add;
                }
                
                // Now we need to get a new chunk
                // Wait for access to the chunk buffers
                
                [gCtx->chunkListLock lock];
                
                // We were filling, first deal with the old chunk that is now full
                
                if (gCtx->fillingChunk) 
                {
                    int j;
                    
//                  printf("Chunk filled with %ld bytes\n", gCtx->fillingChunkBuffer.numBytes);
                    
                    // Pass the complete chunk to the full list
                    // Move full buffers one up
                    
                    for (j = gCtx->numFullBuffers - 1; j >= 0; j--) 
                        gCtx->fullChunkBuffers[j + 1] = gCtx->fullChunkBuffers[j];
                    
                    gCtx->fullChunkBuffers[0] = gCtx->fillingChunkBuffer; // Insert the filling one as newest
                    gCtx->numFullBuffers++;				// We have inserted one buffer
                                                        //  What if the list was already full? - That is not possible
                    gCtx->fillingChunk = false;			// Now we're not filling (still in the lock to be sure no buffer is lost)
                    [gCtx->chunkReadyLock unlock];		// Wake up the decoding thread
                    gCtx->framesSinceLastChunk = 0;     // Reset watchdog
                } 
                // else // There was no current filling chunk. Just get a new one.
                
                // We still have the list access lock. Get a new buffer to fill.
                
                if (gCtx->numEmptyBuffers > 0) 			// There's an empty buffer to use
                {
                    gCtx->numEmptyBuffers--;
                    gCtx->fillingChunkBuffer = gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers];
                } 
                else // No empty buffer: discard a full one (there are enough, both lists can't be empty)
                {
                    gCtx->numFullBuffers--;             // Use the oldest one
                    gCtx->fillingChunkBuffer = gCtx->fullChunkBuffers[gCtx->numFullBuffers];
                }
                gCtx->fillingChunk = true;				// Now we're filling (still in the lock to be sure no buffer is lost)
                gCtx->fillingChunkBuffer.numBytes = 0;	// Start with empty buffer
                [gCtx->chunkListLock unlock];			// Free access to the chunk buffers
            }
            // else // validFrame 
            
            if (gCtx->fillingChunk && (dataLength > 0)) 
            {
                [gCtx->chunkListLock lock];
                int add = (*gCtx->isocDataCopier)(gCtx->fillingChunkBuffer.buffer + gCtx->fillingChunkBuffer.numBytes, 
                                                  frameBase + dataStart, dataLength, gCtx->chunkBufferLength - gCtx->fillingChunkBuffer.numBytes);
                gCtx->fillingChunkBuffer.numBytes += add;
                [gCtx->chunkListLock unlock];
            }
        }
        
        gCtx->framesSinceLastChunk += gCtx->numberOfFramesPerTransfer; // Count frames (not necessary to be too precise here...)
        
        if (gCtx->framesSinceLastChunk > 1000) // One second without a frame? That is too long, something is wrong.
        {
            NSLog(@"GenericDriver: grab aborted because of invalid data stream (too long without a frame, %i invalid frames, %i invalid chunks)", droppedFrames, droppedChunks);
            *gCtx->shouldBeGrabbing = NO;
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorUSBProblem;
        }
    }
    
    // Initiate next transfer
    
    if (*gCtx->shouldBeGrabbing) 
    {
        if (!startNextIsochRead(gCtx, transferIdx)) 
            *gCtx->shouldBeGrabbing = NO;
    }
    
    // Shutdown cleanup: Collect finished transfers and exit if all transfers have ended
    
    if (!(*gCtx->shouldBeGrabbing)) 
    {
        droppedFrames = 0;
        gCtx->finishedTransfers++;
        if (gCtx->finishedTransfers >= gCtx->numberOfTransfers) 
            CFRunLoopStop(CFRunLoopGetCurrent());
    }
}

//
// Avoid recreating this function if possible
// Return true if everything is OK
//
static bool startNextIsochRead(GenericGrabContext * gCtx, int transferIdx) 
{
    IOReturn error;
    
    error = (*gCtx->intf)->ReadIsochPipeAsync(gCtx->intf,
                                                 gCtx->grabbingPipe,
                                                 gCtx->transferContexts[transferIdx].buffer,
                                                 gCtx->initiatedUntil,
                                                 gCtx->numberOfFramesPerTransfer,
                                                 gCtx->transferContexts[transferIdx].frameList,
                                                 (IOAsyncCallback1) (isocComplete),
                                                 gCtx);
    
    gCtx->initiatedUntil += gCtx->numberOfFramesPerTransfer;
    
    switch (error) 
    {
        case kIOReturnSuccess:
            break;
            
        case kIOReturnNoDevice:
        case kIOReturnNotOpen:
        default:
            CheckError(error, "StartNextIsochRead-ReadIsochPipeAsync");
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorUSBProblem;
            break;
    }
    
    return (error == kIOReturnSuccess);
}

//
// Avoid subclassing this method if possible
// Instead put functionality into [setGrabInterfacePipe], [startupGrabStream] and [shutdownGrabStream]
//
- (void) grabbingThread: (id) data 
{
    NSAutoreleasePool * pool=[[NSAutoreleasePool alloc] init];
    CFRunLoopSourceRef cfSource;
    IOReturn error;
    bool ok = true;
    long i;
    
    ChangeMyThreadPriority(10);	// We need to update the isoch read in time, so timing is important for us
    
    // Try to get as much bandwidth as possible somehow?
    
    if (![self setGrabInterfacePipe]) 
    {
        if (grabContext.contextError == CameraErrorOK) 
            grabContext.contextError = CameraErrorNoBandwidth; // Probably means not enough bandwidth
        ok = NO;
    }
    
    // Start the stream
    
    if (ok) 
        ok = [self startupGrabStream];
    
    // Get USB timing info
    
    if (ok) 
    {
        if (![self usbGetSoon:&(grabContext.initiatedUntil)]) 
        {
            shouldBeGrabbing = NO;
            if (grabContext.contextError == CameraErrorOK) 
                grabContext.contextError = CameraErrorUSBProblem; // Did the pipe stall perhaps?
        }
    }
    
    // Set up the asynchronous read calls
    
    if (ok) 
    {
        error = (*intf)->CreateInterfaceAsyncEventSource(intf, &cfSource); // Create an event source
        CheckError(error, "CreateInterfaceAsyncEventSource");
        CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode); // Add it to our run loop
        
        for (i = 0; ok && (i < GENERIC_NUM_TRANSFERS); i++) // Initiate transfers
            ok = startNextIsochRead(&grabContext, i);
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


- (BOOL) setupDecoding 
{
    BOOL ok = YES;
    
    if (compressionType == jpegCompression) 
    {
        printf("JPEG compression is being used.\n");
        printf("   decompression using method %d\n", jpegVersion);
    }
    
    if (compressionType == jpegCompression && jpegVersion == 1) 
    {
        CocoaJPEG.rect = CGRectMake(0, 0, [self width], [self height]);
        
        CocoaJPEG.imageRep = [NSBitmapImageRep alloc];
        CocoaJPEG.imageRep = [CocoaJPEG.imageRep initWithBitmapDataPlanes:NULL
                                                                     pixelsWide:[self width]
                                                                     pixelsHigh:[self height]
                                                                  bitsPerSample:8
                                                                samplesPerPixel:4
                                                                       hasAlpha:YES
                                                                       isPlanar:NO
                                                                 colorSpaceName:NSDeviceRGBColorSpace
                                                                    bytesPerRow:4 * [self width]
                                                                   bitsPerPixel:4 * 8];
        
        // use CGBitmapContextCreate() instead??
/*
00270                 CGColorSpaceRef colorspace_ref = (image_depth == 8) ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
00271                 
00272                 if (!colorspace_ref)
00273                         return false;
00274                 
00275                 CGImageAlphaInfo alpha_info = (image_depth == 8) ? kCGImageAlphaNone : kCGImageAlphaPremultipliedLast; //kCGImageAlphaLast; //RGBA format
00276 
00277                 context_ref = CGBitmapContextCreate(buffer->data, (size_t)image_size.width, (size_t)image_size.height, 8, buffer_rowbytes, colorspace_ref, alpha_info);
00278 
00279                 if (context_ref)
00280                 {
00281                         CGContextSetFillColorSpace(context_ref, colorspace_ref);
00282                         CGContextSetStrokeColorSpace(context_ref, colorspace_ref);
00283                         // move down, and flip vertically 
00284                         // to turn postscript style coordinates to "screen style"
00285                         CGContextTranslateCTM(context_ref, 0.0, image_size.height);
00286                         CGContextScaleCTM(context_ref, 1.0, -1.0);
00287                 }
00288                 
00289                 CGColorSpaceRelease(colorspace_ref);
00290                 colorspace_ref = NULL;
*/
        
/*
CGColorSpaceRef CreateSystemColorSpace () 
{
    CMProfileRef sysprof = NULL;
    CGColorSpaceRef dispColorSpace = NULL;
    
    // Get the Systems Profile for the main display
    if (CMGetSystemProfile(&sysprof) == noErr)
    {
        // Create a colorspace with the systems profile
        dispColorSpace = CGColorSpaceCreateWithPlatformColorSpace(sysprof);
        
        // Close the profile
        CMCloseProfile(sysprof);
    }
    
    return dispColorSpace;
}
*/
        
        CMProfileRef sysprof = NULL;
        CGColorSpaceRef dispColorSpace = NULL;
        
        // Get the Systems Profile for the main display
        if (CMGetSystemProfile(&sysprof) == noErr)
        {
            // Create a colorspace with the systems profile
            dispColorSpace = CGColorSpaceCreateWithPlatformColorSpace(sysprof);
            
            // Close the profile
            CMCloseProfile(sysprof);
        }
        
        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
        
        CocoaJPEG.imageContext = CGBitmapContextCreate( [CocoaJPEG.imageRep bitmapData],
                                            [self width], [self height], 8, 4 * [self width],
                                            colorspace, kCGImageAlphaPremultipliedLast);
        
        CGColorSpaceRelease(colorspace);
        CGColorSpaceRelease(dispColorSpace);
    }
    
    if (compressionType == jpegCompression && jpegVersion == 2) 
    {
        CocoaJPEG.rect = CGRectMake(0, 0, [self width], [self height]);
        
        CocoaJPEG.imageRep = [NSBitmapImageRep alloc];
        CocoaJPEG.imageRep = [CocoaJPEG.imageRep initWithBitmapDataPlanes:NULL
                                                                     pixelsWide:[self width]
                                                                     pixelsHigh:[self height]
                                                                  bitsPerSample:8
                                                                samplesPerPixel:4
                                                                       hasAlpha:YES
                                                                       isPlanar:NO
                                                                 colorSpaceName:NSDeviceRGBColorSpace
                                                                    bytesPerRow:4 * [self width]
                                                                   bitsPerPixel:4 * 8];
        
        //  This only works with 32 bits/pixel ARGB
        //  bitmapGC = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];
        
        //  Need this for pre 10.4 compatibility?
        CocoaJPEG.bitmapGC = [NSGraphicsContext graphicsContextWithAttributes:
            [NSDictionary dictionaryWithObject:CocoaJPEG.imageRep forKey:NSGraphicsContextDestinationAttributeName]];
        //  NSGraphicsContext * bitmapGC = [NSGraphicsContext graphicsContextWithAttributes:<#(NSDictionary *)attributes#>];
        
        CocoaJPEG.imageContext = (CGContextRef) [CocoaJPEG.bitmapGC graphicsPort];
    }
    
    return ok;
}


- (void) cleanupDecoding;
{
    if (CocoaJPEG.imageRep != NULL) 
        [CocoaJPEG.imageRep release];
    CocoaJPEG.imageRep = NULL;
}

//
// Avoid subclassing this method if possible
// Instead put functionality into [decodeBuffer]
//
- (CameraError) decodingThread 
{
    CameraError error = CameraErrorOK;
    grabbingThreadRunning = NO;
    
    // Initialize
    
    if (![self setupGrabContext] || ![self setupDecoding]) 
    {
        error = CameraErrorNoMem;
        shouldBeGrabbing = NO;
    }
    
    // Start the grabbing thread
    
    if (shouldBeGrabbing) 
    {
        grabbingThreadRunning = YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];
    }
    
    // The decoding loop
    
    while (shouldBeGrabbing) 
    {
        [grabContext.chunkReadyLock lock]; // Wait for chunks to become ready
        
        while (shouldBeGrabbing && (grabContext.numFullBuffers > 0)) 
        {
            GenericChunkBuffer currentBuffer;   // The buffer to decode
            
            // Get a full buffer
            
            [grabContext.chunkListLock lock];   // Get access to the buffer lists
            grabContext.numFullBuffers--;       // There's always one since no one else can empty it completely
            currentBuffer = grabContext.fullChunkBuffers[grabContext.numFullBuffers];
            [grabContext.chunkListLock unlock]; // Release access to the buffer lists
            
            // Do the decoding
            
            if (nextImageBufferSet) 
            {
                [imageBufferLock lock]; // Lock image buffer access
                
                if (nextImageBuffer != NULL) 
                {
                    [self decodeBuffer:&currentBuffer]; // Into nextImageBuffer
                }
                
                lastImageBuffer = nextImageBuffer; // Copy nextBuffer info into lastBuffer
                lastImageBufferBPP = nextImageBufferBPP;
                lastImageBufferRowBytes = nextImageBufferRowBytes;
                nextImageBufferSet = NO;  // nextBuffer has been eaten up
                [imageBufferLock unlock]; // Release lock
                
                [self mergeImageReady];   // Notify delegate about the image. Perhaps get a new buffer
            }
            
            // Put the chunk buffer back to the empty ones
            
            [grabContext.chunkListLock lock];   // Get access to the buffer lists
            grabContext.emptyChunkBuffers[grabContext.numEmptyBuffers] = currentBuffer;
            grabContext.numEmptyBuffers++;
            [grabContext.chunkListLock unlock]; // Release access to the buffer lists            
        }
    }
    
    // Shutdown, but wait for grabbingThread finish first
    
    while (grabbingThreadRunning) 
    {
        usleep(10000); // Sleep for 10 ms, then try again
    }
    
    [self cleanupGrabContext];
    [self cleanupDecoding];
    
    if (error == CameraErrorOK) 
        error = grabContext.contextError; // Return the error from the context if there was one
    
    return error;
}


void BufferProviderRelease(void * info, const void * data, size_t size)
{
    if (info != NULL) 
    {
        // Odd
    }
    
    if (data != NULL) 
    {
        // Normal
    }
}


- (void) decodeBufferCocoaJPEG: (GenericChunkBuffer *) buffer
{
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer->buffer, buffer->numBytes, BufferProviderRelease);
    CGImageRef image = CGImageCreateWithJPEGDataProvider(provider, NULL, false, kCGRenderingIntentDefault);
    
    CGContextDrawImage(CocoaJPEG.imageContext, CocoaJPEG.rect, image);
    
    CGContextFlush(CocoaJPEG.imageContext);
    
    CGDataProviderRelease(provider);
    CGImageRelease(image);
    
    [LUT processImageRep:CocoaJPEG.imageRep 
                  buffer:nextImageBuffer 
                 numRows:[self height] 
                rowBytes:nextImageBufferRowBytes 
                     bpp:nextImageBufferBPP];
}


- (void) decodeBufferJPEGversion3: (GenericChunkBuffer *) buffer
{
    // QuickTime
}

//
// Decode the chunk buffer into the nextImageBuffer
// This *must* be subclassed as the decoding is camera dependent
//
- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
    if (compressionType == jpegCompression) 
    {
        switch (jpegVersion) 
        {
            case 3:
                [self decodeBufferJPEGversion3:buffer];
                break;
                
            default:
                NSLog(@"GenericDriver - decodeBuffer encountered unknown jpegVersion (%i)", jpegVersion);
            case 2:
            case 1:
                [self decodeBufferCocoaJPEG:buffer];
                break;
        }
    }
    else 
        NSLog(@"GenericDriver - decodeBuffer must be implemented");
}

@end
