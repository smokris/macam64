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

#include "GlobalDefs.h"
#import "MySPCA500Driver.h"
#import "MyCameraCentral.h"
#include "Resolvers.h"
#include "MiscTools.h"
#include "unistd.h"	//usleep
#include "JFIFHeaderTemplate.h"

extern UInt8 JFIFHeaderTemplate[];
extern UInt8 ZigZagLookup[];
extern UInt8 QTables[];

#define SPCA_RETRIES 5
#define SPCA_WAIT_RETRY 500000

@interface MySPCA500Driver (Private)

- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;
- (BOOL) setupGrabContext;
- (void) cleanupGrabContext;
- (void) grabbingThread:(id)data;

- (CameraError) openDSCInterface;	//Opens the dsc interface, calls dscInit
- (void) closeDSCInterface;		//calls dscShutdown, closes the dsc interface
- (CameraError) internalReadFileFromCamWithIndex:(int)tocIndex width:(int)width height:(int)height blocks:(int)blocks rawSize:(int)rawSize qTabIdx:(int)qTabIdx to:(NSBitmapImageRep**)outImage;	//Internal call from [getStoredMediaObject]

- (BOOL) dscReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;
- (BOOL) dscWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;

- (void) flipImage:(UInt8*)ptr width:(long)width height:(long)height bpp:(short)bpp rowBytes:(long)rb;
- (void) decodeCompressedBuffer:(SPCA500ChunkBuffer*)chunkBuf;
- (void) decode420Uncompressed:(UInt8*)rawSrc;
- (void) decode422Uncompressed:(UInt8*)rawSrc;

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


- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId {
    CameraError err;
    err=[self usbConnectToCam:usbLocationId configIdx:0];
    fps=5;
    resolution=ResolutionVGA;
    if (!err) {
        [self setCompression:0];
        [self setBrightness:0.5f];
        [self setContrast:0.5f];
        [self setSaturation:0.5f];
        [self setSharpness:0.5f];
        [self setGamma:0.5f];
        [self setShutter:0.5f];
        [self setGain:0.5f];
        [self setCompression:0];
        [self setHFlip:NO];
        pccamImgDesc=(ImageDescriptionHandle)NewHandle(sizeof(ImageDescription));
        if (pccamImgDesc==NULL) err=CameraErrorNoMem;
    }
    if (err==CameraErrorOK) {	//Init fields
        (**pccamImgDesc).idSize=56;
        (**pccamImgDesc).cType='jpeg';
        (**pccamImgDesc).resvd1=0;
        (**pccamImgDesc).resvd2=0;
        (**pccamImgDesc).dataRefIndex=0;
        (**pccamImgDesc).version=1;
        (**pccamImgDesc).revisionLevel=1;
        (**pccamImgDesc).vendor='appl';
        (**pccamImgDesc).temporalQuality=codecMinQuality;
        (**pccamImgDesc).spatialQuality=codecNormalQuality;
        (**pccamImgDesc).width=640;
        (**pccamImgDesc).height=480;
        (**pccamImgDesc).hRes=72<<16;
        (**pccamImgDesc).vRes=72<<16;
        (**pccamImgDesc).dataSize=0;	//Ths has to be changed for each image
        (**pccamImgDesc).frameCount=1;
        (**pccamImgDesc).name[ 0]=12;
        (**pccamImgDesc).name[ 1]='P';
        (**pccamImgDesc).name[ 2]='h';
        (**pccamImgDesc).name[ 3]='o';
        (**pccamImgDesc).name[ 4]='t';
        (**pccamImgDesc).name[ 5]='o';
        (**pccamImgDesc).name[ 6]=' ';
        (**pccamImgDesc).name[ 7]='-';
        (**pccamImgDesc).name[ 8]=' ';
        (**pccamImgDesc).name[ 9]='J';
        (**pccamImgDesc).name[10]='P';
        (**pccamImgDesc).name[11]='E';
        (**pccamImgDesc).name[12]='G';
        (**pccamImgDesc).name[13]=0;
        (**pccamImgDesc).depth=24;
        (**pccamImgDesc).clutID=-1;
    }
    if (err==CameraErrorOK) err=[super startupWithUsbLocationId:usbLocationId];
    if (err==CameraErrorOK) err=[self openDSCInterface];
    
    return err;
}

