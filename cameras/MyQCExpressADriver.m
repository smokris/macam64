/*
 MyQCExpressADriver.m - macam camera driver class for QuickCam Express (STV600)

 Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 $Id$
*/

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#import "MyCameraCentral.h"
#import "MyQCExpressADriver.h"
#import "Resolvers.h"
#import "yuv2rgb.h"
#include "MiscTools.h"
#import "MyPB0100Sensor.h"
#import "MyHDCS1000Sensor.h"
#import "MyHDCS1020Sensor.h"
#import "MyVV6410Sensor.h"
#include "unistd.h"

@interface MyQCExpressADriver (Private)

- (BOOL) setupGrabContext;				//Sets up the grabContext structure for the usb async callbacks
- (BOOL) cleanupGrabContext;				//Cleans it up
- (void) read:(id)data;			//Entry method for the usb data grabbing thread
- (void) decodeChunk:(STV600ChunkBuffer*)chunk;

- (BOOL) camBoot;
- (BOOL) camInit;
- (BOOL) camStartStreaming;
- (BOOL) camStopStreaming;

@end

@implementation MyQCExpressADriver

+ (unsigned short) cameraUsbProductID { return 0x840; }
+ (unsigned short) cameraUsbVendorID { return 0x46d; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"QuickCam Express"]; }

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId {
    CameraError err=[self usbConnectToCam:usbLocationId configIdx:0];
    if (err!=CameraErrorOK) return err;
    memset(&grabContext,0,sizeof(STV600GrabContext));
    if (![self camBoot]) return CameraErrorUnimplemented;
    bayerConverter=[[BayerConverter alloc] init];
    [bayerConverter setSourceFormat:2];
    [self setBrightness:0.5f];
    [self setContrast:0.5f];
    [self setSaturation:0.5f];
    [self setGamma:0.5f];
    [self setGain:0.0f];
    [self setShutter:1.0f];
    [self setSharpness:1.0f];
    [self setAutoGain:YES];
    extraBytesInLine=0;
    return [super startupWithUsbLocationId:usbLocationId];
}

- (void) dealloc {
    if (bayerConverter) [bayerConverter release];
    [self usbCloseConnection];
    [super dealloc];
}

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    BOOL rOK=((r==ResolutionQCIF)||(r==ResolutionCIF));
    BOOL frOK=(fr==5);
    return (rOK&&frOK);
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {	//This is a start
    if (dFps) *dFps=5;
    return ResolutionCIF;
}

- (void) setResolution:(CameraResolution)r fps:(short)fr {
    [super setResolution:r fps:fr];
    [bayerConverter setSourceWidth:[self width] height:[self height]];
    [bayerConverter setDestinationWidth:[self width] height:[self height]];
}

- (BOOL) canSetBrightness { return YES; }

- (void) setBrightness:(float)v {
    [super setBrightness:v];
    [bayerConverter setBrightness:brightness*2.0f-1.0f];
}

- (BOOL) canSetContrast { return YES; }

- (void) setContrast:(float)v {
    [super setContrast:v];
    [bayerConverter setContrast:contrast*2.0f];
}

- (BOOL) canSetSaturation { return YES; }

- (void) setSaturation:(float)v {
    [super setSaturation:v];
    [bayerConverter setSaturation:saturation*2.0f];
}

- (BOOL) canSetGamma  { return YES; }

- (void) setGamma:(float)v {
    [super setGamma:v];
    [bayerConverter setGamma:gamma*2.0f];
}

- (BOOL) canSetSharpness  { return YES; }

- (void) setSharpness:(float)v {
    [super setSharpness:v];
    [bayerConverter setSharpness:sharpness];
}

- (BOOL) canSetGain { return YES; }

- (void) setGain:(float)v {
    [super setGain:v];
    [sensor adjustExposure];
}

- (BOOL) canSetShutter { return YES; }

- (void) setShutter:(float)v {
    [super setShutter:v];
    [sensor adjustExposure];
}

- (BOOL) canSetAutoGain { return YES; }

