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

#import "MySPCA504Driver.h"
#import "MyCameraCentral.h"
#include "Resolvers.h"
#include "MiscTools.h"
#include "unistd.h"	//usleep

#define SPCA_RETRIES 5
#define SPCA_WAIT_RETRY 500000

extern UInt8 JFIFHeaderTemplate[];
extern UInt8 ZigZagLookup[];

@interface MySPCA504Driver (Private)

//PC CAMERA internals

- (BOOL) pccamSetQTable;		//Sets the compression table for PC Camera JPEG compressed data
- (BOOL) pccamWaitCommandReceived;	//Waits for the last command to finish, NO if error or timeout
- (BOOL) pccamWaitCameraIdle;		//Waits for the camera to idle (ready for new work), NO if error or
- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;
- (BOOL) setupGrabContext;
- (void) cleanupGrabContext;
- (void) grabbingThread:(id)data;
- (void) decode422Uncompressed:(UInt8*)rawSrc;

//High level DSC access (ordered from high to low level)

- (CameraError) openDSCInterface;	//Opens the dsc interface, calls dscInit
- (void) closeDSCInterface;		//calls dscShutdown, closes the dsc interface

- (NSData*) dscDownloadMediaFromCard:(int)idx;	//Downloads a media object from SmartMedia card
- (NSData*) dscDownloadMediaFromFlash:(int)idx;	//Downloads a media object from NAND Flash
- (NSData*) dscDownloadMediaFromSDRAM:(int)idx;	//Downloads a media object from SDRAM

- (BOOL) dscInit;			//Initializes the dsc, gets camera and stored data properties
- (void) dscShutdown;			//Un-initializes the dsc

- (BOOL) dscWaitCommandReceived;	//Waits for the last command to finish, NO if error or timeout
- (BOOL) dscWaitCameraIdle;		//Waits for the camera to idle (ready for new work), NO if error or timeout
- (BOOL) dscWaitDataReady;		//Waits for a bulk page to be ready, NO if error or timeout

- (BOOL) dscReadSDRAMTo:(UInt8*)buf start:(long)start count:(long)count;
- (BOOL) dscReadBulkTo:(UInt8*)buf count:(long)bytesToTransfer;

- (BOOL) dscSetCameraModeTo:(short)mode;

- (BOOL) dscReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;
- (BOOL) dscWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;

//DEBUG!
- (void) dumpCamStats;


@end 

@implementation MySPCA504Driver


#define VENDOR_SUNPLUS 0x4fc
#define PRODUCT_SPCA504 0x504a
#define PRODUCT_SPCA504B 0x504b
#define VENDOR_MUSTEK 0x055f
#define PRODUCT_GSMART_MINI2 0xc420

+ (NSArray*) cameraUsbDescriptions {
    NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_SPCA504],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_SUNPLUS],@"idVendor",
        @"Megapixel Camera ",@"name",NULL];
    NSDictionary* dict2=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_SPCA504B],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_SUNPLUS],@"idVendor",
        @"Megapixel Camera (B)",@"name",NULL];
    NSDictionary* dict3=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_GSMART_MINI2],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_MUSTEK],@"idVendor",
        @"Mustek GSmart MINI 2",@"name",NULL];
    return [NSArray arrayWithObjects:dict1,dict2,dict3,NULL];
}

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err = [self usbConnectToCam:usbDeviceRef];
    fps=5;
    resolution=ResolutionVGA;
    [self setCompression:0];
    [self setBrightness:0.0f];
    [self setContrast:0.5f];
    [self setSaturation:0.5f];
    [self setCompression:0];
    if (err==CameraErrorOK) err=[super startupWithUsbDeviceRef:usbDeviceRef];
    //Init dsc values
    firmwareVersion=0;
    sdramSize=0;
    flashPresent=NO;
    cardPresent=NO;
    cardClusterSize=0;
    sdramFileInfo=[[NSMutableArray alloc] initWithCapacity:10];
    flashFileInfo=[[NSMutableArray alloc] initWithCapacity:10];
    cardFileInfo=[[NSMutableArray alloc] initWithCapacity:10];
    

    //Init PC Cam image description
    pccamImgDesc=(ImageDescriptionHandle)NewHandle(sizeof(ImageDescription));
    if (pccamImgDesc==NULL) err=CameraErrorNoMem;
    else {	//Init fields
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

    if (err==CameraErrorOK) [self openDSCInterface];

    return err;
}



- (void) shutdown {
    [sdramFileInfo release]; sdramFileInfo=NULL;
    [flashFileInfo release]; flashFileInfo=NULL;
    [cardFileInfo release]; cardFileInfo=NULL;
    if (pccamImgDesc) DisposeHandle((Handle)pccamImgDesc); pccamImgDesc=NULL;
    [self closeDSCInterface];
    [super shutdown];
}

// FROM HERE: PC CAMERA METHODS

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    if (fr!=5) return NO;
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
    return 7;
}

- (void) setCompression:(short)v {
    [super setCompression:v];
    pccamQTabIdx=7-compression;
}

- (BOOL) canSetBrightness {
    return YES;
}

- (void) setBrightness:(float)v {
    [super setBrightness:v];
    if (isGrabbing) {
        int val=brightness*127.0f;
        [self usbWriteCmdWithBRequest:0x00 wValue:val wIndex:0x21a7 buf:NULL len:0];
    }
}

- (BOOL) canSetContrast {
    return YES;
}

- (void) setContrast:(float)v {
    [super setContrast:v];
    if (isGrabbing) {
        int val=contrast*63.0f;
        [self usbWriteCmdWithBRequest:0x00 wValue:val wIndex:0x21a8 buf:NULL len:0];
    }
}

- (BOOL) canSetSaturation {
    return YES;
}

- (void) setSaturation:(float)v {
    [super setSaturation:v];
    if (isGrabbing) {
        int val=saturation*63.0f;
        [self usbWriteCmdWithBRequest:0x00 wValue:val wIndex:0x21ae buf:NULL len:0];
    }
}

