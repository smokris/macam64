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
#import "MySonix2028Driver.h"
#import "Resolvers.h"
#import "yuv2rgb.h"
#include "MiscTools.h"

#define VENDOR_AEL	0x0c45
#define PRODUCT_DC31UC	0x8000

@interface MySonix2028Driver (Private)

- (BOOL) setupGrabContext;				//Sets up the grabContext structure for the usb async callbacks
- (BOOL) cleanupGrabContext;				//Cleans it up
- (void) grabbingThread:(id)data;			//Entry method for the usb data grabbing thread
- (CameraError) decodingThread;				//Entry method for the chunk to image decoding thread
- (BOOL) startupGrabStream;				//Initiates camera streaming
- (BOOL) shutdownGrabStream;				//stops camera streaming
- (void) decodeChunk:(SONIXChunkBuffer*)chunk to:(UInt8*)pixmap bpp:(short)bpp rowBytes:(long)rb;
//Decodes a chunk into a pixmap. No checks, all assumed locked and ready. Just the internal decode.

- (CameraError) writeRegisterBlind:(UInt16)reg value:(UInt16)val;
- (CameraError) writeRegister:(UInt16)reg value:(UInt16)val wantedResult:(UInt8)wanted;

@end

@implementation MySonix2028Driver

+ (unsigned short) cameraUsbProductID { return PRODUCT_DC31UC; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_AEL; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"AEL Auracam DC-31UC"]; }

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err=[self usbConnectToCam:usbDeviceRef];
//setup connection to camera
    if (err!=CameraErrorOK) return err;
//Set brightness, contrast and saturation
    [super setContrast:0.5f];
    [super setSaturation:0.5f];
    [self setBrightness:0.5f];
    [super setAutoGain:YES];
    [super setShutter:0.5f];
    [self setGain:0.5f];
    [self setCompression:0];
    memset(&grabContext,0,sizeof(SONIXGrabContext));
    return [super startupWithUsbDeviceRef:usbDeviceRef];
}

- (void) dealloc {
    [self usbCloseConnection];
    [super dealloc];
}


- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    return ((fr==5)&&((r==ResolutionQSIF)||(r==ResolutionSIF)||(r==ResolutionVGA)));
}

- (void) setResolution:(CameraResolution)r fps:(short)fr {
    [super setResolution:r fps:fr];	//Update instance variables if state is ok and format is supported
    //***
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {	//This is a start
    if (dFps) *dFps=5;
    return ResolutionSIF;
}

- (BOOL) setupGrabContext {
    long i;

    BOOL ok=YES;
    [self cleanupGrabContext];					//cleanup in case there's something left in here

//Simple things first
    grabContext.bytesPerFrame=1023;	//We can find this out *********
    grabContext.chunkBufferLength=[self width]*[self height]*4+10000;	//That should be more than enough ***
    grabContext.numEmptyBuffers=0;
    grabContext.numFullBuffers=0;
    grabContext.fillingChunk=false;
    grabContext.finishedTransfers=0;
    grabContext.intf=intf;
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
    for (i=0;(i<SONIX_NUM_CHUNK_BUFFERS)&&(ok);i++) {
        MALLOC(grabContext.emptyChunkBuffers[i].buffer,unsigned char*,grabContext.chunkBufferLength,"SONIX chunk buffers");
        if (grabContext.emptyChunkBuffers[i].buffer) grabContext.numEmptyBuffers++;
        else ok=NO;
    }
//get the transfer buffers
    for (i=0;(i<SONIX_NUM_TRANSFERS)&&(ok);i++) {
        MALLOC(grabContext.transferContexts[i].buffer,unsigned char*,grabContext.bytesPerFrame*SONIX_FRAMES_PER_TRANSFER+10,"SONIX transfer buffers");	//10 extra for chunk end check ***
        if (!(grabContext.transferContexts[i].buffer)) ok=NO;
        else {
            long j;
            for (j=0;j<SONIX_FRAMES_PER_TRANSFER;j++) {	//init frameList
                grabContext.transferContexts[i].frameList[j].frReqCount=grabContext.bytesPerFrame;
                grabContext.transferContexts[i].frameList[j].frActCount=0;
                grabContext.transferContexts[i].frameList[j].frStatus=0;
            }
        }
    }
    //Note: Timing info will be filled in later
    
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
    
    for (i=0;(i<SONIX_NUM_TRANSFERS)&&(ok);i++) {
        if (grabContext.transferContexts[i].buffer) {
            FREE(grabContext.transferContexts[i].buffer,"transfer buffer");
            grabContext.transferContexts[i].buffer=NULL;
        }
    }
    return YES;
}

//StartNextIsochRead and isocComplete refer to each other, so here we need a declaration
static bool StartNextIsochRead(SONIXGrabContext* grabContext, int transferIdx);


//Puts the current chunk to the empty chunk list. Afterwards, there's no current chunk
inline static void discardCurrentChunk(SONIXGrabContext* gCtx) {
    if (!(gCtx->fillingChunk)) return;		//Nothing to discard
    [gCtx->chunkListLock lock];			//Get permission to manipulate chunk lists
    gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers]=gCtx->fillingChunkBuffer;
    gCtx->numEmptyBuffers++;			//our fresh chunk has been added to the full ones
    gCtx->fillingChunk=false;
    gCtx->fillingChunkBuffer.buffer=NULL;	//it's redundant but to be safe...
    [gCtx->chunkListLock unlock];		//exit critical section
}

