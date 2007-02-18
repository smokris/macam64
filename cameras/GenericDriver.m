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
    
    driverType = isochronousDriver; // This is the default
    exactBufferLength = 0;
    
    grabbingThreadRunning = NO;
	bayerConverter = NULL;
    LUT = NULL;
    
    hardwareBrightness = NO;
    hardwareContrast = NO;
    hardwareSaturation = NO;
    hardwareGamma = NO;
    hardwareSharpness = NO;   
    hardwareHue = NO;   
    hardwareFlicker = NO;   
    
    decodingSkipBytes = 0;
    
    compressionType = unknownCompression;
    jpegVersion = 0;
    quicktimeCodec = 0;
    
    CocoaDecoding.rect = CGRectMake(0, 0, [self width], [self height]);
    CocoaDecoding.imageRep = NULL;
    CocoaDecoding.bitmapGC = NULL;
    CocoaDecoding.imageContext = NULL;
    
    QuicktimeDecoding.imageDescription = NULL;
    QuicktimeDecoding.gworldPtr = NULL;
    SetQDRect(&QuicktimeDecoding.boundsRect, 0, 0, [self width], [self height]);
    
    SequenceDecoding.sequenceIdentifier = 0;
    
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
	[self setHue:0.5];
	[self setSharpness:0.5];
    
    if ([self canSetAutoGain]) 
        [self setAutoGain:YES];
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
// Hue
//
- (BOOL) canSetHue 
{ 
    return (hardwareHue) ? YES : NO;
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
// Flicker
//
- (BOOL) canSetFlicker
{ 
    return (hardwareFlicker) ? YES : NO;
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
    return (driverType == bulkDriver) ? YES : NO;
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
//  [self usbSetAltInterfaceTo:0 testPipe:0]; // Reset to control pipe -- normal could be a different alt than 0!
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
    
    if (driverType == isochronousDriver) 
    {
        grabContext.numberOfTransfers = GENERIC_NUM_TRANSFERS;
        grabContext.numberOfFramesPerTransfer = GENERIC_FRAMES_PER_TRANSFER;
    }
    else 
    {
        grabContext.numberOfTransfers = 0;
        grabContext.numberOfFramesPerTransfer = 0;
    }
    grabContext.numberOfChunkBuffers = GENERIC_NUM_CHUNK_BUFFERS;
    
    grabContext.imageWidth = [self width];
    grabContext.imageHeight = [self height];
    grabContext.chunkBufferLength = [self width] * [self height] * 4 + 10000; // That should be more than enough, but should include any JPEG header
    
    [self setIsocFrameFunctions];  // can also adjust number of transfers, frames, buffers, buffer-sizes
    
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
    
    grabContext.intf = streamIntf;
    grabContext.grabbingPipe = [self getGrabbingPipe];
    grabContext.bytesPerFrame = (driverType == isochronousDriver) ? [self usbGetIsocFrameSize] : 0;
    
    grabContext.shouldBeGrabbing = &shouldBeGrabbing;
    grabContext.contextError = CameraErrorOK;
    
    grabContext.initiatedUntil = 0; // Will be set later (directly before start)
    grabContext.finishedTransfers = 0;
    grabContext.framesSinceLastChunk = 0;
    
    grabContext.numFullBuffers = 0;
    grabContext.numEmptyBuffers = 0;
    grabContext.fillingChunk = false;
    
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
// This is the callback function for the bulk driver
// This should nao have to be sibclassed or otherwise recreated
//
static void handleFullChunk(void * refcon, IOReturn result, void * arg0)
{
    GenericDriver * driver = (GenericDriver *) refcon;
    UInt32 size = (UInt32) arg0;
    [driver handleFullChunkWithReadBytes:size error:result];
}

//
// Called by the above function
//
- (void) handleFullChunkWithReadBytes:(UInt32) readSize error:(IOReturn) err  
{
    videoBulkReadsPending--;
    
#if REALLY_VERBOSE
    printf("read a chunk with %ld bytes (err = %d)\n", readSize, err);
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
    
	if (shouldBeGrabbing && (readSize > 0))  // No USB error and not an empty chunk
    {
        int j;
        
        grabContext.fillingChunkBuffer.numBytes = readSize;
        
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

//
// Avoid subclassing this method if possible
// Instead put functionality into [setGrabInterfacePipe], [startupGrabStream] and [shutdownGrabStream]
//
- (void) grabbingThread:(id) data 
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
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
    
    shouldBeGrabbing = NO; // Error in grabbingThread or abort? initiate shutdown of everything else
    [grabContext.chunkReadyLock unlock]; // Give the decodingThread a chance to abort
    
    // Exit the thread cleanly
    
    [pool release];
    grabbingThreadRunning = NO;
    [NSThread exit];
}


- (BOOL) setupDecoding 
{
    BOOL ok = NO;
    
    switch (compressionType) 
    {
        case noCompression: 
            ok = YES;
            break;
            
        case jpegCompression:
#if VERBOSE
            printf("JPEG compression is being used, ");
            printf("decompression using method %d\n", jpegVersion);
#endif
            ok = [self setupJpegCompression];
            break;
            
        case quicktimeImage:
#if VERBOSE
            printf("QuickTime image-based decoding is being used.\n");
#endif
            ok = [self setupQuicktimeImageCompression];
            break;
            
        case quicktimeSequence:
#if VERBOSE
            printf("QuickTime sequence-based decoding is being used.\n");
#endif
            ok = [self setupQuicktimeSequenceCompression];
            break;
            
        case proprietaryCompression:
            ok = YES;
            break;
            
        case unknownCompression: 
        default:
            break;
    }
    
    return ok;
}


- (BOOL) setupJpegCompression
{
    BOOL result = NO;
    
    switch (jpegVersion) 
    {
        case 0:
            printf("Error: [setupJpegCompression] should be implemented in current driver!\n");
            break;
            
        case 1:
            result = [self setupJpegVersion1];
            break;
            
        case 2:
            result = [self setupJpegVersion2];
            break;
            
        case 3:
            quicktimeCodec = kJPEGCodecType;
            compressionType = quicktimeImage;
            break;
            
        case 4:
            quicktimeCodec = kJPEGCodecType;
            compressionType = quicktimeSequence;
            break;
            
        case 5:
            quicktimeCodec = kMotionJPEGACodecType;
            compressionType = quicktimeImage;
            break;
            
        case 6:
            quicktimeCodec = kMotionJPEGACodecType;
            compressionType = quicktimeSequence;
            break;
            
        case 7:
            quicktimeCodec = kMotionJPEGBCodecType;
            compressionType = quicktimeImage;
            break;
            
        case 8:
            quicktimeCodec = kMotionJPEGBCodecType;
            compressionType = quicktimeSequence;
            break;
            
        default:
            printf("Error: JPEG decoding version %d does not exist yet!\n", jpegVersion);
            break;
    }
    
    if (compressionType != jpegCompression) 
        result = [self setupDecoding];  // Call this again in the same chain, hope this works OK
    
    return result;
}


- (BOOL) setupJpegVersion1
{
    CocoaDecoding.rect = CGRectMake(0, 0, [self width], [self height]);
    
    CocoaDecoding.imageRep = [NSBitmapImageRep alloc];
    CocoaDecoding.imageRep = [CocoaDecoding.imageRep initWithBitmapDataPlanes:NULL
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
    
    CocoaDecoding.imageContext = CGBitmapContextCreate( [CocoaDecoding.imageRep bitmapData],
                                                        [self width], [self height], 8, 4 * [self width],
                                                        colorspace, kCGImageAlphaPremultipliedLast);
    
    CGColorSpaceRelease(colorspace);
    CGColorSpaceRelease(dispColorSpace);
    
    return YES;
}


- (BOOL) setupJpegVersion2
{
    CocoaDecoding.rect = CGRectMake(0, 0, [self width], [self height]);
    
    CocoaDecoding.imageRep = [NSBitmapImageRep alloc];
    CocoaDecoding.imageRep = [CocoaDecoding.imageRep initWithBitmapDataPlanes:NULL
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
    CocoaDecoding.bitmapGC = [NSGraphicsContext graphicsContextWithAttributes:
        [NSDictionary dictionaryWithObject:CocoaDecoding.imageRep forKey:NSGraphicsContextDestinationAttributeName]];
    //  NSGraphicsContext * bitmapGC = [NSGraphicsContext graphicsContextWithAttributes:<#(NSDictionary *)attributes#>];
    
    CocoaDecoding.imageContext = (CGContextRef) [CocoaDecoding.bitmapGC graphicsPort];
    
    return YES;
}

- (BOOL) setupQuicktimeImageCompression
{
//    OSErr err;
    BOOL ok = YES;
    
    SetQDRect(&QuicktimeDecoding.boundsRect, 0, 0, [self width], [self height]);
    
/*    
    err = QTNewGWorld(&QuicktimeDecoding.gworldPtr,     // returned GWorld
    				  k32ARGBPixelFormat,               // pixel format
    				  &QuicktimeDecoding.boundsRect,    // bounding rectangle
    				  0,                                // color table
    				  NULL,                             // graphic device handle
    				  0);                               // flags
    
    if (err) 
        ok = NO;
    
    QuicktimeDecoding.imageRep = [NSBitmapImageRep alloc];
    QuicktimeDecoding.imageRep = [QuicktimeDecoding.imageRep initWithBitmapDataPlanes:GetPixBaseAddr(GetGWorldPixMap(QuicktimeDecoding.gworldPtr)) 
                                                                   pixelsWide:[self width]
                                                                   pixelsHigh:[self height]
                                                                bitsPerSample:8
                                                              samplesPerPixel:4
                                                                     hasAlpha:YES
                                                                     isPlanar:NO
                                                               colorSpaceName:NSDeviceRGBColorSpace
                                                                  bytesPerRow:4 * [self width]
                                                                 bitsPerPixel:4 * 8];
    
    if (QuicktimeDecoding.imageRep == NULL) 
        ok = NO;
*/    
    
    QuicktimeDecoding.imageDescription = (ImageDescriptionHandle) NewHandle(sizeof(ImageDescription));
        
    (**QuicktimeDecoding.imageDescription).idSize = sizeof(ImageDescription);
    (**QuicktimeDecoding.imageDescription).cType = quicktimeCodec;
    (**QuicktimeDecoding.imageDescription).resvd1 = 0;
    (**QuicktimeDecoding.imageDescription).resvd2 = 0;
    (**QuicktimeDecoding.imageDescription).dataRefIndex = 0;
    (**QuicktimeDecoding.imageDescription).version = 1;
    (**QuicktimeDecoding.imageDescription).revisionLevel = 1;
    (**QuicktimeDecoding.imageDescription).vendor = 'appl';
    (**QuicktimeDecoding.imageDescription).temporalQuality = codecNormalQuality;
    (**QuicktimeDecoding.imageDescription).spatialQuality = codecNormalQuality;
    
    (**QuicktimeDecoding.imageDescription).width = [self width];
    (**QuicktimeDecoding.imageDescription).height = [self height];
    (**QuicktimeDecoding.imageDescription).hRes = (72 << 16);
    (**QuicktimeDecoding.imageDescription).vRes = (72 << 16);
    (**QuicktimeDecoding.imageDescription).dataSize = 0;
    (**QuicktimeDecoding.imageDescription).frameCount = 1;
    (**QuicktimeDecoding.imageDescription).name[0] =  6;
    (**QuicktimeDecoding.imageDescription).name[1] = 'C';
    (**QuicktimeDecoding.imageDescription).name[2] = 'a';
    (**QuicktimeDecoding.imageDescription).name[3] = 'm';
    (**QuicktimeDecoding.imageDescription).name[4] = 'e';
    (**QuicktimeDecoding.imageDescription).name[5] = 'r';
    (**QuicktimeDecoding.imageDescription).name[6] = 'a';
    (**QuicktimeDecoding.imageDescription).name[7] =  0;
    (**QuicktimeDecoding.imageDescription).depth = 24;
    (**QuicktimeDecoding.imageDescription).clutID = -1;
    
    return ok;
}

// Not working yet
- (BOOL) setupQuicktimeSequenceCompression
{
    BOOL ok = [self setupQuicktimeImageCompression];
    MatrixRecord scaleMatrix;
    OSErr err;
    
    RectMatrix(&scaleMatrix, &QuicktimeDecoding.boundsRect, &QuicktimeDecoding.boundsRect);
    
    err = DecompressSequenceBeginS(&SequenceDecoding.sequenceIdentifier, 
                            QuicktimeDecoding.imageDescription, 
                                   NULL, 
                                   0, 
                            QuicktimeDecoding.gworldPtr, 
                            NULL, 
                            NULL, 
                            &scaleMatrix, 
                            srcCopy,
                            NULL, 
                            codecFlagUseImageBuffer, // codecFlagUseImageBuffer ? or 0 ?
                            codecNormalQuality, 
                            NULL);
    
    if (err) 
        ok = NO;
    
    return ok;
}

- (void) cleanupDecoding
{
    if (CocoaDecoding.imageRep != NULL) 
       [CocoaDecoding.imageRep release];
    CocoaDecoding.imageRep = NULL;
    
    if (QuicktimeDecoding.imageDescription != NULL) 
        DisposeHandle((Handle) QuicktimeDecoding.imageDescription);
    QuicktimeDecoding.imageDescription = NULL;
    
    // gworld
    
    // imagerep
    
    if (SequenceDecoding.sequenceIdentifier != 0) 
        CDSequenceEnd(SequenceDecoding.sequenceIdentifier);
    SequenceDecoding.sequenceIdentifier = 0;
}

//
// Avoid subclassing this method if possible
// Instead put functionality into [decodeBuffer]
//
- (CameraError) decodingThread 
{
    CameraError error = CameraErrorOK;
    grabbingThreadRunning = NO;
    
    // Try to get as much bandwidth as possible somehow?
    
    if (shouldBeGrabbing && ![self setGrabInterfacePipe]) 
    {
        error = CameraErrorNoBandwidth; // Probably means not enough bandwidth
        shouldBeGrabbing = NO;
    }
    
    // Initialize grab context
    
    if (shouldBeGrabbing && ![self setupGrabContext]) 
    {
        error = CameraErrorNoMem;
        shouldBeGrabbing = NO;
    }
    
    // Initialize image decoding
    
    if (shouldBeGrabbing && ![self setupDecoding]) 
    {
        error = CameraErrorDecoding;
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
                BOOL decodingOK = NO;
                
                [imageBufferLock lock]; // Lock image buffer access
                
                if (nextImageBuffer != NULL) 
                    decodingOK = [self decodeBuffer:&currentBuffer]; // Into nextImageBuffer
                
                if (decodingOK) 
                {
                    lastImageBuffer = nextImageBuffer; // Copy nextBuffer info into lastBuffer
                    lastImageBufferBPP = nextImageBufferBPP;
                    lastImageBufferRowBytes = nextImageBufferRowBytes;
                    nextImageBufferSet = NO;  // nextBuffer has been eaten up
                }
                
                [imageBufferLock unlock]; // Release lock
                
                if (decodingOK) 
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
    
    CGContextDrawImage(CocoaDecoding.imageContext, CocoaDecoding.rect, image);
    
    CGContextFlush(CocoaDecoding.imageContext);
    
    CGDataProviderRelease(provider);
    CGImageRelease(image);
    
    [LUT processImageRep:CocoaDecoding.imageRep 
                  buffer:nextImageBuffer 
                 numRows:[self height] 
                rowBytes:nextImageBufferRowBytes 
                     bpp:nextImageBufferBPP];
}


- (void) decodeBufferQuicktimeImage: (GenericChunkBuffer *) buffer
{
    OSErr err;
    GWorldPtr gw;
    CGrafPtr oldPort;
    GDHandle oldGDev;
    
    err = QTNewGWorldFromPtr(&gw, (nextImageBufferBPP == 4) ? k32ARGBPixelFormat : k24RGBPixelFormat,
                             &QuicktimeDecoding.boundsRect,
                             NULL, NULL, 0,
                             nextImageBuffer,
                             nextImageBufferRowBytes);
    if (err) 
        return;
    
    (**QuicktimeDecoding.imageDescription).dataSize = buffer->numBytes;
    
    GetGWorld(&oldPort,&oldGDev);
    SetGWorld(gw, NULL);
    
    err = DecompressImage((Ptr) (buffer->buffer), 
                          QuicktimeDecoding.imageDescription,
                          GetGWorldPixMap(gw), 
                          NULL, 
                          &QuicktimeDecoding.boundsRect, 
                          srcCopy, NULL);
    
    SetGWorld(oldPort, oldGDev);
    DisposeGWorld(gw);
}

/*
- (void) decodeBufferQuicktimeImageSaved: (GenericChunkBuffer *) buffer
{
    OSErr err;
    CGrafPtr oldPort;
    GDHandle oldGDev;
    
    (**QuicktimeDecoding.imageDescription).dataSize = buffer->numBytes - decodingSkipBytes;
    
    GetGWorld(&oldPort,&oldGDev);
    SetGWorld(QuicktimeDecoding.gworldPtr, NULL);
    
    err = DecompressImage(buffer->buffer + decodingSkipBytes, QuicktimeDecoding.imageDescription,
                    GetGWorldPixMap(QuicktimeDecoding.gworldPtr), 
                    &QuicktimeDecoding.boundsRect, 
                    &QuicktimeDecoding.boundsRect, 
                    srcCopy, NULL);
    
    SetGWorld(oldPort,oldGDev);
    
    [LUT processImageRep:QuicktimeDecoding.imageRep 
                  buffer:nextImageBuffer 
                 numRows:[self height] 
                rowBytes:nextImageBufferRowBytes 
                     bpp:nextImageBufferBPP];
}
*/

- (void) decodeBufferQuicktimeSequence: (GenericChunkBuffer *) buffer
{
    OSErr err;
    
    err = DecompressSequenceFrameS(SequenceDecoding.sequenceIdentifier, 
                             (Ptr) (buffer->buffer + decodingSkipBytes),
                             buffer->numBytes - decodingSkipBytes, 0, NULL, NULL);
    
    [LUT processImageRep:QuicktimeDecoding.imageRep 
                  buffer:nextImageBuffer 
                 numRows:[self height] 
                rowBytes:nextImageBufferRowBytes 
                     bpp:nextImageBufferBPP];
}

- (void) decodeBufferJPEG: (GenericChunkBuffer *) buffer
{
    NSLog(@"Oops: [decodeBufferJPEG] needs to be implemented in current driver!");
}

- (void) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
    NSLog(@"Oops: [decodeBufferProprietary] needs to be implemented in current driver!");
}

//
// Decode the chunk buffer into the nextImageBuffer
// This *must* be subclassed as the decoding is camera dependent
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
    BOOL ok = YES;
    GenericChunkBuffer newBuffer;
    
    if ((exactBufferLength > 0) && (exactBufferLength != buffer->numBytes)) 
        return NO;
    
#if REALLY_VERBOSE
    printf("decoding a chunk with %ld bytes\n", buffer->numBytes);
    if (0) 
    {
        int b;
        for (b = 0; b < 256; b += 8) 
            printf("buffer[%3d..%3d] = 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", b, b+7, buffer->buffer[b+0], buffer->buffer[b+1], buffer->buffer[b+2], buffer->buffer[b+3], buffer->buffer[b+4], buffer->buffer[b+5], buffer->buffer[b+6], buffer->buffer[b+7]);
    }
#endif
    
    newBuffer.numBytes = buffer->numBytes - decodingSkipBytes;
    newBuffer.buffer = buffer->buffer + decodingSkipBytes;
    
    if (compressionType == jpegCompression) 
    {
        switch (jpegVersion) 
        {
            case 0:
                [self decodeBufferJPEG:&newBuffer];
                break;
                
            default:
                NSLog(@"GenericDriver - decodeBuffer encountered unknown jpegVersion (%i)", jpegVersion);
            case 2:
            case 1:
                [self decodeBufferCocoaJPEG:&newBuffer];
                break;
        }
    }
    else if (compressionType == quicktimeImage) 
    {
        [self decodeBufferQuicktimeImage:&newBuffer];
    }
    else if (compressionType == quicktimeSequence) 
    {
        [self decodeBufferQuicktimeSequence:&newBuffer];
    }
    else if (compressionType == noCompression) 
    {
        // ???
    }
    else if (compressionType == proprietaryCompression) 
    {
        [self decodeBufferProprietary:&newBuffer];
    }
    else 
        NSLog(@"GenericDriver - decodeBuffer must be implemented");
    
    return ok;
}

@end

// Some web-references for QuickTime image decoding
//
// The Image Description structure
// http://developer.apple.com/documentation/QuickTime/RM/CompressDecompress/ImageComprMgr/F-Chapter/chapter_1000_section_15.html
//
// http://developer.apple.com/documentation/QuickTime/Rm/CompressDecompress/ImageComprMgr/G-Chapter/chapter_1000_section_5.html#//apple_ref/doc/uid/TP40000878-HowtoCompressandDecompressSequencesofImages-ASampleProgramforCompressingandDecompressingaSequenceofImages
// http://developer.apple.com/quicktime/icefloe/dispatch008.html
// http://www.extremetech.com/article2/0,1697,1843577,00.asp
// http://www.cs.cf.ac.uk/Dave/Multimedia/node292.html
// http://developer.apple.com/documentation/QuickTime/RM/Fundamentals/QTOverview/QTOverview_Document/chapter_1000_section_2.html
// http://developer.apple.com/documentation/QuickTime/Rm/CompressDecompress/ImageComprMgr/A-Intro/chapter_1000_section_1.html
// http://homepage.mac.com/gregcoats/jp2.html
// http://www.google.com/search?client=safari&rls=en&q=quicktime+decompress+image+sample+code&ie=UTF-8&oe=UTF-8
// 
