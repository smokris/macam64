//
//  SPCA5XX.m
//
//  macam - webcam app and QuickTime driver component
//  SPCA5XX - driver for SPCA5XX-based cameras
//
//  Created by HXR on 9/19/05.
//  Copyright (C) 2005 HXR (hxr@users.sourceforge.net). 
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

#import "SPCA5XX.h"

#include <unistd.h>

#include "USB_VendorProductIDs.h"
#include "MiscTools.h"
#include "Resolvers.h"


#define JFIF_HEADER_LENGTH 0


@interface SPCA5XX (Private)

- (CameraError) startupGrabbing;
- (CameraError) shutdownGrabbing;

@end


@implementation SPCA5XX


void spca5xxRegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbReadCmdWithBRequest:reg 
                            wValue:value 
                            wIndex:index 
                               buf:buffer 
                               len:length];
}


void spca5xxRegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbWriteCmdWithBRequest:reg 
                             wValue:value 
                             wIndex:index 
                                buf:buffer 
                                len:length];
}


int spca50x_reg_write(struct usb_device * dev, __u16 reg, __u16 index, __u16 value)
{
    __u8 buf[16]; // not sure this is needed, but I'm hesitant to pass NULL
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    // No USB_DIR_OUT in original code!
    
    BOOL ok = [driver usbWriteCmdWithBRequest:reg 
                                       wValue:value 
                                       wIndex:index 
                                          buf:buf 
                                          len:0];
    
    return (ok) ? 0 : -1;
}


int spca50x_reg_read_with_value(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u16 length)
{
    __u8 buf[16]; // originally 4, should really check against length
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    BOOL ok = [driver usbReadCmdWithBRequest:reg 
                                       wValue:value 
                                       wIndex:index 
                                          buf:buf 
                                          len:0];
    
    return (ok) ? buf[0] + 256 * buf[1] + 256 * 256 * buf[2] + 256 * 256 * 256 * buf[3] : -1;
//    return *(int *)&buffer[0]; //  original code, non-portable because ofbyte ordering assumptions
}


/* 
 *   returns: negative is error, pos or zero is data
 */
int spca50x_reg_read(struct usb_device * dev, __u16 reg, __u16 index, __u16 length)
{
	return spca50x_reg_read_with_value(dev, reg, 0, index, length);
}


/*
 * Simple function to wait for a given 8-bit value to be returned from
 * a spca50x_reg_read call.
 * Returns: negative is error or timeout, zero is success.
 */
int spca50x_reg_readwait(struct usb_device * dev, __u16 reg, __u16 index, __u16 value)
{
	int count = 0;
	int result = 0;
    
	while (count < 20)
	{
		result = spca50x_reg_read(dev, reg, index, 1);
		if (result == value) 
            return 0;
        
//		wait_ms(50);
        usleep(50);
        
		count++;
	}
    
	return -1;
}


int spca50x_write_vector(struct usb_spca50x * spca50x, __u16 data[][3])
{
	struct usb_device * dev = spca50x->dev;
	int err_code;
    
	int I = 0;
	while ((data[I][0]) != (__u16) 0 || (data[I][1]) != (__u16) 0 || (data[I][2]) != (__u16) 0) 
	{
		err_code = spca50x_reg_write(dev, data[I][0], (__u16) (data[I][2]), (__u16) (data[I][1]));
		if (err_code < 0) 
		{ 
//			PDEBUG(1, "Register write failed for 0x%x,0x%x,0x%x", data[I][0], data[I][1], data[I][2]); 
			return -1; 
		}
		I++;
	}
    
	return 0;
}


// need meat here


- (id) initWithCentral:(id) c 
{
    self = [super initWithCentral:c];
    
    if (!self) 
        return NULL;
    
    spca5xx_struct = (struct usb_spca50x *) malloc(sizeof(struct usb_spca50x));
    spca5xx_struct->dev = (struct usb_device *) malloc(sizeof(struct usb_device));
    spca5xx_struct->dev->driver = self;
    
    bayerConverter = [[BayerConverter alloc] init];
    if (!bayerConverter) 
        return NULL;
        
    return self;
}


