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

#import "MySPCA500Driver.h"
#import "MyCameraCentral.h"
#include "Resolvers.h"
#include "MiscTools.h"
#include "unistd.h"	//usleep

#define SPCA_RETRIES 5
#define SPCA_WAIT_RETRY 500000

@interface MySPCA500Driver (Private)

- (void) decode422Uncompressed:(UInt8*)rawSrc;
- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;
- (BOOL) setupGrabContext;
- (void) cleanupGrabContext;
- (void) grabbingThread:(id)data;

- (CameraError) openDSCInterface;	//Opens the dsc interface, calls dscInit
- (void) closeDSCInterface;		//calls dscShutdown, closes the dsc interface

- (void) reloadTOC;
- (BOOL) dscReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;
- (BOOL) dscWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;

@end 

@implementation MySPCA500Driver


#define VENDOR_SUNPLUS 0x4fc
#define PRODUCT_SPCA500 0x500a
#define PRODUCT_SPCA500B 0x500b
#define VENDOR_MUSTEK 0x055f
#define PRODUCT_GSMART_MINI2 0xc420

+ (unsigned short) cameraUsbProductID {
    return 0x7333;
}

+ (unsigned short) cameraUsbVendorID {
    return 0x04fc;
}

+ (NSString*) cameraName {
    return @"SmartCam";
}


- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err = [self usbConnectToCam:usbDeviceRef];
    fps=5;
    resolution=ResolutionVGA;
    [self setCompression:0];
    [self setBrightness:0.0f];
    [self setContrast:0.5f];
    [self setSaturation:0.5f];
    [self setSharpness:0.5f];
    [self setGamma:0.5f];
    [self setAutoGain:NO];
    [self setShutter:0.5f];
    [self setGain:0.5f];
    [self setCompression:0];
    if (err==CameraErrorOK) err=[super startupWithUsbDeviceRef:usbDeviceRef];
    if (err==CameraErrorOK) err=[self openDSCInterface];
    return err;
}

- (void) shutdown {
    [self closeDSCInterface];
    [super shutdown];
}

// FROM HERE: PC CAMERA METHODS

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    if (fr!=5) return NO;
    if (resolution!=ResolutionVGA) return NO;
    return YES;
}

- (void) setResolution:(CameraResolution)r fps:(short)fr {
    [super setResolution:r fps:fr];	//Update instance variables if state is ok and format is supported
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {	//This is a start
    if (dFps) *dFps=5;
    return ResolutionVGA;
}

- (short) maxCompression {
    return 0;
}

- (void) setCompression:(short)v {
    [super setCompression:v];
}

- (BOOL) canSetBrightness {
    return YES;
}

- (void) setBrightness:(float)v {
    [super setBrightness:v];
}

- (BOOL) canSetContrast {
    return YES;
}

- (void) setContrast:(float)v {
    [super setContrast:v];
}

- (BOOL) canSetSaturation {
    return YES;
}

- (void) setSaturation:(float)v {
    [super setSaturation:v];
}

- (BOOL) startupGrabStream {
    //Set camera to PC camera mode
    if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0004 wIndex:0x8000 buf:NULL len:0]) return NO;
    //Set image width
    if (![self usbWriteCmdWithBRequest:0x00 wValue:40 wIndex:0x8001 buf:NULL len:0]) return NO;
    //Set image height
    if (![self usbWriteCmdWithBRequest:0x00 wValue:30 wIndex:0x8002 buf:NULL len:0]) return NO;
    //Set no compression, no subsampling
    if (![self usbWriteCmdWithBRequest:0x00 wValue:2 wIndex:0x8003 buf:NULL len:0]) return NO;
    return YES;
}

- (void) shutdownGrabStream {
    [self usbSetAltInterfaceTo:0 testPipe:0];
}