- (BOOL) pccamSetQTable {
    int i;
    for (i=0;i<64;i++) {	//Set matrices
        if (![self usbWriteCmdWithBRequest:0x00 wValue:NoZigZagY(pccamQTabIdx,i) wIndex:0x2800+i buf:NULL len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:NoZigZagUV(pccamQTabIdx,i) wIndex:0x2840+i buf:NULL len:0]) return NO;
    }
    return YES;
}

- (BOOL) pccamWaitCommandReceived {
    int retries=SPCA_RETRIES;
    UInt8 buf[8];
    usleep(SPCA_WAIT_RETRY);		//Wait some time	
    while (true) {
        //Ask camera: Is there a command still pending?
        if (firmwareVersion>=512) {
            if (![self usbReadCmdWithBRequest:0x21 wValue:0x0000 wIndex:0x0001 buf:buf len:1]) return NO;
            buf[0]=buf[0]&0x01;
        } else {
            if (![self usbReadCmdWithBRequest:0x01 wValue:0x0000 wIndex:0x0001 buf:buf len:1]) return NO;
            buf[0]=!(buf[0]&0x01);
        }
        if (buf[0]) break;		//Cam done -> everything's fine
        retries--;
        if (retries<=0) return NO;	//Max retries reached -> give up
        usleep(SPCA_WAIT_RETRY);	//Wait a bit
    }
    //Reset pending command flag
    if (firmwareVersion>=512) {
        buf[0]=0;
        if (![self usbWriteCmdWithBRequest:0x21 wValue:0x0000 wIndex:0x0001 buf:buf len:1]) return NO;
    } else {
        if (![self usbWriteCmdWithBRequest:0x01 wValue:0x0000 wIndex:0x0001 buf:buf len:0]) return NO;
    }
    return YES;
}

- (BOOL) pccamWaitCameraIdle {
    int retries=SPCA_RETRIES;
    UInt8 buf[8];

    while (true) {
        //Ask camera: Are you idle?
        if (firmwareVersion>=512) {
            if (![self usbReadCmdWithBRequest:0x21 wValue:0x0000 wIndex:0x0000 buf:buf len:1]) return NO;
            buf[0]=buf[0]&0x01;
        } else {
            if (![self usbReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2000 buf:buf len:1]) return NO;
            buf[0]=buf[0]&0x01;
        }
        if (buf[0]) {		//Not idle?
            retries--;
            if (retries<=0) return NO;	//Max retries reached -> give up
            usleep(SPCA_WAIT_RETRY);	//Wait a bit
        } else break;			//Cam idle -> everything's fine
    }
    return YES;
}

- (BOOL) startupGrabStream {
    UInt8 buf[256];
    int i;
    
    if (firmwareVersion>=512) {
        buf[0]=0;
        if (![self usbWriteCmdWithBRequest:0x24 wValue:0x0000 wIndex:0x0000 buf:buf len:1]) return NO;	//Set AE/AWB to auto
        if (![self pccamWaitCameraIdle]) return NO;
        if (![self usbWriteCmdWithBRequest:0x34 wValue:0x0000 wIndex:0x0000 buf:NULL len:0]) return NO;	//turn on GPIO power
        if (![self pccamWaitCommandReceived]) return NO;
        buf[0]=1;	//Setting this to 2 makes the camera send native SIF. But we scale later.
        if (![self usbWriteCmdWithBRequest:0x25 wValue:buf[0] wIndex:0x0004 buf:buf len:1]) return NO;	//camera size index for PC Camera mode: 5
        buf[0]=6;
        //0=raw 10Bit, 1=raw 8Bit, 2=YUV422, 3=YUV422 compr, 4=YUV420, 5=YUV-UV. 6=YUV420 compr, 7=YUV420-UV compr
        if (![self usbWriteCmdWithBRequest:0x27 wValue:buf[0] wIndex:0x0000 buf:buf len:1]) return NO;	//Image Type
        buf[0]=pccamQTabIdx;
        if (![self usbWriteCmdWithBRequest:0x26 wValue:pccamQTabIdx wIndex:0x0000 buf:buf len:1]) return NO;	//set q-table index
        if (![self pccamWaitCameraIdle]) return NO;
        if (![self usbWriteCmdWithBRequest:0x31 wValue:0x0000 wIndex:0x0004 buf:buf len:0]) return NO;	//Start PC Cam
        if (![self pccamWaitCommandReceived]) return NO;
        [self setBrightness:[self brightness]];
        [self setContrast:[self contrast]];
        [self setSaturation:[self saturation]];
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x21a3 buf:NULL len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x21ad buf:buf len:0]) return NO;	//Adjust Hue
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x21ac buf:buf len:0]) return NO;	//Adjust Saturation/Hue dis.
    } else {	//Firmware 1
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2000 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0013 wIndex:0x2301 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x2883 buf:buf len:0]) return NO;
        if (![self pccamSetQTable]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x2501 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2306 buf:buf len:0]) return NO;
        if (![self usbReadCmdWithBRequest:0x20 wValue:0 wIndex:0x0000 buf:buf+0 len:1]) return NO;
        if (![self usbReadCmdWithBRequest:0x20 wValue:1 wIndex:0x0000 buf:buf+1 len:1]) return NO;
        if (![self usbReadCmdWithBRequest:0x20 wValue:2 wIndex:0x0000 buf:buf+2 len:1]) return NO;
        if (![self usbReadCmdWithBRequest:0x20 wValue:3 wIndex:0x0000 buf:buf+3 len:1]) return NO;
        if (![self usbReadCmdWithBRequest:0x20 wValue:4 wIndex:0x0000 buf:buf+4 len:1]) return NO;
        if (![self usbReadCmdWithBRequest:0x20 wValue:5 wIndex:0x0000 buf:buf+5 len:1]) return NO;
//        NSLog(@"read info: %i %i %i %i %i %i (should be 1,0,2,2,0,0)",buf[0],buf[1],buf[2],buf[3],buf[4],buf[5]);
        if (![self usbReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2000 buf:buf len:1]) return NO;