- (void) dealloc 
{
    [self spca5xx_shutdown];
    
    if (bayerConverter) 
    {
        [bayerConverter release]; 
        bayerConverter = NULL;
    }
    
    [super dealloc];
}


- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId 
{
    CameraError error;
    
    // Setup the connection to the camera
    
    error = [self usbConnectToCam:usbLocationId configIdx:0];
    
    if (error != CameraErrorOK) 
        return error;
    
    // 
    
    [self spca5xx_init];
    [self spca5xx_config];
    
    // Set some default parameters
    
    [self setBrightness:0.5];
    [self setContrast:0.5];
    [self setSaturation:0.5];
    [self setSharpness:0.5];
    [self setGamma: 0.5];
    
    // Do the remaining, usual connection stuff
    
    error = [super startupWithUsbLocationId:usbLocationId];
    
    return error;
}


//////////////////////////////////////
//
//  Image / camera properties can/set
//
//////////////////////////////////////


- (BOOL) canSetSharpness 
{
    return YES; // Perhaps ill-advised
}


- (void) setSharpness:(float) v 
{
    [super setSharpness:v];
    [bayerConverter setSharpness:sharpness];
}


- (BOOL) canSetBrightness 
{
     return YES;
}


- (void) setBrightness:(float) v 
{
    [self spca5xx_setbrightness];
    [super setBrightness:v];
    [bayerConverter setBrightness:brightness - 0.5f];
}


- (BOOL) canSetContrast 
{
    return YES;
}


- (void) setContrast:(float) v
{
    [self spca5xx_setcontrast];
    [super setContrast:v];
    [bayerConverter setContrast:contrast + 0.5f];
}


- (BOOL) canSetSaturation
{
    return YES;
}


- (void) setSaturation:(float) v
{
    [super setSaturation:v];
    [bayerConverter setSaturation:saturation * 2.0f];
}


- (BOOL) canSetGamma 
{
    return YES; // Perhaps ill-advised
}


- (void) setGamma:(float) v
{
    [super setGamma:v];
    [bayerConverter setGamma:gamma + 0.5f];
}


- (BOOL) canSetGain 
{
    return NO;
}


- (BOOL) canSetShutter 
{
    return NO;
}


// Gain and shutter combined
- (BOOL) canSetAutoGain 
{
    return NO;
}


- (void) setAutoGain:(BOOL) v
{
    if (v == autoGain) 
        return;
    
    [super setAutoGain:v];
    [bayerConverter setMakeImageStats:v];
}


- (BOOL) canSetHFlip 
{
    return YES;
}


- (short) maxCompression 
{
    return 0;
}


- (BOOL) canSetWhiteBalanceMode 
{
    return NO;
}


- (WhiteBalanceMode) defaultWhiteBalanceMode 
{
    return WhiteBalanceLinear;
}


- (BOOL) canBlackWhiteMode 
{
    return NO;
}


- (BOOL) canSetLed 
{
    return NO;
}


// use mode array from "config"
- (BOOL) supportsResolution:(CameraResolution) res fps:(short) rate 
{
//    spca5xx_struct;
    int mode;
    
    for (mode = QCIF; mode < TOTMODE; mode++) 
    {
        /*
         spca50x->mode_cam[CIF].width = 320;
         spca50x->mode_cam[CIF].height = 240;
         spca50x->mode_cam[CIF].t_palette = P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
         spca50x->mode_cam[CIF].pipe = 1023;
         spca50x->mode_cam[CIF].method = 1;
         spca50x->mode_cam[CIF].mode = 0;
*/         
    }
    
    if (rate > 30 || rate < 1) 
        return NO;
    
    if (res == ResolutionQSIF) 
        return YES;
    
    if (res == ResolutionSIF) 
        return YES;
    
    if (res == ResolutionVGA) 
        return YES;
    
    return NO;
}


