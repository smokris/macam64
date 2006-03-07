//
//  GenericDriver.m
//
//  macam - webcam app and QuickTime driver component
//  GenericDriver - generic driver for many cameras
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


#define JFIF_HEADER_LENGTH 0


@implementation GenericDriver


- (BOOL) startupGrabStream 
{
    // make the proper USB calls
    // if anything goes wrong, return NO
    
    return NO;
}


- (void) shutdownGrabStream 
{
    // make any necessary USB calls
}


- (void) cleanupGrabContext 
{
    int i;
    
    if (grabContext.chunkReadyLock) // cleanup chunk ready lock
    {
        [grabContext.chunkReadyLock release];
        grabContext.chunkReadyLock = NULL;
    }
    
    if (grabContext.chunkListLock) // cleanup chunk list lock
    {
        [grabContext.chunkListLock release];
        grabContext.chunkListLock = NULL;
    }
    
    for (i = 0; i < GENERIC_NUM_TRANSFERS; i++) // cleanup isoc buffers
    {
        if (grabContext.transferContexts[i].buffer) 
        {
            FREE(grabContext.transferContexts[i].buffer, "isoc data buffer");
            grabContext.transferContexts[i].buffer = NULL;
        }
    }
    for (i = grabContext.numEmptyBuffers-1; i>= 0; i--) // cleanup empty chunk buffers
    {
        if (grabContext.emptyChunkBuffers[i].buffer) 
        {
            FREE(grabContext.emptyChunkBuffers[i].buffer - JFIF_HEADER_LENGTH, "empty chunk buffer");
            grabContext.emptyChunkBuffers[i].buffer = NULL;
        }
    }
    
    grabContext.numEmptyBuffers = 0;
    
    for (i = grabContext.numFullBuffers-1; i >= 0; i--) // cleanup full chunk buffers
    {
        if (grabContext.fullChunkBuffers[i].buffer) 
        {
            FREE(grabContext.fullChunkBuffers[i].buffer - JFIF_HEADER_LENGTH, "full chunk buffer");
            grabContext.fullChunkBuffers[i].buffer = NULL;
        }
    }
    
    grabContext.numFullBuffers = 0;
    
    if (grabContext.fillingChunk) // cleanup filling chunk buffer
    {
        if (grabContext.fillingChunkBuffer.buffer) 
        {
            FREE(grabContext.fillingChunkBuffer.buffer - JFIF_HEADER_LENGTH, "filling chunk buffer");
            grabContext.fillingChunkBuffer.buffer = NULL;
        }
        grabContext.fillingChunk = false;
    }
}


- (BOOL) setupGrabContext 
{
    BOOL ok = YES;
    int i, j;
    
    // Clear things that have to be set back if init() fails
    
    grabContext.chunkReadyLock = NULL;
    grabContext.chunkListLock = NULL;
    
    for (i = 0; i < GENERIC_NUM_TRANSFERS; i++) 
    {
        grabContext.transferContexts[i].buffer = NULL;
    }
    
    // Setup simple things
    
    grabContext.bytesPerFrame = 1023;
    grabContext.finishedTransfers = 0;
    grabContext.intf = intf;
    grabContext.initiatedUntil = 0; // Will be set later (directly before start)
    grabContext.shouldBeGrabbing = &shouldBeGrabbing;
    grabContext.contextError = CameraErrorOK;
    grabContext.framesSinceLastChunk = 0;
    grabContext.chunkBufferLength = 2000000; // Should be safe for now. *** FIXME: Make a better estimate...
    grabContext.numEmptyBuffers = 0;
    grabContext.numFullBuffers = 0;
    grabContext.fillingChunk = false;
    
    // Setup JFIF header
/*    
    memcpy(pccamJfifHeader, JFIFHeaderTemplate, JFIF_HEADER_LENGTH);
    
    pccamJfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+0] = 480 / 256;
    pccamJfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+1] = 480 % 256;
    pccamJfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+2] = 640 / 256;
    pccamJfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+3] = 640 % 256;
    pccamJfifHeader[JFIF_YUVTYPE_OFFSET] = 0x22;
*/
/* 
    Set up the quantizing tables. 
    To be honest, this is unnecessary since we copy other quantizing tables later on 
    (in startupGrabStream). The reason for this is that different cameras have different 
    built-in quantizing table sets (for some really strange reason). 
    Think of this as a fallback - having a wrong quantizing table is better than
    having none at all...) 
 */
/*
    for (i = 0; i < 64; i++) 
    {
        pccamJfifHeader[JFIF_QTABLE0_OFFSET+i] = ZigZagY(pccamQTabIdx, i);
        pccamJfifHeader[JFIF_QTABLE1_OFFSET+i] = ZigZagUV(pccamQTabIdx, i);
    }
*/    
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
    
    if (ok) 
    {
        for (i = 0; ok && (i < GENERIC_NUM_TRANSFERS); i++) 
        {
            for (j = 0; j < GENERIC_FRAMES_PER_TRANSFER; j++) 
            {
                grabContext.transferContexts[i].frameList[j].frStatus = 0;
                grabContext.transferContexts[i].frameList[j].frReqCount = grabContext.bytesPerFrame;
                grabContext.transferContexts[i].frameList[j].frActCount = 0;
            }
            MALLOC(grabContext.transferContexts[i].buffer,
                   UInt8*,
                   GENERIC_FRAMES_PER_TRANSFER*grabContext.bytesPerFrame,
                   "isoc transfer buffer");
            if (grabContext.transferContexts[i].buffer == NULL) 
                ok = NO;
        }
    }
    
    for (i = 0; ok && (i < GENERIC_NUM_CHUNK_BUFFERS); i++) 
    {
        MALLOC(grabContext.emptyChunkBuffers[i].buffer, UInt8*, grabContext.chunkBufferLength + JFIF_HEADER_LENGTH, "Chunk buffer");
        if (grabContext.emptyChunkBuffers[i].buffer == NULL) 
            ok = NO;
        else 
            grabContext.numEmptyBuffers = i+1;
    }
    
/* 
    The chunk buffers will later be prefilled with the JPEG header. 
    We cannot do this here since we don't have the exact JPEG header yet. 
    We obtain the correct quantizing tables at the end of [startupGrabStream].
    But we can make sure that nothing bad can happen then...
*/
    if (!ok) 
    {
        NSLog(@"setupGrabContext failed");
        [self cleanupGrabContext];
    }
    
    return ok;
}