//Puts the current chunk to the full chunk list and notifies the decoder. Afterwards, there's no current chunk
inline static void passCurrentChunk(SONIXGrabContext* gCtx) {
    if (!(gCtx->fillingChunk)) return;		//Nothing to pass
    [gCtx->chunkListLock lock];			//Get permission to manipulate chunk lists
    gCtx->fullChunkBuffers[gCtx->numFullBuffers]=gCtx->fillingChunkBuffer;
    gCtx->numFullBuffers++;			//our fresh chunk has been added to the full ones
    gCtx->fillingChunk=false;
    gCtx->fillingChunkBuffer.buffer=NULL;	//it's redundant but to be safe...
    [gCtx->chunkListLock unlock];		//exit critical section
    [gCtx->chunkReadyLock tryLock];		//try to wake up the decoder
    [gCtx->chunkReadyLock unlock];
    gCtx->framesSinceLastChunk=0;
}

//Takes a new chunk from the empty chunk list (or the full ones, if there's no empty one left). Discards the
//current chunk if there's one
inline static void startNewChunk(SONIXGrabContext* gCtx) {
    if (gCtx->fillingChunk) discardCurrentChunk(gCtx);
    [gCtx->chunkListLock lock];			//Get permission to manipulate buffer lists
    if (gCtx->numEmptyBuffers>0) {			//We can take an empty chunk
        gCtx->numEmptyBuffers--;
        gCtx->fillingChunkBuffer=gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers];
    } else {					//No empty chunk - take the oldest full one
        long j;
        gCtx->fillingChunkBuffer=gCtx->fullChunkBuffers[0];
        for (j=1;j<gCtx->numFullBuffers;j++) {	//all other full ones go one up in the list
            gCtx->fullChunkBuffers[j-1]=gCtx->fullChunkBuffers[j];
        }
        gCtx->numFullBuffers--;
    }
    gCtx->fillingChunk=true;
    [gCtx->chunkListLock unlock];			//Done manipulating buffer lists
    gCtx->fillingChunkBuffer.numBytes=0;
}


FILE* logFile=NULL;


