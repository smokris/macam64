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

/* Here's what I know (or guess) about the chipset so far:

The native Resolution is VGA (it might also be CIF, but my camera is VGA and therefore I assume it right now). Based on the wanted resolution, there's a subsampling factor (by 1,2 or 4). The divider is chosen by setting either register 0x1601,0x1602 or 0x1604 to zero (seems to be a trigger).

Registers 0x1b23, 0x1d25 and 0x2036 seem to be shutter/gain settings.
Registers 0x1328, 0x1329, 1121, 1123 and 1c20 seem to be resolution- (or compression-)dependent.

Registers accessed repeatedly:
0x1227
0x1b32 : Gain / Shutter ???
0x1d25
0x2027
0x2029
0x2036 : Band filter 50/60 Hz ???
0x1d25

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

The frame header is 12 bytes long (0xff 0xff 0x00 0xc4 0xc4 0x96 0x00 0x<*1> 0x<*2> 0x<*3> 0x<*4> 0x<*5>). <*1> seems to be a frame counter (bits 6 and 7) and a size indicator (bits 1 and 2: 00=VGA, 01=SIF, 10=QSIF) Bit 0 seems to be always 1, 4 and 5 seem to be always 0. Bit 3 is often 0 (but not always).<*2> to <*5>'s meanings are probably some sort of brightness summary/averavge.

After that, the video lines follow. Each line starts with a 16-bit line header with two 8-bit starting values - since it's a Bayer pattern, there are two color components alternating in each line. Both components are tracked individually and independently (just alternating).

After the line header, the actual pixels follow. Th line lengths don't match exactly their named formats - for example, VGA mode seems to have only 638 Pixels in a row. For each pixel, there's a code in the stream that describes the next component value. It can either be described as a change from the last value of that component or as a direct value. These codes are not bound to bytes - it's a pure bitstream. Codes have different lengths, according to their likeliness. The algorithm is similar to Huffman compression, the main differences are a) the two modes, b) the bit codes seem to be handmade, c) there's some redundancy because of the two description modes and d) not all possible values exist - therefore, the values had to be quantized (i.e. this compression algorithm is lossy). The codes are as follows (they are not completely correct, I have to figure out a better way to decipher this, but they basically work):

0 		: 0 (leave as is)
1000		: +8
1001		: -8
101 		: +3
110 		: -3
11100		: +18
11101xxxxx 	: =8*(xxxxx)+4 (these values seem to be unprecise - especially for low values)
1111		: -18






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
- (void) decode:(UInt8*)src to:(UInt8*)pixmap width:(int)width height:(int) height bpp:(short)bpp rowBytes:(long)rb;
//Decodes SONIX-compressed data into a pixmap. No checks, all assumed ready and fine. Just the internal decode.

- (CameraError) writeRegisterBlind:(UInt16)reg value:(UInt16)val;
- (CameraError) writeRegister:(UInt16)reg value:(UInt16)val result:(UInt32*)wanted;

@end

@implementation MySonix2028Driver

+ (unsigned short) cameraUsbProductID { return PRODUCT_DC31UC; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_AEL; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"AEL Auracam DC-31UC"]; }

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err=[self usbConnectToCam:usbDeviceRef];
//setup connection to camera
    if (err!=CameraErrorOK) return err;
    memset(&grabContext,0,sizeof(SONIXGrabContext));
    bayerConverter=[[BayerConverter alloc] init];
    if (!bayerConverter) return CameraErrorNoMem;
    [bayerConverter setSourceFormat:2];
    MALLOC(bayerBuffer,UInt8*,(642)*(382),"Temp Bayer buffer");
    if (!bayerBuffer) return CameraErrorNoMem;
    //Set brightness, contrast, saturation etc
    [self setContrast:0.5f];
    [self setSaturation:0.5f];
    [self setBrightness:0.5f];
    [self setGamma:0.5f];
    [self setSharpness:0.5f];
    [self setAutoGain:YES];
    [super setShutter:0.5f];
    [super setGain:0.5f];
    [self setCompression:0];
    return [super startupWithUsbDeviceRef:usbDeviceRef];
}

- (void) dealloc {
    [self usbCloseConnection];
    if (bayerBuffer) FREE(bayerBuffer,"Temp Bayer buffer");
    if (bayerConverter) [bayerConverter release];
    [super dealloc];
}


- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    return ((fr==5)&&((r==ResolutionQSIF)||(r==ResolutionSIF)||(r==ResolutionVGA)));
}


- (CameraResolution) defaultResolutionAndRate:(short*)dFps {	//This is a start
    if (dFps) *dFps=5;
    return ResolutionSIF;
}

- (BOOL) canSetSharpness {
    return YES;
}

- (void) setSharpness:(float)v {
    [super setSharpness:v];
    [bayerConverter setSharpness:sharpness];
}

- (BOOL) canSetBrightness {
    return YES;
}

- (void) setBrightness:(float)v {
    [super setBrightness:v];
    [bayerConverter setBrightness:brightness-0.5f];
}

- (BOOL) canSetContrast {
    return YES;
}

- (void) setContrast:(float)v {
    [super setContrast:v];
    [bayerConverter setContrast:contrast+0.5f];
}

- (BOOL) canSetSaturation {
    return YES;
}

- (void) setSaturation:(float)v {
    [super setSaturation:v];
    [bayerConverter setSaturation:saturation*2.0f];
}

- (BOOL) canSetGamma  {
    return YES;
}

- (void) setGamma:(float)v {
    [super setGamma:v];
    [bayerConverter setGamma:gamma+0.5f];
}

- (BOOL) canSetGain {
    return YES;
}

- (BOOL) canSetShutter {
    return YES;
}

- (BOOL) canSetAutoGain {
    return YES;
}

- (void) setAutoGain:(BOOL)v{
    [super setAutoGain:v];
    if (autoGain) {
        grabContext.autoExposure=0.5f;
    } else {
        [self setGain:gain];
        [self setShutter:shutter];
    }
}

- (void) setGain:(float)val {
    [super setGain:val];
    if (isGrabbing) {
        int v=gain*50.0f;
        [self writeRegisterBlind:0x1b32 value:v<<8];
        [self writeRegister:0x1227 value:0x0100 result:NULL]; //should return 0x9220;
    }
}

- (void) setShutter:(float)val {
    [super setShutter:val];
    if (isGrabbing) {
        int v=(1.0f-shutter)*2560.0f;
        [self writeRegisterBlind:0x1d25 value:v];
        [self writeRegister:0x1227 value:0x0100 result:NULL]; //should return 0x9220;
    }
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
    grabContext.underexposuredFrames=0;
    grabContext.overexposuredFrames=0;
    grabContext.autoExposure=0.5f;
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
//This is probably not the best place for auto exposure calculations, but it is efficient because every valid chunk passes this point. And these calculations don't need much time. So it is done here. The real adjustment commands are sent in the decoding thread.
inline static void passCurrentChunk(SONIXGrabContext* gCtx) {
    if (!(gCtx->fillingChunk)) return;		//Nothing to pass
    {	//Do auto exposure calculations here
        int lightness=gCtx->fillingChunkBuffer.buffer[10]+256*gCtx->fillingChunkBuffer.buffer[11];
        if (lightness<SONIX_AE_WANTED_BRIGHTNESS-SONIX_AE_ACCEPTED_TOLERANCE) gCtx->underexposuredFrames++;
        else gCtx->underexposuredFrames=0;
        if (lightness>SONIX_AE_WANTED_BRIGHTNESS+SONIX_AE_ACCEPTED_TOLERANCE) gCtx->overexposuredFrames++;
        else gCtx->overexposuredFrames=0;
        if (gCtx->underexposuredFrames>=SONIX_AE_ADJUST_LATENCY) gCtx->autoExposure-=SONIX_AE_ADJUST_STEP;
        else if (gCtx->overexposuredFrames>=SONIX_AE_ADJUST_LATENCY) gCtx->autoExposure+=SONIX_AE_ADJUST_STEP;
        if (gCtx->autoExposure>1.0f) gCtx->autoExposure=1.0f;
        if (gCtx->autoExposure<0.0f) gCtx->autoExposure=0.0f;
    }
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

//if there's a filling chunk, tries top add data to the filling chunk or discards the chunk if there's an overflow
inline static void appendToChunk(SONIXGrabContext* gCtx,UInt8* buf, long len) {
    if (len<=0) return;
    if (!gCtx->fillingChunk) return;
    if ((gCtx->fillingChunkBuffer.numBytes+len)>=gCtx->chunkBufferLength) {
        discardCurrentChunk(gCtx);
    } else {
        memcpy(gCtx->fillingChunkBuffer.buffer+gCtx->fillingChunkBuffer.numBytes,buf,len);
        gCtx->fillingChunkBuffer.numBytes+=len;
    }
}

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
            int sof=-1;
            int j;
            currFrameLength=myFrameList[i].frActCount;			//Cache this - it won't change and we need it several times
            frameBase=gCtx->transferContexts[transferIdx].buffer+gCtx->bytesPerFrame*i;
            
            //Step one: Find Start-of-frame id's in the frame
            for (j=0;j<currFrameLength-5;j++) {
                if (frameBase[j]==0xff) {
                    if (frameBase[j+1]==0xff) {
                        if (frameBase[j+2]==0x00) {
                            if (frameBase[j+3]==0xc4) {
                                if (frameBase[j+4]==0xc4) {
                                    if (frameBase[j+5]==0x96) {
                                        sof=j;
                                        j=currFrameLength;
                                    }}}}}}
            }

            //Step 2: Do the copying
            if (sof>-1) {//There's a chunk start, so we can finish the current one (if there's one...)
                appendToChunk(gCtx,frameBase,sof);
                passCurrentChunk(gCtx);
                startNewChunk(gCtx);	//Any case we have to start a new chunk here
            }
            if (sof<0) sof=0;
            appendToChunk(gCtx,frameBase+sof,currFrameLength-sof);
        }

        gCtx->framesSinceLastChunk+=SONIX_FRAMES_PER_TRANSFER;	//Count frames (not necessary to be too precise here...)
        if ((gCtx->framesSinceLastChunk)>10000) {		//One second without a frame?
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






//This is the "netto" decoder - maybe some work left to do :)

#define PEEK_BITS(num,to) {\
    if (bitBufCount<num){do{bitBuf=(bitBuf<<8)|(*(src++));bitBufCount+=8;}while(bitBufCount<24);}\
    to=bitBuf>>(bitBufCount-num);}
//PEEK_BITS puts the next <num> bits into the low bits of <to>. when the buffer is empty, it is completely refilled. This strategy tries to reduce memory access. Note that the high bits are NOT set to zero!

#define EAT_BITS(num) { bitBufCount-=num; }
//EAT_BITS consumes <num> bits (PEEK_BITS does not consume anything, it just peeks)


#define PARSE_PIXEL(val) {\
    PEEK_BITS(10,bits);\
    if ((bits&0x00000200)==0) { EAT_BITS(1); }\
    else if ((bits&0x00000380)==0x00000280) { EAT_BITS(3); val+=3; if (val>255) val=255; }\
    else if ((bits&0x00000380)==0x00000300) { EAT_BITS(3); val-=3; if (val<0) val=0;}\
    else if ((bits&0x000003c0)==0x00000200) { EAT_BITS(4); val+=8; if (val>255) val=255;}\
    else if ((bits&0x000003c0)==0x00000240) { EAT_BITS(4); val-=8; if (val<0) val=0;}\
    else if ((bits&0x000003c0)==0x000003c0) { EAT_BITS(4); val-=18; if (val<0) val=0;}\
    else if ((bits&0x000003e0)==0x00000380) { EAT_BITS(5); val+=18; if (val>255) val=255;}\
    else { EAT_BITS(10); val=8*(bits&0x0000001f)+4; }}


#define PUT_PIXEL_PAIR {\
    SInt32 pp=(c1val<<8)+c2val;\
    *((UInt16*)dst)=pp;\
    dst+=2; }

- (void) decode:(UInt8*)src to:(UInt8*)pixmap width:(int)width height:(int) height bpp:(short)bpp rowBytes:(long)rb {
    UInt8* dst=bayerBuffer+width;
    UInt16 bits;
    SInt16 c1val,c2val;
    int x,y;
    UInt32 bitBuf=0;
    UInt32 bitBufCount=0;
    src+=12;
    width-=2;		//The camera's data is actually 2 columns smaller
    for (y=0;y<height;y++) {
        PEEK_BITS(8,bits);
        EAT_BITS(8);
        c1val=bits&0x000000ff;
        PEEK_BITS(8,bits);
        EAT_BITS(8);
        c2val=bits&0x000000ff;
        for (x=0;x<width;x+=2) {
            PARSE_PIXEL(c1val);
            PARSE_PIXEL(c2val);
            PUT_PIXEL_PAIR;
        }
        PUT_PIXEL_PAIR;	//repeat the missing two pixels
    }
    [bayerConverter convertFromSrc:bayerBuffer
                            toDest:pixmap
                       srcRowBytes:width+2
                       dstRowBytes:rb
                            dstBPP:bpp];
}

- (CameraError) decodingThread {
    SONIXChunkBuffer currChunk;
    long i;
    CameraError err=CameraErrorOK;
    grabbingThreadRunning=NO;
    int width=[self width];	//Width and height are constant during a grab session, so ...
    int height=[self height];	//... they can safely be cached (to reduce Obj-C calls)
    //Setup the stuff for the decoder.
    [bayerConverter setSourceWidth:width height:height];
    [bayerConverter setDestinationWidth:width height:height];
    //Set the decoder to current settings (might be set to neutral by [getStoredMediaObject:])
    [self setBrightness:brightness];
    [self setContrast:contrast];
    [self setSaturation:saturation];
    [self setGamma:gamma];
    [self setSharpness:sharpness];
    
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

            if (nextImageBufferSet) {
                [imageBufferLock lock];				//lock image buffer access
                if (nextImageBuffer!=NULL) {
                    [self decode:currChunk.buffer
                              to:nextImageBuffer
                           width:width
                          height:height
                             bpp:nextImageBufferBPP
                        rowBytes:nextImageBufferRowBytes];
                }
                lastImageBuffer=nextImageBuffer;		//Copy nextBuffer info into lastBuffer
                lastImageBufferBPP=nextImageBufferBPP;
                lastImageBufferRowBytes=nextImageBufferRowBytes;
                nextImageBufferSet=NO;				//nextBuffer has been eaten up
                [imageBufferLock unlock];			//release lock
                [self mergeImageReady];				//notify delegate about the image. perhaps get a new buffer
                if (autoGain) {
                    int v=grabContext.autoExposure*50.0f;
                    [self writeRegisterBlind:0x1b32 value:v<<8];
                    [self writeRegister:0x1227 value:0x0100 result:NULL]; //should return 0x9220;
                    v=(1.0f-grabContext.autoExposure)*2560.0f;
                    [self writeRegisterBlind:0x1d25 value:v];
                    [self writeRegister:0x1227 value:0x0100 result:NULL]; //should return 0x9220;
                }
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
    
    if (!err) err=grabContext.err;			//Forward decoding thread error
    return grabContext.err;				//notify delegate
}



- (BOOL) startupGrabStream {
    //Don't ask me why - it's just a reproduction of what the windows driver does...
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
    
    //Unless otherwise commented, they all should return 0,0,0 for byte 2,3 and 4 (Hi byte of register+0x80 at byte 1)
    if ([self writeRegister:0x0c01 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:dividerReg value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1000 value:0x0000 result:NULL]) return NO;	//Should return 0x9001
    if ([self writeRegister:0x1325 value:0x0116 result:NULL]) return NO;
    if ([self writeRegister:0x1326 value:0x0112 result:NULL]) return NO;
    if ([self writeRegister:0x1328 value:0x010e result:NULL]) return NO;
    if ([self writeRegister:0x1327 value:0x0120 result:NULL]) return NO;
    if ([self writeRegister:0x1329 value:0x0122 result:NULL]) return NO;
    if ([self writeRegister:0x132c value:0x0102 result:NULL]) return NO;
    if ([self writeRegister:0x132d value:0x0102 result:NULL]) return NO;
    if ([self writeRegister:0x132e value:0x0109 result:NULL]) return NO;
    if ([self writeRegister:0x132f value:0x0107 result:NULL]) return NO;
    if ([self writeRegister:0x1120 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1121 value:0x2d00 result:NULL]) return NO;
    if ([self writeRegister:0x1122 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1123 value:0x0300 result:NULL]) return NO;
    if ([self writeRegister:0x1110 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1111 value:0x6400 result:NULL]) return NO;
    if ([self writeRegister:0x1112 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1113 value:0x9100 result:NULL]) return NO;
    if ([self writeRegister:0x1114 value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x1115 value:0x2000 result:NULL]) return NO;
    if ([self writeRegister:0x1116 value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x1117 value:0x6000 result:NULL]) return NO;
    if ([self writeRegisterBlind:0x1c20 value:0x002d]) return NO;
    if ([self writeRegister:0x1320 value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x1321 value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x1322 value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x1323 value:0x0101 result:NULL]) return NO;
    if ([self writeRegister:0x1324 value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x1325 value:0x0116 result:NULL]) return NO;
    if ([self writeRegister:0x1326 value:0x0112 result:NULL]) return NO;
    if ([self writeRegister:0x1327 value:0x0120 result:NULL]) return NO;
    if ([self writeRegister:0x1328 value:0x010e result:NULL]) return NO;
    if ([self writeRegister:0x1329 value:0x0122 result:NULL]) return NO;
    if ([self writeRegister:0x132a value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x132b value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x132c value:0x0102 result:NULL]) return NO;
    if ([self writeRegister:0x132d value:0x0102 result:NULL]) return NO;
    if ([self writeRegister:0x132e value:0x0109 result:NULL]) return NO;
    if ([self writeRegister:0x132f value:0x0107 result:NULL]) return NO;
    if ([self writeRegister:0x1234 value:0x0100 result:NULL]) return NO; //Should return 0x92a1
    if ([self writeRegister:0x1334 value:0x01a1 result:NULL]) return NO;
    if ([self writeRegister:0x1335 value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x1101 value:0x0400 result:NULL]) return NO;
    if ([self writeRegister:0x1102 value:0x9200 result:NULL]) return NO;
    if ([self writeRegister:0x1110 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1111 value:0x6400 result:NULL]) return NO;
    if ([self writeRegister:0x1112 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1113 value:0x9100 result:NULL]) return NO;
    if ([self writeRegister:0x1114 value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x1115 value:0x2000 result:NULL]) return NO;
    if ([self writeRegister:0x1116 value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x1117 value:0x6000 result:NULL]) return NO;
    if ([self writeRegister:0x1120 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1121 value:0x2d00 result:NULL]) return NO;
    if ([self writeRegister:0x1122 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1123 value:0x0300 result:NULL]) return NO;
    if ([self writeRegister:0x1125 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1126 value:0x0200 result:NULL]) return NO;
    if ([self writeRegister:0x1127 value:0x8800 result:NULL]) return NO;
    if ([self writeRegister:0x1130 value:0x3800 result:NULL]) return NO;
    if ([self writeRegister:0x1131 value:0x2a00 result:NULL]) return NO;
    if ([self writeRegister:0x1132 value:0x2a00 result:NULL]) return NO;
    if ([self writeRegister:0x1133 value:0x2a00 result:NULL]) return NO;
    if ([self writeRegister:0x1134 value:0x0200 result:NULL]) return NO;
    if ([self writeRegister:0x115b value:0x0a00 result:NULL]) return NO;
    if ([self writeRegister:0x1325 value:0x0128 result:NULL]) return NO;
    if ([self writeRegister:0x1326 value:0x011e result:NULL]) return NO;
    if ([self writeRegister:0x1328 value:reg1328val result:NULL]) return NO;
    if ([self writeRegister:0x1327 value:0x0120 result:NULL]) return NO;
    if ([self writeRegister:0x1329 value:reg1329val result:NULL]) return NO;
    if ([self writeRegister:0x132c value:0x0102 result:NULL]) return NO;
    if ([self writeRegister:0x132d value:0x0103 result:NULL]) return NO;
    if ([self writeRegister:0x132e value:0x010f result:NULL]) return NO;
    if ([self writeRegister:0x132f value:0x010c result:NULL]) return NO;
    if ([self writeRegister:0x1120 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1121 value:reg1121val result:NULL]) return NO;
    if ([self writeRegister:0x1122 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1123 value:reg1123val result:NULL]) return NO;
    if ([self writeRegister:0x1110 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1111 value:0x0400 result:NULL]) return NO;
    if ([self writeRegister:0x1112 value:0x0000 result:NULL]) return NO;
    if ([self writeRegister:0x1113 value:0x0300 result:NULL]) return NO;
    if ([self writeRegister:0x1114 value:0x0100 result:NULL]) return NO;
    if ([self writeRegister:0x1115 value:0xe000 result:NULL]) return NO;
    if ([self writeRegister:0x1116 value:0x0200 result:NULL]) return NO;
    if ([self writeRegister:0x1117 value:0x8000 result:NULL]) return NO;
    if ([self writeRegisterBlind:0x1c20 value:reg1c20val]) return NO;
    if ([self writeRegisterBlind:0x1c20 value:reg1c20val]) return NO;
    if ([self writeRegisterBlind:0x2034 value:0xa100]) return NO;
    [self setGain:[self gain]];
    [self setShutter:[self shutter]];
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

- (CameraError) writeRegister:(UInt16)reg value:(UInt16)val result:(UInt32*)ret {
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
    if ((((reg&0xff00)>>8)+0x80)!=buf[0]) NSLog(@"writeRegister:%04x value:%04x bad result %04x",reg,val,buf[0]);
    if (ret) *ret=*((UInt32*)buf);
    return CameraErrorOK;
}

//DSC Image download
- (BOOL) canStoreMedia {
    return YES;
}

- (long) numberOfStoredMediaObjects {
    UInt32 result;
    if ([self writeRegister:0x0c00 value:0x0000 result:&result]) return 0;
    if ([self writeRegister:0x1600 value:0x0000 result:&result]) return 0;
    if ([self writeRegister:0x1800 value:0x0000 result:&result]) return 0;
    result=(result&0x00ff0000)>>16;
    return result;
}

- (NSDictionary*) getStoredMediaObject:(long)idx {
    NSMutableData* rawBuffer;
    UInt32 result;
    UInt32 rawLength;
    UInt32 readLength;
    IOReturn err;
    NSBitmapImageRep* imageRep;
    int width;
    int height;

    //Neutralize bayer converter
    [bayerConverter setBrightness:0.0f];
    [bayerConverter setContrast:1.0f];
    [bayerConverter setSaturation:1.0f];
    [bayerConverter setGamma:1.0f];
    [bayerConverter setSharpness:0.5f];

    //Get dimensions of image
    if ([self writeRegister:0x1900+((idx+1)&0xff) value:((idx+1)&0xff00) result:&result]) return NULL;
    if (result&0x00010000) {
        width=320;
        height=240;
    }
    else {
        width=640;
        height=480;
    }

    //Get data size of image
    if ([self writeRegister:0x1a00+((idx+1)&0xff) value:((idx+1)&0xff00) result:&result]) return NULL;
    rawLength=((((result&0xff)<<16)+(result&0xff00)+((result&0xff0000)>>16))+0x3f)&0xffffc0;

    //Get raw data buffer
    //Add some safety to prevent the decoder from running into the desert
    rawBuffer=[NSMutableData dataWithLength:rawLength+12+height*2+width*height/8+100];
    if (!rawBuffer) return NULL;

    //Read raw image data
    readLength=rawLength;
    err=(*intf)->ReadPipe(intf,2, [rawBuffer mutableBytes]+12, &readLength);	//Read one chunk
    CheckError(err,"getStoredMediaObject-ReadBulkPipe");
    if (rawLength!=readLength) {
        NSLog(@"getStoredMediaObject: problem: wanted %i bytes, got %i, trying to continue...",rawLength,readLength);
    }

    //Get an imageRep to hold the image
    imageRep=[[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                      pixelsWide:width
                                                      pixelsHigh:height
                                                   bitsPerSample:8
                                                 samplesPerPixel:3
                                                        hasAlpha:NO
                                                        isPlanar:NO
                                                  colorSpaceName:NSCalibratedRGBColorSpace
                                                     bytesPerRow:0
                                                    bitsPerPixel:0] autorelease];

    //Decode the image
    [bayerConverter setSourceWidth:width height:height];
    [bayerConverter setDestinationWidth:width height:height];
    [self decode:[rawBuffer mutableBytes]
              to:[imageRep bitmapData]
           width:width
          height:height
             bpp:[imageRep bitsPerPixel]/8
        rowBytes:[imageRep bytesPerRow]];

    //Clean up
    [[rawBuffer retain] release];	//Explicitly release buffer (be nice when there are many pics)

    //Return result
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:@"bitmap",@"type",imageRep,@"data",NULL];
}


@end