- (BOOL) setupGrabContext {
    BOOL ok=YES;
    int i,j;
    
    //Clear things that have to be set back if init fails
    grabContext.chunkReadyLock=NULL;
    grabContext.chunkListLock=NULL;
    for (i=0;i<SPCA500_NUM_TRANSFERS;i++) {
        grabContext.transferContexts[i].buffer=NULL;
    }
    for (i=0;i<SPCA500_NUM_CHUNK_BUFFERS;i++) {
        grabContext.emptyChunkBuffers[i].buffer=NULL;
        grabContext.fullChunkBuffers[i].buffer=NULL;
    }
    //Setup simple things    
    grabContext.bytesPerFrame=1023;
    grabContext.finishedTransfers=0;
    grabContext.intf=intf;
    grabContext.initiatedUntil=0;	//Will be set later (directly before start)
    grabContext.shouldBeGrabbing=&shouldBeGrabbing;
    grabContext.err=CameraErrorOK;
    grabContext.framesSinceLastChunk=0;
    grabContext.chunkBufferLength=2000000;	//Should be safe for now. *** FIXME: Make a better estimation...
    grabContext.numEmptyBuffers=0;
    grabContext.numFullBuffers=0;
    grabContext.fillingChunk=false;

    //Setup things that have to be set back if init fails
    if (ok) {
        grabContext.chunkReadyLock=[[NSLock alloc] init];
        if (grabContext.chunkReadyLock==NULL) ok=NO;
    }
    if (ok) {
        grabContext.chunkListLock=[[NSLock alloc] init];
        if (grabContext.chunkListLock==NULL) ok=NO;
    }
    if (ok) {
        for (i=0;ok&&(i<SPCA500_NUM_TRANSFERS);i++) {
            for (j=0;j<SPCA500_FRAMES_PER_TRANSFER;j++) {
                grabContext.transferContexts[i].frameList[j].frStatus=0;
                grabContext.transferContexts[i].frameList[j].frReqCount=grabContext.bytesPerFrame;
                grabContext.transferContexts[i].frameList[j].frActCount=0;
            }
            MALLOC(grabContext.transferContexts[i].buffer,
                   UInt8*,
                   SPCA500_FRAMES_PER_TRANSFER*grabContext.bytesPerFrame,
                   "isoc transfer buffer");
            if (grabContext.transferContexts[i].buffer==NULL) ok=NO;
        }
    }
    for (i=0;(i<SPCA500_NUM_CHUNK_BUFFERS)&&ok;i++) {
        MALLOC(grabContext.emptyChunkBuffers[i].buffer,UInt8*,grabContext.chunkBufferLength,"Chunk buffer");
        if (grabContext.emptyChunkBuffers[i].buffer==NULL) ok=NO;
        else grabContext.numEmptyBuffers=i+1;
    }
    if (!ok) {
        NSLog(@"setupGrabContext failed");
        [self cleanupGrabContext];
    }
    return ok;
}

- (void) cleanupGrabContext {
    int i;
    if (grabContext.chunkReadyLock) {			//cleanup chunk ready lock
        [grabContext.chunkReadyLock release];
        grabContext.chunkReadyLock=NULL;
    }
    if (grabContext.chunkListLock) {			//cleanup chunk list lock
        [grabContext.chunkListLock release];
        grabContext.chunkListLock=NULL;
    }
    for (i=0;i<SPCA500_NUM_TRANSFERS;i++) {		//cleanup isoc buffers
        if (grabContext.transferContexts[i].buffer) {
            FREE(grabContext.transferContexts[i].buffer,"isoc data buffer");
            grabContext.transferContexts[i].buffer=NULL;
        }
    }
    for (i=grabContext.numEmptyBuffers-1;i>=0;i--) {	//cleanup empty chunk buffers
        if (grabContext.emptyChunkBuffers[i].buffer) {
            FREE(grabContext.emptyChunkBuffers[i].buffer,"empty chunk buffer");
            grabContext.emptyChunkBuffers[i].buffer=NULL;
        }
    }
    grabContext.numEmptyBuffers=0;
    for (i=grabContext.numFullBuffers-1;i>=0;i--) {	//cleanup full chunk buffers
        if (grabContext.fullChunkBuffers[i].buffer) {
            FREE(grabContext.fullChunkBuffers[i].buffer,"full chunk buffer");
            grabContext.fullChunkBuffers[i].buffer=NULL;
        }
    }
    grabContext.numFullBuffers=0;
    if (grabContext.fillingChunk) {			//cleanup filling chunk buffer
        if (grabContext.fillingChunkBuffer.buffer) {
            FREE(grabContext.fillingChunkBuffer.buffer-JFIF_HEADER_LENGTH,"filling chunk buffer");
            grabContext.fillingChunkBuffer.buffer=NULL;
        }
        grabContext.fillingChunk=false;
    }
}