- (CameraResolution) defaultResolutionAndRate:(short *) dFps 
{
    if (dFps) 
        *dFps = 5;
    
    return ResolutionSIF;
}




- (BOOL) startupGrabStream 
{
    // make the proper USB calls
    // if anything goes wrong, return NO
    [self spca5xx_start];
    
    return YES;
}


- (void) shutdownGrabStream 
{
    // make any necessary USB calls
    [self spca5xx_stop];
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



#if 0
//
// Do we really need a separate grabbing thread? Let's try without
// 
- (CameraError) decodingThread 
{
    CameraError error = CameraErrorOK;
    BOOL bufferSet, actualFlip;
    
    // Initialize grabbing
    
    error = [self startupGrabbing];
    
    if (error) 
        shouldBeGrabbing = NO;
    
    // Grab until told to stop
    
    if (shouldBeGrabbing) 
    {
        while (shouldBeGrabbing) 
        {
            // Get the data
            
//            [self readEntry:chunkBuffer len:chunkLength];
            
            // Get the buffer ready
            
            [imageBufferLock lock];
            
            lastImageBuffer = nextImageBuffer;
            lastImageBufferBPP = nextImageBufferBPP;
            lastImageBufferRowBytes = nextImageBufferRowBytes;
            
            bufferSet = nextImageBufferSet;
            nextImageBufferSet = NO;
            
            actualFlip = hFlip;
//          actualFlip = [self flipGrabbedImages] ? !hFlip : hFlip;
            
            // Decode into buffer
            
            if (bufferSet) 
            {
//              unsigned char * imageSource = (unsigned char *) (chunkBuffer + chunkHeader);
                unsigned char * imageSource = (unsigned char *) NULL;
                
                [bayerConverter convertFromSrc:imageSource
                                        toDest:lastImageBuffer
                                   srcRowBytes:[self width]
                                   dstRowBytes:lastImageBufferRowBytes
                                        dstBPP:lastImageBufferBPP
                                          flip:actualFlip
                                     rotate180:YES];
                
                [imageBufferLock unlock];
                [self mergeImageReady];
            } 
            else 
            {
                [imageBufferLock unlock];
            }
        }
    }
    
    // close grabbing
    
    [self shutdownGrabbing];
    
    return error;
}    
    

- (CameraError) startupGrabbing 
{
    CameraError error = CameraErrorOK;
    
    switch ([self resolution])
    {
        case ResolutionQSIF:
            break;
            
        case ResolutionSIF:
            break;
            
        case ResolutionVGA:
            break;
            
        default:
            break;
    }
    
    // Initialize Bayer decoder
    
    if (!error) 
    {
        [bayerConverter setSourceWidth:[self width] height:[self height]];
        [bayerConverter setDestinationWidth:[self width] height:[self height]];
        [bayerConverter setSourceFormat:4];
//      [bayerConverter setMakeImageStats:YES];
    }
    
    
    return error;
}


- (CameraError) shutdownGrabbing 
{
    CameraError error = CameraErrorOK;
    
//    free(chunkBuffer);
    
    return error;
}
#endif


#pragma mark ----- SPCA5XX Specific -----
#pragma mark -> Subclass Must Implement! <-

// The follwing must be implemented by subclasses of the SPCA5XX driver
// And hopefully it is simple, a simple call to a routine for each


// return int?
// turn off LED
// verify sensor
- (CameraError) spca5xx_init
{
    return CameraErrorUnimplemented;
}


// return int?
// get sensor and set up sensor mode array
// turn off power
// set bias
- (CameraError) spca5xx_config
{
    return CameraErrorUnimplemented;
}


// turn on power
// turn on LED
// initialize sensor
// setup image formats and compression

- (CameraError) spca5xx_start
{
    return CameraErrorUnimplemented;
}


// stop sending
// turn off LED
// turn off power
- (CameraError) spca5xx_stop
{
    return CameraErrorUnimplemented;
}


// turn off LED
// turn off power
- (CameraError) spca5xx_shutdown
{
    return CameraErrorUnimplemented;
}


// return brightness
- (CameraError) spca5xx_getbrightness
{
    return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_setbrightness
{
    return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_setAutobright
{
    return CameraErrorUnimplemented;
}


// return contrast??
- (CameraError) spca5xx_getcontrast
{
    return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_setcontrast
{
    return CameraErrorUnimplemented;
}



- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
    NSLog(@"GenericDriver - decodeBuffer must be implemented");
}


@end




@implementation SPCA5XX_SONIX


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        /*
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VISTA_PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Vista Plus", @"name", NULL], 
        */
        // Add more entries here
        
        NULL];
}

/*

static void sonixRegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{   
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbReadVICmdWithBRequest:reg 
                              wValue:value 
                              wIndex:index 
                                 buf:buffer 
                                 len:length];
}


static void sonixRegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 *buffer, __u16 length)
{
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbWriteVICmdWithBRequest:reg 
                               wValue:value 
                               wIndex:index 
                                  buf:buffer 
                                  len:length];
}


#include "sonix.h"

*/


// stuff


@end


// how about PDEBUG???

// define
void udelay(int delay_time_probably_micro_seconds)
{
    usleep(delay_time_probably_micro_seconds);
}


#pragma mark ----- PAC207 -----

@implementation PAC207


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VISTA_PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Vista Plus", @"name", NULL], 
        
        // Add more entries here
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x00], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Q-TEC Webcam 100 USB", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x01], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 01)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x02], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 02)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x03], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 03)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x04], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 04)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x05], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 05)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x06], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 06)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x07], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 07)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x08], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Common PixArt PAC207 based webcam", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x09], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 09)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0a)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0b)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0d)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0f)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x10], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Genius VideoCAM GE112 (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x11], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Genius KYE VideoCAM GE111 (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x12], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 12)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x13], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 13)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x14], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 14)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x15], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 15)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x16], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 16)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x17], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 17)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x18], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 18)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x19], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 19)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1a)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1b)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1d)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1f)", @"name", NULL], 
        
        NULL];
}