- (void) setAutoGain:(BOOL)ag {
    [super setAutoGain:ag];
    [bayerConverter setMakeImageStats:ag];
    if (!autoGain) [sensor adjustExposure];	//Make sure they are correct
}

- (BOOL) canSetHFlip {
    return YES;
}

- (BOOL) canSetWhiteBalanceMode { return YES; }

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode {
    BOOL ok=YES;
    switch (newMode) {
        case WhiteBalanceLinear:
        case WhiteBalanceIndoor:
        case WhiteBalanceOutdoor:
        case WhiteBalanceAutomatic:
            break;
        default:
            ok=NO;
            break;
    }
    return ok;
}

- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode {
    [super setWhiteBalanceMode:newMode];
    switch (whiteBalanceMode) {
        case WhiteBalanceLinear:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:1.0f green:1.0f blue:1.0f];
            break;
        case WhiteBalanceIndoor:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:0.94f green:0.96f blue:1.1f];
            break;
        case WhiteBalanceOutdoor:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:1.12f green:0.95f blue:0.93f];
            break;
        case WhiteBalanceAutomatic:
            [bayerConverter setGainsDynamic:YES];
            break;
        case WhiteBalanceManual:
            // not handled yet
            break;
    }
}

- (BOOL) setupGrabContext {
    long i;
    AbsoluteTime at;
    IOReturn err;

    BOOL ok=YES;
    [self cleanupGrabContext];					//cleanup in case there's something left in here

//Simple things first
    grabContext.bytesPerFrame=1023;				//***
    grabContext.chunkBufferLength=[self width]*[self height]*3+100;	//That should be more than enough ***
    grabContext.numEmptyBuffers=0;
    grabContext.numFullBuffers=0;
    grabContext.fillingChunk=false;
    grabContext.finishedTransfers=0;
    grabContext.intf=streamIntf;
    grabContext.shouldBeGrabbing=&shouldBeGrabbing;
    grabContext.err=CameraErrorOK;
    grabContext.framesSinceLastChunk=0;
//Note: There's no danger of random memory pointers in the structs since we call [cleanupGrabContext] before
    
//Allocate the locks
    if (ok) {					//alloc and init the locks
        grabContext.chunkListLock=[[NSLock alloc] init];
        if ((grabContext.chunkListLock)==NULL) ok=NO;
    }
    if (ok) {
        grabContext.chunkReadyLock=[[NSLock alloc] init];
        if ((grabContext.chunkReadyLock)==NULL) ok=NO;
        else {					//locked by standard, will be unlocked by isocComplete
            [grabContext.chunkReadyLock tryLock];
        }
    }
//get the chunk buffers
    for (i=0;(i<STV600_NUM_CHUNK_BUFFERS)&&(ok);i++) {
        MALLOC(grabContext.emptyChunkBuffers[i].buffer,unsigned char*,grabContext.chunkBufferLength,"STV600 chunk buffers");
        if (grabContext.emptyChunkBuffers[i].buffer) grabContext.numEmptyBuffers++;
        else ok=NO;
    }
//get the transfer buffers
    for (i=0;(i<STV600_NUM_TRANSFERS)&&(ok);i++) {
        MALLOC(grabContext.transferContexts[i].buffer,unsigned char*,grabContext.bytesPerFrame*STV600_FRAMES_PER_TRANSFER,"STV600 transfer buffers");
        if (!(grabContext.transferContexts[i].buffer)) ok=NO;
        else {
            long j;
            for (j=0;j<STV600_FRAMES_PER_TRANSFER;j++) {	//init frameList
                grabContext.transferContexts[i].frameList[j].frReqCount=grabContext.bytesPerFrame;
                grabContext.transferContexts[i].frameList[j].frActCount=0;
                grabContext.transferContexts[i].frameList[j].frStatus=0;
            }
        }
    }
    //Get usb timing info
    if (ok) {
        err=(*streamIntf)->GetBusFrameNumber(streamIntf, &(grabContext.initiatedUntil), &at);
        CheckError(err,"GetBusFrameNumber");
        if (err) ok=NO;
        grabContext.initiatedUntil+=50;	//give it a little time to start
    }
    if (!ok) [self cleanupGrabContext];				//We failed. Throw away the garbage
    return ok;
}