//Forward declaration
static bool StartNextIsochRead(SPCA500GrabContext* gCtx, int transferIdx);


static void isocComplete(void *refcon, IOReturn result, void *arg0) {
    int i;
    SPCA500GrabContext* gCtx=(SPCA500GrabContext*)refcon;
    IOUSBIsocFrame* myFrameList=(IOUSBIsocFrame*)arg0;
    short transferIdx=0;
    bool frameListFound=false;
    long currFrameLength;
    UInt8* frameBase;


    //Handle result from isoc transfer
    switch (result) {
        case 0:			//No error -> alright
        case kIOReturnUnderrun:	//Data hickup - not so serious
            result=0;
            break;
        case kIOReturnOverrun:
        case kIOReturnTimeout:
            *(gCtx->shouldBeGrabbing)=NO;
            if (!(gCtx->err)) gCtx->err=CameraErrorTimeout;
                break;
        default:
            *(gCtx->shouldBeGrabbing)=NO;
            if (!(gCtx->err)) gCtx->err=CameraErrorUSBProblem;
                break;
    }
    CheckError(result,"isocComplete");	//Show errors (really needed here?)

    //look up which transfer we are
    if (*(gCtx->shouldBeGrabbing)) {
        while ((!frameListFound)&&(transferIdx<SPCA500_NUM_TRANSFERS)) {
            if ((gCtx->transferContexts[transferIdx].frameList)==myFrameList) frameListFound=true;
            else transferIdx++;
        }
        if (!frameListFound) {
            NSLog(@"isocComplete: Didn't find my frameList");
            *(gCtx->shouldBeGrabbing)=NO;
            if (!(gCtx->err)) gCtx->err=CameraErrorInternal;
        }
    }

    //Parse returned data
    if (*(gCtx->shouldBeGrabbing)) {
        long numBytes=0;
        for (i=0;i<SPCA500_FRAMES_PER_TRANSFER;i++) {			//let's have a look into the usb frames we got
            currFrameLength=myFrameList[i].frActCount;			//Cache this - it won't change and we need it several times
            if (currFrameLength>0) {					//If there is data in this frame
                numBytes+=currFrameLength;
                frameBase=gCtx->transferContexts[transferIdx].buffer+gCtx->bytesPerFrame*i;
                if (currFrameLength>1) {
                    UInt8* copyStart;
                    UInt32 copyLength;
                    if (frameBase[0]==0xff) {
                        if (frameBase[1]==0x01) {		//Start of frame
                            NSLog(@"received SOF");
                            if (gCtx->fillingChunk) {				//We were filling -> chunk done
                                                         //Pass the complete chunk to the full list
                                int j;
                                [gCtx->chunkListLock lock];			//Get access to the chunk buffers
                                for (j=gCtx->numFullBuffers-1;j>=0;j--) {	//Move full buffers one up
                                    gCtx->fullChunkBuffers[j+1]=gCtx->fullChunkBuffers[j];
                                }
                                gCtx->fullChunkBuffers[0]=gCtx->fillingChunkBuffer;	//Insert the filling one as newest
                                gCtx->numFullBuffers++;				//We have inserted one buffer
                                gCtx->fillingChunk=false;			//Now we're not filling (still in the lock to be sure no buffer is lost)
                                [gCtx->chunkReadyLock unlock];			//Wake up decoding thread
                                gCtx->framesSinceLastChunk=0;			//reset watchdog
                            } else {						//There was no current filling chunk. Just get a new one.
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
                            gCtx->fillingChunk=true;				//Now we're filling (still in the lock to be sure no buffer is lost)
                            gCtx->fillingChunkBuffer.numBytes=0;		//Start with empty buffer
                            [gCtx->chunkListLock unlock];			//Free access to the chunk buffers
                            copyStart=frameBase+16;				//Skip past header
                            copyLength=currFrameLength-16;
                        } else if (frameBase[1]==0x00) {			//Empty frame - silently drop this one
                            NSLog(@"received drop frame");
                            copyLength=0;
                        } else {
                            NSLog(@"received strange frame");
                            copyLength=0;
                        }
                    } else {					
                        copyStart=frameBase+1;
                        copyLength=currFrameLength-1;
                    }
                    if (copyLength>0) {				//There's image data to copy
                        if (gCtx->fillingChunk) {
                            if (gCtx->fillingChunkBuffer.numBytes+copyLength<=gCtx->chunkBufferLength) {
                                //There's enough space remaining to copy
                                memcpy(gCtx->fillingChunkBuffer.buffer+gCtx->fillingChunkBuffer.numBytes,
                                       copyStart,copyLength);
                                gCtx->fillingChunkBuffer.numBytes+=copyLength;
                            } else {	//The chunk buffer is too full -> expect error -> drop
                                [gCtx->chunkListLock lock];			//Get access to the chunk buffers
                                gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers]=gCtx->fillingChunkBuffer;
                                gCtx->numEmptyBuffers++;
                                gCtx->fillingChunk=false;			//Now we're not filling (still in the lock to be sure no buffer is lost)
                                [gCtx->chunkListLock unlock];			//Free access to the chunk buffers                                
                            }
                        }
                    }
                }
            }
        }
        NSLog(@"Bytes received: %i",numBytes);
        gCtx->framesSinceLastChunk+=SPCA500_FRAMES_PER_TRANSFER;	//Count frames (not necessary to be too precise here...)
/* WATCHDOG DISABLED
 if ((gCtx->framesSinceLastChunk)>1000) {			//One second without a frame?
            NSLog(@"SPCA500 grab aborted because of invalid data stream");
            *(gCtx->shouldBeGrabbing)=NO;
            if (!gCtx->err) gCtx->err=CameraErrorUSBProblem;
        }
        */
    }
    //initiate next transfer
    if (*(gCtx->shouldBeGrabbing)) {
        if (!StartNextIsochRead(gCtx,transferIdx)) *(gCtx->shouldBeGrabbing)=NO;
    }

    //Shutdown cleanup: Collect finished transfers and exit if all transfers have ended
    if (!(*(gCtx->shouldBeGrabbing))) {
        gCtx->finishedTransfers++;
        if ((gCtx->finishedTransfers)>=(SPCA500_NUM_TRANSFERS)) {
            CFRunLoopStop(CFRunLoopGetCurrent());
        }
    }
}