- (void) shutdown {
    if (pccamImgDesc) DisposeHandle((Handle)pccamImgDesc); pccamImgDesc=NULL;
    if (storedFileInfo) [storedFileInfo release]; storedFileInfo=NULL;
    [self closeDSCInterface];
    [super shutdown];
}

// FROM HERE: PC CAMERA METHODS

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    if (fr!=5) return NO;
    if ((r==ResolutionVGA)||(r==ResolutionSIF)||(r==ResolutionCIF)||(r==ResolutionQCIF)) return YES;
    return NO;
}

- (void) setResolution:(CameraResolution)r fps:(short)fr {
    [super setResolution:r fps:fr];	//Update instance variables if state is ok and format is supported
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {	//This is a start
    if (dFps) *dFps=5;
    return ResolutionVGA;
}

- (short) maxCompression {
    return 1;
}

- (void) setCompression:(short)v {
    [super setCompression:v];
}

- (BOOL) canSetBrightness {
    return YES;
}

- (void) setBrightness:(float)v {
    [super setBrightness:v];
    if (isGrabbing) {
        SInt8 val=(brightness-0.5f)*254.0f;
        UInt8 uVal=*((UInt8*)(&val));
        [self usbWriteCmdWithBRequest:0x00 wValue:uVal wIndex:0x8167 buf:NULL len:0];
    }
}

- (BOOL) canSetContrast {
    return YES;
}

- (void) setContrast:(float)v {
    [super setContrast:v];
    if (isGrabbing) {
        [self usbWriteCmdWithBRequest:0x00 wValue:contrast*63.0f wIndex:0x8168 buf:NULL len:0];
    }
}

- (BOOL) canSetSaturation {
    return YES;
}

- (void) setSaturation:(float)v {
    [super setSaturation:v];
    if (isGrabbing) {
        UInt8 sat=saturation*63.0f;
        [self usbWriteCmdWithBRequest:0x00 wValue:sat wIndex:0x8169 buf:NULL len:0];
    }
}

- (BOOL) isAutoGain {
    return YES;
}

- (WhiteBalanceMode) defaultWhiteBalanceMode {
    return WhiteBalanceAutomatic;
}

- (WhiteBalanceMode) whiteBalanceMode {
    return WhiteBalanceAutomatic;
}

- (BOOL) canSetHFlip {
    return YES;
}

- (BOOL) startupGrabStream {
    int subsample,width,height,subsampleCode,compressionCode,i;
    UInt8 buf[128];
    UInt8 jfifHeader[JFIF_HEADER_LENGTH];
    
    subsample=1;
    if (resolution<=ResolutionSIF) subsample=2;
    if (resolution<=ResolutionQSIF) subsample=4;
    width=([self width]*subsample)/16;
    height=([self height]*subsample)/16;
    switch (subsample) {
        case 2:  subsampleCode=0x10; break;
        case 4:  subsampleCode=0x20; break;
        default: subsampleCode=0x00; break;
    }
    compressionCode=(compression)?0x00:0x02;
    usleep(200000);
    //Do someting unknown
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0002 wIndex:0x0d01 buf:NULL len:0]) return NO;
    //Enable drop packet
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x850a buf:NULL len:0]) return NO;
    //Set agc transfer: synced inbetween frames
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x820f buf:NULL len:0]) return NO;
    //Init SDRAM - needed for SDRAM access
    //    if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0004 wIndex:0x870a buf:NULL len:0]) return NO;
    
    //Set image width
    if (![self usbWriteCmdWithBRequest:0x00 wValue:width wIndex:0x8001 buf:NULL len:0]) return NO;
    //Set image height
    if (![self usbWriteCmdWithBRequest:0x00 wValue:height wIndex:0x8002 buf:NULL len:0]) return NO;
    //Set compression and subsampling
    if (![self usbWriteCmdWithBRequest:0x00
                                wValue:compressionCode+subsampleCode wIndex:0x8003 buf:NULL len:0]) return NO;
    if (compression) {	//For compressed mode: set quantization table and precopy JFIF headers into chunk buffers
        //Set the quantization table index
        if (![self usbWriteCmdWithBRequest:0x00 wValue:compression-1 wIndex:0x8880 buf:NULL len:0]) return NO;
        //Copy our own JFIF template
        memcpy(jfifHeader,JFIFHeaderTemplate,JFIF_HEADER_LENGTH);
        //Set properties
        jfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+0]=([self height]>>8)&0xff;
        jfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+1]= [self height]    &0xff;
        jfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+2]=([self width]>>8) &0xff;
        jfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+3]= [self width]     &0xff;
        jfifHeader[JFIF_YUVTYPE_OFFSET]=0x22;
        //Get the qtable data
        for (i=0;i<128;i++) {
            if (![self usbReadCmdWithBRequest:0 wValue:0 wIndex:0x8800+i buf:buf+i len:1]) return NO;
        }
        //Place the values into the JFIF header
        for (i=0;i<64;i++) {
            jfifHeader[JFIF_QTABLE0_OFFSET+i]=buf[ZigZagLookup[i]];
            jfifHeader[JFIF_QTABLE1_OFFSET+i]=buf[64+ZigZagLookup[i]];
        }
        //Copy the header into all chunks
        for (i=0;i<grabContext.numEmptyBuffers;i++) {
            memcpy(grabContext.emptyChunkBuffers[i].buffer,jfifHeader,JFIF_HEADER_LENGTH);
        }
    }
    //Enable brightness, contrast, hue, saturation controls
    if (![self usbWriteCmdWithBRequest:0x00 wValue:0x03 wIndex:0x816b buf:NULL len:0]) return NO;
    //Set camera to PC camera mode
    if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0004 wIndex:0x8000 buf:NULL len:0]) return NO;
    [self setBrightness:brightness];
    [self setContrast:contrast];
    [self setSaturation:saturation];
    return YES;
}

