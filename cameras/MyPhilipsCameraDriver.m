/*
    macam - webcam app and QuickTime driver component
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
#import "MyPhilipsCameraDriver.h"
#import "Resolvers.h"
#import "yuv2rgb.h"
#import "MiscTools.h"
#include "unistd.h"

//camera modes and the necessary data for them

@interface MyPhilipsCameraDriver (Private)

- (BOOL) setupGrabContext;				//Sets up the grabContext structure for the usb async callbacks
- (BOOL) cleanupGrabContext;				//Cleans it up
- (void) grabbingThread:(id)data;			//Entry method for the usb data grabbing thread

@end

@implementation MyPhilipsCameraDriver

//Class methods needed
+ (unsigned short) cameraUsbProductID { return 0; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_PHILIPS; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"abstract Philips generic camera"]; }

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err=[self usbConnectToCam:usbDeviceRef];
//setup connection to camera
     if (err!=CameraErrorOK) return err;
//set internals
    camHFlip=NO;			//Some defaults that can be changed during startup
    chunkHeader=0;
    chunkFooter=0;
//set camera video defaults
    [self setBrightness:0.5f];
    [self setContrast:0.5f];
    [self setGamma:0.5f];
    [self setSaturation:0.5f];
    [self setGain:0.5f];
    [self setShutter:0.5f];
    [self setAutoGain:YES];
    return [super startupWithUsbDeviceRef:usbDeviceRef];
}

- (void) dealloc {
    [self usbCloseConnection];
    [super dealloc];
}

- (BOOL) canSetBrightness { return YES; }
- (void) setBrightness:(float)v{
    UInt8 b;
    if (![self canSetBrightness]) return;
    b=TO_BRIGHTNESS(CLAMP_UNIT(v));
    if ((b!=TO_BRIGHTNESS(brightness)))
        [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_BRIGHTNESS wIndex:INTF_CONTROL buf:&b len:1];
    [super setBrightness:v];
}

- (BOOL) canSetContrast { return YES; }
- (void) setContrast:(float)v {
    UInt8 b;
    if (![self canSetContrast]) return;
    b=TO_CONTRAST(CLAMP_UNIT(v));
    if (b!=TO_CONTRAST(contrast))
        [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_CONTRAST wIndex:INTF_CONTROL buf:&b len:1];
    [super setContrast:v];
}

- (BOOL) canSetSaturation { return YES; }
- (void) setSaturation:(float)v {
    UInt8 b;
    if (![self canSetSaturation]) return;
    b=TO_SATURATION(CLAMP_UNIT(v));
    if (b!=TO_SATURATION(saturation))
        [self usbWriteCmdWithBRequest:GRP_SET_CHROMA wValue:SEL_SATURATION wIndex:INTF_CONTROL buf:&b len:1];
    [super setSaturation:v];
}

- (BOOL) canSetGamma { return YES; }
- (void) setGamma:(float)v {
    UInt8 b;
    if (![self canSetGamma]) return;
    b=TO_GAMMA(CLAMP_UNIT(v));
    if (b!=TO_GAMMA(gamma))
        [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_GAMMA wIndex:INTF_CONTROL buf:&b len:1];
    [super setGamma:v];
}

- (BOOL) canSetShutter { return YES; }
- (void) setShutter:(float)v {
    UInt8 b[2];
    if (![self canSetShutter]) return;
    b[0]=TO_SHUTTER(CLAMP_UNIT(v));
    if (b[0]!=TO_SHUTTER(shutter))
        [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_SHUTTER wIndex:INTF_CONTROL buf:b len:2];
    [super setShutter:v];
}

- (BOOL) canSetGain { return YES; }
- (void) setGain:(float)v {
    UInt8 b;
    if (![self canSetGain]) return;
    b=TO_GAIN(CLAMP_UNIT(v));
    if (b!=TO_GAIN(gain))
        [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_GAIN wIndex:INTF_CONTROL buf:&b len:1];
    [super setGain:v];
}

- (BOOL) canSetAutoGain { return YES; }
- (void) setAutoGain:(BOOL)v {
    UInt8 b;
    UInt8 gb;
    UInt8 sb[2];
    if (![self canSetAutoGain]) return;
    b=TO_AUTOGAIN(v);
    gb=TO_GAIN(gain);
    sb[0]=TO_SHUTTER(shutter);
    if (b!=TO_AUTOGAIN(autoGain)) {
        [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_AUTOGAIN wIndex:INTF_CONTROL buf:&b len:1];
        if (!v) {
            [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_GAIN wIndex:INTF_CONTROL buf:&gb len:1];
            [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_SHUTTER wIndex:INTF_CONTROL buf:sb len:2];
        }
    }
    [super setAutoGain:v];
}    

- (BOOL)canSetHFlip { return YES; }

- (WhiteBalanceMode) defaultWhiteBalanceMode { return WhiteBalanceAutomatic; }

- (void) setImageBuffer:(unsigned char*)buffer bpp:(short)bpp rowBytes:(long)rb{
    if (buffer==NULL) return;
    if ((bpp!=3)&&(bpp!=4)) return;
    if (rb<0) return;
    [super setImageBuffer:buffer bpp:bpp rowBytes:rb];
}


- (BOOL) setupGrabContext {
    long i,j;
    AbsoluteTime at;
    IOReturn err;

    BOOL ok=YES;
    [self cleanupGrabContext];					//cleanup in case there's something left in here

    grabContext.bytesPerFrame=usbFrameBytes;
    grabContext.framesPerTransfer=50;
    grabContext.framesInRing=1000;
    grabContext.concurrentTransfers=3;
    grabContext.finishedTransfers=0;
    grabContext.bytesPerChunk=[self height]*[self width]*6/4+chunkHeader+chunkFooter;	//4 yuv pixels fit into 4 bytes  + header + footer
    grabContext.nextReadOffset=0;
    grabContext.bufferLength=grabContext.bytesPerFrame*grabContext.framesInRing+grabContext.bytesPerChunk;
    grabContext.droppedFrames=0;
    grabContext.currentChunkStart=-1;
    grabContext.bytesInChunkSoFar=0;
    grabContext.maxCompleteChunks=3;
    grabContext.currCompleteChunks=0;
    grabContext.intf=intf;
    grabContext.shouldBeGrabbing=&shouldBeGrabbing;
    grabContext.err=CameraErrorOK;
//preliminary set more complicated parameters to NULL, so there are no stale pointers if setup fails
    grabContext.initiatedUntil=0;
    grabContext.chunkListLock=NULL;
    grabContext.chunkReadyLock=NULL;
    grabContext.buffer=NULL;
    grabContext.transferContexts=NULL;
    grabContext.chunkList=NULL;
//Setup locks
    if (ok) {
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
//Setup ring buffer
    if (ok) {
        MALLOC(grabContext.buffer,void*,grabContext.bufferLength,"setupGrabContext-buffer");
        if ((grabContext.buffer)==NULL) ok=NO;
    }
//Setup transfer contexts
    if (ok) {
        MALLOC(grabContext.transferContexts,PhilipsTransferContext*,sizeof(PhilipsTransferContext)*grabContext.concurrentTransfers,"setupGrabContext-PhilipsTransferContext");
        if ((grabContext.transferContexts)==NULL) ok=NO;
    }
    if (ok) {
        for (i=0;i<grabContext.concurrentTransfers;i++) {
            grabContext.transferContexts[i].frameList=NULL;
            grabContext.transferContexts[i].bufferOffset=0;
        }
        for (i=0;(i<grabContext.concurrentTransfers)&&ok;i++) {
            MALLOC(grabContext.transferContexts[i].frameList,IOUSBIsocFrame*,sizeof(IOUSBIsocFrame)*grabContext.framesPerTransfer,"setupGrabContext-frameList");
            if ((grabContext.transferContexts[i].frameList)==NULL) ok=NO;
            else {
                for (j=0;j<grabContext.framesPerTransfer;j++) {
                    grabContext.transferContexts[i].frameList[j].frReqCount=grabContext.bytesPerFrame;
                    grabContext.transferContexts[i].frameList[j].frActCount=0;
                    grabContext.transferContexts[i].frameList[j].frStatus=0;
                }
            }
        }
    }
//The list of ready-to-decode chunks
    if (ok) {
        MALLOC(grabContext.chunkList,PhilipsCompleteChunk*,sizeof(PhilipsCompleteChunk)*grabContext.maxCompleteChunks,"setupGrabContext-chunkList");
        if ((grabContext.chunkList)==NULL) ok=NO;
    }
//Get usb timing info
    if (ok) {
        err=(*intf)->GetBusFrameNumber(intf, &(grabContext.initiatedUntil), &at);
        CheckError(err,"GetBusFrameNumber");
        if (err) ok=NO;
        grabContext.initiatedUntil+=50;	//give it a little time to start
    }
    if (!ok) [self cleanupGrabContext];				//We failed. Throw away the garbage
    return ok;
}

- (BOOL) cleanupGrabContext {
    long l;
    if (grabContext.buffer) {				//dispose the buffer
        FREE(grabContext.buffer,"cleanupGrabContext-buffer");
        grabContext.buffer=NULL;
    }
    if (grabContext.transferContexts) {			//if we have transfer contexts
        for (l=0;l<grabContext.concurrentTransfers;l++) {	//iterate through the contexts and throw them away
            if (grabContext.transferContexts[l].frameList) {
                FREE(grabContext.transferContexts[l].frameList,"cleanupGrabContext-frameList");
                grabContext.transferContexts[l].frameList=NULL;
            }
        }
        FREE(grabContext.transferContexts,"cleanupgrabContext.transferContexts");
        grabContext.transferContexts=NULL;
    }
    if (grabContext.chunkList) {				//throw away the list of ready-to-decode chunks
        FREE(grabContext.chunkList,"cleanupGrabContext-chunkList");
        grabContext.chunkList=NULL;
    }
    if (grabContext.chunkListLock) {			//throw away the chunk list access lock
        [grabContext.chunkListLock release];
        grabContext.chunkListLock=NULL;
    }
    if (grabContext.chunkReadyLock) {			//throw away the chunk ready gate lock
        [grabContext.chunkReadyLock release];
        grabContext.chunkReadyLock=NULL;
    }
    return YES;
}

//StartNextIsochRead and isocComplete refer to each other, so here we need a declaration
static bool StartNextIsochRead(PhilipsGrabContext* grabContext, int transferIdx);

static void isocComplete(void *refcon, IOReturn result, void *arg0) {
    int i,j;
    PhilipsGrabContext* grabContext=(PhilipsGrabContext*)refcon;
    IOUSBIsocFrame* myFrameList=(IOUSBIsocFrame*)arg0;
    short transferIdx=0;
    bool frameListFound=false;
    long currFrameLength;
    bool fullFrame;
    if (result==kIOReturnUnderrun) result=0;                  //Data underrun is not too bad (Jaguar fix)
    //Thanks to Arthur Petry for checking this!
    if (result) {						//USB error handling
        *(grabContext->shouldBeGrabbing)=NO;			//We'll stop no matter what happened
        if (!grabContext->err) {
            if (result==kIOReturnOverrun) grabContext->err=CameraErrorTimeout;	//We didn't setup the transfer in time
            else grabContext->err=CameraErrorUSBProblem;			//Probably some communication error
        }
        if (result!=kIOReturnOverrun) CheckError(result,"isocComplete");		//Other error: log to console
    }
    
    if (*(grabContext->shouldBeGrabbing)) {						//look up which transfer we are
        while ((!frameListFound)&&(transferIdx<grabContext->concurrentTransfers)) {	
            if ((grabContext->transferContexts[transferIdx].frameList)==myFrameList) frameListFound=true;
            else transferIdx++;
        }
        if (!frameListFound) {
#ifdef VERBOSE
            NSLog(@"isocComplete: Didn't find my frameList");
#endif
            *(grabContext->shouldBeGrabbing)=NO;
        }
    }

    if (*(grabContext->shouldBeGrabbing)) {
        for (i=0;i<grabContext->framesPerTransfer;i++) {		//let's have a look into the usb frames we got  
            currFrameLength=myFrameList[i].frActCount;
            fullFrame=(currFrameLength==grabContext->bytesPerFrame);
            if ((grabContext->currentChunkStart)>=0) {			//we are currently inside a chunk
                grabContext->bytesInChunkSoFar+=currFrameLength;
                if (!fullFrame) {					//Chunk done?
                    if (grabContext->bytesInChunkSoFar==grabContext->bytesPerChunk) {	//chunk complete? -> notify decodingThread
                        [grabContext->chunkListLock lock];		//Enter critical section
                        if (grabContext->currCompleteChunks>=grabContext->maxCompleteChunks) {	//overflow: throw away oldest chunk
                            for (j=1;j<grabContext->maxCompleteChunks;j++) {
                                grabContext->chunkList[j-1]=grabContext->chunkList[j];
                            }
                            grabContext->currCompleteChunks--;
                        }
                        grabContext->chunkList[grabContext->currCompleteChunks].start=grabContext->currentChunkStart;	//insert new chunk
                        grabContext->chunkList[grabContext->currCompleteChunks].end=
                            grabContext->transferContexts[transferIdx].bufferOffset+i*grabContext->bytesPerFrame+currFrameLength;
                        grabContext->currCompleteChunks++;
                        [grabContext->chunkListLock unlock];		//exit critical section
                        [grabContext->chunkReadyLock tryLock];		//try to wake up the decoder
                        [grabContext->chunkReadyLock unlock];
                    } else {						//broken frame -> drop
                        grabContext->droppedFrames++;
//#ifdef VERBOSE
//    commented out because it's useful for debugging but not for use. some people want important things on the console.
//    NSLog(@"packet size %d instead of %d: frame dropped",(int)grabContext->bytesInChunkSoFar,(int)grabContext->bytesPerChunk);
//#endif
                    }
                    grabContext->currentChunkStart=-1;	//no matter what happened, we are now outside a chunk
                }
            } else {			//we are currently outside a chunk
                if (fullFrame) {	//chunk starting! -> remember this.
                    grabContext->currentChunkStart=grabContext->transferContexts[transferIdx].bufferOffset+i*grabContext->bytesPerFrame;
                    grabContext->bytesInChunkSoFar=grabContext->bytesPerFrame;
                }
            }	
        }
    }

    if (*(grabContext->shouldBeGrabbing)) {	//initiate next transfer
        if (!StartNextIsochRead(grabContext,transferIdx)) *(grabContext->shouldBeGrabbing)=NO;
    }
    if (!(*(grabContext->shouldBeGrabbing))) {	//on error: collect finished transfers and exit if all transfers have ended
        grabContext->finishedTransfers++;
        if ((grabContext->finishedTransfers)>=(grabContext->concurrentTransfers)) {
            CFRunLoopStop(CFRunLoopGetCurrent());
        }
    }
}

static bool StartNextIsochRead(PhilipsGrabContext* grabContext, int transferIdx) {
    IOReturn err;
    long bytesInRing=grabContext->framesInRing*grabContext->bytesPerFrame;
    grabContext->transferContexts[transferIdx].bufferOffset=grabContext->nextReadOffset;
    err=(*(grabContext->intf))->ReadIsochPipeAsync(grabContext->intf,
                                    2,
                                    grabContext->buffer+grabContext->transferContexts[transferIdx].bufferOffset,
                                    grabContext->initiatedUntil,
                                    grabContext->framesPerTransfer,
                                    grabContext->transferContexts[transferIdx].frameList,
                                    (IOAsyncCallback1)(isocComplete),
                                    grabContext);
    switch (err) {
        case 0:
            grabContext->initiatedUntil+=grabContext->framesPerTransfer;	//update frames
            grabContext->nextReadOffset+=grabContext->framesPerTransfer*grabContext->bytesPerFrame;	//update buffer offset
            if ((grabContext->nextReadOffset)>=bytesInRing) {			//wrap around ring (it's a ring buffer)
                grabContext->nextReadOffset-=bytesInRing;
                if (grabContext->nextReadOffset) {
#ifdef VERBOSE
                    NSLog(@"StartNextIsochRead: ring buffer is not properly wrapping");
#endif
                    err=1;
                }
            }
            break;
        case 0x1000003:
            if (!grabContext->err) grabContext->err=CameraErrorNoCam;
            break;
        default:
            CheckError(err,"StartNextIsochRead-ReadIsochPipeAsync");
            if (!grabContext->err) grabContext->err=CameraErrorUSBProblem;
                break;
    }
    return !err;
}

- (void) grabbingThread:(id)data {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    long i;
    IOReturn err;
    CFRunLoopSourceRef cfSource;
    bool ok=true;

    ChangeMyThreadPriority(10);	//We need to update the isoch read in time, so timing is important for us

    if (![self usbSetAltInterfaceTo:usbAltInterface testPipe:2]) {
        if (!grabContext.err) grabContext.err=CameraErrorNoBandwidth;	//probably no bandwidth
        ok=NO;
    }

    if (!isUSBOK) { grabContext.err=CameraErrorNoCam; ok=NO; }

    err = (*intf)->CreateInterfaceAsyncEventSource(intf, &cfSource);	//Create an event source
    CheckError(err,"CreateInterfaceAsyncEventSource");
    CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//Add it to our run loop
    
    if (!isUSBOK) { grabContext.err=CameraErrorNoCam; ok=NO; }
    
    for (i=0;(i<grabContext.concurrentTransfers)&&ok;i++) {	//Initiate transfers
        ok=StartNextIsochRead(&grabContext,i);
    }
    if (ok) CFRunLoopRun();					//Do our run loop

    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//remove the event source

    if (![self usbSetAltInterfaceTo:0 testPipe:0]) {
        if (!grabContext.err) grabContext.err=CameraErrorNoBandwidth;	//probably no bandwidth
        ok=NO;
    }

    shouldBeGrabbing=NO;			//error in grabbingThread or abort? initiate shutdown of everything else
    [grabContext.chunkReadyLock unlock];	//give the decodingThread a chance to abort
    [pool release];
    grabbingThreadRunning=NO;
    [NSThread exit];
}

- (CameraError) decodingThread {
    int lineExtra;
    PhilipsCompleteChunk currChunk;
    long i;
    unsigned char* chunkBuffer;
    short width=[self width];	//Should remain constant during grab
    short height=[self height];	//Should remain constant during grab
    CameraError err=CameraErrorOK;
    grabbingThreadRunning=NO;

    if (![self setupGrabContext]) {
        err=CameraErrorNoMem;
        shouldBeGrabbing=NO;
    }

    if (shouldBeGrabbing) {
        grabbingThreadRunning=YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];    //start grabbingThread
    }

    while (shouldBeGrabbing) {
        [grabContext.chunkReadyLock lock];				//wait for ready-to-decode chunks
        while ((shouldBeGrabbing)&&(grabContext.currCompleteChunks>0)) {	//decode all chunks unless we should stop grabbing
            [grabContext.chunkListLock lock];			//lock for access to chunk list
            currChunk=grabContext.chunkList[0];			//take first (oldest) chunk
            for(i=1;i<grabContext.currCompleteChunks;i++) {		//all others go one down
                grabContext.chunkList[i-1]=grabContext.chunkList[i];
            }
            grabContext.currCompleteChunks--;			//we have taken one from the list
            [grabContext.chunkListLock unlock];			//we're done accessing the chunk list.
            if (nextImageBufferSet) {				//do we have a target to decode into?
                [imageBufferLock lock];				//lock image buffer access
                if (nextImageBuffer!=NULL) {
                    if (currChunk.end<currChunk.start) {		//does the chunk wrap?
                        memcpy(grabContext.buffer+grabContext.framesInRing*grabContext.bytesPerFrame,
                               grabContext.buffer,
                               currChunk.end);		//Copy the second part at the end of the first part (into the Q-buffer appendix)
                    }
                    chunkBuffer=grabContext.buffer+currChunk.start+chunkHeader;	//Our chunk starts here
                    lineExtra=nextImageBufferRowBytes-width*nextImageBufferBPP;	//bytes to skip after each line in target buffer
                    yuv2rgb (width,height,YUVPhilipsStyle,chunkBuffer,nextImageBuffer,
                             nextImageBufferBPP,0,lineExtra,hFlip!=camHFlip);	//decode
                }
                lastImageBuffer=nextImageBuffer;			//Copy nextBuffer info into lastBuffer
                lastImageBufferBPP=nextImageBufferBPP;
                lastImageBufferRowBytes=nextImageBufferRowBytes;
                nextImageBufferSet=NO;				//nextBuffer has been eaten up
                [imageBufferLock unlock];				//release lock
                [self mergeImageReady];				//notify delegate about the image. perhaps get a new buffer
            }
        }
    }
    while (grabbingThreadRunning) { usleep(10000); }	//Wait for grabbingThread finish
    //We need to sleep here because otherwise the compiler would optimize the loop away

    if (!err) err=grabContext.err;
    [self cleanupGrabContext];				//grabbingThread doesn't need the context any more since it's done
    return err;
}
    

@end