static bool StartNextIsochRead(SPCA500GrabContext* gCtx, int transferIdx) {
    IOReturn err;
    err=(*(gCtx->intf))->ReadIsochPipeAsync(gCtx->intf,
                                            1,
                                            gCtx->transferContexts[transferIdx].buffer,
                                            gCtx->initiatedUntil,
                                            SPCA500_FRAMES_PER_TRANSFER,
                                            gCtx->transferContexts[transferIdx].frameList,
                                            (IOAsyncCallback1)(isocComplete),
                                            gCtx);
    gCtx->initiatedUntil+=SPCA500_FRAMES_PER_TRANSFER;
    switch (err) {
        case 0:
            break;
        default:
            CheckError(err,"StartNextIsochRead-ReadIsochPipeAsync");
            if (!gCtx->err) gCtx->err=CameraErrorUSBProblem;
                break;
    }
    return (err==0);
}

- (void) grabbingThread:(id)data {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    long i;
    IOReturn err;
    CFRunLoopSourceRef cfSource;
    bool ok=true;
    
    ChangeMyThreadPriority(10);	//We need to update the isoch read in time, so timing is important for us

    if (![self usbSetAltInterfaceTo:7 testPipe:1]) {			//Max bandwidth
        if (!grabContext.err) grabContext.err=CameraErrorNoBandwidth;	//probably no bandwidth
        ok=NO;
    }

    if (ok) {
        ok=[self startupGrabStream];
        if ((ok)&&(!grabContext.err)) grabContext.err=CameraErrorUSBProblem;
    }

    //Get usb timing info
    if (ok) {
        if (![self usbGetSoon:&(grabContext.initiatedUntil)]) {
            shouldBeGrabbing=NO;
            if (!grabContext.err) grabContext.err=CameraErrorUSBProblem;	//Stall or so?
        }
    }

    if (ok) {
        err = (*intf)->CreateInterfaceAsyncEventSource(intf, &cfSource);	//Create an event source
        CheckError(err,"CreateInterfaceAsyncEventSource");
        CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//Add it to our run loop
    
        for (i=0;(i<SPCA500_NUM_TRANSFERS)&&ok;i++) {	//Initiate transfers
            ok=StartNextIsochRead(&grabContext,i);
        }
    }

    if (ok) {
        CFRunLoopRun();					//Do our run loop
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//remove the event source
    }

    [self shutdownGrabStream];
    [self usbSetAltInterfaceTo:0 testPipe:0];
    [grabContext.chunkReadyLock unlock];	//give the decodingThread a chance to abort
    [pool release];
    grabbingThreadRunning=NO;
    [NSThread exit];
}