- (void) shutdownGrabStream {
    //Set camera to idle
    [self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x8000 buf:NULL len:0];
    usleep(200000);
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
    grabContext.compressed=(compression>0)?YES:NO;

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
            FREE(grabContext.fillingChunkBuffer.buffer,"filling chunk buffer");
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
                if (currFrameLength>1) {					//Drop empty frames
                    UInt8* copyStart=frameBase;
                    UInt32 copyLength=0;
                    if (frameBase[0]==0xff) {
                        if (frameBase[1]==0x01) {				//Start of frame
                            if (gCtx->fillingChunk) {				//We were filling -> chunk done
                                //Pass the complete chunk to the full list
                                int j;
                                //Add the end tag to make it a complete JFIF
                                if (gCtx->compressed) {
                                    gCtx->fillingChunkBuffer.buffer[gCtx->fillingChunkBuffer.numBytes]  =0xff;
                                    gCtx->fillingChunkBuffer.buffer[gCtx->fillingChunkBuffer.numBytes+1]=0xd9;
                                    gCtx->fillingChunkBuffer.numBytes+=2;
                                }
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
                            if (gCtx->compressed) gCtx->fillingChunkBuffer.numBytes=JFIF_HEADER_LENGTH;
                            else gCtx->fillingChunkBuffer.numBytes=0;		//Start with empty buffer
                            [gCtx->chunkListLock unlock];			//Free access to the chunk buffers
                            copyStart=frameBase+16;				//Skip past header
                            copyLength=currFrameLength-16;
                        } else if (frameBase[1]==0x00) {			//A "drop frame" - silently drop this one
                            copyLength=0;
                        } else {
                            copyLength=0;
                        }
                    } else {					
                        copyStart=frameBase+1;
                        copyLength=currFrameLength-1;
                    }
                    if (copyLength>0) {				//There's image data to copy
                        if (gCtx->fillingChunk) {
                            if (gCtx->chunkBufferLength-gCtx->fillingChunkBuffer.numBytes>copyLength*2+2) {
                                //There's enough space remaining to copy (*2 because of JFIF-escaping, +2 because of end tag)
                                if (gCtx->compressed) {		//Copy with escaping (0xff -> 0xff 0x00)
                                    int x,y;
                                    UInt8 ch;
                                    UInt8* blitDst=gCtx->fillingChunkBuffer.buffer+gCtx->fillingChunkBuffer.numBytes;
                                    x=y=0;
                                    while (x<copyLength) {
                                        ch=copyStart[x++];
                                        blitDst[y++]=ch;
                                        if (ch==0xff) blitDst[y++]=0x00;
                                    }
                                    gCtx->fillingChunkBuffer.numBytes+=y;
                                } else {	//Copy without escaping
                                    memcpy(gCtx->fillingChunkBuffer.buffer+gCtx->fillingChunkBuffer.numBytes,copyStart,copyLength);
                                    gCtx->fillingChunkBuffer.numBytes+=copyLength;
                                }
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
        gCtx->framesSinceLastChunk+=SPCA500_FRAMES_PER_TRANSFER;	//Count frames (not necessary to be too precise here...)
        if ((gCtx->framesSinceLastChunk)>1000) {			//One second without a frame?
            NSLog(@"SPCA500 grab aborted because of invalid data stream");
            *(gCtx->shouldBeGrabbing)=NO;
            if (!gCtx->err) gCtx->err=CameraErrorUSBProblem;
        }
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

    //Allocate bandwidth
    if (![self usbSetAltInterfaceTo:7 testPipe:1]) {			//Max bandwidth
        if (!grabContext.err) grabContext.err=CameraErrorNoBandwidth;	//probably no bandwidth
        ok=NO;
    }

    //Prepare the camera
    if (ok) {
        ok=[self startupGrabStream];
        if (!ok) {
            shouldBeGrabbing=NO;
            if (!grabContext.err) grabContext.err=CameraErrorUSBProblem;
        }
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
                    if (grabContext.compressed) {			//do the actual decoding/decompression
                        [self decodeCompressedBuffer:&currBuffer];
                    } else {
                        [self decode420Uncompressed:currBuffer.buffer];
                    }
                }
                if (!hFlip) [self flipImage:nextImageBuffer
                                      width:[self width]
                                     height:[self height]
                                        bpp:nextImageBufferBPP
                                   rowBytes:nextImageBufferRowBytes];
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
    //We don't really count here - it was dont in [loadTocAndImage] when the camera dsc interface was opened.
    if (!storedFileInfo) return 0;
    return [storedFileInfo count];
}

//DSC USB COMMAND FUNCTIONS

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

    [self getStoredMediaObject:-1];	//Sounds illogical, but this will load the TOC

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


- (NSDictionary*) getStoredMediaObject:(long)imgIdx {

/*

This is a quite crappy solution, but I don't know how to solve it better yet: I have no idea how to get
the TOC and download files from the camera individually (because I couldn't log such a process from the
windows driver). The current solution is to do it in combination each time a file is downloaded. This
will - of course - result in the TOC being loaded far too often, but the transfer time for that is rather
low and at least it will work. There is some documentation on the SPCA500A on the web, but it seems to
be incomplete concerning the commands - there seem to be some firmware differences. I hope to be able to
fix this once I have a better understanding of the chip. Call this method with a invalid (i.e. negative)
image index to just download the Toc and no file.

 Descriptions in the TOC for each stored file - returned in reverse order

 Each description is 14 bytes long (the remaining 242 bytes are probably just padding)

 Interpretation (I know so far):

 read size (blocks a 256 bytes): buf[5]+buf[6]*0x100;
 file size (bytes): buf[11]+buf[12]*0x100+buf[13]*0x10000;
 qtable index: buf[7]
 width: buf[8]*16
 height: buf[9]*16

 */
#define FAIL(A) { err=A; goto bail; }
#define FAIL2(A) { err=A; goto bail2; }
 
    UInt8 buf[256];
    UInt32 readLen;
    UInt8 numFiles;
    int retries,i;
    unsigned long rawSize,blocks,tocIndex,qTabIdx,width,height;
    CameraError err=CameraErrorOK;
    IOReturn ret;
    NSBitmapImageRep* ir;
    NSData* data;
    NSDictionary* outDict=NULL;
    
    //DISCARD THE OLD FILE INFO ARRAY
    if (storedFileInfo) [storedFileInfo release]; storedFileInfo=NULL;	//Throw away old array
    storedFileInfo=[[NSMutableArray alloc] initWithCapacity:100];	//Get new file array
    if (!storedFileInfo) FAIL2(CameraErrorNoMem);			//We need the array to store the info
    if (!dscIntf) FAIL2(CameraErrorUSBProblem);				//We need the DSC interface

    //LOOK IF THERE ARE OBJECTS
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x0d03 buf:buf len:1]) FAIL2(CameraErrorUSBProblem);
    if (!buf[0]) {
        if (imgIdx>=0) { FAIL2(CameraErrorInternal); }
        else { FAIL2(CameraErrorInternal); }
    }
    
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0010 wIndex:0x0d04 buf:NULL len:0]) FAIL2(CameraErrorUSBProblem);
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0002 wIndex:0x0d01 buf:NULL len:0]) FAIL(CameraErrorUSBProblem);
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x0d06 buf:buf len:1]) FAIL(CameraErrorUSBProblem);
    numFiles=buf[0];
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x0d07 buf:buf len:1]) FAIL(CameraErrorUSBProblem);
    numFiles+=256*buf[0];
    //GET THE ACTUAL TOC
    if (numFiles>0) {
        if (![self dscWriteCmdWithBRequest:0x02 wValue:0x0000 wIndex:0x0007 buf:NULL len:0]) FAIL(CameraErrorUSBProblem);
        for (retries=0;retries<10;retries++) {
            if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x0d00 buf:buf len:1]) FAIL(CameraErrorUSBProblem);
            if (!buf[0]) break;
            usleep(100000);
        }
        if (buf[0]) {
            NSLog(@"couldn't get TOC - device is probably hung");
            FAIL(CameraErrorUSBProblem);
        }
        if (![self dscWriteCmdWithBRequest:0x04 wValue:0x0000 wIndex:0x0000 buf:NULL len:0]) FAIL(CameraErrorUSBProblem);
        for (i=numFiles-1;i>=0;i--) {
            NSDictionary* fileInfo=NULL;
            readLen=256;
            ret=((IOUSBInterfaceInterface182*)(*dscIntf))->ReadPipeTO(dscIntf,1,buf,&readLen,2000,3000);
            CheckError(ret,"Get TOC: ReadPipe");
            if (ret) FAIL(CameraErrorUSBProblem);
            switch (buf[0]) {
                case 0:			//We have an image
                    fileInfo=[NSDictionary dictionaryWithObjectsAndKeys:
                        @"image",									@"type",
                        [NSNumber numberWithUnsignedLong:i],						@"index",
                        [NSNumber numberWithUnsignedLong:buf[5]+buf[6]*0x100],				@"blocks",
                        [NSNumber numberWithUnsignedLong:buf[7]],					@"qTabIndex",
                        [NSNumber numberWithUnsignedLong:buf[8]*16],					@"width",
                        [NSNumber numberWithUnsignedLong:buf[9]*16],					@"height",
                        [NSNumber numberWithUnsignedLong:buf[11]+buf[12]*0x100+buf[13]*0x10000],	@"bytes",NULL];
                    break;
                case 3:			//We have a movie frame - skipped for now
                    fileInfo=NULL;
                    break;
                default:
                    FAIL(CameraErrorUnimplemented);
                    break;
            }
            if (fileInfo) [storedFileInfo insertObject:fileInfo atIndex:0];
        }
    }
    //READ THE IMAGE
    if (imgIdx>=[storedFileInfo count]) FAIL(CameraErrorInternal);
    if (imgIdx>=0) {
        //Do some preparation commands (don't ask me...)
        if (![self dscReadCmdWithBRequest:0 wValue:0 wIndex:0x0d04 buf:buf len:1]) FAIL(CameraErrorUSBProblem);
        if (![self dscReadCmdWithBRequest:0 wValue:0 wIndex:0x0d04 buf:buf len:1]) FAIL(CameraErrorUSBProblem);
        if (![self dscReadCmdWithBRequest:0 wValue:0 wIndex:0x0d04 buf:buf len:1]) FAIL(CameraErrorUSBProblem);
        if (![self dscWriteCmdWithBRequest:2 wValue:0 wIndex:0x0007 buf:buf len:1]) FAIL(CameraErrorUSBProblem);
        if (![self dscReadCmdWithBRequest:0 wValue:0 wIndex:0x0d00 buf:buf len:1]) FAIL(CameraErrorUSBProblem);

        if ([[[storedFileInfo objectAtIndex:imgIdx] objectForKey:@"type"] isEqualToString:@"image"]) {
            rawSize=[[[storedFileInfo objectAtIndex:imgIdx] objectForKey:@"bytes"] unsignedLongValue];
            blocks=[[[storedFileInfo objectAtIndex:imgIdx] objectForKey:@"blocks"] unsignedLongValue];
            tocIndex=[[[storedFileInfo objectAtIndex:imgIdx] objectForKey:@"index"] unsignedLongValue];
            qTabIdx=[[[storedFileInfo objectAtIndex:imgIdx] objectForKey:@"qTabIndex"] shortValue];
            width=[[[storedFileInfo objectAtIndex:imgIdx] objectForKey:@"width"] unsignedLongValue];
            height=[[[storedFileInfo objectAtIndex:imgIdx] objectForKey:@"height"] unsignedLongValue];
            err=[self internalReadFileFromCamWithIndex:tocIndex width:width height:height blocks:blocks
                                               rawSize:rawSize qTabIdx:qTabIdx to:&ir];
            if (err) FAIL(err);
            if (!ir) FAIL(CameraErrorNoMem);
            data=[ir representationUsingType:NSJPEGFileType properties:
                [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:0.95f],NSImageCompressionFactor,NULL]];
            if (!data) FAIL(CameraErrorNoMem);
            outDict=[NSDictionary dictionaryWithObjectsAndKeys:data,@"data",@"jpeg",@"type",NULL];
            [[data retain] release];	//Explicitly release data
            if (!outDict) FAIL(CameraErrorNoMem);
        } else FAIL(CameraErrorInternal);	//We encountered a wrong media type
    }