//        NSLog(@"startup 1: read %i (should be 0)",buf[0]);
        if (![self usbWriteCmdWithBRequest:0x24 wValue:0x0003 wIndex:0x0008 buf:buf len:0]) return NO;
        if (![self pccamWaitCommandReceived]) return NO;
        if (![self usbWriteCmdWithBRequest:0x24 wValue:0x0000 wIndex:0x0000 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2000 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2883 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2884 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0005 wIndex:0x270c buf:buf len:0]) return NO;

/* Always setup VGA - other resolutions are scaled down later in the JPEG decompression. I had problems setting up a Firmware 1 camera to send formats other than VGA. It was well possible with FW2, but splitting this up would definitively make this code unnecessarily difficult. */
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0080 wIndex:0x2720 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0002 wIndex:0x2721 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x00e0 wIndex:0x2722 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x2723 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0080 wIndex:0x2711 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0002 wIndex:0x2712 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x00e0 wIndex:0x2713 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x2714 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x270d buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x270e buf:buf len:0]) return NO;
        
        if (![self usbWriteCmdWithBRequest:0x08 wValue:0x0000 wIndex:0x0004 buf:buf len:0]) return NO;
        if (![self pccamWaitCommandReceived]) return NO;
        if (![self usbWriteCmdWithBRequest:0x01 wValue:0x0000 wIndex:0x0003 buf:buf len:0]) return NO;
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0005 wIndex:0x2310 buf:buf len:0]) return NO;
        [self setBrightness:[self brightness]];
        [self setContrast:[self contrast]];
        [self setSaturation:[self saturation]];
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x21a3 buf:buf len:0]) return NO;	//gamma?
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x21ad buf:buf len:0]) return NO;	//Hue
        if (![self usbWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x21ac buf:buf len:0]) return NO;	//sat/hue
        if (![self pccamSetQTable]) return NO;
    }
    //COMING NEXT: Get and set quantizing tables
    //Get the matrix data
    for (i=0;i<128;i++) {
        if (![self usbReadCmdWithBRequest:0 wValue:0 wIndex:0x2800+i buf:buf+i len:1]) return NO;
    }
    //Place the values into the JFIF header
    for (i=0;i<64;i++) {
        pccamJfifHeader[JFIF_QTABLE0_OFFSET+i]=buf[ZigZagLookup[i]];
        pccamJfifHeader[JFIF_QTABLE1_OFFSET+i]=buf[64+ZigZagLookup[i]];
    }
    //Copy the JFIF header into the chunk buffers
    for (i=0;i<grabContext.numEmptyBuffers;i++) {
        memcpy(grabContext.emptyChunkBuffers[i].buffer,pccamJfifHeader,JFIF_HEADER_LENGTH);	//Copy header ...
        grabContext.emptyChunkBuffers[i].buffer+=JFIF_HEADER_LENGTH;		//... and point past it
    }
    //DONE: Get and set quantizing tables
    return YES;
}

- (void) shutdownGrabStream {
    if (firmwareVersion>=512) {
        [self usbWriteCmdWithBRequest:0 wValue:0 wIndex:0x2000 buf:NULL len:0];
    } else {
        [self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2000 buf:NULL len:0];
        [self usbWriteCmdWithBRequest:0x08 wValue:0x0000 wIndex:0x0006 buf:NULL len:0];
        [self pccamWaitCommandReceived];
        [self usbWriteCmdWithBRequest:0x24 wValue:0x0000 wIndex:0x0000 buf:NULL len:0];
        [self pccamWaitCommandReceived];
        [self usbWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x2306 buf:NULL len:0];
        [self usbWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x0d04 buf:NULL len:0];
    }
}

- (BOOL) setupGrabContext {
    BOOL ok=YES;
    int i,j;
    //Clear things that have to be set back if init fails
    grabContext.chunkReadyLock=NULL;
    grabContext.chunkListLock=NULL;
    for (i=0;i<SPCA504_NUM_TRANSFERS;i++) {
        grabContext.transferContexts[i].buffer=NULL;
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
    //Setup JFIF header
    memcpy(pccamJfifHeader,JFIFHeaderTemplate,JFIF_HEADER_LENGTH);
    pccamJfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+0]=480/256;
    pccamJfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+1]=480%256;
    pccamJfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+2]=640/256;
    pccamJfifHeader[JFIF_HEIGHT_WIDTH_OFFSET+3]=640%256;
    pccamJfifHeader[JFIF_YUVTYPE_OFFSET]=0x22;

/* Set quantizing tables. to be honest, this is unnecessary since we copy other quantizing tables later on (in startupGrabStream). The reason for this is that different cameras have different built-in quantizing table sets
(for some really strange reason). Think of this as a fallback - having a wrong quantizing table is better than
having none at all...) */

    for (i=0;i<64;i++) {
        pccamJfifHeader[JFIF_QTABLE0_OFFSET+i]=ZigZagY(pccamQTabIdx,i);
        pccamJfifHeader[JFIF_QTABLE1_OFFSET+i]=ZigZagUV(pccamQTabIdx,i);
    }
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
        for (i=0;ok&&(i<SPCA504_NUM_TRANSFERS);i++) {
            for (j=0;j<SPCA504_FRAMES_PER_TRANSFER;j++) {
                grabContext.transferContexts[i].frameList[j].frStatus=0;
                grabContext.transferContexts[i].frameList[j].frReqCount=grabContext.bytesPerFrame;
                grabContext.transferContexts[i].frameList[j].frActCount=0;
            }
            MALLOC(grabContext.transferContexts[i].buffer,
                   UInt8*,
                   SPCA504_FRAMES_PER_TRANSFER*grabContext.bytesPerFrame,
                   "isoc transfer buffer");
            if (grabContext.transferContexts[i].buffer==NULL) ok=NO;
        }
    }
    for (i=0;(i<SPCA504_NUM_CHUNK_BUFFERS)&&ok;i++) {
        MALLOC(grabContext.emptyChunkBuffers[i].buffer,UInt8*,grabContext.chunkBufferLength+JFIF_HEADER_LENGTH,"Chunk buffer");
        if (grabContext.emptyChunkBuffers[i].buffer==NULL) ok=NO;
        else grabContext.numEmptyBuffers=i+1;
    }