- (void) decode422Uncompressed:(UInt8*)rawSrc {
    int b=0;	//Block
    int i,j;
    int numDoubleBlocks=2400;
    int doubleBlocksPerRow=40;
    int dstBlockRowSkip=nextImageBufferRowBytes-8*nextImageBufferBPP;
    for (b=0;b<numDoubleBlocks;b++) {
        SInt8* src=(SInt8*)rawSrc+b*256;
        UInt8* dst=nextImageBuffer+
            ((b/doubleBlocksPerRow)*8)*nextImageBufferRowBytes+((b%doubleBlocksPerRow)*16)*3;
        for(j=0;j<8;j++) {
            for(i=0;i<4;i++) {
                short y11=src[  0]+128;
                short y12=src[  1]+128;
                short y21=src[ 64]+128;
                short y22=src[ 65]+128;
                short v1 =src[128]*2;
                short v2 =src[129]*2;
                short u1 =src[192]*2;
                short u2 =src[193]*2;
                short r,b;
                if (nextImageBufferBPP==3) {
                    r=y11+u1;
                    b=y11+v1;
                    dst[                    0]=CLAMP(r,0,255);
                    dst[                    1]=y11;
                    dst[                    2]=CLAMP(b,0,255);
                    r=y12+u1;
                    b=y12+v1;
                    dst[nextImageBufferBPP+ 0]=CLAMP(r,0,255);
                    dst[nextImageBufferBPP+ 1]=y12;
                    dst[nextImageBufferBPP+ 2]=CLAMP(b,0,255);
                    r=y21+u2;
                    b=y21+v2;
                    dst[                   24]=CLAMP(r,0,255);
                    dst[                   25]=y21;
                    dst[                   26]=CLAMP(b,0,255);
                    r=y22+u2;
                    b=y22+v2;
                    dst[nextImageBufferBPP+24]=CLAMP(r,0,255);
                    dst[nextImageBufferBPP+25]=y22;
                    dst[nextImageBufferBPP+26]=CLAMP(b,0,255);
                    src+=2;
                    dst+=6;
                } else {
                    r=y11+u1;
                    b=y11+v1;
                    dst[                    0]=CLAMP(r,0,255);
                    dst[                    1]=y11;
                    dst[                    2]=CLAMP(b,0,255);
                    r=y12+u1;
                    b=y12+v1;
                    dst[nextImageBufferBPP+ 0]=CLAMP(r,0,255);
                    dst[nextImageBufferBPP+ 1]=y12;
                    dst[nextImageBufferBPP+ 2]=CLAMP(b,0,255);
                    r=y21+u2;
                    b=y21+v2;
                    dst[                   32]=CLAMP(r,0,255);
                    dst[                   33]=y21;
                    dst[                   34]=CLAMP(b,0,255);
                    r=y22+u2;
                    b=y22+v2;
                    dst[nextImageBufferBPP+32]=CLAMP(r,0,255);
                    dst[nextImageBufferBPP+33]=y22;
                    dst[nextImageBufferBPP+34]=CLAMP(b,0,255);
                    src+=2;
                    dst+=8;
                }
            }
            dst+=dstBlockRowSkip;
        }
    }
}