static void pac207RegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{   
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbReadVICmdWithBRequest:reg 
                              wValue:value 
                              wIndex:index 
                                 buf:buffer 
                                 len:length];
}


static void pac207RegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 *buffer, __u16 length)
{
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbWriteVICmdWithBRequest:reg 
                               wValue:value 
                               wIndex:index 
                                  buf:buffer 
                                  len:length];
}


#include "pac207.h"

// 


- (CameraError) spca5xx_init
{
    pac207_init(spca5xx_struct);
    return CameraErrorOK;
}



- (CameraError) spca5xx_config
{
    pac207_config(spca5xx_struct);
    return CameraErrorOK;
}


- (CameraError) spca5xx_start
{
    pac207_start(spca5xx_struct);
    return CameraErrorOK;
}


- (CameraError) spca5xx_stop
{
    pac207_stop(spca5xx_struct);
    return CameraErrorOK;
}


- (CameraError) spca5xx_shutdown
{
    pac207_shutdown(spca5xx_struct);
    return CameraErrorOK;
}


// brightness also returned in spca5xx_struct

- (CameraError) spca5xx_getbrightness
{
    pac207_getbrightness(spca5xx_struct);
    return CameraErrorOK;
}


// takes brightness from spca5xx_struct

- (CameraError) spca5xx_setbrightness
{
    pac207_setbrightness(spca5xx_struct);
    return CameraErrorOK;
}


// contrast also return in spca5xx_struct

- (CameraError) spca5xx_getcontrast
{
    pac207_getcontrast(spca5xx_struct);
    return CameraErrorOK;
}


// takes contrast from spca5xx_struct

- (CameraError) spca5xx_setcontrast
{
    pac207_setcontrast(spca5xx_struct);
    return CameraErrorOK;
}


// other stuff, including decompression


- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
    printf("Need to decode a buffer with %ld bytes.\n", buffer->numBytes);
    NSLog(@"PAC207 - decodeBuffer must be implemented");
}



@end



