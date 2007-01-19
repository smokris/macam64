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


ViviCam 3350B additions
=======================

This uses the OV7630 imaging chip, which has a BGGR bayer matrix

The code sent is almost exactly the same as above, except:
- need to skip 20 bytes, not 12 when decoding
- rows do indeed contain the full amount of pixels (the first two are actually the first two!)
- the bit-stream decoding is almost the same, these work very well, and are absolutely correct
11100		: +20
11101xxxxx 	: =8*(xxxxx)+0
1111		: -20

Some of these changes may also apply to the original (Sonix2028) driver, but without 
a way to test changes, they will be left alone.

The video for the VivCam 3350B still does not work.

FF FF 00 C4 C4 96 00 41 00 00 81 00 
0D 0E AC AC 00 00 AC 00 02 ED 42 B0 2B 00 00 00 AC 15

width and height are wrong in decoding...

*/

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#import "MyCameraCentral.h"
#import "MySonix2028Driver.h"
#import "Resolvers.h"
#import "yuv2rgb.h"
#include "MiscTools.h"
#include "unistd.h"
#include "USB_VendorProductIDs.h"


#define MAX_SHUTTER 2560000.0f

typedef enum SonixSensorType {
    SonixSensorHynixHV7131DorE_VGA=0,
    SonixSensorPixartPAS106B_CIF=1,
    SonixSensorTASC5130D_VGA=4,
    SonixSensorOV7620_VGA=6,
    SonixSensorPixartPAS202B_VGA=8,
    SonixSensorOV7630_VGA=10,
} SonixSensorType;

@interface MySonix2028Driver (Private)

- (BOOL) setupGrabContext;				//Sets up the grabContext structure for the usb async callbacks
- (BOOL) cleanupGrabContext;				//Cleans it up
- (void) grabbingThread:(id)data;			//Entry method for the usb data grabbing thread
- (CameraError) decodingThread;				//Entry method for the chunk to image decoding thread
- (BOOL) startupGrabStream;				//Initiates camera streaming
- (BOOL) shutdownGrabStream;				//stops camera streaming
- (void) decode:(UInt8*)src to:(UInt8*)pixmap width:(int)width height:(int) height bpp:(short)bpp rowBytes:(long)rb;
//Decodes SONIX-compressed data into a pixmap. No checks, all assumed ready and fine. Just the internal decode.

- (CameraError) sonixGenericCommand:(UInt8*)paramBuf expectResponse:(BOOL)resp to:(UInt8*)retBuf;

- (CameraError) sonixBulkWrite:(UInt8)type length:(UInt32)len;		//DSC mode only
- (CameraError) sonixEraseAllPictures;
- (CameraError) sonixEraseLastPicture;
- (CameraError) sonixSetModeToDSC;
- (CameraError) sonixSetModeToPCCam;
- (CameraError) sonixCaptureOneImage;					//DCS mode only, will return noMem if cam is full
- (CameraError) sonixIICSensorReadByte:(UInt8)reg to:(UInt8*)ret;	//PC Cam mode only
- (CameraError) sonixIICSensorWriteByte:(UInt8)reg to:(UInt8)val;	//PC Cam mode only
- (CameraError) sonixAsicRamReadByte:(UInt16)reg to:(UInt8*)ret;
- (CameraError) sonixAsicRamWriteByte:(UInt16)reg to:(UInt8)val;
- (CameraError) sonixQuitAP;
- (CameraError) sonixGetSensorType:(SonixSensorType*)type;
- (CameraError) sonixSetSubsampling:(int)subsample forDSCMode:(BOOL)dsc;//Allowed: 1/NO, 2/NO, 4/NO, 1/YES, 2/YES - not checked
- (CameraError) sonixGetNumberOfStoredImages:(short*)numPics;
- (CameraError) sonixIsFull:(BOOL*)full;
- (CameraError) sonixGetPictureType:(short)picIdx flash:(BOOL*)flash resolution:(CameraResolution*)res;
- (CameraError) sonixGetPicture:(short)picIdx length:(UInt32*)len;	//DSC mode only, follow bulk read, round up to n*64
- (CameraError) sonixSensorWrite1:(UInt8)addr byte1:(UInt8)b1;	//PC Cam mode only
- (CameraError) sonixSensorWrite2:(UInt8)addr byte1:(UInt8)b1 byte2:(UInt8)b2;	//PC Cam mode only
- (CameraError) sonixSensorWrite3:(UInt8)addr byte1:(UInt8)b1 byte2:(UInt8)b2 byte3:(UInt8)b3;	//PC Cam mode only
- (CameraError) sonixSensorWrite4:(UInt8)addr byte1:(UInt8)b1 byte2:(UInt8)b2 byte3:(UInt8)b3 byte4:(UInt8)b4;//PC Cam mode only
- (CameraError) sonixAsicWrite1:(UInt16)addr byte1:(UInt8)b1;
- (CameraError) sonixAsicWrite2:(UInt16)addr byte1:(UInt8)b1 byte2:(UInt8)b2;
- (CameraError) sonixAsicWrite3:(UInt16)addr byte1:(UInt8)b1 byte2:(UInt8)b2 byte3:(UInt8)b3;
- (CameraError) sonixAsicWrite4:(UInt16)addr byte1:(UInt8)b1 byte2:(UInt8)b2 byte3:(UInt8)b3 byte4:(UInt8)b4;



@end

@implementation MySonix2028Driver

+ (NSArray*) cameraUsbDescriptions 
{
    NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_SONIX],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_DC31UC],@"idProduct",
        @"AEL Auracam DC-31UC",@"name",NULL];
    
    return [NSArray arrayWithObjects:dict1,NULL];
}

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId {
    CameraError err=[self usbConnectToCam:usbLocationId configIdx:0];
//setup connection to camera
    if (err!=CameraErrorOK) return err;
    memset(&grabContext,0,sizeof(SONIXGrabContext));
    bayerConverter=[[BayerConverter alloc] init];
    if (!bayerConverter) return CameraErrorNoMem;
    [bayerConverter setSourceFormat:2];
    MALLOC(bayerBuffer,UInt8*,(642)*(482),"Temp Bayer buffer");
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
	writeSkipBytes = 12;
    rotate = NO;
    return [super startupWithUsbLocationId:usbLocationId];
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

- (BOOL) canSetShutter {
    return YES;
}

- (void) setShutter:(float)val {
    [super setShutter:val];
    if (isGrabbing) {
        UInt32 v=(1.0f-shutter)*MAX_SHUTTER;
        [self sonixSensorWrite3:0x25 byte1:(v>>16)&0xff byte2:(v>>8)&0xff byte3:(v)&0xff];
        [self sonixAsicRamReadByte:0x0127 to:NULL];
        //win driver returns 0x20
    }
}

- (BOOL) canSetAutoGain {
    return YES;
}

- (void) setAutoGain:(BOOL)v{
    [super setAutoGain:v];
    if (autoGain) {
        grabContext.autoExposure=0.5f;
    } else {
        [self setShutter:shutter];
    }
}

- (BOOL) canSetWhiteBalanceMode {
    return YES;
}

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode {
    return ((newMode==WhiteBalanceLinear)||
            (newMode==WhiteBalanceIndoor)||
            (newMode==WhiteBalanceOutdoor)||
            (newMode==WhiteBalanceAutomatic));
}

- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode {
    [super setWhiteBalanceMode:newMode];
    switch (newMode) {
        case WhiteBalanceLinear:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:1.0f green:1.0f blue:1.0f];
            break;
        case WhiteBalanceIndoor:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:0.7f green:1.1f blue:1.15f];
            break;
        case WhiteBalanceOutdoor:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:1.1f green:1.0f blue:0.9f];
            break;
        case WhiteBalanceAutomatic:
            [bayerConverter setGainsDynamic:YES];
            break;
        default:
            break;
    }
}