static inline void decode420Block(SInt8* srcy,SInt8* srcu,SInt8* srcv,UInt8* dst,int bpp, int rb) {
    int i,j;
    short y11,y12,y21,y22,u,v,r,b;
    for (j=0;j<4;j++) {
        for (i=0;i<4;i++) {
            v=srcu[0];
            u=srcv[0];
            y11=srcy[0]+128;
            y12=srcy[1]+128;
            y21=srcy[8]+128;
            y22=srcy[9]+128;
            if (bpp==3) {
                r=y11+u;b=y11+v;
                dst[0]=CLAMP(r,0,255);
                dst[1]=y11;
                dst[2]=CLAMP(b,0,255);
                r=y12+u;b=y12+v;
                dst[3]=CLAMP(r,0,255);
                dst[4]=y12;
                dst[5]=CLAMP(b,0,255);
                dst+=rb;
                r=y21+u;b=y21+v;
                dst[0]=CLAMP(r,0,255);
                dst[1]=y21;
                dst[2]=CLAMP(b,0,255);
                r=y22+u;b=y22+v;
                dst[3]=CLAMP(r,0,255);
                dst[4]=y22;
                dst[5]=CLAMP(b,0,255);
                dst-=(rb-6);
            } else {
                r=y11+u;b=y11+v;
                dst[0]=255;
                dst[1]=CLAMP(r,0,255);
                dst[2]=y11;
                dst[3]=CLAMP(b,0,255);
                r=y12+u;b=y12+v;
                dst[4]=255;
                dst[5]=CLAMP(r,0,255);
                dst[6]=y12;
                dst[7]=CLAMP(b,0,255);
                dst+=rb;
                r=y21+u;b=y21+v;
                dst[0]=255;
                dst[1]=CLAMP(r,0,255);
                dst[2]=y21;
                dst[3]=CLAMP(b,0,255);
                r=y22+u;b=y22+v;
                dst[4]=255;
                dst[5]=CLAMP(r,0,255);
                dst[6]=y22;
                dst[7]=CLAMP(b,0,255);
                dst-=(rb-8);
            }
            srcu++;
            srcv++;
            srcy+=2;
        }
        dst+=2*rb-8*bpp;
        srcu+=4;
        srcv+=4;
        srcy+=8;
    }
}

- (void) decode420Uncompressed:(UInt8*)rawSrc {
    int i,j;
    int macroBlocksPerRow=[self width]/16;
    int macroBlocksPerCol=[self height]/16;
    UInt8* src=rawSrc;
    UInt8* dst=nextImageBuffer;
    for (j=0;j<macroBlocksPerCol;j++) {
        for (i=0;i<macroBlocksPerRow;i++) {
            decode420Block(src    ,src+256,src+320,dst                          ,nextImageBufferBPP,nextImageBufferRowBytes);
            decode420Block(src+64 ,src+260,src+324,dst+8*nextImageBufferBPP     ,nextImageBufferBPP,nextImageBufferRowBytes);
            decode420Block(src+128,src+288,src+352,dst+8*nextImageBufferRowBytes,nextImageBufferBPP,nextImageBufferRowBytes);
            decode420Block(src+192,src+292,src+356,dst+8*nextImageBufferRowBytes+8*nextImageBufferBPP
                                                                                ,nextImageBufferBPP,nextImageBufferRowBytes);
            src+=6*64;
            dst+=16*nextImageBufferBPP;
        }
        dst+=16*nextImageBufferRowBytes-macroBlocksPerRow*16*nextImageBufferBPP;
    }
}