bail:
    //Cleanup
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x0d04 buf:buf len:1]) err=CameraErrorUSBProblem;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x0d04 buf:NULL len:0]) err=CameraErrorUSBProblem;
bail2:
    if (err) return NULL;
    else return outDict;
}

- (CameraError) internalReadFileFromCamWithIndex:(int)tocIndex width:(int)width height:(int)height blocks:(int)blocks rawSize:(int)rawSize qTabIdx:(int)qTabIdx to:(NSBitmapImageRep**)outImage{
    NSMutableData *raw,*jfif;
    UInt8 *rawPtr,*jfifPtr;
    UInt32 readLen,jpegSize,i,j;
    IOReturn ret;
    NSBitmapImageRep* ir;
    
    //Get memory for the raw JPEG data
    raw=[NSMutableData dataWithLength:blocks*256];
    if (!raw) return CameraErrorNoMem;

    //Get unwrapped JPEG image data from camera:
    if (![self dscWriteCmdWithBRequest:7 wValue:0x70ff-tocIndex wIndex:5 buf:NULL len:0]) return CameraErrorUSBProblem;

    rawPtr=[raw mutableBytes];
    readLen=256*blocks;
    ret=((IOUSBInterfaceInterface182*)(*dscIntf))->ReadPipeTO(dscIntf,1,rawPtr,&readLen,2000,5000);
    CheckError(ret,"Read file from cam: ReadPipe");
    if (ret) return CameraErrorUSBProblem;

    //Go through data to see where we have to insert bytes
    jpegSize=rawSize+JFIF_HEADER_LENGTH+2;
    for (i=0;i<=rawSize;i++) {
        if (rawPtr[i]==0xff) jpegSize++;
    }

    //Allocate memory for the final pic
    jfif=[NSMutableData dataWithLength:jpegSize];
    if (!jfif) return CameraErrorNoMem;
    jfifPtr=[jfif mutableBytes];
    //Copy Header template
    memcpy(jfifPtr,JFIFHeaderTemplate,JFIF_HEADER_LENGTH);
    //Change header
    jfifPtr[JFIF_HEIGHT_WIDTH_OFFSET+0]=(height>>8)&0xff;
    jfifPtr[JFIF_HEIGHT_WIDTH_OFFSET+1]= height    &0xff;
    jfifPtr[JFIF_HEIGHT_WIDTH_OFFSET+2]=(width>>8) &0xff;
    jfifPtr[JFIF_HEIGHT_WIDTH_OFFSET+3]= width     &0xff;
    jfifPtr[JFIF_YUVTYPE_OFFSET]=0x21;
    for (i=0;i<64;i++) {
        jfifPtr[JFIF_QTABLE0_OFFSET+i]=ZigZagY(qTabIdx,i);
        jfifPtr[JFIF_QTABLE1_OFFSET+i]=ZigZagUV(qTabIdx,i);
    }
    //Copy footer
    jfifPtr[jpegSize-2]=0xff;
    jfifPtr[jpegSize-1]=0xd9;
    j=JFIF_HEADER_LENGTH;
    for (i=0;i<rawSize;i++) {	//Copy data and escape 0xff -> 0xff 0x00
        if (rawPtr[i]==0xff) {
            jfifPtr[j++]=rawPtr[i];
            jfifPtr[j++]=0x00;	//insert escape code
        } else jfifPtr[j++]=rawPtr[i];
    }
    [[raw retain] release];	//Explicitly dealloc buffer
    //Construct a Bitmap image from jfif
    ir=[NSBitmapImageRep imageRepWithData:jfif];
    if (!ir) return CameraErrorNoMem;
    //The camera sends everything mirrored - correct this
    [self flipImage:[ir bitmapData]
              width:[ir pixelsWide]
             height:[ir pixelsHigh]
                bpp:[ir bitsPerPixel]/8
           rowBytes:[ir bytesPerRow]];
    [[jfif retain] release];
    if (outImage) *outImage=ir;
    return CameraErrorOK;
}    