- (BOOL) cleanupGrabContext {
/* We just free allocated memory, but don't clear the other fields any more. this is since there are fields (currently, err) that are used after the context has been cleaned up to get info about the last grab */
    long i;
    if (grabContext.chunkListLock)  [grabContext.chunkListLock release];	//release lock
    grabContext.chunkListLock=NULL;
    if (grabContext.chunkReadyLock) [grabContext.chunkReadyLock release];	//release lock
    grabContext.chunkReadyLock=NULL;
    for (i=0;i<grabContext.numEmptyBuffers;i++) {
        if (grabContext.emptyChunkBuffers[i].buffer) FREE(grabContext.emptyChunkBuffers[i].buffer,"empty chunk buffers");
        grabContext.emptyChunkBuffers[i].buffer=NULL;
    }
    grabContext.numEmptyBuffers=0;
    for (i=0;i<grabContext.numFullBuffers;i++) {
        if (grabContext.fullChunkBuffers[i].buffer) FREE(grabContext.fullChunkBuffers[i].buffer,"full chunk buffers");
        grabContext.fullChunkBuffers[i].buffer=NULL;
    }
    grabContext.numFullBuffers=0;
    if ((grabContext.fillingChunkBuffer.buffer)&&(grabContext.fillingChunk)) {
        FREE(grabContext.fillingChunkBuffer.buffer,"filling chunk buffer");
        grabContext.fillingChunkBuffer.buffer=NULL;
        grabContext.fillingChunk=false;
    }
    
    for (i=0;(i<STV600_NUM_TRANSFERS)&&(ok);i++) {
        if (grabContext.transferContexts[i].buffer) {
            FREE(grabContext.transferContexts[i].buffer,"transfer buffer");
            grabContext.transferContexts[i].buffer=NULL;
        }
    }
    return YES;
}

void GetFillingChunk(STV600GrabContext* gCtx) {
	//Make sure there is a filling buffer
    if (gCtx->fillingChunk)
	{
        gCtx->fillingChunkBuffer.numBytes=0;
    }
	else
	{
        [gCtx->chunkListLock lock];			//Get permission to manipulate buffer lists
        if (gCtx->numEmptyBuffers>0)
		{			//We can take an empty chunk
            gCtx->numEmptyBuffers--;
            gCtx->fillingChunkBuffer=gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers];
        }
		else
		{					//No empty chunk - take the oldest full one
            long j;
            gCtx->fillingChunkBuffer=gCtx->fullChunkBuffers[0];
            for (j=1;j<gCtx->numFullBuffers;j++)
			{	//all other full ones go one up in the list
                gCtx->fullChunkBuffers[j-1]=gCtx->fullChunkBuffers[j];
            }
            gCtx->numFullBuffers--;
        }
        gCtx->fillingChunk=true;
        [gCtx->chunkListLock unlock];			//Done manipulating buffer lists
        gCtx->fillingChunkBuffer.numBytes=0;
    }    
}

void FinishFillingChunk(STV600GrabContext* gCtx) {	//Put the filling chunk to the full ones and notify decodingThread
    if (!(gCtx->fillingChunk)) return;
    [gCtx->chunkListLock lock];				//Get permission to manipulate chunk lists
    gCtx->fullChunkBuffers[gCtx->numFullBuffers]=gCtx->fillingChunkBuffer;
    gCtx->numFullBuffers++;				//our fresh chunk has been added to the full ones
    gCtx->fillingChunk=false;
    gCtx->fillingChunkBuffer.buffer=NULL;		//it's redundant but to be safe...
    [gCtx->chunkListLock unlock];			//exit critical section
    [gCtx->chunkReadyLock tryLock];			//try to wake up the decoder
    [gCtx->chunkReadyLock unlock];
}