- (CameraError) decodingThread {
    
    CameraError err=CameraErrorOK;
    grabbingThreadRunning=NO;

    //Init
    if (![self setupGrabContext]) {
        err=CameraErrorNoMem;
        shouldBeGrabbing=NO;
    }

    if (shouldBeGrabbing) {
        grabbingThreadRunning=YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];
    }
    
    //The decoding loop
    while (shouldBeGrabbing) {
        [grabContext.chunkReadyLock lock];	//Wait for chunks to become ready
        while ((grabContext.numFullBuffers>0)&&(shouldBeGrabbing)) {
            SPCA500ChunkBuffer currBuffer;	//The buffer to decode
            //Get a full buffer
            [grabContext.chunkListLock lock];	//Get access to the buffer lists
            grabContext.numFullBuffers--;	//There's always one since noone else can empty it completely
            currBuffer=grabContext.fullChunkBuffers[grabContext.numFullBuffers];
            [grabContext.chunkListLock unlock];	//Get access to the buffer lists
            //Do the decoding
            if (nextImageBufferSet) {
                [imageBufferLock lock];					//lock image buffer access
                if (nextImageBuffer!=NULL) {
                    [self decode420Uncompressed:currBuffer.buffer];
                }
                lastImageBuffer=nextImageBuffer;			//Copy nextBuffer info into lastBuffer
                lastImageBufferBPP=nextImageBufferBPP;
                lastImageBufferRowBytes=nextImageBufferRowBytes;
                nextImageBufferSet=NO;					//nextBuffer has been eaten up
                [imageBufferLock unlock];				//release lock
                [self mergeImageReady];					//notify delegate about the image. perhaps get a new buffer
            }
            //put the buffer back to the empty ones
            [grabContext.chunkListLock lock];	//Get access to the buffer lists
            grabContext.emptyChunkBuffers[grabContext.numEmptyBuffers]=currBuffer;
            grabContext.numEmptyBuffers++;
            [grabContext.chunkListLock unlock];	//Get access to the buffer lists            
        }

    }

    //Shutdown
    while (grabbingThreadRunning) { usleep(10000); }	//Wait for grabbingThread finish
    //We need to sleep here because otherwise the compiler would optimize the loop away
    [self cleanupGrabContext];
    if (!err) err=grabContext.err;	//Take error from context
    return err;
}

// FROM HERE: DSC METHODS

- (BOOL) canStoreMedia {
    return YES;
}

- (long) numberOfStoredMediaObjects {
    [self reloadTOC];
    if (!storedFileInfo) return 0;
    return [storedFileInfo count];
}

- (NSDictionary*) getStoredMediaObject:(long)idx {
    return NULL;
}

- (void) eraseStoredMedia {
#ifdef VERBOSE
    NSLog(@"MySPCA500Driver: eraseStoredMedia not implemented");
#endif
}