- (BOOL) dscReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    IOReturn err;
    IOUSBDevRequest req;
    if (!isUSBOK) return NO;
    if (dscIntf==NULL) return NO;
    req.bmRequestType=USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBInterface);
    req.bRequest=bReq;
    req.wValue=wVal;
    req.wIndex=wIdx;
    req.wLength=len;
    req.pData=buf;
    err=(*dscIntf)->ControlRequest(dscIntf,0,&req);
    CheckError(err,"usbReadCmdWithBRequest");
    if (err==kIOUSBPipeStalled) (*dscIntf)->ClearPipeStall(dscIntf,0);
//    NSLog(@"read %02x val %04x idx %04x <-- %02x",bReq,wVal,wIdx,((UInt8*)buf)[0]);
    usleep(100000);
    return (!err);
}

- (BOOL) dscWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    IOReturn err;
    IOUSBDevRequest req;
    if (!isUSBOK) return NO;
    if (dscIntf==NULL) return NO;
    req.bmRequestType=USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBInterface);
    req.bRequest=bReq;
    req.wValue=wVal;
    req.wIndex=wIdx;
    req.wLength=len;
    req.pData=buf;
    err=(*dscIntf)->ControlRequest(dscIntf,0,&req);
    CheckError(err,"usbWriteCmdWithBRequest");
    if (err==kIOUSBPipeStalled) (*dscIntf)->ClearPipeStall(dscIntf,0);