void DiscardFillingChunk(STV600GrabContext* gCtx) {	//Put the filling chunk back to the empty buffers
    if (!(gCtx->fillingChunk)) return;	
    [gCtx->chunkListLock lock];				//Get permission to manipulate buffer lists
    gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers]=gCtx->fillingChunkBuffer;
    gCtx->numEmptyBuffers++;
    gCtx->fillingChunk=false;
    gCtx->fillingChunkBuffer.buffer=NULL;		//it's redundant but to be safe...
    [gCtx->chunkListLock unlock];			//Done manipulating buffer lists
}

//StartNextIsochRead and isocComplete refer to each other, so here we need a declaration
static bool StartNextIsochRead(STV600GrabContext* grabContext, int transferIdx);

static void isocComplete(void *refcon, IOReturn result, void *arg0) {
    int i;
    STV600GrabContext* gCtx=(STV600GrabContext*)refcon;
    IOUSBIsocFrame* myFrameList=(IOUSBIsocFrame*)arg0;
    short transferIdx=0;
    bool frameListFound=false;
    unsigned char* frameBase;
    long frameRun;
    long dataRunCode;
    long dataRunLength;
    
    
    gCtx->framesSinceLastChunk+=STV600_FRAMES_PER_TRANSFER;
    
    // USB error handling
    switch (result) {
        case 0:
            // no error is fine with us :-)
            break;
            
        case kIOReturnUnderrun:
        case kIOUSBNotSent2Err:
        case kIOReturnIsoTooOld:
            // ignore these errors
            result = 0;
            break;
            
        case kIOReturnOverrun:
            // we didn't setup the transfer in time
            *(gCtx->shouldBeGrabbing) = NO;
            if (! gCtx->err)
                gCtx->err=CameraErrorTimeout;		
                break;
            
        default:
            *(gCtx->shouldBeGrabbing) = NO;
            if (!gCtx->err)
                gCtx->err=CameraErrorUSBProblem;
                
                // log to console
                CheckError(result,"isocComplete");
	}
    
    if (*(gCtx->shouldBeGrabbing)) {
        //look up which transfer we are
        while ((!frameListFound)&&(transferIdx<STV600_NUM_TRANSFERS)) {
            if ((gCtx->transferContexts[transferIdx].frameList)==myFrameList) frameListFound=true;
            else transferIdx++;
        }
        
        if (!frameListFound) {
#ifdef VERBOSE
            NSLog(@"isocComplete: Didn't find my frameList");
#endif
            *(gCtx->shouldBeGrabbing)=NO;
        }
    }
    
    if (*(gCtx->shouldBeGrabbing)) {
        //let's have a look into the usb frames we got
        for (i=0;i<STV600_FRAMES_PER_TRANSFER;i++) {
            // cache this - it won't change and we need it several times
            const long currFrameLength = myFrameList[i].frActCount;
            
            frameRun=0;
            frameBase=gCtx->transferContexts[transferIdx].buffer+gCtx->bytesPerFrame*i;
            
            while (frameRun<currFrameLength) {
                dataRunCode    = (frameBase[frameRun]  <<8)+frameBase[frameRun+1];
                dataRunLength  = (frameBase[frameRun+2]<<8)+frameBase[frameRun+3];
                frameRun      += 4;
                
                switch (dataRunCode) {
                    case 0x8005:	//Start of image chunk - sensor change pending (???)
                    case 0xc001:	//Start of image chunk - some exposure error (???)
                    case 0xc005:	//Start of image chunk - some exposure error (???)
                                 //						NSLog (@"flagged start chunk");
                    case 0x8001:	//Start of image chunk
                        GetFillingChunk(gCtx);
                        break;
                    case 0x8006:	//End of image chunk - sensor change pending (???)
                    case 0xc002:	//End of image chunk - some exposure error (???)
                    case 0xc006:	//End of image chunk - some exposure error (???)
                                 //						NSLog (@"flagged end chunk");
                    case 0x8002:	//End of image chunk
                        gCtx->framesSinceLastChunk=0;
                        FinishFillingChunk(gCtx);
                        break;
                    case 0x4200:	//Data run with some flag set (lighting? timing?)
                                 //						NSLog (@"flagged data chunk");
                    case 0x0200:	//Data run
                        if (gCtx->fillingChunk) {
                            if (gCtx->fillingChunkBuffer.numBytes+dataRunLength<=gCtx->chunkBufferLength) {
                                // copy the data run to our chunk
                                memcpy (gCtx->fillingChunkBuffer.buffer
                                        + gCtx->fillingChunkBuffer.numBytes,
                                        frameBase+frameRun,
                                        dataRunLength);
                                gCtx->fillingChunkBuffer.numBytes+=dataRunLength;
                            } else {
                                //Buffer Overflow
                                NSLog (@"buffer overflow");
                                DiscardFillingChunk(gCtx);
                            }
                        }
                        break;
                    default:
                        NSLog(@"unknown chunk %04x, length: %i",(unsigned short)dataRunCode,dataRunLength);
                        if (dataRunLength) DumpMem(frameBase+frameRun,dataRunLength);
                            break;
                } 
                frameRun+=dataRunLength;
            }
        }
    }
    
    if (gCtx->framesSinceLastChunk>1000) {
        // more than a second without data?
        *(gCtx->shouldBeGrabbing)=NO;
        if (!gCtx->err) gCtx->err=CameraErrorUSBProblem;
    }
    
    if (*(gCtx->shouldBeGrabbing)) {
        // initiate next transfer
        if (!StartNextIsochRead(gCtx,transferIdx)) *(gCtx->shouldBeGrabbing)=NO;
    }
    
    if (!(*(gCtx->shouldBeGrabbing))) {
        // on error: collect finished transfers and exit if all transfers have ended
        gCtx->finishedTransfers++;
        if ((gCtx->finishedTransfers)>=(STV600_NUM_TRANSFERS)) {
            CFRunLoopStop(CFRunLoopGetCurrent());
        }
    }
}