- (BOOL) canSetHFlip {
    return YES;
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
    grabContext.intf=streamIntf;
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
//This is a good place for some auto exposure calculations because every valid chunk passes this point. The real decisions are made and the adjustment commands are sent in the decoding thread.
inline static void passCurrentChunk(SONIXGrabContext* gCtx) {
    if (!(gCtx->fillingChunk)) return;		//Nothing to pass
    {	//Do auto exposure calculations here
        int lightness=gCtx->fillingChunkBuffer.buffer[10]+256*gCtx->fillingChunkBuffer.buffer[11];
        if (lightness<SONIX_AE_WANTED_BRIGHTNESS-SONIX_AE_ACCEPTED_TOLERANCE) gCtx->underexposuredFrames++;
        else gCtx->underexposuredFrames=0;
        if (lightness>SONIX_AE_WANTED_BRIGHTNESS+SONIX_AE_ACCEPTED_TOLERANCE) gCtx->overexposuredFrames++;
        else gCtx->overexposuredFrames=0;
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
        err = (*streamIntf)->CreateInterfaceAsyncEventSource(streamIntf, &cfSource);	//Create an event source
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
        else if ((bits&0x00000380)==0x00000280) { EAT_BITS(3); val+=3; if (val>255) val=255;}\
    else if ((bits&0x00000380)==0x00000300) { EAT_BITS(3); val-=3; if (val<0) val=0;}\
    else if ((bits&0x000003c0)==0x00000200) { EAT_BITS(4); val+=8; if (val>255) val=255;}\
    else if ((bits&0x000003c0)==0x00000240) { EAT_BITS(4); val-=8; if (val<0) val=0;}\
    else if ((bits&0x000003c0)==0x000003c0) { EAT_BITS(4); val-=18; if (val<0) val=0;}\
    else if ((bits&0x000003e0)==0x00000380) { EAT_BITS(5); val+=18; if (val>255) val=255;}\
    else { EAT_BITS(10); val=8*(bits&0x0000001f)+4; }}

/*
#define PUT_PIXEL_PAIR {\
    SInt32 pp;\
    pp=(c1val<<8)+c2val;\
    *((UInt16 *) dst) = CFSwapInt16HostToBig(pp); \
    dst+=2; }
*/

#define PUT_PIXEL_PAIR {\
    *dst++ = c1val;\
    *dst++ = c2val;\
    }
    
    
- (void) decode:(UInt8*)src to:(UInt8*)pixmap width:(int)width height:(int) height bpp:(short)bpp rowBytes:(long)rb {
    UInt8* dst=bayerBuffer+width;
    UInt16 bits;
    SInt16 c1val,c2val;
    int x,y;
    UInt32 bitBuf=0;
    UInt32 bitBufCount=0;
    src+=12;
    width-=2;		//The camera's data is actually 2 columns smaller
    height-=1;		//We start at the second line!
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
    //Copy third to first line (repeat to prevent an empty one)
    dst=bayerBuffer;
    for (x=width+2;x>0;x--) {
        *dst=dst[2*width+4];
        dst++;
    }
    //Decode Bayer
    [bayerConverter convertFromSrc:bayerBuffer
                            toDest:pixmap
                       srcRowBytes:width+2
                       dstRowBytes:rb
                            dstBPP:bpp
                              flip:hFlip
						 rotate180:rotate];
}

- (CameraError) decodingThread {
    SONIXChunkBuffer currChunk;
    long i;
    unsigned long imageCounter = 1234;
    CameraError err=CameraErrorOK;
    int width=[self width];	//Width and height are constant during a grab session, so ...
    int height=[self height];	//... they can safely be cached (to reduce Obj-C calls)
    grabbingThreadRunning=NO;
    //Setup the stuff for the decoder.
    [bayerConverter setSourceWidth:width height:height];
    [bayerConverter setDestinationWidth:width height:height];

    //Set the decoder to current settings (might be set to neutral by [getStoredMediaObject:])
    [self setBrightness:brightness];
    [self setContrast:contrast];
    [self setSaturation:saturation];
    [self setGamma:gamma];
    [self setSharpness:sharpness];
    [self setWhiteBalanceMode:whiteBalanceMode];
    
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
// Here we should save the image TODO
// currChunk.buffer
// imageCounter
			if (0) 
			{
			NSString * filename=[NSString stringWithFormat:@"/Users/harald/frame%04i.%@", imageCounter, @"raw"];
			NSData * data = [NSData dataWithBytesNoCopy: currChunk.buffer
												 length: currChunk.numBytes];
			[[NSFileManager defaultManager] createFileAtPath: filename 
													contents: data 
												  attributes: nil];
			}
// writeData
// closeFile
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
                imageCounter++;					//Count images we have decoded so far
                if (autoGain) {
                    float oldAutoExposure=grabContext.autoExposure;	//Remember old value
                    float correction=oldAutoExposure*SONIX_AE_MIN_ADJUST_STEP+
                        (1.0f-oldAutoExposure)*SONIX_AE_MAX_ADJUST_STEP;
                    if (grabContext.underexposuredFrames>SONIX_AE_ADJUST_LATENCY) {		//too dark?
                        grabContext.autoExposure-=correction;
                        if (grabContext.autoExposure<0.0f) grabContext.autoExposure=0.0f;
                    } else if (grabContext.overexposuredFrames>SONIX_AE_ADJUST_LATENCY) {	//too bright?
                        grabContext.autoExposure+=correction;
                        if (grabContext.autoExposure>1.0f) grabContext.autoExposure=1.0f;
                    }
                    if (grabContext.autoExposure!=oldAutoExposure) {	//Did something change?
                        UInt32 aExp=(1.0f-grabContext.autoExposure)*MAX_SHUTTER;
                        [self sonixSensorWrite3:0x25 byte1:(aExp>>16)&0xff byte2:(aExp>>8)&0xff byte3:aExp&0xff];
                        [self sonixAsicRamReadByte:0x0127 to:NULL];
                        //win driver returns 0x20
                    }
                }
                if ((imageCounter%2)==0) {	//HV7131 Reset level correction
                    
                }
            }
/*
 UInt8 v=gain*50.0f;
 [self sonixSensorWrite1:0x32 byte1:v];		//Bias Offset
 [self sonixAsicRamReadByte:0x0127 to:NULL];
*/
            
/*Now it's time to give back the chunk buffer we used - no matter if we used it or not. In case it was discarded this is somehow not the most elegant solution because we have to lock chunkListLock twice, but that should be not too much of a problem since we obviously have plenty of image data to waste... */
            [grabContext.chunkListLock lock];			//lock for access to chunk list
            grabContext.emptyChunkBuffers[grabContext.numEmptyBuffers]=currChunk;	//give back chunk buffer
            grabContext.numEmptyBuffers++;
            [grabContext.chunkListLock unlock];			//we're done accessing the chunk list.
        }
    }

    while (grabbingThreadRunning) { usleep(10000); }	//Wait for grabbingThread finish
    //We need to sleep here because otherwise the compiler would optimize the loop away
    
    [self cleanupGrabContext];				//grabbingThread doesn't need the context any more since it's done
    
    if (!err) err=grabContext.err;			//Forward decoding thread error
    return grabContext.err;				//notify delegate
}