//    NSLog(@"write %02x val %04x idx %04x",bReq,wVal,wIdx);
    usleep(100000);
    return (!err);
}

//IMAGE DECOMPRESSOR FUNCTIONS


- (void) flipImage:(UInt8*)ptr width:(long)width height:(long)height bpp:(short)bpp rowBytes:(long)rb {
    short x,y,left,right;
    
    UInt8 ch;
    if (bpp==3) {
        for (y=height;y>0;y--) {
            left=0;
            right=(width-1)*3;
            for (x=width/2;x>0;x--) {
                ch=ptr[left]; ptr[left++]=ptr[right]; ptr[right++]=ch;
                ch=ptr[left]; ptr[left++]=ptr[right]; ptr[right++]=ch;
                ch=ptr[left]; ptr[left++]=ptr[right]; ptr[right++]=ch;
                right-=6;               
            }
            ptr+=rb;
        }
    } else {	//4 bpp
        for (y=height;y>0;y--) {
            left=0;
            right=(width-1)*4;
            for (x=width/2;x>0;x--) {
                ch=ptr[left]; ptr[left++]=ptr[right]; ptr[right++]=ch;
                ch=ptr[left]; ptr[left++]=ptr[right]; ptr[right++]=ch;
                ch=ptr[left]; ptr[left++]=ptr[right]; ptr[right++]=ch;
                ch=ptr[left]; ptr[left++]=ptr[right]; ptr[right++]=ch;
                right-=8;
            }
            ptr+=rb;
        }
    }
}