// Forward declaration
static bool StartNextIsochRead(GenericGrabContext * gCtx, int transferIdx);


static void isocComplete(void * refcon, IOReturn result, void * arg0) 
{
    int i;
    GenericGrabContext * gCtx = (GenericGrabContext *) refcon;
    IOUSBIsocFrame * myFrameList = (IOUSBIsocFrame *) arg0;
    short transferIdx = 0;
    bool frameListFound = false;
    long currFrameLength;
    UInt8 * frameBase;
    
    // Handle result from isoc transfer
    
    switch (result) 
    {
        case 0: // No error -> alright
        case kIOReturnUnderrun: // Data hickup - not so serious
            result = 0;
            break;
            
        case kIOReturnOverrun:
        case kIOReturnTimeout:
            *(gCtx->shouldBeGrabbing) = NO;
            if (!(gCtx->contextError)) 
                gCtx->contextError = CameraErrorTimeout;
                break;
            
        default:
            *(gCtx->shouldBeGrabbing) = NO;
            if (!(gCtx->contextError)) 
                gCtx->contextError = CameraErrorUSBProblem;
                break;
    }
    CheckError(result, "isocComplete"); // Show errors (really needed here?)

    // Look up which transfer we are
    
    if (*(gCtx->shouldBeGrabbing)) 
    {
        while ((!frameListFound) && (transferIdx < GENERIC_NUM_TRANSFERS)) 
        {
            if ((gCtx->transferContexts[transferIdx].frameList) == myFrameList) 
                frameListFound = true;
            else 
                transferIdx++;
        }
        
        if (!frameListFound) 
        {
            NSLog(@"isocComplete: Didn't find my frameList");
            *(gCtx->shouldBeGrabbing) = NO;
            if (!(gCtx->contextError)) 
                gCtx->contextError = CameraErrorInternal;
        }
    }

    // Parse returned data
    
    if (*(gCtx->shouldBeGrabbing)) 
    {
        for (i = 0; i < GENERIC_FRAMES_PER_TRANSFER; i++) // Let's have a look into the usb frames we got
        {
            currFrameLength = myFrameList[i].frActCount; // Cache this - it won't change and we need it several times
            if (currFrameLength > 0) // If there is data in this frame
            {
                frameBase = gCtx->transferContexts[transferIdx].buffer + gCtx->bytesPerFrame * i;
                if (frameBase[0] == 0xff) // Invalid chunk?
                {
                    currFrameLength = 0;
                } 
                else if (frameBase[0]==0xfe) // Start of new chunk (image) ?
                {
                    if (gCtx->fillingChunk) // We were filling -> chunk done
                    {
                        // Pass the complete chunk to the full list
                        int j;
                        [gCtx->chunkListLock lock]; // Get access to the chunk buffers
                        for (j = gCtx->numFullBuffers-1; j >= 0; j--) // Move full buffers one up
                        {
                            gCtx->fullChunkBuffers[j+1] = gCtx->fullChunkBuffers[j];
                        }
                        gCtx->fullChunkBuffers[0] = gCtx->fillingChunkBuffer;	//Insert the filling one as newest
                        gCtx->numFullBuffers++;				//We have inserted one buffer
                        gCtx->fillingChunk = false;			//Now we're not filling (still in the lock to be sure no buffer is lost)
                        [gCtx->chunkReadyLock unlock];			//Wake up decoding thread
                        gCtx->framesSinceLastChunk = 0;			//reset watchdog
                    } 
                    else {						//There was no current filling chunk. Just get a new one.
                        [gCtx->chunkListLock lock];			//Get access to the chunk buffers
                    }
                    //We have the list access lock. Get a new buffer to fill.
                    if (gCtx->numEmptyBuffers>0) {			//There's an empty buffer to use
                        gCtx->numEmptyBuffers--;
                        gCtx->fillingChunkBuffer=gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers];
                    } else {						//No empty buffer: discard a full one (there are enough, both can't be empty)
                        gCtx->numFullBuffers--;
                        gCtx->fillingChunkBuffer=gCtx->fullChunkBuffers[gCtx->numFullBuffers];
                    }
                    gCtx->fillingChunk = true;				//Now we're filling (still in the lock to be sure no buffer is lost)
                    gCtx->fillingChunkBuffer.numBytes = 0;		//Start with empty buffer
                    [gCtx->chunkListLock unlock];			//Free access to the chunk buffers
                    frameBase += 10;					//Skip past header
                    currFrameLength -= 10;
                } 
                else // No new chunk start
                {
                    frameBase += 1; // Skip past header
                    currFrameLength -= 1;
                }
                
                if ((gCtx->fillingChunk) && (currFrameLength > 0)) 
                {
                    if (gCtx->chunkBufferLength-gCtx->fillingChunkBuffer.numBytes>(2*currFrameLength+2)) {	//There's plenty of space to receive data (*2 beacuse of escaping, +2 because of end tag)
                        // Copy and add 0x00 after each 0xff
                        int x,y;
                        UInt8 ch;
                        UInt8 * blitDst = gCtx->fillingChunkBuffer.buffer + gCtx->fillingChunkBuffer.numBytes;
                        
                        x = y = 0;
                        while (x<currFrameLength) 
                        {
                            ch=frameBase[x++];
                            blitDst[y++]=ch;
                            if (ch==0xff) blitDst[y++]=0x00;
                        }
                        gCtx->fillingChunkBuffer.numBytes+=y;
                    } 
                    else 
                    {						//Buffer is already full -> expect broken chunk -> discard
                        [gCtx->chunkListLock lock];			//Get access to the chunk buffers
                        gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers]=gCtx->fillingChunkBuffer;
                        gCtx->numEmptyBuffers++;
                        gCtx->fillingChunk=false;			//Now we're not filling (still in the lock to be sure no buffer is lost)
                        [gCtx->chunkListLock unlock];			//Free access to the chunk buffers
                    }
                }
            }
        }
        
        gCtx->framesSinceLastChunk += GENERIC_FRAMES_PER_TRANSFER;	//Count frames (not necessary to be too precise here...)
        if ((gCtx->framesSinceLastChunk) > 1000) //One second without a frame?
        {
            NSLog(@"SPCA5XX grab aborted because of invalid data stream");
            *(gCtx->shouldBeGrabbing)=NO;
            if (!gCtx->contextError) gCtx->contextError=CameraErrorUSBProblem;
        }
    }

    //initiate next transfer
    if (*(gCtx->shouldBeGrabbing)) {
        if (!StartNextIsochRead(gCtx,transferIdx)) *(gCtx->shouldBeGrabbing)=NO;
    }

    //Shutdown cleanup: Collect finished transfers and exit if all transfers have ended
    if (!(*(gCtx->shouldBeGrabbing))) {
        gCtx->finishedTransfers++;
        if ((gCtx->finishedTransfers)>=(GENERIC_NUM_TRANSFERS)) {
            CFRunLoopStop(CFRunLoopGetCurrent());
        }
    }
}