- (BOOL) startupGrabStream {
    //Don't ask me why - it's just a reproduction of what the windows driver does...
    UInt8 retBuf[1];
    CameraError err=CameraErrorOK;
    
    if (!err) err=[self sonixSetModeToPCCam];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixSetSubsampling:1 forDSCMode:NO]; break;
        case ResolutionSIF: if (!err) err=[self sonixSetSubsampling:2 forDSCMode:NO]; break;
        case ResolutionQSIF: if (!err) err=[self sonixSetSubsampling:4 forDSCMode:NO]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    //Some setup from the windows driver is omitted here - I think it's useless
    if (!err) err=[self sonixIICSensorReadByte:0x00 to:retBuf];	//Get sensor identity - here model 0 (7131), rev. 1
    if (!err) err=[self sonixAsicRamWriteByte:0x0120 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0121 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0122 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0123 to:0x01];
    if (!err) err=[self sonixAsicRamWriteByte:0x0124 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0125 to:0x16];
    if (!err) err=[self sonixAsicRamWriteByte:0x0126 to:0x12];
    if (!err) err=[self sonixAsicRamWriteByte:0x0127 to:0x20];
    if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x0e];
    if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x22];
    if (!err) err=[self sonixAsicRamWriteByte:0x012a to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x012b to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x012c to:0x02];
    if (!err) err=[self sonixAsicRamWriteByte:0x012d to:0x02];
    if (!err) err=[self sonixAsicRamWriteByte:0x012e to:0x09];
    if (!err) err=[self sonixAsicRamWriteByte:0x012f to:0x07];
    if (!err) err=[self sonixAsicRamReadByte:0x0134 to:retBuf];
    if (!err) err=[self sonixAsicRamWriteByte:0x0134 to:0xa1];
    if (!err) err=[self sonixAsicRamWriteByte:0x0135 to:0x00];
    if (!err) err=[self sonixIICSensorWriteByte:0x01 to:0x04];	//Window mode, exposure line timing
    if (!err) err=[self sonixIICSensorWriteByte:0x02 to:0x92];	//some rev. 1 stuff
    if (!err) err=[self sonixIICSensorWriteByte:0x10 to:0x00];	//row start high
    if (!err) err=[self sonixIICSensorWriteByte:0x11 to:0x64];	//row start low
    if (!err) err=[self sonixIICSensorWriteByte:0x12 to:0x00];	//col start high
    if (!err) err=[self sonixIICSensorWriteByte:0x13 to:0x91];	//col start low
    if (!err) err=[self sonixIICSensorWriteByte:0x14 to:0x01];	//win width high
    if (!err) err=[self sonixIICSensorWriteByte:0x15 to:0x20];	//win width low
    if (!err) err=[self sonixIICSensorWriteByte:0x16 to:0x01];	//win height high
    if (!err) err=[self sonixIICSensorWriteByte:0x17 to:0x60];	//win height low
    if (!err) err=[self sonixIICSensorWriteByte:0x20 to:0x00];	//hsync high
    if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0x2d];	//hsync low
    if (!err) err=[self sonixIICSensorWriteByte:0x22 to:0x00];	//vsync high
    if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x03];	//vsync low
    if (!err) err=[self sonixIICSensorWriteByte:0x25 to:0x00];	//intg hi
    if (!err) err=[self sonixIICSensorWriteByte:0x26 to:0x02];	//intg mid
    if (!err) err=[self sonixIICSensorWriteByte:0x27 to:0x88];	//intg low
    if (!err) err=[self sonixIICSensorWriteByte:0x30 to:0x38];	//reset level
    if (!err) err=[self sonixIICSensorWriteByte:0x31 to:0x1e];	//gain red
    if (!err) err=[self sonixIICSensorWriteByte:0x32 to:0x1e];	//gain green
    if (!err) err=[self sonixIICSensorWriteByte:0x33 to:0x1e];	//intg blue
    if (!err) err=[self sonixIICSensorWriteByte:0x34 to:0x02];	//pixel bias
    if (!err) err=[self sonixIICSensorWriteByte:0x5b to:0x0a];	//some rev. 1 suff
    if (!err) err=[self sonixAsicRamWriteByte:0x0125 to:0x28];
    if (!err) err=[self sonixAsicRamWriteByte:0x0126 to:0x1e];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x0e]; break;
        case ResolutionSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x1e]; break;
        case ResolutionQSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x2e]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixAsicRamWriteByte:0x0127 to:0x20];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x62]; break;
        case ResolutionSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x22]; break;
        case ResolutionQSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x22]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixAsicRamWriteByte:0x012c to:0x02];
    if (!err) err=[self sonixAsicRamWriteByte:0x012d to:0x03];
    if (!err) err=[self sonixAsicRamWriteByte:0x012e to:0x0f];
    if (!err) err=[self sonixAsicRamWriteByte:0x012f to:0x0c];
    if (!err) err=[self sonixIICSensorWriteByte:0x20 to:0x00];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0x2a]; break;
        case ResolutionSIF: if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0xc1]; break;
        case ResolutionQSIF: if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0xc1]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixIICSensorWriteByte:0x22 to:0x00];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x28]; break;
        case ResolutionSIF: if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x10]; break;
        case ResolutionQSIF: if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x10]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixIICSensorWriteByte:0x10 to:0x00];
    if (!err) err=[self sonixIICSensorWriteByte:0x11 to:0x04];
    if (!err) err=[self sonixIICSensorWriteByte:0x12 to:0x00];
    if (!err) err=[self sonixIICSensorWriteByte:0x13 to:0x03];
    if (!err) err=[self sonixIICSensorWriteByte:0x14 to:0x01];
    if (!err) err=[self sonixIICSensorWriteByte:0x15 to:0xe0];
    if (!err) err=[self sonixIICSensorWriteByte:0x16 to:0x02];
    if (!err) err=[self sonixIICSensorWriteByte:0x17 to:0x80];
 switch (resolution) {
        case ResolutionVGA:
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0x2a];
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0x2a];
            break;
        case ResolutionSIF:
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
            break;
        case ResolutionQSIF:
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
            break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixAsicWrite1:0x0134 byte1:0xa1];

    if (!err) [self setGain:[self gain]];
    if (!err) [self setShutter:[self shutter]];
    return YES;
}

- (BOOL) shutdownGrabStream {
    BOOL ok=YES;
    if ([self sonixQuitAP]!=CameraErrorOK) ok=NO;
    return ok;
}