- (CameraError) openDSCInterface {
    IOUSBFindInterfaceRequest		interfaceRequest;
    io_iterator_t			iterator;
    IOReturn 				err;
    io_service_t			usbInterfaceRef;
    IOCFPlugInInterface 		**iodev;		// requires <IOKit/IOCFPlugIn.h>
    SInt32 				score;

    interfaceRequest.bInterfaceClass = kIOUSBFindInterfaceDontCare;		// requested class
    interfaceRequest.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;		// requested subclass
    interfaceRequest.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;		// requested protocol
    interfaceRequest.bAlternateSetting = kIOUSBFindInterfaceDontCare;		// requested alt setting

    //take an iterator over the device interfaces...
    err = (*dev)->CreateInterfaceIterator(dev, &interfaceRequest, &iterator);
    CheckError(err,"openDSCInterface-CreateInterfaceIterator");

    //and take the second one
    usbInterfaceRef = IOIteratorNext(iterator);
    usbInterfaceRef = IOIteratorNext(iterator);
    assert (usbInterfaceRef);

    //we don't need the iterator any more
    IOObjectRelease(iterator);
    iterator = 0;

    //get a plugin interface for the interface interface
    err = IOCreatePlugInInterfaceForService(usbInterfaceRef, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
    CheckError(err,"openDSCInterface-IOCreatePlugInInterfaceForService");
    assert(iodev);
    IOObjectRelease(usbInterfaceRef);

    //get access to the interface interface
    err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID)&dscIntf);
    CheckError(err,"openDSCInterface-QueryInterface2");
    assert(dscIntf);
    (*iodev)->Release(iodev);						// done with this

    //open interface
    err = (*dscIntf)->USBInterfaceOpen(dscIntf);
    CheckError(err,"openDSCInterface-USBInterfaceOpen");

    //set alternate interface
    err = (*dscIntf)->SetAlternateInterface(dscIntf,0);
    CheckError(err,"openDSCInterface-SetAlternateInterface");
    if (err) return CameraErrorUSBProblem;
//    if (![self dscInit]) return CameraErrorUSBProblem;
    return CameraErrorOK;
}

- (void) closeDSCInterface {
    IOReturn err;
    if (dscIntf) {							//close our interface interface
        if (isUSBOK) {
            err = (*dscIntf)->USBInterfaceClose(dscIntf);
        }
        err = (*dscIntf)->Release(dscIntf);
        CheckError(err,"closeDSCInterface-Release Interface");
        dscIntf=NULL;
    }
}

- (void) reloadTOC {
    UInt8 buf[64];
    UInt32 readLen;
    
    if (storedFileInfo) [storedFileInfo release];			//Throw away old array
    storedFileInfo=[[NSMutableArray alloc] initWithCapacity:100];	//Get new file array
    if (!storedFileInfo) return;					//We need the array to store the info
    if (!dscIntf) return;						//We need the DSC interface
    //Set Register 0x8000 to 1 (Operation mode to upload)
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x8000 buf:NULL len:0]) return;
    //Set Register 0x8301 to 3 (OprMode)
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0003 wIndex:0x8301 buf:NULL len:0]) return;

    //Ask for FAT
    if (![self dscWriteCmdWithBRequest:0x01 wValue:0x0000 wIndex:0x0002 buf:NULL len:0]) return;
    readLen=64;
    ((IOUSBInterfaceInterface182*)(*dscIntf))->ReadPipeTO(intf,1,buf,&readLen,2000,3000);
    NSLog(@"read:%i",readLen);
    DumpMem(buf,64);
    //Set Register 0x8000 to 0 (Operation mode to idle)
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0003 wIndex:0x8000 buf:NULL len:0]) return;
}

- (BOOL) dscReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    IOReturn err;
    IOUSBDevRequest req;
    if (!isUSBOK) return NO;
    if (dscIntf==NULL) return NO;
    req.bmRequestType=USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBDevice);
    req.bRequest=bReq;
    req.wValue=wVal;
    req.wIndex=wIdx;
    req.wLength=len;
    req.pData=buf;
    err=(*dscIntf)->ControlRequest(dscIntf,0,&req);
    CheckError(err,"usbReadCmdWithBRequest");
    if (err==kIOUSBPipeStalled) (*dscIntf)->ClearPipeStall(dscIntf,0);
    return (!err);
}

- (BOOL) dscWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    IOReturn err;
    IOUSBDevRequest req;
    if (!isUSBOK) return NO;
    if (dscIntf==NULL) return NO;
    req.bmRequestType=USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice);
    req.bRequest=bReq;
    req.wValue=wVal;
    req.wIndex=wIdx;
    req.wLength=len;
    req.pData=buf;
    err=(*dscIntf)->ControlRequest(dscIntf,0,&req);
    CheckError(err,"usbWriteCmdWithBRequest");
    if (err==kIOUSBPipeStalled) (*dscIntf)->ClearPipeStall(dscIntf,0);
    return (!err);
}

@end