static bool StartNextIsochRead(GenericGrabContext * gCtx, int transferIdx) 
{
    IOReturn err;
    err = (* (gCtx->intf))->ReadIsochPipeAsync(gCtx->intf,
                                               1,
                                               gCtx->transferContexts[transferIdx].buffer,
                                               gCtx->initiatedUntil,
                                               GENERIC_FRAMES_PER_TRANSFER,
                                               gCtx->transferContexts[transferIdx].frameList,
                                               (IOAsyncCallback1) (isocComplete),
                                               gCtx);
    
    gCtx->initiatedUntil += GENERIC_FRAMES_PER_TRANSFER;
    
    switch (err) 
    {
        case 0:
            break;
        default:
            CheckError(err, "StartNextIsochRead-ReadIsochPipeAsync");
            if (!gCtx->contextError) 
                gCtx->contextError = CameraErrorUSBProblem;
                break;
    }
    
    return (err == 0);
}


- (void) grabbingThread:(id) data 
{
    NSAutoreleasePool * pool=[[NSAutoreleasePool alloc] init];
    long i;
    IOReturn error;
    CFRunLoopSourceRef cfSource;
    bool ok = true;
    
    ChangeMyThreadPriority(10);	// We need to update the isoch read in time, so timing is important for us
    
    // Put into startupGrabStream
    // Try to get as much bandwidth as possible?
    
    if (![self usbSetAltInterfaceTo:7 testPipe:1]) // This will be different for different cameras
    {
        if (!grabContext.contextError) 
            grabContext.contextError = CameraErrorNoBandwidth; // Probably no bandwidth
        ok = NO;
    }

    if (ok) 
        ok = [self startupGrabStream];
    
    // Get USB timing info
    
    if (ok) 
    {
        if (![self usbGetSoon:&(grabContext.initiatedUntil)]) 
        {
            shouldBeGrabbing = NO;
            if (!grabContext.contextError) 
                grabContext.contextError = CameraErrorUSBProblem; // Stall or so?
        }
    }
    
    if (ok) 
    {
        error = (*intf)->CreateInterfaceAsyncEventSource(intf, &cfSource); // Create an event source
        CheckError(error, "CreateInterfaceAsyncEventSource");
        CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode); // Add it to our run loop
        
        for (i = 0; ok && (i < GENERIC_NUM_TRANSFERS); i++) // Initiate transfers
            ok = StartNextIsochRead(&grabContext, i);
    }
    
    if (ok) 
    {
        CFRunLoopRun(); // Do our run loop
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode); // Remove the event source
    }
    
    // Stop the stream, reset the USB, close down 
    
    [self shutdownGrabStream];
    [self usbSetAltInterfaceTo:0 testPipe:0];
    
    shouldBeGrabbing = NO; // Error in grabbingThread or abort? initiate shutdown of everything else
    [grabContext.chunkReadyLock unlock]; // Give the decodingThread a chance to abort
    [pool release];
    grabbingThreadRunning = NO;
    [NSThread exit];
}