/* The chunk buffers will later be prefilled with the JPEG header. We cannot do this here since we don't
have the exact JPEG header yet. We obtain the correct quantizing tables at the end of [startupGrabStream].
But we can make sure that nothing bad can happen then...
*/
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
    for (i=0;i<SPCA504_NUM_TRANSFERS;i++) {		//cleanup isoc buffers
        if (grabContext.transferContexts[i].buffer) {
            FREE(grabContext.transferContexts[i].buffer,"isoc data buffer");
            grabContext.transferContexts[i].buffer=NULL;
        }
    }
    for (i=grabContext.numEmptyBuffers-1;i>=0;i--) {	//cleanup empty chunk buffers
        if (grabContext.emptyChunkBuffers[i].buffer) {
            FREE(grabContext.emptyChunkBuffers[i].buffer-JFIF_HEADER_LENGTH,"empty chunk buffer");
            grabContext.emptyChunkBuffers[i].buffer=NULL;
        }
    }
    grabContext.numEmptyBuffers=0;
    for (i=grabContext.numFullBuffers-1;i>=0;i--) {	//cleanup full chunk buffers
        if (grabContext.fullChunkBuffers[i].buffer) {
            FREE(grabContext.fullChunkBuffers[i].buffer-JFIF_HEADER_LENGTH,"full chunk buffer");
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
static bool StartNextIsochRead(SPCA504GrabContext* gCtx, int transferIdx);


static void isocComplete(void *refcon, IOReturn result, void *arg0) {
    int i;
    SPCA504GrabContext* gCtx=(SPCA504GrabContext*)refcon;
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
        while ((!frameListFound)&&(transferIdx<SPCA504_NUM_TRANSFERS)) {
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
        for (i=0;i<SPCA504_FRAMES_PER_TRANSFER;i++) {			//let's have a look into the usb frames we got
            currFrameLength=myFrameList[i].frActCount;			//Cache this - it won't change and we need it several times
            if (currFrameLength>0) {					//If there is data in this frame
                frameBase=gCtx->transferContexts[transferIdx].buffer+gCtx->bytesPerFrame*i;
                if (frameBase[0]==0xff) {				//Invalid chunk?
                    currFrameLength=0;
                } else if (frameBase[0]==0xfe) {			//Start of new chunk (image) ?
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
                    frameBase+=10;					//Skip past header
                    currFrameLength-=10;
                } else {						//No new chunk start
                    frameBase+=1;					//Skip past header
                    currFrameLength-=1;
                }
                if ((gCtx->fillingChunk)&&(currFrameLength>0)) {
                    if (gCtx->chunkBufferLength-gCtx->fillingChunkBuffer.numBytes>(2*currFrameLength+2)) {	//There's plenty of space to receive data (*2 beacuse of escaping, +2 because of end tag)
                        //Copy and add 0x00 after each 0xff
                        int x,y;
                        UInt8 ch;
                        UInt8* blitDst=gCtx->fillingChunkBuffer.buffer+gCtx->fillingChunkBuffer.numBytes;
                        x=y=0;
                        while (x<currFrameLength) {
                            ch=frameBase[x++];
                            blitDst[y++]=ch;
                            if (ch==0xff) blitDst[y++]=0x00;
                        }
                        gCtx->fillingChunkBuffer.numBytes+=y;
                    } else {						//Buffer is already full -> expect broken chunk -> discard
                        [gCtx->chunkListLock lock];			//Get access to the chunk buffers
                        gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers]=gCtx->fillingChunkBuffer;
                        gCtx->numEmptyBuffers++;
                        gCtx->fillingChunk=false;			//Now we're not filling (still in the lock to be sure no buffer is lost)
                        [gCtx->chunkListLock unlock];			//Free access to the chunk buffers
                    }
                }
            }
        }
        gCtx->framesSinceLastChunk+=SPCA504_FRAMES_PER_TRANSFER;	//Count frames (not necessary to be too precise here...)
        if ((gCtx->framesSinceLastChunk)>1000) {			//One second without a frame?
            NSLog(@"SPCA504 grab aborted because of invalid data stream");
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
        if ((gCtx->finishedTransfers)>=(SPCA504_NUM_TRANSFERS)) {
            CFRunLoopStop(CFRunLoopGetCurrent());
        }
    }
}

static bool StartNextIsochRead(SPCA504GrabContext* gCtx, int transferIdx) {
    IOReturn err;
    err=(*(gCtx->intf))->ReadIsochPipeAsync(gCtx->intf,
                                            1,
                                            gCtx->transferContexts[transferIdx].buffer,
                                            gCtx->initiatedUntil,
                                            SPCA504_FRAMES_PER_TRANSFER,
                                            gCtx->transferContexts[transferIdx].frameList,
                                            (IOAsyncCallback1)(isocComplete),
                                            gCtx);
    gCtx->initiatedUntil+=SPCA504_FRAMES_PER_TRANSFER;
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
    
        for (i=0;(i<SPCA504_NUM_TRANSFERS)&&ok;i++) {	//Initiate transfers
            ok=StartNextIsochRead(&grabContext,i);
        }
    }

    if (ok) {
        CFRunLoopRun();					//Do our run loop
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//remove the event source
    }

/*
 while (shouldBeGrabbing) {
        UInt8 buf[256];
        long count=256;
        memset(buf,0,256);
        IOReturn err=((IOUSBInterfaceInterface182*)(*dscIntf))->ReadPipeTO(dscIntf,1,buf,&count,1000,2000);
        CheckError(err,"grabbingThread bulk read");
        NSLog(@"read: %i bytes",count);
    }
 */
    
    [self shutdownGrabStream];
    [self usbSetAltInterfaceTo:0 testPipe:0];
    shouldBeGrabbing=NO;			//error in grabbingThread or abort? initiate shutdown of everything else
    [grabContext.chunkReadyLock unlock];	//give the decodingThread a chance to abort
    [pool release];
    grabbingThreadRunning=NO;
    [NSThread exit];
}

- (void) decodeCompressedBuffer:(SPCA504ChunkBuffer*)chunkBuf {
    UInt8* jfifBuf=chunkBuf->buffer-JFIF_HEADER_LENGTH;
    long jfifLength=chunkBuf->numBytes+JFIF_HEADER_LENGTH;
    Rect srcBounds,dstBounds;
    GWorldPtr gw;
    PixMapHandle pm;
    CGrafPtr oldPort;
    GDHandle oldGDev;
    OSErr err;
    SetRect(&srcBounds,0,0,624,480);
    SetRect(&dstBounds,0,0,[self width],[self height]);
    jfifBuf[jfifLength++]=0xff;	//Add end tag
    jfifBuf[jfifLength++]=0xd9;
    err=    QTNewGWorldFromPtr(
                             &gw,
                             (nextImageBufferBPP==4)?k32ARGBPixelFormat:k24RGBPixelFormat,
                             &dstBounds,
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
    DecompressImage(jfifBuf,pccamImgDesc,pm,&srcBounds,&dstBounds,srcCopy,NULL);
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
            SPCA504ChunkBuffer currBuffer;	//The buffer to decode
            //Get a full buffer
            [grabContext.chunkListLock lock];	//Get access to the buffer lists
            grabContext.numFullBuffers--;	//There's always one since noone else can empty it completely
            currBuffer=grabContext.fullChunkBuffers[grabContext.numFullBuffers];
            [grabContext.chunkListLock unlock];	//Get access to the buffer lists
            //Do the decoding
            if (nextImageBufferSet) {
                [imageBufferLock lock];					//lock image buffer access
                if (nextImageBuffer!=NULL) {
                    [self decodeCompressedBuffer:&currBuffer];
//                    [self decode422Uncompressed:currBuffer.buffer];
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
    return [sdramFileInfo count]+[flashFileInfo count]+[cardFileInfo count];
}

- (NSDictionary*) getStoredMediaObject:(long)idx {
    NSData* data=NULL;
    if (idx<[sdramFileInfo count]) {
        data=[self dscDownloadMediaFromSDRAM:idx];
    } else {
        idx-=[sdramFileInfo count];
        if (idx<[flashFileInfo count]) {
            data=[self dscDownloadMediaFromFlash:idx];
        } else {
            idx-=[flashFileInfo count];
            if (idx<[cardFileInfo count]) {
                data=[self dscDownloadMediaFromCard:idx];
            }
        }
    }
    if (data!=NULL) {
        return [NSDictionary dictionaryWithObjectsAndKeys:
            data,@"data",@"jpeg",@"type",NULL];
    } else return NULL;
}

- (void) eraseStoredMedia {
#ifdef VERBOSE
    NSLog(@"MySPCA504Driver: eraseStoredMedia not implemented");
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
    (*iodev)->Release(iodev);					// done with this

    //open interface
    err = (*dscIntf)->USBInterfaceOpen(dscIntf);
    CheckError(err,"openDSCInterface-USBInterfaceOpen");

    //set alternate interface
    err = (*dscIntf)->SetAlternateInterface(dscIntf,0);
    CheckError(err,"openDSCInterface-SetAlternateInterface");
    if (err) return CameraErrorUSBProblem;
    if (![self dscInit]) return CameraErrorUSBProblem;
    return CameraErrorOK;
}

- (void) closeDSCInterface {
    IOReturn err;
    if (dscIntf) {						//close our interface interface
        [self dscShutdown];
        if (isUSBOK) {
            err = (*dscIntf)->USBInterfaceClose(dscIntf);
        }
        err = (*dscIntf)->Release(dscIntf);
        CheckError(err,"closeDSCInterface-Release Interface");
        dscIntf=NULL;
    }
}

- (NSData*) dscDownloadMediaFromCard:(int)idx {
    long size=[[[cardFileInfo objectAtIndex:idx] objectForKey:@"Size"] longValue];
    NSMutableData* data=[[[NSMutableData alloc] initWithLength:size] autorelease];
    //Wait idle
    if (![self dscWaitCameraIdle]) return NULL;
    //Start download
    if (![self dscWriteCmdWithBRequest:0x54 wValue:idx+1 wIndex:0x02 buf:NULL len:0]) return NO;
    //Wait command completion
    if (![self dscWaitCommandReceived]) return NULL;
    //Download data
    if (![self dscReadBulkTo:[data mutableBytes] count:size]) return NO;
    return data;
}

- (NSData*) dscDownloadMediaFromFlash:(int)idx {
    UInt8 buf[2];
    long length=[[[flashFileInfo objectAtIndex:idx] objectForKey:@"Size"] longValue];
    long i=[[[flashFileInfo objectAtIndex:idx] objectForKey:@"Index"] longValue];

    NSMutableData* imageData=[NSMutableData dataWithLength:length];
    UInt8* imageBuf=[imageData mutableBytes];
    if (![self dscReadCmdWithBRequest:0x0b wValue:0x0000 wIndex:0x0005 buf:buf len:1]) return NULL;
    if (![self dscReadCmdWithBRequest:0x01 wValue:0x0040 wIndex:0x0005 buf:buf len:1]) return NULL;
    if (![self dscWriteCmdWithBRequest:0x0a wValue:i wIndex:0x000d buf:buf len:0]) return NULL;
    if (![self dscReadBulkTo:imageBuf count:length]) return NULL;
    return imageData;
}


- (NSData*) dscDownloadMediaFromSDRAM:(int)idx {
    long start=[[[sdramFileInfo objectAtIndex:idx] objectForKey:@"Start"] longValue];
    long rawSize=[[[sdramFileInfo objectAtIndex:idx] objectForKey:@"Size"] longValue];
    long alignedSize=((rawSize+63)/64)*64;
    short qTabIdx=[[[sdramFileInfo objectAtIndex:idx] objectForKey:@"Q-Index"] shortValue];
    short width=[[[sdramFileInfo objectAtIndex:idx] objectForKey:@"Width"] shortValue];
    short height=[[[sdramFileInfo objectAtIndex:idx] objectForKey:@"Height"] shortValue];
    BOOL doEscapeFF=![[[sdramFileInfo objectAtIndex:idx] objectForKey:@"FFescaped"] boolValue];
    BOOL isYUV422=[[[sdramFileInfo objectAtIndex:idx] objectForKey:@"YUV422"] boolValue];

    long i,j,jpegSize;
    NSMutableData* raw=[NSMutableData dataWithLength:alignedSize];
    UInt8* rawPtr=[raw mutableBytes];
    NSMutableData* jpeg;
    UInt8* jpegPtr;
    
    //Get unwrapped JPEG image data from camera
    if (![self dscReadSDRAMTo:rawPtr start:start count:alignedSize]) return NULL;
    //Go through data to see where we have to insert bytes
    jpegSize=rawSize+JFIF_HEADER_LENGTH+2;
    if (doEscapeFF) {
        for (i=0;i<=rawSize;i++) {
            if (rawPtr[i]==0xff) jpegSize++;
        }
    }
    //Allocate memory for the final pic
    jpeg=[NSMutableData dataWithLength:jpegSize];
    jpegPtr=[jpeg mutableBytes];
    //Copy Header template
    memcpy(jpegPtr,JFIFHeaderTemplate,JFIF_HEADER_LENGTH);
    //Change header
    jpegPtr[JFIF_HEIGHT_WIDTH_OFFSET+0]=(height>>8)&0xff;
    jpegPtr[JFIF_HEIGHT_WIDTH_OFFSET+1]= height    &0xff;
    jpegPtr[JFIF_HEIGHT_WIDTH_OFFSET+2]=(width>>8) &0xff;
    jpegPtr[JFIF_HEIGHT_WIDTH_OFFSET+3]= width     &0xff;
    jpegPtr[JFIF_YUVTYPE_OFFSET]=isYUV422?0x21:0x22;
    for (i=0;i<64;i++) {
        jpegPtr[JFIF_QTABLE0_OFFSET+i]=ZigZagY(qTabIdx,i);
        jpegPtr[JFIF_QTABLE1_OFFSET+i]=ZigZagUV(qTabIdx,i);
    }
    //Copy footer
    jpegPtr[jpegSize-2]=0xff;
    jpegPtr[jpegSize-1]=0xd9;
    j=JFIF_HEADER_LENGTH;
    if (doEscapeFF) {
        for (i=0;i<rawSize;i++) {
            if (rawPtr[i]==0xff) {
                jpegPtr[j++]=rawPtr[i];
                jpegPtr[j++]=0x00;	//insert escape code
            } else jpegPtr[j++]=rawPtr[i];
        }
    } else memcpy(jpegPtr+JFIF_HEADER_LENGTH,rawPtr,rawSize);
    [[raw retain] release];	//Explicitly dealloc buffer
    return jpeg;
}

- (BOOL) dscInit {
    UInt8 buf[256];
    firmwareVersion=0;

    /* *** TODO/FIXME: Move firmware detection to some more appropriate place (e.g. startupWithUsbDeviceRef) */ 
    
    if (![self dscWaitCameraIdle]) return NO;
    //Check firmware revision
    if (![self dscReadCmdWithBRequest:0x20 wValue:0x0000 wIndex:0x0000 buf:buf len:1]) return NO;
    firmwareVersion=buf[0]*256;

    //Enable autp pb size
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x2306 buf:NULL len:0]) return NO;
    //set dram -> fifo, bulk
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0013 wIndex:0x2301 buf:NULL len:0]) return NO;
    //Wait for idle
    if (![self dscWaitCameraIdle]) return NO;

    //----------------- SDRAM ------------------
    
    //Reset internal SDRAM info
    [sdramFileInfo removeAllObjects];
    sdramSize=0;
    //Is SDRAM present?
    if (![self dscReadCmdWithBRequest:0x28 wValue:0x0000 wIndex:0x0000 buf:buf len:1]) return NO;
    if (buf[0]) {				//SDRAM present
        //Get SDRAM info
        if (![self dscReadCmdWithBRequest:0x0 wValue:0x0000 wIndex:0x2705 buf:buf len:1]) return NO;
        switch (buf[0]) {
            case 4: sdramSize=16<<20; break;	//128 MBit = 16 MB
            case 3: sdramSize=8<<20; break;	//64 MBit = 8 MB
            default: sdramSize=8<<20; break;	//64 MBit = 8 MB
        }
        //Count number of images in sdram memory, read TOC and build file info at the same time
        //Get TOC for each object and count them
        while (true) {
            //Get TOC for next file
            long tocStart=sdramSize-([sdramFileInfo count]+1)*256;
            if (![self dscReadSDRAMTo:buf start:tocStart count:256]) break;	//Error: no more images (try to fail gracefully)
            if (buf[0]==255) break;	//No valid toc -> done
            else {			//valid toc -> remember important stuff and go on
                NSDictionary* dict=[NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithUnsignedChar:buf[0]],@"Type",
                    [NSNumber numberWithLong:(buf[1]<<8)+(buf[2]<<16)],@"Start",
                    [NSNumber numberWithLong:buf[11]+(buf[12]<<8)+(buf[13]<<16)],@"Size",
                    [NSNumber numberWithUnsignedChar:buf[7]&0x0f],@"Q-Index",
                    [NSNumber numberWithBool:(buf[7]&0x80)?YES:NO],@"FFescaped",
                    [NSNumber numberWithBool:YES],@"YUV422",	//****************
                    [NSNumber numberWithUnsignedChar:buf[40]],@"Quality",
                    [NSNumber numberWithShort:16*buf[8]],@"Width",
                    [NSNumber numberWithShort:16*buf[9]],@"Height",
                    NULL];
                [sdramFileInfo addObject:dict];
            }
        }
    }
    

    //----------------- NAND FLASH ------------------
    
    //Reset internal FLASH info
    [flashFileInfo removeAllObjects];
    flashPresent=NO;
    if (![self dscReadCmdWithBRequest:0x28 wValue:0x0000 wIndex:0x0001 buf:buf len:1]) return NO;
    if (buf[0]) {
        long mediaCount,i;
        NSMutableData* fdbs;
        UInt8* fdbPtr;
        flashPresent=YES;
        //Count number of images in flash memory
        if (![self dscWaitCameraIdle]) return NO;
        sleep(3);
        if (![self dscReadCmdWithBRequest:0x0b wValue:0x0000 wIndex:0x0000 buf:buf len:2]) return NO;
        mediaCount=buf[0]+(buf[1]<<8);
        //Get FDBs
        if (![self dscWaitCameraIdle]) return NO;
        sleep(3);
        if (![self dscWriteCmdWithBRequest:0x0a wValue:mediaCount wIndex:0x000c buf:buf len:0]) return NO;
        fdbs=[[[NSMutableData alloc] initWithLength:32*mediaCount] autorelease];
        fdbPtr=[fdbs mutableBytes];
        if (![self dscReadBulkTo:fdbPtr count:32*mediaCount]) return NO;
        //Go through FDBs and filter "good" info
        for (i=0;i<mediaCount;i++) {
            if ((fdbPtr[8]=='J')&&(fdbPtr[9]=='P')&&(fdbPtr[10]=='G')) {	//Is it a JPG?
                long len=fdbPtr[28]+(fdbPtr[29]<<8)+(fdbPtr[30]<<16);
                long idx=((fdbPtr[4]-'0')*1000)+
                    ((fdbPtr[5]-'0')*100)+
                    ((fdbPtr[6]-'0')*10)+
                    ((fdbPtr[7]-'0')*1);
                NSDictionary* dict=[NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithLong:idx],@"Index",
                    [NSNumber numberWithLong:len],@"Size",
                    NULL];
                [flashFileInfo addObject:dict];
            }
            fdbPtr+=32;
        }
    }

    //----------------- SMART MEDIA CARD ------------------
    
    //Reset internal SMC info
    [cardFileInfo removeAllObjects];
    cardPresent=NO;
    //Ask if a card is present
    if (![self dscReadCmdWithBRequest:0x28 wValue:0x0000 wIndex:0x0002 buf:buf len:1]) return NO;
    if ((buf[0])&&(firmwareVersion>=512)) {	//I have no idea about card support before fw 2
        long mediaCount;
        cardPresent=YES;
        //Find out number of objects on SmardMedia card
        if (![self dscWaitCameraIdle]) return NO;
        if (![self dscReadCmdWithBRequest:0x54 wValue:0x0000 wIndex:0x0000 buf:buf len:2]) return NO;
        mediaCount=buf[0]+256*buf[1];
        if (mediaCount>0) {    //Files on card -> Get info for files
            //Get fdb storage
            long fdbSize=((mediaCount*32+511)/512)*512;
            NSMutableData* cardFDB=[NSMutableData dataWithLength:fdbSize];
            UInt8* fdbBuf=[cardFDB mutableBytes];
            //Wait idle
            if (![self dscWaitCameraIdle]) return NO;
            //Flush
            [self dscReadBulkTo:NULL count:0];
            //Get card cluster size
            if (![self dscReadCmdWithBRequest:0x23 wValue:0x0000 wIndex:0x0064 buf:buf len:2]) return NO;
            cardClusterSize=buf[0]+256*buf[1];
            cardClusterSize&=0x0fff;
            cardClusterSize*=512;
            //read fdb
            if (![self dscWriteCmdWithBRequest:0x54 wValue:mediaCount wIndex:0x01 buf:buf len:0]) return NO;
            if (![self dscWaitCommandReceived]) return NO;
            if (![self dscReadBulkTo:fdbBuf count:fdbSize]) return NO;
            //Parse fdb
            while (mediaCount>0) {
                NSDictionary* dict=[NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithLong:fdbBuf[28]+(fdbBuf[29]<<8)+(fdbBuf[30]<<16)+(fdbBuf[31]<<24)],@"Size",
                    NULL];
                [cardFileInfo addObject:dict];
                mediaCount--;
                fdbBuf+=32;
            }
        }
    }    
    
    [self dumpCamStats];
    return YES;
}