//DSC Image download
- (BOOL) canStoreMedia {
    return YES;
}

- (long) numberOfStoredMediaObjects {
    short num;
    SonixSensorType sensorType;
    if ([self sonixSetModeToDSC]!=CameraErrorOK) return 0;
    if ([self sonixGetSensorType:&sensorType]!=CameraErrorOK) return 0;
    if ([self sonixGetNumberOfStoredImages:&num]!=CameraErrorOK) return 0;
    return num;
}

- (NSDictionary*) getStoredMediaObject:(long)idx {
    NSMutableData* rawBuffer=NULL;
    UInt32 rawLength;
    UInt32 readLength;
    CameraError err=CameraErrorOK;
    IOReturn ioErr;
    CameraResolution picRes=ResolutionInvalid;
    int width=1;
    int height=1;
    BOOL flash=NO;
    NSBitmapImageRep* imageRep=NULL;

    //Neutralize bayer converter
    if (!bayerConverter) err=CameraErrorInternal;
    if (err==CameraErrorOK) {
        [bayerConverter setBrightness:0.0f];						//Reset bayer decoder
        [bayerConverter setContrast:1.0f];
        [bayerConverter setSaturation:1.0f];
        [bayerConverter setGamma:1.0f];
        [bayerConverter setSharpness:0.5f];
        [bayerConverter setGainsDynamic:NO];
        [bayerConverter setGainsRed:1.0f green:1.0f blue:1.0f];
        err=[self sonixGetPictureType:idx+1 flash:&flash resolution:&picRes];	//Get image info
    }
    if (err==CameraErrorOK) {
        width=WidthOfResolution(picRes);
        height=HeightOfResolution(picRes);
        err=[self sonixGetPicture:idx+1 length:&rawLength];     //Get data size of image and prepare download
    }
    if (err==CameraErrorOK) {
        //Get raw data buffer - Add some safety to prevent the decoder from running into the desert
        rawBuffer=[NSMutableData dataWithLength:rawLength+12+height*2+width*height/8+100];
        if (!rawBuffer) err=CameraErrorNoMem;
    }
    if (err==CameraErrorOK) {
        //Read raw image data
        rawLength=((rawLength+63)/64)*64;	//Round up to n*64
        readLength=rawLength;
        ioErr=(*streamIntf)->ReadPipe(streamIntf,2, [rawBuffer mutableBytes]+writeSkipBytes, &readLength);	//Read image data
        CheckError(ioErr,"getStoredMediaObject-ReadBulkPipe");
        if (rawLength!=readLength) {
            NSLog(@"getStoredMediaObject: problem: wanted %i bytes, got %i, trying to continue...",rawLength,readLength);
        }
        if (ioErr==kIOReturnOverrun) ioErr=0;
        if (ioErr) err=CameraErrorUSBProblem;
    }
    if (err==CameraErrorOK) {
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
        if (!imageRep) err=CameraErrorNoMem;
    }
    if (err==CameraErrorOK) {
        //Decode the image
        [bayerConverter setSourceWidth:width height:height];
        [bayerConverter setDestinationWidth:width height:height];
        [self decode:[rawBuffer mutableBytes]
                  to:[imageRep bitmapData]
               width:width
              height:height
                 bpp:[imageRep bitsPerPixel]/8
            rowBytes:[imageRep bytesPerRow]];
    }

    //Clean up
    if (rawBuffer) [[rawBuffer retain] release];	//Explicitly release buffer (be nice when there are many pics)
    if ((imageRep)&&(err!=CameraErrorOK)) {		//If an error occurred, explicitly release the imageRep
        [[imageRep retain] release];
        imageRep=NULL;
    }

    //Return result
    if (err!=CameraErrorOK) return NULL;
    else return [NSMutableDictionary dictionaryWithObjectsAndKeys:@"bitmap",@"type",imageRep,@"data",NULL];
}

- (BOOL) canDeleteAll {
    return YES;
}

- (CameraError) deleteAll {
	CameraError err = CameraErrorOK;
	if (!err) err = [self sonixSetModeToDSC];
	if (!err) err = [self sonixEraseAllPictures];
    return err;
}

- (BOOL) canDeleteLast {
    return YES;
}

- (CameraError) deleteLast {
	CameraError err = CameraErrorOK;
	if (!err) err = [self sonixSetModeToDSC];
	if (!err) err = [self sonixEraseLastPicture];
    return err;
}

- (BOOL) canCaptureOne {
    return YES;
}

- (CameraError) captureOne {
//  short num;
//  SonixSensorType sensorType;
	CameraError err = CameraErrorOK;
	if (!err) err = [self sonixSetModeToDSC];
//  if (!err) err = [self sonixGetSensorType:&sensorType];
//  if (!err) err = [self sonixGetNumberOfStoredImages:&num];
	if (!err) err = [self sonixCaptureOneImage];
    return err;
}


- (CameraError) sonixGenericCommand:(UInt8*)paramBuf expectResponse:(BOOL)resp to:(UInt8*)retBuf {
    UInt8 junkBuf[4];
    
    //Send write command
    if (![self usbWriteVICmdWithBRequest:8 wValue:2 wIndex:0 buf:paramBuf len:6]) return CameraErrorOK;

    if (!resp) {
        usleep(100000);			//I don't know if this is needed - just for safety: Let the camera work a bit
        return CameraErrorOK;
    }
    if (!retBuf) retBuf=junkBuf;	//We expect a response, but we throw it away
    
    //Wait for completion (?)
    do {
        if (![self usbReadVICmdWithBRequest:0 wValue:1 wIndex:0 buf:retBuf len:1]) return CameraErrorUSBProblem;
    } while (retBuf[0]!=2);

    //Check result
    if (![self usbReadVICmdWithBRequest:0 wValue:4 wIndex:0 buf:retBuf len:4]) return CameraErrorUSBProblem;
    if ((paramBuf[0]+0x80)!=retBuf[0]) {
        NSLog(@"sendSonixCommand: Warning: bad return code");
    }
    
    return CameraErrorOK;
}

//These methods do specific Sonix 2028 commands

- (CameraError) sonixEraseAllPictures {
    UInt8 paramBuf[]={0x05,0x00,0x00,0x00,0x00,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:YES to:NULL];
}

- (CameraError) sonixEraseLastPicture {
    UInt8 paramBuf[]={0x05,0x01,0x00,0x00,0x00,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:YES to:NULL];
}

- (CameraError) sonixBulkWrite:(UInt8)type length:(UInt32)len {		//DSC mode only
    UInt8 paramBuf[]={0x01,type,len&0xff,(len>>8)&0xff,(len>>16)&0xff,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:YES to:NULL];
}

- (CameraError) sonixSetModeToDSC {
    UInt8 paramBuf[]={0x0c,0x00,0x00,0x00,0x00,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:YES to:NULL];
}

- (CameraError) sonixSetModeToPCCam {
    UInt8 paramBuf[]={0x0c,0x01,0x00,0x00,0x00,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:YES to:NULL];
}