- (CameraError) decodingThread 
{
    CameraError error = CameraErrorOK;
    
    grabbingThreadRunning = NO;
    
    // Initialize
    
    if (![self setupGrabContext]) 
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
        
        while ((grabContext.numFullBuffers > 0) && (shouldBeGrabbing)) 
        {
            GenericChunkBuffer currentBuffer;	// The buffer to decode
            
            // Get a full buffer
            
            [grabContext.chunkListLock lock]; // Get access to the buffer lists
            grabContext.numFullBuffers--;	// There's always one since no one else can empty it completely
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
                nextImageBufferSet = NO; // nextBuffer has been eaten up
                [imageBufferLock unlock]; // Release lock
                
                [self mergeImageReady]; // Notify delegate about the image. Perhaps get a new buffer
            }
            
            // Put the buffer back to the empty ones
            
            [grabContext.chunkListLock lock]; // Get access to the buffer lists
            grabContext.emptyChunkBuffers[grabContext.numEmptyBuffers] = currentBuffer;
            grabContext.numEmptyBuffers++;
            [grabContext.chunkListLock unlock]; // Release access to the buffer lists            
        }

    }
    
    // Shutdown
    
    while (grabbingThreadRunning) // Wait for grabbingThread finish
    {
        usleep(10000); // We need to sleep here because otherwise the compiler would optimize the loop away
    }
    
    [self cleanupGrabContext];
    
    if (error = CameraErrorOK) 
        error = grabContext.contextError; // Return the error from the context instead
    
    return error;
}


- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
    NSLog(@"GenericDriver - decodeBuffer must be implemented");
}


@end