static bool StartNextIsochRead(STV600GrabContext* grabContext, int transferIdx) {
    IOReturn err;
    err=(*(grabContext->intf))->ReadIsochPipeAsync(grabContext->intf,
                                                   1,
                                                   grabContext->transferContexts[transferIdx].buffer,
                                                   grabContext->initiatedUntil,
                                                   STV600_FRAMES_PER_TRANSFER,
                                                   grabContext->transferContexts[transferIdx].frameList,
                                                   (IOAsyncCallback1)(isocComplete),
                                                   grabContext);
    switch (err) {
        case 0:
            grabContext->initiatedUntil+=STV600_FRAMES_PER_TRANSFER;	//update frames
            break;
        case 0x1000003:
            if (!grabContext->err)
				grabContext->err=CameraErrorNoCam;
            break;
        default:
            CheckError(err,"StartNextIsochRead-ReadIsochPipeAsync");
            if (!grabContext->err)
				grabContext->err=CameraErrorUSBProblem;
            break;
    }
    return !err;
}

- (void) grabbingThread:(id)data
{
    NSAutoreleasePool   * pool=[[NSAutoreleasePool alloc] init];
    long                  i;
    IOReturn              err;
    CFRunLoopSourceRef    cfSource;
    BOOL                  ok=YES;

    ChangeMyThreadPriority(10);	//We need to update the isoch read in time, so timing is important for us

    if (ok)
	{
        if (![self usbSetAltInterfaceTo:1 testPipe:1])
		{	//*** Check this for QuickCam Express! was alt 3!
            if (!grabContext.err)
				grabContext.err=CameraErrorNoBandwidth;
            ok=NO;
        }
    }
    if (ok)
	{
        if (![self camInit])
		{
            if (!grabContext.err) grabContext.err=CameraErrorUSBProblem;
            ok=NO;
        }
    }
    if (ok) {
        [sensor adjustExposure];
        if (![sensor startStream])
		{
            if (!grabContext.err) grabContext.err=CameraErrorUSBProblem;
            ok=NO;
        }
    }
    if (ok)
	{
        if (![self writeSTVRegister:0x1440 value:1]) {
            if (!grabContext.err) grabContext.err=CameraErrorUSBProblem;
            ok=NO;
        }
    }

    if (ok) {
        err = (*streamIntf)->CreateInterfaceAsyncEventSource(streamIntf, &cfSource);	//Create an event source
        CheckError(err,"CreateInterfaceAsyncEventSource");
        CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//Add it to our run loop
        for (i=0;(i<STV600_NUM_TRANSFERS)&&ok;i++) {	//Initiate transfers
            ok=StartNextIsochRead(&grabContext,i);
        }
    }
    if (ok)
	{
        CFRunLoopRun();					//Do our run loop
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//remove the event source
    }

    shouldBeGrabbing=NO;	//error in grabbingThread or abort? initiate shutdown of everything else

    //Stopping doesn't check for ok any more - clean up what we can
    if (![self writeSTVRegister:0x1440 value:0]) {
        if (!grabContext.err) grabContext.err=CameraErrorUSBProblem;
        ok=NO;
    }

    if (![sensor stopStream])
	{
        if (!grabContext.err) grabContext.err=CameraErrorUSBProblem;
        ok=NO;
    }

    if (![self usbSetAltInterfaceTo:0 testPipe:0])
	{
        if (!grabContext.err) grabContext.err=CameraErrorUSBProblem;
        ok=NO;
    }

    [grabContext.chunkReadyLock unlock];	//give the decodingThread a chance to abort
    [pool release];
    grabbingThreadRunning=NO;
    [NSThread exit];
}