static void isocComplete(void *refcon, IOReturn result, void *arg0) {
    int i;
    SONIXGrabContext* gCtx=(SONIXGrabContext*)refcon;
    IOUSBIsocFrame* myFrameList=(IOUSBIsocFrame*)arg0;
    short transferIdx=0;
    bool frameListFound=false;
    long currFrameLength;
    unsigned char* frameBase;

    //Ignore data underruns - timeouts will be detected by framesSinceLastChunk
//    NSLog(@"isocComplete: %i",result);

    if (result==kIOReturnUnderrun) result=0;
    
    if (result) {						//USB error handling
        *(gCtx->shouldBeGrabbing)=NO;				//We'll stop no matter what happened
        if (!gCtx->err) {
            if (result==kIOReturnOverrun) gCtx->err=CameraErrorTimeout;		//We didn't setup the transfer in time
            else gCtx->err=CameraErrorUSBProblem;				//Something else...
        }
        if (result!=kIOReturnOverrun) CheckError(result,"isocComplete");	//Other error than timeout: log to console
    }

    if (*(gCtx->shouldBeGrabbing)) {						//look up which transfer we are
        while ((!frameListFound)&&(transferIdx<SONIX_NUM_TRANSFERS)) {
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
        for (i=0;i<SONIX_FRAMES_PER_TRANSFER;i++) {			//let's have a look into the usb frames we got
            currFrameLength=myFrameList[i].frActCount;			//Cache this - it won't change and we need it several times
            frameBase=gCtx->transferContexts[transferIdx].buffer+gCtx->bytesPerFrame*i;
            
            //DO DATA PARSING HERE ****
            if (logFile==NULL) logFile=fopen("/Users/matthias/Desktop/log","w");
            fwrite(frameBase,1,currFrameLength,logFile);

            if (!(gCtx->fillingChunk)) startNewChunk(gCtx);
            if (!gCtx->fillingChunk) {
                UInt8* src=frameBase;
                long i=currFrameLength;
                for (i=0;i<currFrameLength-5;i++) {
                    if ((src[i]==0xff)&&(src[i+1]==0xff)&&(src[i+2]==0x00)
                            &&(src[i+3]==0xc4)&&(src[i+4]==0xc4)&&(src[i+5]==0x96)) {
                        startNewChunk(gCtx);
                        currFrameLength-=i+1;
                        frameBase+=i+1;
                        i=currFrameLength+1;	//Break from loop
                    }
                }
            }
            if (gCtx->fillingChunk) {
                //Prevent buffer overflows. The chunk buffers have enough extra space to hold a whole chunk in every case.
                if (gCtx->fillingChunkBuffer.numBytes+currFrameLength>=gCtx->chunkBufferLength) discardCurrentChunk(gCtx);
                else {
                    UInt8* src=frameBase;
                    UInt8* dst=gCtx->fillingChunkBuffer.buffer+gCtx->fillingChunkBuffer.numBytes;
                    UInt8 val;
                    long i=currFrameLength;
                    for (i=0;i<currFrameLength;i++) {
                        val=*(src++);
                        *(dst++)=val;
                        if (val==0xff) {
                            //Chunk end detection
                            if ((src[0]==0xff)&&(src[1]==0x00)&&(src[2]==0xc4)&&(src[3]==0xc4)&&(src[4]==0x96)) {
                                gCtx->fillingChunkBuffer.numBytes+=i;
                                passCurrentChunk(gCtx);
                                startNewChunk(gCtx);
                                dst=gCtx->fillingChunkBuffer.buffer;
                                gCtx->fillingChunkBuffer.numBytes-=i;	//Warning! Might temporarily be negative!
                            }
                        }
                    }
                    gCtx->fillingChunkBuffer.numBytes+=currFrameLength;
                }
            }
        }
        gCtx->framesSinceLastChunk+=SONIX_FRAMES_PER_TRANSFER;	//Count frames (not necessary to be too precise here...)
        if ((gCtx->framesSinceLastChunk)>1000) {		//One second without a frame?
#ifdef VERBOSE
            NSLog(@"SONIX grab aborted because of invalid data stream");
#endif
            *(gCtx->shouldBeGrabbing)=NO;
            if (!gCtx->err) gCtx->err=CameraErrorUSBProblem;
        }
    }
    if (*(gCtx->shouldBeGrabbing)) {	//initiate next transfer
        if (!StartNextIsochRead(gCtx,transferIdx)) *(gCtx->shouldBeGrabbing)=NO;
    }
    if (!(*(gCtx->shouldBeGrabbing))) {	//on error: collect finished transfers and exit if all transfers have ended
        gCtx->finishedTransfers++;
        if ((gCtx->finishedTransfers)>=(SONIX_NUM_TRANSFERS)) {
            discardCurrentChunk(gCtx);
            fclose(logFile);
            logFile=NULL;
            CFRunLoopStop(CFRunLoopGetCurrent());
        }
    }
}

static bool StartNextIsochRead(SONIXGrabContext* grabContext, int transferIdx) {
    IOReturn err;
    err=(*(grabContext->intf))->ReadIsochPipeAsync(grabContext->intf,
                                                   1,
                                                   grabContext->transferContexts[transferIdx].buffer,
                                                   grabContext->initiatedUntil,
                                                   SONIX_FRAMES_PER_TRANSFER,
                                                   grabContext->transferContexts[transferIdx].frameList,
                                                   (IOAsyncCallback1)(isocComplete),
                                                   grabContext);
    switch (err) {
        case 0:
            grabContext->initiatedUntil+=SONIX_FRAMES_PER_TRANSFER;	//update frames
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

    if (![self usbSetAltInterfaceTo:8 testPipe:1]) {
        if (!grabContext.err) grabContext.err=CameraErrorNoBandwidth;	//probably no bandwidth
        ok=NO;
    }
    if (![self usbSetAltInterfaceTo:7 testPipe:1]) {
        if (!grabContext.err) grabContext.err=CameraErrorNoBandwidth;	//probably no bandwidth
        ok=NO;
    }
    if (ok) {
        ok=[self startupGrabStream];
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
        for (i=0;(i<SONIX_NUM_TRANSFERS)&&ok;i++) {	//Initiate transfers
            ok=StartNextIsochRead(&grabContext,i);
        }
    }

    if (ok) {
                
        CFRunLoopRun();					//Do our run loop
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//remove the event source
    }

    [self shutdownGrabStream];
    [self usbSetAltInterfaceTo:0 testPipe:0];
    shouldBeGrabbing=NO;			//error in grabbingThread or abort? initiate shutdown of everything else
    [grabContext.chunkReadyLock unlock];	//give the decodingThread a chance to abort
    [pool release];
    grabbingThreadRunning=NO;
    [NSThread exit];
}


#define REFILL_BIT_BUF {if (bitBufCount<24) { bitBuf=(bitBuf<<8)|(*(src++)); bitBufCount+=8;}}
#define GET_ONE_FROM_BIT_BUF { bits=(bitBuf>>(bitBufCount-1))&0x01; bitBufCount--; }
#define GET_TWO_FROM_BIT_BUF { bits=(bitBuf>>(bitBufCount-2))&0x03; bitBufCount-=2; }
#define GET_FOUR_FROM_BIT_BUF { bits=(bitBuf>>(bitBufCount-4))&0x0f; bitBufCount-=4; }
#define GET_FIVE_FROM_BIT_BUF { bits=(bitBuf>>(bitBufCount-5))&0x1f; bitBufCount-=5; }
#define GET_SIX_FROM_BIT_BUF { bits=(bitBuf>>(bitBufCount-6))&0x3f; bitBufCount-=6; }
#define GET_SEVEN_FROM_BIT_BUF { bits=(bitBuf>>(bitBufCount-7))&0x7f; bitBufCount-=7; }
#define GET_EIGHT_FROM_BIT_BUF { bits=(bitBuf>>(bitBufCount-8))&0xff; bitBufCount-=8; }

/* Here's the format of the data stream format (AFAIK)

The strem


*/

//This is the "netto" decoder - maybe some work left to do :)

- (void) decodeChunk:(SONIXChunkBuffer*)chunk to:(UInt8*)pixmap bpp:(short)bpp rowBytes:(long)rb {
    UInt8* src=chunk->buffer;
    UInt8* dst=pixmap;
    UInt8 bits;
    UInt8 c1val,c2val,val;
    int x,y;
    int width=[self width];
    int height=[self height];
    int dstRowSkip=rb-(width*bpp);
    UInt32 bitBuf;
    UInt32 bitBufCount=0;
    BOOL marker;
    src+=11;
    REFILL_BIT_BUF;
    GET_ONE_FROM_BIT_BUF;
    GET_ONE_FROM_BIT_BUF;
    for (y=0;y<height;y++) {
        //Line 0
        REFILL_BIT_BUF;
        GET_SIX_FROM_BIT_BUF;
        c1val=bits;
        REFILL_BIT_BUF;
        GET_EIGHT_FROM_BIT_BUF;
        c2val=bits;
        NSLog(@"six: %02x eight:%02x",c1val,c2val);
        c1val=c2val=0;
        for (x=0;x<width;x++) {
            marker=NO;
            val=(x&1)?c2val:c1val;
            REFILL_BIT_BUF;
            GET_ONE_FROM_BIT_BUF;			//bit 1
            if (bits) {
                GET_TWO_FROM_BIT_BUF;			//Bit 2 & 3
                switch (bits) {
                    case 1:
                        val++;
                        break;
                    case 2:
                        val--;
                        break;
                    case 0:
                        GET_ONE_FROM_BIT_BUF;		//bit 4
                        if (bits) val+=2;
                        else val-=2;
                        break;
                    case 3:
                        GET_ONE_FROM_BIT_BUF;		//bit 4
                        if (bits==0) {
                            GET_ONE_FROM_BIT_BUF;	//bit 5
                            if (bits==0) {//0
                                val+=4;
                            } else {
                                REFILL_BIT_BUF;
                                GET_FIVE_FROM_BIT_BUF;	//bit 6-10
                                val=bits*8;
                                marker=YES;
                            }
                        } else {
                            val-=4;
                        }
                        break;
                    default:
                        break;
                }
            }
            if (x&1) {
                c2val=val;
            } else {
                c1val=val;
            }
            if (bpp==4) *(dst++)=255;
            if (marker) {
                *(dst++)=255;
                *(dst++)=0;
                *(dst++)=0;
            } else {
                *(dst++)=val*10;
                *(dst++)=val*10;
                *(dst++)=val*10;
            }
        }
        dst+=dstRowSkip;
    }
}

- (BOOL) canSetBrightness { return YES; }
- (BOOL) canSetContrast { return YES; }

- (void) dummyDecodeChunk:(SONIXChunkBuffer*)chunk to:(UInt8*)pixmap bpp:(short)bpp rowBytes:(long)rb {
    UInt8* dst=pixmap;
    UInt8* src=chunk->buffer;
    UInt8 val;
    int x,y;
    int width=[self width];
    int height=[self height];
    int dstRowSkip=rb-(width*bpp);
    memset(chunk->buffer+chunk->numBytes,0,grabContext.chunkBufferLength-chunk->numBytes);
    for (y=height;y>0;y--) {
        for (x=width;x>0;x--) {
            val=*(src++);
            *(dst++)=val;
            *(dst++)=val;
            *(dst++)=val;
            if (bpp==4) *(dst++)=val;
        }
        dst+=dstRowSkip;
    }
}

- (CameraError) decodingThread {
    SONIXChunkBuffer currChunk;
    long i;
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

//Following: The decoding loop
    while (shouldBeGrabbing) {
        [grabContext.chunkReadyLock lock];				//wait for ready-to-decode chunks
        while ((grabContext.numFullBuffers>0)&&(shouldBeGrabbing)&&(err==CameraErrorOK)) {	//decode all chunks or skip if we have stopped grabbing
            [grabContext.chunkListLock lock];				//lock for access to chunk list
            currChunk=grabContext.fullChunkBuffers[0];			//take first (oldest) chunk

/* Note: we may safely take out the buffer if we but it back in later since grabbingThread doesn't require to have a constant number. And if there are at least three buffers, there's always one to take. But we have to give it back before completion for a clean dealloc */

            for(i=1;i<grabContext.numFullBuffers;i++) {			//all others go one down
                grabContext.fullChunkBuffers[i-1]=grabContext.fullChunkBuffers[i];
            }
            grabContext.numFullBuffers--;				//we have taken one from the list
            [grabContext.chunkListLock unlock];				//we're done accessing the chunk list.
            frameCounter++;

            //Data is in currChunk. Here's the place to decode... *******

            if (nextImageBufferSet) {
                [imageBufferLock lock];				//lock image buffer access
                if (nextImageBuffer!=NULL) {
                    [self decodeChunk:&currChunk
                                   to:nextImageBuffer
                                  bpp:nextImageBufferBPP
                             rowBytes:nextImageBufferRowBytes];
                }
                lastImageBuffer=nextImageBuffer;		//Copy nextBuffer info into lastBuffer
                lastImageBufferBPP=nextImageBufferBPP;
                lastImageBufferRowBytes=nextImageBufferRowBytes;
                nextImageBufferSet=NO;				//nextBuffer has been eaten up
                [imageBufferLock unlock];			//release lock
                [self mergeImageReady];				//notify delegate about the image. perhaps get a new buffer
            }
            
/*Now it's time to give back the chunk buffer we used - no matter if we used it or not. In case it was discarded this is somehow not the most elegant solution because we have to lock chunkListLock twice, but that should be not too much of a problem since we obviously have plenty of image data to waste... */
            [grabContext.chunkListLock lock];			//lock for access to chunk list
            grabContext.emptyChunkBuffers[grabContext.numEmptyBuffers]=currChunk;	//give back chunk buffer
            grabContext.numEmptyBuffers++;
            [grabContext.chunkListLock unlock];			//we're done accessing the chunk list.
        }
    }

    while (grabbingThreadRunning) {}			//Active wait for grabbingThread finish
    
    [self cleanupGrabContext];				//grabbingThread doesn't need the context any more since it's done
    if (mergeBuffer) {
        FREE(mergeBuffer,"mergeBuffer");		//don't need the merge buffer any more
        mergeBuffer=NULL;
    }
    if (!err) err=grabContext.err;			//Forward decoding thread error
    return grabContext.err;				//notify delegate
}

/* Here's what I know (or guess) about the registers so far:

The native Resolution is VGA (it might also be CIF, but my camera is VGA and therefore I assume it right now). Based on the wanted resolution, there's a subsampling factor (by 1,2 or 4). The divider is chosen by setting either register 0x1601,0x1602 or 0x1604 to zero (seems to be a trigger).

Registers 0x1d25 and 0x2036 seem to be shutter/gain settings.

Registers 0x1328, 0x1329, 1121, 1123 and 1c20 seem to be resolution- (or compression-)dependent.

There seems to be a procedure to set the registers. It is implemented in [writeRegister:].

The video in the data stream is a GRBG-Bayer pattern (compressed by some sort of run-length encoding and Huffman compression). The data stream format is as follows:

<frame 1 header>
   <line 1 header>
      <pixel 1 bitcode>
      <pixel 2 bitcode>
      ...
      <pixel x bitcode>
   <line 2 header>
   ...
   <line y header>
<padding bits>
<frame 2 header>
...

The frame header is 12 bytes long (0xff 0xff 0x00 0xc4 0xc4 0x96 0x00 0x<*1> 0x<*2> 0x<*3> 0x<*4> 0x<*5>). <*1> seems to be a frame counter (bits 6 and 7) and a size indicator (bits 1 and 2: 00=VGA, 01=SIF, 10=QSIF) Bit 0 seems to be always 1 (validity?), 4 and 5 seem to be always 0. Bit 3 is often 0 (but not always).<*2> to <*5>'s meanings are unknown (maybe some sort of brightness summary).

After that, the video lines follow. Each line starts with a 14-bit line header with two 7-bit starting values - since it's a Bayer pattern, there are two color components alternating in each line. Both components are tracked individually and independently (just alternating).

For each pixel, there's a code in the stream that describes how the component value changes. These codes are not bound to bytes - it's a pure bitstream. Codes have different lengths, according to their likeliness (similar to Huffman compression). The codes are as follows:

0 		: 0 (leave as is)
1000		: ???
1001		: ???
101 		: +1
110 		: -1
11100		: ???
11101xxxxx 	: ???
1111		: ???

After the line header, the actual pixels follow.


*/


- (BOOL) startupGrabStream {
    UInt16 dividerReg, reg1328val, reg1329val, reg1121val, reg1123val, reg1c20val;
    switch (resolution) {
        case ResolutionVGA:
            dividerReg=0x1601;
            reg1328val=0x010e;
            reg1329val=0x0162;
            reg1121val=0x2a00;
            reg1123val=0x2800;
            reg1c20val=0x002a;
            break;
        case ResolutionSIF:
            dividerReg=0x1602;
            reg1328val=0x011e;
            reg1329val=0x0122;
            reg1121val=0xc100;
            reg1123val=0x1000;
            reg1c20val=0x00c1;
            break;
        default: // ResolutionQSIF:
            dividerReg=0x1604;
            reg1328val=0x012e;
            reg1329val=0x0122;
            reg1121val=0xc100;
            reg1123val=0x1000;
            reg1c20val=0x00c1;
            break;
    }
    if ([self writeRegister:0x0c01 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:dividerReg value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1000 value:0x0000 wantedResult:0x01]) return NO;
    if ([self writeRegister:0x1325 value:0x0116 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1326 value:0x0112 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1328 value:0x010e wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1327 value:0x0120 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1329 value:0x0122 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132c value:0x0102 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132d value:0x0102 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132e value:0x0109 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132f value:0x0107 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1120 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1121 value:0x2d00 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1122 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1123 value:0x0300 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1110 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1111 value:0x6400 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1112 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1113 value:0x9100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1114 value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1115 value:0x2000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1116 value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1117 value:0x6000 wantedResult:0x00]) return NO;
    if ([self writeRegisterBlind:0x1c20 value:0x002d]) return NO;
    if ([self writeRegister:0x1320 value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1321 value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1322 value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1323 value:0x0101 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1324 value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1325 value:0x0116 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1326 value:0x0112 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1327 value:0x0120 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1328 value:0x010e wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1329 value:0x0122 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132a value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132b value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132c value:0x0102 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132d value:0x0102 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132e value:0x0109 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132f value:0x0107 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1234 value:0x0100 wantedResult:0xa1]) return NO;
    if ([self writeRegister:0x1334 value:0x01a1 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1335 value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1101 value:0x0400 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1102 value:0x9200 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1110 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1111 value:0x6400 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1112 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1113 value:0x9100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1114 value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1115 value:0x2000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1116 value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1117 value:0x6000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1120 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1121 value:0x2d00 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1122 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1123 value:0x0300 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1125 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1126 value:0x0200 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1127 value:0x8800 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1130 value:0x3800 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1131 value:0x2a00 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1132 value:0x2a00 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1133 value:0x2a00 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1134 value:0x0200 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x115b value:0x0a00 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1325 value:0x0128 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1326 value:0x011e wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1328 value:reg1328val wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1327 value:0x0120 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1329 value:reg1329val wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132c value:0x0102 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132d value:0x0103 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132e value:0x010f wantedResult:0x00]) return NO;
    if ([self writeRegister:0x132f value:0x010c wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1120 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1121 value:reg1121val wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1122 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1123 value:reg1123val wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1110 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1111 value:0x0400 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1112 value:0x0000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1113 value:0x0300 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1114 value:0x0100 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1115 value:0xe000 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1116 value:0x0200 wantedResult:0x00]) return NO;
    if ([self writeRegister:0x1117 value:0x8000 wantedResult:0x00]) return NO;
    if ([self writeRegisterBlind:0x1c20 value:reg1c20val]) return NO;
    if ([self writeRegisterBlind:0x1c20 value:reg1c20val]) return NO;
    if ([self writeRegisterBlind:0x2034 value:0xa100]) return NO;
    return YES;
}

- (BOOL) shutdownGrabStream {
    if ([self writeRegisterBlind:0x1400 value:0x0000]) return NO;
    return YES;
}

- (CameraError) writeRegisterBlind:(UInt16)reg value:(UInt16)val {
    UInt8 buf[6];
    buf[0]=(reg&0xff00)>>8;
    buf[1]=reg&0x00ff;
    buf[2]=(val&0xff00)>>8;
    buf[3]=val&0x00ff;
    buf[4]=0;
    buf[5]=0;
    if ([self usbWriteVICmdWithBRequest:8 wValue:2 wIndex:0 buf:buf len:6]) return CameraErrorOK;
    else return CameraErrorUSBProblem;
}

- (CameraError) writeRegister:(UInt16)reg value:(UInt16)val wantedResult:(UInt8)wanted {
    CameraError err;

    //Send write command
    err=[self writeRegisterBlind:reg value:val];	
    UInt8 buf[4];
    //Wait for completion (?)
    do {
        if (![self usbReadVICmdWithBRequest:0 wValue:1 wIndex:0 buf:buf len:1]) return CameraErrorUSBProblem;
    } while (buf[0]!=2);
    //Check result
    if (![self usbReadVICmdWithBRequest:0 wValue:4 wIndex:0 buf:buf len:4]) return CameraErrorUSBProblem;
    if (wanted!=buf[1]) NSLog(@"writeRegister:%i value:%i wanted:%i received:%i",reg,val,wanted,buf[1]);
    if ((((reg&0xff00)>>8)+0x80)!=buf[0]) NSLog(@"writeRegister:%i value:%i bad result %i",reg,val,buf[0]);
    return CameraErrorOK;
}

@end