- (CameraError) sonixCaptureOneImage {	//DSC mode only, will return noMem if cam is full
    UInt8 paramBuf[]={0x0e,0x00,0x00,0x00,0x00,0x00};
    UInt8 buf[4];
    CameraError err=[self sonixGenericCommand:paramBuf expectResponse:YES to:buf];
    if ((!err)&&(buf[1])) err=CameraErrorNoMem;
    return err;
}

- (CameraError) sonixIICSensorReadByte:(UInt8)reg to:(UInt8*)ret {	//PC Cam mode only
    UInt8 paramBuf[]={0x10,reg,0x00,0x00,0x00,0x00};
    UInt8 retBuf[4];
    CameraError err=[self sonixGenericCommand:paramBuf expectResponse:YES to:retBuf];
    if (ret) *ret=retBuf[1];
    return err;
}

- (CameraError) sonixIICSensorWriteByte:(UInt8)reg to:(UInt8)val {	//PC Cam mode only
    UInt8 paramBuf[]={0x11,reg,val,0x00,0x00,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:YES to:NULL];
}

- (CameraError) sonixAsicRamReadByte:(UInt16)reg to:(UInt8*)ret {
    UInt8 paramBuf[]={0x12,reg&0xff,(reg>>8)&0xff,0x00,0x00,0x00};
    UInt8 retBuf[4];
    CameraError err=[self sonixGenericCommand:paramBuf expectResponse:YES to:retBuf];
    if (ret) *ret=retBuf[1];
    return err;
}

- (CameraError) sonixAsicRamWriteByte:(UInt16)reg to:(UInt8)val {
    UInt8 paramBuf[]={0x13,reg&0xff,(reg>>8)&0xff,val,0x00,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:YES to:NULL];
}

- (CameraError) sonixQuitAP {
    UInt8 paramBuf[]={0x14,0x00,0x00,0x00,0x00,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:NO to:NULL];
}

- (CameraError) sonixGetSensorType:(SonixSensorType*)type {
    UInt8 paramBuf[]={0x16,0x00,0x00,0x00,0x00,0x00};
    UInt8 buf[4];
    CameraError err=[self sonixGenericCommand:paramBuf expectResponse:YES to:buf];
    if (type) *type=(SonixSensorType)(buf[1]);
    return err;
}

- (CameraError) sonixSetSubsampling:(int)subsample forDSCMode:(BOOL)dsc {
    //Allowed: 1/NO, 2/NO, 4/NO, 1/YES, 2/YES - not checked
    UInt8 paramBuf[]={0x16,subsample*((dsc)?0x10:1),0x00,0x00,0x00,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:YES to:NULL];
}

- (CameraError) sonixGetNumberOfStoredImages:(short*)numPics {
    UInt8 paramBuf[]={0x18,0x00,0x00,0x00,0x00,0x00};
    UInt8 buf[4];
    CameraError err=[self sonixGenericCommand:paramBuf expectResponse:YES to:buf];
    if (numPics) *numPics=buf[1]+buf[2]*256;
    return err;
}

- (CameraError) sonixIsFull:(BOOL*)full {
    UInt8 paramBuf[]={0x18,0x00,0x00,0x00,0x00,0x00};
    UInt8 buf[4];
    CameraError err=[self sonixGenericCommand:paramBuf expectResponse:YES to:buf];
    if (full) *full=(buf[3])?YES:NO;
    return err;
}

- (CameraError) sonixGetPictureType:(short)picIdx flash:(BOOL*)flash resolution:(CameraResolution*)res {
    UInt8 paramBuf[]={0x19,picIdx&0xff,(picIdx>>8)&0xff,0x00,0x00,0x00};
    UInt8 buf[4];
    CameraError err=[self sonixGenericCommand:paramBuf expectResponse:YES to:buf];
    if (flash) *flash=(buf[1]&0x80)?YES:NO;
    if (res) {
        switch (buf[1]&0x07) {
            case 0: *res=ResolutionCIF; break;
            case 1: *res=ResolutionQCIF; break;
            case 2: *res=ResolutionVGA; break;
            case 3: *res=ResolutionSIF; break;
            case 4: *res=ResolutionInvalid; break;	//QQCIF
            case 5: *res=ResolutionQSIF; break;	
            case 6: *res=ResolutionInvalid; break;	//Audio
            default: *res=ResolutionInvalid; break;
        }
    }
    return err;
}

- (CameraError) sonixGetPicture:(short)picIdx length:(UInt32*)len {	//DSC mode only, follow bulk read, round up to n*64
    UInt8 paramBuf[]={0x1A,picIdx&0xff,(picIdx>>8)&0xff,0x00,0x00,0x00};
    UInt8 buf[4];
    CameraError err=[self sonixGenericCommand:paramBuf expectResponse:YES to:buf];
    if (len) *len=buf[1]+buf[2]*256+buf[3]*65536;
    return err;
}

- (CameraError) sonixSensorWrite1:(UInt8)addr byte1:(UInt8)b1 {	//PC Cam mode only
    UInt8 paramBuf[]={0x1B,addr,b1,0x00,0x00,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:NO to:NULL];
}

- (CameraError) sonixSensorWrite2:(UInt8)addr byte1:(UInt8)b1 byte2:(UInt8)b2 {	//PC Cam mode only
    UInt8 paramBuf[]={0x1C,addr,b1,b2,0x00,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:NO to:NULL];
}

- (CameraError) sonixSensorWrite3:(UInt8)addr byte1:(UInt8)b1 byte2:(UInt8)b2 byte3:(UInt8)b3 {	//PC Cam mode only
    UInt8 paramBuf[]={0x1D,addr,b1,b2,b3,0x00};
    return [self sonixGenericCommand:paramBuf expectResponse:NO to:NULL];
}

- (CameraError) sonixSensorWrite4:(UInt8)addr byte1:(UInt8)b1 byte2:(UInt8)b2 byte3:(UInt8)b3 byte4:(UInt8)b4 {//PC Cam mode only
    UInt8 paramBuf[]={0x1E,addr,b1,b2,b3,b4};
    return [self sonixGenericCommand:paramBuf expectResponse:NO to:NULL];
}

- (CameraError) sonixAsicWrite1:(UInt16)addr byte1:(UInt8)b1 {
    UInt8 paramBuf[]={0x20,addr-0x100,b1,0x00,0x00,0x00};
    if ((addr<0x100)||(addr>0x1ff)) return CameraErrorInternal;
    return [self sonixGenericCommand:paramBuf expectResponse:NO to:NULL];
}

- (CameraError) sonixAsicWrite2:(UInt16)addr byte1:(UInt8)b1 byte2:(UInt8)b2 {
    UInt8 paramBuf[]={0x21,addr-0x100,b1,b2,0x00,0x00};
    if ((addr<0x100)||(addr>0x1ff)) return CameraErrorInternal;
    return [self sonixGenericCommand:paramBuf expectResponse:NO to:NULL];
}

- (CameraError) sonixAsicWrite3:(UInt16)addr byte1:(UInt8)b1 byte2:(UInt8)b2 byte3:(UInt8)b3 {
    UInt8 paramBuf[]={0x22,addr-0x100,b1,b2,b3,0x00};
    if ((addr<0x100)||(addr>0x1ff)) return CameraErrorInternal;
    return [self sonixGenericCommand:paramBuf expectResponse:NO to:NULL];
}