- (CameraError) decodingThread
{
    STV600ChunkBuffer  currChunk;
    CameraError        err = CameraErrorOK;

    grabbingThreadRunning = NO;

    if (![self setupGrabContext])
    {
        err = CameraErrorNoMem;
        shouldBeGrabbing=NO;
    }

    if (shouldBeGrabbing)
    {
        grabbingThreadRunning=YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];    //start grabbingThread
    }


    while (shouldBeGrabbing)
    {
        // wait for ready-to-decode chunks
        [grabContext.chunkReadyLock lock];

        // decode new chunks or skip if we have stopped grabbing
        if ((grabContext.numFullBuffers>0)&&(shouldBeGrabbing))
        {
            // lock access to chunk list
            [grabContext.chunkListLock lock];

            // discard all but the newest new chunk
            currChunk = grabContext.fullChunkBuffers[--grabContext.numFullBuffers];
            for (;grabContext.numFullBuffers > 0; grabContext.numFullBuffers--)
                grabContext.emptyChunkBuffers[grabContext.numEmptyBuffers++] = grabContext.fullChunkBuffers[grabContext.numFullBuffers-1];

            // we're done accessing the chunk list.
            [grabContext.chunkListLock unlock];

            // do the work
            [self decodeChunk:&currChunk];

            // lock for access to chunk list
            [grabContext.chunkListLock lock];

            // re-insert the used chunk buffer
            grabContext.emptyChunkBuffers[grabContext.numEmptyBuffers++]=currChunk;

            // we're done accessing the chunk list.
            [grabContext.chunkListLock unlock];
        }
    }

    // Active wait until grabbing thread stops
    while (grabbingThreadRunning) { usleep(100000); }

    // grabbingThread doesn't need the context any more since it's done
    [self cleanupGrabContext];

    // Forward decoding thread error if sensible
    if (!err) return grabContext.err;
    else return err;
}