- (void) dscShutdown {
    //Set camera mode to idle
    [self dscWriteCmdWithBRequest:0x32 wValue:0x0000 wIndex:0x0000 buf:NULL len:0];
}
    
- (BOOL) dscWaitCommandReceived {
    int retries=SPCA_RETRIES;
    UInt8 buf[8];
    usleep(SPCA_WAIT_RETRY);		//Wait some time
    while (true) {
        //Ask camera: Is there a command still pending?
        if (![self dscReadCmdWithBRequest:0x21 wValue:0x0000 wIndex:0x0001 buf:buf len:1]) return NO;
        if (buf[0]&0x01) break;		//Cam done -> everything's fine
        retries--;
        if (retries<=0) return NO;	//Max retries reached -> give up
        usleep(SPCA_WAIT_RETRY);	//Wait a bit
    }
    //Reset pending command flag
    buf[0]=0;
    if (![self dscWriteCmdWithBRequest:0x21 wValue:0x0000 wIndex:0x0001 buf:buf len:1]) return NO;
    return YES;
}

- (BOOL) dscWaitCameraIdle {
    int retries=SPCA_RETRIES;
    UInt8 buf[8];
    
    while (true) {
        //Ask camera: Are you idle?
        if (firmwareVersion>=512) {
            if (![self dscReadCmdWithBRequest:0x21 wValue:0x0000 wIndex:0x0000 buf:buf len:1]) return NO;
        } else {
            if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2000 buf:buf len:1]) return NO;
        }
        if (buf[0]&0x01) {		//Not idle?
            retries--;
            if (retries<=0) return NO;	//Max retries reached -> give up
            usleep(SPCA_WAIT_RETRY);	//Wait a bit
        } else break;			//Cam idle -> everything's fine
    }
    return YES;
}