- (CameraError) sonixAsicWrite4:(UInt16)addr byte1:(UInt8)b1 byte2:(UInt8)b2 byte3:(UInt8)b3 byte4:(UInt8)b4 {
    UInt8 paramBuf[]={0x23,addr-0x100,b1,b2,b3,b4};
    if ((addr<0x100)||(addr>0x1ff)) return CameraErrorInternal;
    return [self sonixGenericCommand:paramBuf expectResponse:NO to:NULL];
}


@end


// The Sonix2028 driver almost works for the ViviCam3350B
// There are some small but significant changes in the decoding,
// although some may also appply to the AEL Auracam DC-31UC
// for example, the first two bytes on the line are actually the first two bytes, 
// and thus the line is 640 wide or whatever it is supposed to be
// The AEL may also use BGGR bayer pattern, which is perhaps why the 
// original driver started on the second line

@interface MyViviCam3350BDriver (Private)

- (BOOL) startupGrabStream;				//Initiates camera streaming

@end

@implementation MyViviCam3350BDriver

+ (NSArray*) cameraUsbDescriptions 
{
    NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_SONIX],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_VIVICAM3350B],@"idProduct",
        @"Vivitar ViviCam 3350B",@"name",NULL];
    
    NSDictionary* dict2=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_SONIX],@"idVendor",
        [NSNumber numberWithUnsignedShort:0x8001],@"idProduct",
        @"Digital Spy Camera",@"name",NULL];
    
    return [NSArray arrayWithObjects:dict1,dict2,NULL];
}

//  Class methods needed
//+ (unsigned short) cameraUsbProductID { return PRODUCT_VIVICAM3350B; }
//+ (unsigned short) cameraUsbVendorID { return VENDOR_SONIX; }
//+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"Vivitar ViviCam 3350B"]; }

- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId 
{
	CameraError err = [super startupWithUsbLocationId:usbLocationId];
    if (err != CameraErrorOK) 
		return err;
	
	[bayerConverter setSourceFormat:4];  //  This is in BGGR format!
	
	writeSkipBytes = 4;
    rotate = YES;
	
	return CameraErrorOK;
}


- (BOOL) startupGrabStream {
    //Don't ask me why - it's just a reproduction of what the windows driver does...
    UInt8 retBuf[1];
    CameraError err=CameraErrorOK;
    
    if (!err) err=[self sonixSetModeToPCCam];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixSetSubsampling:1 forDSCMode:NO]; break;
        case ResolutionSIF: if (!err) err=[self sonixSetSubsampling:2 forDSCMode:NO]; break;
        case ResolutionQSIF: if (!err) err=[self sonixSetSubsampling:4 forDSCMode:NO]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    //Some setup from the windows driver is omitted here - I think it's useless
    if (!err) err=[self sonixIICSensorReadByte:0x00 to:retBuf];	//Get sensor identity - here model 0 (7131), rev. 1
    if (!err) err=[self sonixAsicRamWriteByte:0x0120 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0121 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0122 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0123 to:0x01];
    if (!err) err=[self sonixAsicRamWriteByte:0x0124 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0125 to:0x16];
    if (!err) err=[self sonixAsicRamWriteByte:0x0126 to:0x12];
    if (!err) err=[self sonixAsicRamWriteByte:0x0127 to:0x20];
    if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x0e];
    if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x22];
    if (!err) err=[self sonixAsicRamWriteByte:0x012a to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x012b to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x012c to:0x02];
    if (!err) err=[self sonixAsicRamWriteByte:0x012d to:0x02];
    if (!err) err=[self sonixAsicRamWriteByte:0x012e to:0x09];
    if (!err) err=[self sonixAsicRamWriteByte:0x012f to:0x07];
    if (!err) err=[self sonixAsicRamReadByte:0x0134 to:retBuf];
    if (!err) err=[self sonixAsicRamWriteByte:0x0134 to:0xa1];
    if (!err) err=[self sonixAsicRamWriteByte:0x0135 to:0x00];
/*	
    if (!err) err=[self sonixIICSensorWriteByte:0x01 to:0x04];	//Window mode, exposure line timing
    if (!err) err=[self sonixIICSensorWriteByte:0x02 to:0x92];	//some rev. 1 stuff
    if (!err) err=[self sonixIICSensorWriteByte:0x10 to:0x00];	//row start high
    if (!err) err=[self sonixIICSensorWriteByte:0x11 to:0x64];	//row start low
    if (!err) err=[self sonixIICSensorWriteByte:0x12 to:0x00];	//col start high
    if (!err) err=[self sonixIICSensorWriteByte:0x13 to:0x91];	//col start low
    if (!err) err=[self sonixIICSensorWriteByte:0x14 to:0x01];	//win width high
    if (!err) err=[self sonixIICSensorWriteByte:0x15 to:0x20];	//win width low
    if (!err) err=[self sonixIICSensorWriteByte:0x16 to:0x01];	//win height high
    if (!err) err=[self sonixIICSensorWriteByte:0x17 to:0x60];	//win height low
    if (!err) err=[self sonixIICSensorWriteByte:0x20 to:0x00];	//hsync high
    if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0x2d];	//hsync low
    if (!err) err=[self sonixIICSensorWriteByte:0x22 to:0x00];	//vsync high
    if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x03];	//vsync low
    if (!err) err=[self sonixIICSensorWriteByte:0x25 to:0x00];	//intg hi
    if (!err) err=[self sonixIICSensorWriteByte:0x26 to:0x02];	//intg mid
    if (!err) err=[self sonixIICSensorWriteByte:0x27 to:0x88];	//intg low
    if (!err) err=[self sonixIICSensorWriteByte:0x30 to:0x38];	//reset level
    if (!err) err=[self sonixIICSensorWriteByte:0x31 to:0x1e];	//gain red
    if (!err) err=[self sonixIICSensorWriteByte:0x32 to:0x1e];	//gain green
    if (!err) err=[self sonixIICSensorWriteByte:0x33 to:0x1e];	//intg blue
    if (!err) err=[self sonixIICSensorWriteByte:0x34 to:0x02];	//pixel bias
    if (!err) err=[self sonixIICSensorWriteByte:0x5b to:0x0a];	//some rev. 1 suff
*/	
    if (!err) err=[self sonixAsicRamWriteByte:0x0125 to:0x28];
    if (!err) err=[self sonixAsicRamWriteByte:0x0126 to:0x1e];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x0e]; break;
        case ResolutionSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x1e]; break;
        case ResolutionQSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x2e]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixAsicRamWriteByte:0x0127 to:0x20];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x62]; break;
        case ResolutionSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x22]; break;
        case ResolutionQSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x22]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixAsicRamWriteByte:0x012c to:0x02];
    if (!err) err=[self sonixAsicRamWriteByte:0x012d to:0x03];
    if (!err) err=[self sonixAsicRamWriteByte:0x012e to:0x0f];
    if (!err) err=[self sonixAsicRamWriteByte:0x012f to:0x0c];