- (void) decodeCompressedBuffer:(SPCA500ChunkBuffer*)chunkBuf {
    /*

     This method is very similar to the correspondig SPCA504 method. Refactoring this functionality
     into a separate location is probably a good idea.

     */
    UInt8* jfifBuf=chunkBuf->buffer;
    long jfifLength=chunkBuf->numBytes;
    Rect bounds;
    GWorldPtr gw;
    PixMapHandle pm;
    CGrafPtr oldPort;
    GDHandle oldGDev;
    OSErr err;
    short width=[self width];
    short height=[self height];
    
    SetRect(&bounds,0,0,width,height);

    err=    QTNewGWorldFromPtr(
                               &gw,
                               (nextImageBufferBPP==4)?k32ARGBPixelFormat:k24RGBPixelFormat,
                               &bounds,
                               NULL,
                               NULL,
                               0,
                               nextImageBuffer,
                               nextImageBufferRowBytes);
    if (err) return;
    //*** FIXME: Not caching the GWorld is probably a performance killer...
    pm=GetGWorldPixMap(gw);
    LockPixels(pm);
    GetGWorld(&oldPort,&oldGDev);
    SetGWorld(gw,NULL);
    (**pccamImgDesc).dataSize=jfifLength;
    (**pccamImgDesc).width=width;
    (**pccamImgDesc).height=height;
    DecompressImage(jfifBuf,pccamImgDesc,pm,&bounds,&bounds,srcCopy,NULL);
    SetGWorld(oldPort,oldGDev);
    UnlockPixels(pm);
    DisposeGWorld(gw);
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


@end