- (BOOL) dscWaitDataReady {
    int retries=SPCA_RETRIES;
    UInt8 buf[8];
    
    while (true) {
        //Ask camera: Are you idle?
        if (firmwareVersion>=512) {
            if (![self dscReadCmdWithBRequest:0x21 wValue:0x0000 wIndex:0x0002 buf:buf len:1]) return NO;
            if (buf[0]&0x01) break;		//Data waiting -> done
        } else {
            [self dscReadCmdWithBRequest:0x0b wValue:0x0000 wIndex:0x0004 buf:buf len:1];
            if (buf[0]) break;			//Data waiting -> done
        }
        retries--;
        if (retries<=0) return NO;	//Max retries reached -> give up
        usleep(SPCA_WAIT_RETRY);	//Wait a bit
    }
    return YES;
}

- (BOOL) dscReadSDRAMTo:(UInt8*)buf start:(long)start count:(long)count {
    UInt8 save2713;
    UInt8 save2714;
    UInt8 save2715;
    IOReturn err;
    long actCount=count;
    
    //Set mode to upload
    if (![self dscSetCameraModeTo:4]) return NO;
    //setup transfer length
    if (![self dscWriteCmdWithBRequest:0x00 wValue:(count    )&0xff wIndex:0x2710 buf:NULL len:0]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:(count>>8 )&0xff wIndex:0x2711 buf:NULL len:0]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:(count>>16)&0xff wIndex:0x2712 buf:NULL len:0]) return NO;
    //remember start address
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2713 buf:&save2713 len:1]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2714 buf:&save2714 len:1]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2715 buf:&save2715 len:1]) return NO;
    //setup start address
    if (![self dscWriteCmdWithBRequest:0x00 wValue:(start>>1 )&0xff wIndex:0x2713 buf:NULL len:0]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:(start>>9 )&0xff wIndex:0x2714 buf:NULL len:0]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:(start>>17)&0xff wIndex:0x2715 buf:NULL len:0]) return NO;
    //Set transfer direction
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0013 wIndex:0x2301 buf:NULL len:0]) return NO;
    //Trigger transfer
    if (![self dscWriteCmdWithBRequest:0x00 wValue:2 wIndex:0x27a1 buf:NULL len:0]) return NO;
    //Do the transfer
    err=((IOUSBInterfaceInterface182*)(*dscIntf))->ReadPipeTO(dscIntf,1,buf,&actCount,1000,2000);
    switch (err) {
        case 0: break;
        case kIOReturnOverrun:
        case kIOReturnUnderrun:
            (*dscIntf)->ClearPipeStall(dscIntf,1);
            return (actCount==count);
            break;
        default:
            CheckError(err,"SDRAM bulk read");
            (*dscIntf)->ClearPipeStall(dscIntf,1);
            return NO;
            break;
    }
    //reset start address to remembered values
    if (![self dscWriteCmdWithBRequest:0x00 wValue:save2713 wIndex:0x2713 buf:NULL len:0]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:save2714 wIndex:0x2714 buf:NULL len:0]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:save2715 wIndex:0x2715 buf:NULL len:0]) return NO;

    return YES;
}