/*	
    if (!err) err=[self sonixIICSensorWriteByte:0x20 to:0x00];	
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0x2a]; break;
        case ResolutionSIF: if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0xc1]; break;
        case ResolutionQSIF: if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0xc1]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixIICSensorWriteByte:0x22 to:0x00];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x28]; break;
        case ResolutionSIF: if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x10]; break;
        case ResolutionQSIF: if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x10]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixIICSensorWriteByte:0x10 to:0x00];
    if (!err) err=[self sonixIICSensorWriteByte:0x11 to:0x04];
    if (!err) err=[self sonixIICSensorWriteByte:0x12 to:0x00];
    if (!err) err=[self sonixIICSensorWriteByte:0x13 to:0x03];
    if (!err) err=[self sonixIICSensorWriteByte:0x14 to:0x01];
    if (!err) err=[self sonixIICSensorWriteByte:0x15 to:0xe0];
    if (!err) err=[self sonixIICSensorWriteByte:0x16 to:0x02];
    if (!err) err=[self sonixIICSensorWriteByte:0x17 to:0x80];
	switch (resolution) {
        case ResolutionVGA:
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0x2a];
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0x2a];
				break;
        case ResolutionSIF:
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
				break;
        case ResolutionQSIF:
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
				break;
        default: if (!err) err=CameraErrorInternal; break;
    }
*/
    if (!err) err=[self sonixAsicWrite1:0x0134 byte1:0xa1];
	
    if (!err) [self setGain:[self gain]];
    if (!err) [self setShutter:[self shutter]];
    return YES;
}

#undef PARSE_PIXEL_NEW

#define PARSE_PIXEL_NEW(val) {\
    PEEK_BITS(10,bits);\
		if ((bits&0x00000200)==0) { EAT_BITS(1); }\
        else if ((bits&0x00000380)==0x00000280) { EAT_BITS(3); val+=3; if (val>255) val=255;}\
		else if ((bits&0x00000380)==0x00000300) { EAT_BITS(3); val-=3; if (val<0) val=0;}\
		else if ((bits&0x000003c0)==0x00000200) { EAT_BITS(4); val+=8; if (val>255) val=255;}\
		else if ((bits&0x000003c0)==0x00000240) { EAT_BITS(4); val-=8; if (val<0) val=0;}\
		else if ((bits&0x000003c0)==0x000003c0) { EAT_BITS(4); val-=20; if (val<0) val=0;}\
		else if ((bits&0x000003e0)==0x00000380) { EAT_BITS(5); val+=20; if (val>255) val=255;}\
		else { EAT_BITS(10); val=8*(bits&0x0000001f)+0; }}


- (void) decode:(UInt8*)src to:(UInt8*)pixmap width:(int)width height:(int) height bpp:(short)bpp rowBytes:(long)rb 
{
    UInt8* dst=bayerBuffer;
    UInt16 bits;
    SInt16 c1val,c2val;
    int x,y;
    UInt32 bitBuf=0;
    UInt32 bitBufCount=0;
	
	src += 12;	//  This should work for video *and* stills now
	
    for (y = 0; y < height; y++) 
	{
        PEEK_BITS(8,bits);
        EAT_BITS(8);
        c1val=bits&0x000000ff;
		
        PEEK_BITS(8,bits);
        EAT_BITS(8);
        c2val=bits&0x000000ff;
		
        PUT_PIXEL_PAIR;
		
        for (x = 2; x < width; x += 2) 
		{
            PARSE_PIXEL_NEW(c1val);
            PARSE_PIXEL_NEW(c2val);
            PUT_PIXEL_PAIR;
        }
    }
	
    //Decode Bayer
    [bayerConverter convertFromSrc:bayerBuffer
                            toDest:pixmap
                       srcRowBytes:width
                       dstRowBytes:rb
                            dstBPP:bpp
                              flip:hFlip
						 rotate180:rotate];
}

@end


@implementation MyFunCamDriver

+ (NSArray*) cameraUsbDescriptions 
{
    NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:0x0471],@"idVendor",
        [NSNumber numberWithUnsignedShort:0x0321],@"idProduct",
        @"Philips Fun Camera (DMVC 300K)",@"name",NULL];
    
    return [NSArray arrayWithObjects:dict1,NULL];
}

- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId 
{
	CameraError err = [super startupWithUsbLocationId:usbLocationId];
    if (err != CameraErrorOK) 
		return err;
	
	rotate = NO;
	
	return CameraErrorOK;
}

@end


@interface MySwedaSSP09BDriver (Private)

- (BOOL) startupGrabStream;				//Initiates camera streaming

@end

@implementation MySwedaSSP09BDriver

+ (NSArray*) cameraUsbDescriptions 
{
	NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_SMARTCAM_VGAS],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_SWEDA],@"idVendor",
        @"Sweda SmartCam VGAs",@"name",NULL];
	
    return [NSArray arrayWithObjects:dict1,NULL];
}

- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId 
{
	CameraError err = [super startupWithUsbLocationId:usbLocationId];
    if (err != CameraErrorOK) 
		return err;
	
	[bayerConverter setSourceFormat:2];
	
	writeSkipBytes = 4;
	
	return CameraErrorOK;
}


- (BOOL) startupGrabStream {
    //Don't ask me why - it's just a reproduction of what the windows driver does...
    UInt8 retBuf[1];
    CameraError err=CameraErrorOK;
    
    if (!err) err=[self sonixSetModeToPCCam];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixSetSubsampling:1 forDSCMode:NO]; break;
        case ResolutionSIF: if (!err) err=[self sonixSetSubsampling:2 forDSCMode:NO]; break;
        case ResolutionQSIF: if (!err) err=[self sonixSetSubsampling:4 forDSCMode:NO]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    //Some setup from the windows driver is omitted here - I think it's useless
    if (!err) err=[self sonixIICSensorReadByte:0x00 to:retBuf];	//Get sensor identity - here model 0 (7131), rev. 1
    if (!err) err=[self sonixAsicRamWriteByte:0x0120 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0121 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0122 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0123 to:0x01];
    if (!err) err=[self sonixAsicRamWriteByte:0x0124 to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x0125 to:0x16];
    if (!err) err=[self sonixAsicRamWriteByte:0x0126 to:0x12];
    if (!err) err=[self sonixAsicRamWriteByte:0x0127 to:0x20];
    if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x0e];
    if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x22];
    if (!err) err=[self sonixAsicRamWriteByte:0x012a to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x012b to:0x00];
    if (!err) err=[self sonixAsicRamWriteByte:0x012c to:0x02];
    if (!err) err=[self sonixAsicRamWriteByte:0x012d to:0x02];
    if (!err) err=[self sonixAsicRamWriteByte:0x012e to:0x09];
    if (!err) err=[self sonixAsicRamWriteByte:0x012f to:0x07];
    if (!err) err=[self sonixAsicRamReadByte:0x0134 to:retBuf];
    if (!err) err=[self sonixAsicRamWriteByte:0x0134 to:0xa1];
    if (!err) err=[self sonixAsicRamWriteByte:0x0135 to:0x00];