- (void) decodeChunk:(STV600ChunkBuffer*) chunkBuffer {
    unsigned char  * bayerData = 0;
    
    // no need to decode
    if (!nextImageBufferSet) {
        NSLog (@"no next image buffer set");
        return;
    }
    
    // lock image buffer access
    [imageBufferLock lock];
    
    // check if an output buffer is available
    if (!nextImageBuffer)
    {
        // release lock
        [imageBufferLock unlock];
        NSLog (@"no next image buffer");
        return;
    }
    
    // quick-hack fix by Mark.Asbach
    //disabled because it causes trouble with QCWeb / VV6410 - mattik
    
    /*	if (resolution==ResolutionCIF)
        bayerData = chunkBuffer->buffer + 3;
    else
        */
    bayerData = chunkBuffer->buffer + 2;
    
    // convert the data
    [bayerConverter convertFromSrc: bayerData
                            toDest: nextImageBuffer
                       srcRowBytes: [self width] + extraBytesInLine
                       dstRowBytes: nextImageBufferRowBytes
                            dstBPP: nextImageBufferBPP
                              flip: hFlip
						 rotate180: NO];
    
    // advance buffer
    lastImageBuffer         = nextImageBuffer;
    lastImageBufferBPP      = nextImageBufferBPP;
    lastImageBufferRowBytes = nextImageBufferRowBytes;
    
    // nextBuffer has been eaten up
    nextImageBufferSet      = NO;				
    
    // release lock
    [imageBufferLock unlock];				
    
    // notify delegate about the image. perhaps get a new buffer
    [self mergeImageReady];
    
    // adapt gain if necessary
    if (autoGain) {
        [sensor setLastMeanBrightness: [bayerConverter lastMeanBrightness]];
        [sensor adjustExposure];
    }
}


- (BOOL) writeSTVRegister:(long)reg value:(unsigned char)val {
    return [self usbWriteCmdWithBRequest:4 wValue:(unsigned short)reg wIndex:0 buf:&val len:1];
}

- (BOOL) writeWideSTVRegister:(long)reg value:(unsigned short int)val {
	if ( [self writeSTVRegister:reg value:(val&0xff)] )
		return [self writeSTVRegister:(reg+1) value:((val>>8)&0xff)];
	else
		return NO;
}

- (BOOL) camBoot {
    if (![self writeSTVRegister:0x1440 value:0]) return NO;
    sensor=[[MyPB0100Sensor alloc] initWithCamera:self];
    if ([sensor checkSensor]) return YES;		//Sensor found and ok
    [sensor release];
    sensor=[[MyHDCS1000Sensor alloc] initWithCamera:self];
    if ([sensor checkSensor]) return YES;		//Sensor found and ok
    [sensor release];
    sensor=[[MyHDCS1020Sensor alloc] initWithCamera:self];
    if ([sensor checkSensor]) return YES;		//Sensor found and ok
    [sensor release];
    sensor=[[MyVV6410Sensor alloc] initWithCamera:self];
    if ([sensor checkSensor]) return YES;		//Sensor found and ok
    [sensor release];
    return NO;
}

- (BOOL) camInit {
    BOOL ok;
    UInt8 direction;
    UInt8 number;
    UInt8 transferType;
    UInt16 maxPacketSize;
    UInt8 interval;
    IOReturn err;
    
    ok=[self writeSTVRegister:0x1500 value:1];
    if (ok) ok=[self writeSTVRegister:0x1443 value:0]; // scan rate

    if (ok) ok=[sensor resetSensor];

    if (ok) {
        if (streamIntf&&isUSBOK) {
            err=(*streamIntf)->GetPipeProperties(streamIntf,1,&direction,&number,&transferType,&maxPacketSize,&interval);
            if (err) ok=NO;
        } else ok=NO;
    }

    if (ok) ok=[self writeWideSTVRegister:0x15c1 value:maxPacketSize];		//isoch frame size

    if (resolution==ResolutionCIF) {
        if (ok) ok=[self writeSTVRegister:0x1443 value:0x20];		//timing
        if (ok) ok=[self writeSTVRegister:0x1680 value:10];		//x subsampling
        if (ok) ok=[self writeSTVRegister:0x15c3 value:1];		//y subsampling
    } else {	//QCIF
        if (ok) ok=[self writeSTVRegister:0x1443 value:0x10];		//timing
        if (ok) ok=[self writeSTVRegister:0x1680 value:6];		//x subsampling
        if (ok) ok=[self writeSTVRegister:0x15c3 value:2];		//y subsampling
    }        
    return ok;
}

@end