- (BOOL) dscReadBulkTo:(UInt8*)buf count:(long)bytesToTransfer {
    UInt8 tmpBuf[256];
    long bytesTransferred=0;
    long readLength;
    IOReturn err;

    //Wait until a page is ready
    if (![self dscWaitDataReady]) return NO;
    //Transfer in chunks of 256 bytes each
    while (true) {
        //read the page
        readLength=256;
        err=((IOUSBInterfaceInterface182*)(*dscIntf))->
            ReadPipeTO(dscIntf,1,tmpBuf,&readLength,1000,2000);
        if (bytesToTransfer>bytesTransferred) {
            int copyLength=MIN(256,(bytesToTransfer-bytesTransferred));
            memcpy(buf+bytesTransferred,tmpBuf,copyLength);
            bytesTransferred+=copyLength;
        }

        switch (err) {
            case 0: break;
            case kIOReturnOverrun:
            case kIOReturnUnderrun:
            case kIOUSBTransactionTimeout:
                (*dscIntf)->ClearPipeStall(dscIntf,1);
                if (![self dscWaitDataReady]) return (bytesTransferred>=bytesToTransfer);
                    break;
            default:
                CheckError(err,"read bulk");
                return NO;
                break;
        }
    }
}

- (BOOL) dscSetCameraModeTo:(short)mode {
    UInt8 oldMode;
    //Is cam in idle mode?
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2000 buf:&oldMode len:1]) return NO;
    //Not in idle mode -> Set to idle mode
    if (oldMode!=0) {
        if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2000 buf:NULL len:0]) return NO;
    }
    //New mode not idle mode?
    if (mode!=0) {
        if (![self dscWriteCmdWithBRequest:0x00 wValue:mode wIndex:0x2000 buf:NULL len:0]) return NO;
    }
    return YES;
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

- (void) dumpCamStats {
    NSLog(	@"Firmware Version : %f",((float)firmwareVersion)/256.0f);
    NSLog(	@"SDRAM size (MB)  : %i",sdramSize>>20);
    if (sdramSize>0) {
        NSLog(	@"SDRAM media count: %i",[sdramFileInfo count]);
    }
    if (flashPresent) {
        NSLog(	@"FLASH media count: %i",[flashFileInfo count]);
    } else {
        NSLog(	@"FLASH present    : NO");
    }
    if (cardPresent) {
        NSLog(	@"SMC media count  : %i",[cardFileInfo count]);
    } else {
        NSLog(	@"SMC present      : NO");
    }
}

@end