/*	
    if (!err) err=[self sonixIICSensorWriteByte:0x01 to:0x04];	//Window mode, exposure line timing
    if (!err) err=[self sonixIICSensorWriteByte:0x02 to:0x92];	//some rev. 1 stuff
    if (!err) err=[self sonixIICSensorWriteByte:0x10 to:0x00];	//row start high
    if (!err) err=[self sonixIICSensorWriteByte:0x11 to:0x64];	//row start low
    if (!err) err=[self sonixIICSensorWriteByte:0x12 to:0x00];	//col start high
    if (!err) err=[self sonixIICSensorWriteByte:0x13 to:0x91];	//col start low
    if (!err) err=[self sonixIICSensorWriteByte:0x14 to:0x01];	//win width high
    if (!err) err=[self sonixIICSensorWriteByte:0x15 to:0x20];	//win width low
    if (!err) err=[self sonixIICSensorWriteByte:0x16 to:0x01];	//win height high
    if (!err) err=[self sonixIICSensorWriteByte:0x17 to:0x60];	//win height low
    if (!err) err=[self sonixIICSensorWriteByte:0x20 to:0x00];	//hsync high
    if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0x2d];	//hsync low
    if (!err) err=[self sonixIICSensorWriteByte:0x22 to:0x00];	//vsync high
    if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x03];	//vsync low
    if (!err) err=[self sonixIICSensorWriteByte:0x25 to:0x00];	//intg hi
    if (!err) err=[self sonixIICSensorWriteByte:0x26 to:0x02];	//intg mid
    if (!err) err=[self sonixIICSensorWriteByte:0x27 to:0x88];	//intg low
    if (!err) err=[self sonixIICSensorWriteByte:0x30 to:0x38];	//reset level
    if (!err) err=[self sonixIICSensorWriteByte:0x31 to:0x1e];	//gain red
    if (!err) err=[self sonixIICSensorWriteByte:0x32 to:0x1e];	//gain green
    if (!err) err=[self sonixIICSensorWriteByte:0x33 to:0x1e];	//intg blue
    if (!err) err=[self sonixIICSensorWriteByte:0x34 to:0x02];	//pixel bias
    if (!err) err=[self sonixIICSensorWriteByte:0x5b to:0x0a];	//some rev. 1 suff
*/	
    if (!err) err=[self sonixAsicRamWriteByte:0x0125 to:0x28];
    if (!err) err=[self sonixAsicRamWriteByte:0x0126 to:0x1e];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x0e]; break;
        case ResolutionSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x1e]; break;
        case ResolutionQSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0128 to:0x2e]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixAsicRamWriteByte:0x0127 to:0x20];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x62]; break;
        case ResolutionSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x22]; break;
        case ResolutionQSIF: if (!err) err=[self sonixAsicRamWriteByte:0x0129 to:0x22]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixAsicRamWriteByte:0x012c to:0x02];
    if (!err) err=[self sonixAsicRamWriteByte:0x012d to:0x03];
    if (!err) err=[self sonixAsicRamWriteByte:0x012e to:0x0f];
    if (!err) err=[self sonixAsicRamWriteByte:0x012f to:0x0c];
/*	
    if (!err) err=[self sonixIICSensorWriteByte:0x20 to:0x00];	
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0x2a]; break;
        case ResolutionSIF: if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0xc1]; break;
        case ResolutionQSIF: if (!err) err=[self sonixIICSensorWriteByte:0x21 to:0xc1]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixIICSensorWriteByte:0x22 to:0x00];
    switch (resolution) {
        case ResolutionVGA: if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x28]; break;
        case ResolutionSIF: if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x10]; break;
        case ResolutionQSIF: if (!err) err=[self sonixIICSensorWriteByte:0x23 to:0x10]; break;
        default: if (!err) err=CameraErrorInternal; break;
    }
    if (!err) err=[self sonixIICSensorWriteByte:0x10 to:0x00];
    if (!err) err=[self sonixIICSensorWriteByte:0x11 to:0x04];
    if (!err) err=[self sonixIICSensorWriteByte:0x12 to:0x00];
    if (!err) err=[self sonixIICSensorWriteByte:0x13 to:0x03];
    if (!err) err=[self sonixIICSensorWriteByte:0x14 to:0x01];
    if (!err) err=[self sonixIICSensorWriteByte:0x15 to:0xe0];
    if (!err) err=[self sonixIICSensorWriteByte:0x16 to:0x02];
    if (!err) err=[self sonixIICSensorWriteByte:0x17 to:0x80];
	switch (resolution) {
        case ResolutionVGA:
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0x2a];
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0x2a];
				break;
        case ResolutionSIF:
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
				break;
        case ResolutionQSIF:
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
            if (!err) err=[self sonixSensorWrite2:0x20 byte1:0x00 byte2:0xc1];
				break;
        default: if (!err) err=CameraErrorInternal; break;
    }
*/
    if (!err) err=[self sonixAsicWrite1:0x0134 byte1:0xa1];
	
    if (!err) [self setGain:[self gain]];
    if (!err) [self setShutter:[self shutter]];
    return YES;
}

#undef PARSE_PIXEL_NEW

#define PARSE_PIXEL_NEW(val) {\
    PEEK_BITS(10,bits);\
		if ((bits&0x00000200)==0) { EAT_BITS(1); }\
        else if ((bits&0x00000380)==0x00000280) { EAT_BITS(3); val+=3; if (val>255) val=255;}\
		else if ((bits&0x00000380)==0x00000300) { EAT_BITS(3); val-=3; if (val<0) val=0;}\
		else if ((bits&0x000003c0)==0x00000200) { EAT_BITS(4); val+=8; if (val>255) val=255;}\
		else if ((bits&0x000003c0)==0x00000240) { EAT_BITS(4); val-=8; if (val<0) val=0;}\
		else if ((bits&0x000003c0)==0x000003c0) { EAT_BITS(4); val-=20; if (val<0) val=0;}\
		else if ((bits&0x000003e0)==0x00000380) { EAT_BITS(5); val+=20; if (val>255) val=255;}\
		else { EAT_BITS(10); val=8*(bits&0x0000001f)+0; }}


- (void) decode:(UInt8*)src to:(UInt8*)pixmap width:(int)width height:(int) height bpp:(short)bpp rowBytes:(long)rb 
{
    UInt8* dst=bayerBuffer;
    UInt16 bits;
    SInt16 c1val,c2val;
    int x,y;
    UInt32 bitBuf=0;
    UInt32 bitBufCount=0;
	
	src += 12;	//  This should work for video *and* stills now
	
    for (y = 0; y < height; y++) 
	{
        PEEK_BITS(8,bits);
        EAT_BITS(8);
        c1val=bits&0x000000ff;
		
        PEEK_BITS(8,bits);
        EAT_BITS(8);
        c2val=bits&0x000000ff;
		
        PUT_PIXEL_PAIR;
		
        for (x = 2; x < width; x += 2) 
		{
            PARSE_PIXEL_NEW(c1val);
            PARSE_PIXEL_NEW(c2val);
            PUT_PIXEL_PAIR;
        }
    }
	
    //Decode Bayer
    [bayerConverter convertFromSrc:bayerBuffer
                            toDest:pixmap
                       srcRowBytes:width
                       dstRowBytes:rb
                            dstBPP:bpp
                              flip:hFlip
						 rotate180:NO];
}

@end
