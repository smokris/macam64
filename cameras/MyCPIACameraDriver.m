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
#import "MyCPIACameraDriver.h"
#import "Resolvers.h"
#import "yuv2rgb.h"
#include "MiscTools.h"
#include "unistd.h"


/*Some Camera specifics:

There are two Alternate interface bandwith settings:

USB_BANDWIDTH=1, default
First is : 0 -> 0, 0 -> 0	(off)
                   1 -> 448 bytes/msec,
                   2 -> 704,
                   3 -> 960 

USB_BANDWIDTH=0
Second is: 0 -> 0, 0 -> 0	(off)
                   1 -> 320 bytes/mesc,
                   2 -> 616,
                   3 -> 896 

Camera specific constants - see CPIA documentation for details. There is ONE VERY IMPORTANT THING we have to keep in mind: The CPIA docs are correct. They tell us the byte ordering the cam wants to have. But: Since the wValue, wIndex and wLength fields are sonsidered to be "short", the USB lib reverses the ordering (thats' also correct, the USB docs recommend receiving the parameters in host endianness and - on big endian systems - converting them to little endian - the USB standard). We are a big endian system and have to expect the byte ordering of the fields to be reversed. So we have take care of that: The byte ordering inside those fields is turned around agains the cpia docs.

*/

#define VENDOR_VISION	0x0553
#define PRODUCT_CPIA_II	0x0002

//Image stream constants
#define CHUNK_HEADER 	64
#define CHUNK_FOOTER 	4
#define LINE_HEADER 	2
#define LINE_FOOTER 	1

// Constant values
#define MAGIC_0		0x19
#define MAGIC_1		0x68
#define EOI		0xff	// four times means End of Image
#define EOL		0xfd	// means End of Line

// Command Requests
// CPIA
#define GET_CAMERA_STATUS	0x03
#define GOTO_HI_POWER		0x04
#define GOTO_LO_POWER		0x05

// Module
#define READ_VC_REG		(1+(1<<5))
#define WRITE_VC_REG		(2+(1<<5))
#define READ_MC_PORT		(3+(1<<5))
#define WRITE_MC_PORT		(4+(1<<5))

// VP CTRL (5<<5)
#define SET_COLOUR_PARAMS	0xa3
#define SET_EXPOSURE		0xa4
#define SET_COLOUR_BALANCE	0xa6
#define SET_SENSOR_FPS		0xa7
#define SET_VP_DEFAULTS		0xa8
#define SET_SENSOR_MATRIX	(0xa0+19)

// Capture (6<<5)
#define SET_GRAB_MODE		0xc3
#define INIT_STREAM_CAP 	0xc4
#define FINI_STREAM_CAP 	0xc5
#define START_STREAM_CAP 	0xc6
#define END_STREAM_CAP	 	0xc7
#define SET_FORMAT	 	0xc8
#define SET_ROI			0xc9
#define SET_COMPRESSION		0xca
#define SET_COMPR_TARGET	0xcb

@implementation MyCPIACameraDriver

+ (unsigned short) cameraUsbProductID { return PRODUCT_CPIA_II; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_VISION; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"CPiA-based camera"]; }

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId {
    CameraError err=[self usbConnectToCam:usbLocationId configIdx:0];
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
    memset(&grabContext,0,sizeof(CPIAGrabContext));
    return [super startupWithUsbLocationId:usbLocationId];
}

- (void) dealloc {
    [self usbCloseConnection];
    [super dealloc];
}


- (BOOL) canSetBrightness { return YES; }
- (void) setBrightness:(float)v {
    [super setBrightness:v];
    if (isGrabbing) {	//In a running grab, really set the params - no stateLock since this is not critical
        [self usbWriteCmdWithBRequest:SET_COLOUR_PARAMS
                               wValue:((long)([self brightness]*100.0f))+(((long)([self contrast]*100.0f))<<8)
                               wIndex:((long)([self saturation]*100.0f))
                                  buf:NULL len:0];
    }
}

- (BOOL) canSetContrast { return YES; }
- (void) setContrast:(float)v {
    [super setContrast:(1.0f-v)];
    [self setBrightness:[self brightness]];
}

- (BOOL) canSetSaturation { return YES; }
- (void) setSaturation:(float)v {
    [super setSaturation:v];
    [self setBrightness:[self brightness]];
}

- (BOOL) canSetGain { return YES; }
- (void) setGain:(float)v {
    [super setGain:v];
    if (isGrabbing) {	//In a running grab, really set the params - no stateLock since this is not critical
        unsigned char buf[8];
        long exposure=[self shutter]*300.0f;
        buf[0]=[self gain]*255.0f;
        buf[1]=0;
        buf[2]=exposure&0x000000ff;
        buf[3]=(exposure&0x0000ff00)>>8;
        if ([self isAutoGain]) {
            [self usbWriteCmdWithBRequest:SET_EXPOSURE wValue:2<<8 wIndex:0 buf:buf len:8];
            // [self usbWriteCmdWithBRequest:SET_EXPOSURE wValue:1<<8 wIndex:0 buf:buf len:8];
        } else {
            [self usbWriteCmdWithBRequest:SET_EXPOSURE wValue:3<<8 wIndex:0 buf:buf len:8];
            [self usbWriteCmdWithBRequest:SET_EXPOSURE wValue:1<<8 wIndex:0 buf:buf len:8];
        }
    }
}

// See 2.3.4 of 'developer.pdf'
- (void) setGPIO: (unsigned char)port and:(unsigned char)andMask or:(unsigned char) orMask {
    // Pass through mode (can we not do this once at init) ? 
    [self usbWriteCmdWithBRequest:WRITE_VC_REG wValue:(unsigned short)(0x90 | (0x8F<<8)) wIndex:(0x50) buf:nil len:0];
    // And do the GPIO data
    [self usbWriteCmdWithBRequest:WRITE_MC_PORT wValue:(port | (andMask<<8)) wIndex:(orMask) buf:nil len:0];
}

// See 2.3.3 of 'developer.pdf'
- (unsigned int) getGPIO {
    unsigned char ports[4];
    [self usbReadCmdWithBRequest:READ_MC_PORT wValue:0 wIndex:0 buf:ports len:4];
    return ports[0] + ((ports[1])<<8) + ((ports[2])<<16) + ((ports[3])<<24);
}

- (void) setMCPort: (unsigned char)port and:(unsigned char)andMask or:(unsigned char) orMask {
    // Twiddle the bits (new = old & and) | or).
    [self usbWriteCmdWithBRequest:WRITE_MC_PORT wValue:(port | (andMask<<8)) wIndex:(orMask) buf:nil len:0];
}


- (BOOL) canSetShutter {
    return YES;
}

- (void) setShutter:(float)v {
    [super setShutter:v];
    [self setGain:[self gain]];
}

- (BOOL) canSetAutoGain { return YES; }
- (void) setAutoGain:(BOOL)v {
    [super setAutoGain:v];
    [self setGain:[self gain]];
}

- (short) maxCompression {
    return 3;
}

/* The camera supports basically three ways to affect the effective frame rate.
First is the SensorBaseRate, which is the base clock for the sensor and can be 25 or 30
Second is the SensorClkDivider (1,2,4 or 8), which divides SensorBaseRate before being sent to the sensor, so we can get 15 (30/2)
Third is the SkipFrames count in intStreamCap to send only the n-th image, so we can get 10 (30/3) and 5 (25/5) */

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    BOOL rOK=((r==ResolutionSQSIF)||(r==ResolutionQSIF)||(r==ResolutionQCIF)||(r==ResolutionSIF)||(r==ResolutionCIF));
    BOOL frOK=((fr==5)||(fr==10)||(fr==15)||(fr==25)||(fr==30));
    return (rOK&&frOK);
}

- (void) setResolution:(CameraResolution)r fps:(short)fr {
    [super setResolution:r fps:fr];	//Update instance variables if state is ok and format is supported
    switch (fps) {			//Set framerate dependent camera parameters
        case 5:  camSensorBaseRate=25; camSensorClkDivider=0; camSkipFrames=4; break;
        case 10: camSensorBaseRate=30; camSensorClkDivider=0; camSkipFrames=2; break;
        case 15: camSensorBaseRate=30; camSensorClkDivider=0; camSkipFrames=1; break;
        case 25: camSensorBaseRate=25; camSensorClkDivider=0; camSkipFrames=0; break;
        case 30: camSensorBaseRate=30; camSensorClkDivider=0; camSkipFrames=0; break;
        default: return; break;
    }
    switch (resolution) {		//Set resolution-dependent camera parameters
        case ResolutionSQSIF: camNativeResolution=ResolutionQCIF; camRangeOfInterest=0x0313061e; break;
        case ResolutionQSIF:  camNativeResolution=ResolutionQCIF; camRangeOfInterest=0x01150321; break;
        case ResolutionQCIF:  camNativeResolution=ResolutionQCIF; camRangeOfInterest=0x00160024; break;
        case ResolutionSIF:   camNativeResolution=ResolutionCIF;  camRangeOfInterest=0x022a0642; break;
        case ResolutionCIF:   camNativeResolution=ResolutionCIF;  camRangeOfInterest=0x002c0048; break;
        default: return;
    }
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {	//This is a start
    if (dFps) *dFps=25;
    return ResolutionQCIF;
}

- (BOOL) canSetWhiteBalanceMode { return YES; }

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)wb {
    BOOL ok=YES;
    switch (wb) {
        case WhiteBalanceLinear:
        case WhiteBalanceOutdoor:
        case WhiteBalanceIndoor:
        case WhiteBalanceAutomatic:
            break;
        default:
            ok=NO;
            break;
    }
    return ok;
}

- (WhiteBalanceMode) defaultWhiteBalanceMode { return WhiteBalanceAutomatic; }

- (void) setSensorMatrix:(int)a1 a2:(int)a2 a3:(int)a3 a4:(int)a4 a5:(int)a5 a6:(int)a6 a7:(int)a7 a8:(int)a8 a9:(int)a9 {
    unsigned char matrix[5] = { a5,a6,a7,a8,a9 };
    [self usbWriteCmdWithBRequest:SET_SENSOR_MATRIX wValue:a1+(a2<<8) wIndex:a3+(a4<<8) buf:matrix len:5];
}

/*
    Setting BalanceMode to 0 causes no change to colour balance.

    Setting BalanceMode to 1 allows the manual setting of the colour balance parameters. The accompanying
    Red/Green/BlueGain parameters are taken as the new values for the three channels. Values may be in the
    range 0-212 for each channel. Values above 212 cause the colour balance matrix to overflow.
    
    Setting BalanceMode to 2 enables the auto-colour balance algorithm. The camera will automatically adjust
    the three colour channel gains to acheive optimum colour balance.

    Setting BalanceMode to 3 disables the auto-colour balance algorithm. It will effectively freeze the current
    colour balance settings.
*/

- (void) setColourBalance:(unsigned short int)mode red:(float)redGain green:(float)greenGain blue:(float)blueGain {
    unsigned short val,idx;

    val=((short)(redGain*CPIA_COLOR_GAIN_FACTOR))<<8;
    idx=(((short)(blueGain*CPIA_COLOR_GAIN_FACTOR))<<8)+((short)(greenGain*CPIA_COLOR_GAIN_FACTOR));

    [self usbWriteCmdWithBRequest:SET_COLOUR_BALANCE wValue:val+mode wIndex:idx buf:NULL len:0];
}

- (void) setWhiteBalanceMode:(WhiteBalanceMode)wb {
    BOOL awb=NO;
    float redGain=1.0f;
    float greenGain=1.0f;
    float blueGain=1.0f;

    [super setWhiteBalanceMode:wb];
    if (isGrabbing) {
        switch (whiteBalanceMode) {
            case WhiteBalanceLinear:
                break;
            case WhiteBalanceOutdoor:
                redGain=1.25;
                greenGain=0.9;
                blueGain=0.85;
                break;
            case WhiteBalanceIndoor:
                redGain=0.8;
                greenGain=0.95;
                blueGain=1.25;
                break;
            case WhiteBalanceAutomatic:
                awb=YES;
                break;
            default:
                break;
        }

        if (awb) {
            [self setColourBalance:2 red:0 green:0 blue:0 ];
        } else {
            [self setColourBalance:3 red:0 green:0 blue:0 ];
            [self setColourBalance:1 red:(redGain*80/212) green:(greenGain*80/212) blue:(blueGain*80/212) ];
        }
    }
}

- (short) usbAltInterface {
    long bytes;
    switch (compression) {
        case 1: return 3; break;
        case 2: return 2; break;
        case 3: return 1; break;
        default:
            bytes=[self width]*[self height]*3/2+[self height]*(LINE_HEADER+LINE_FOOTER)+CHUNK_HEADER+CHUNK_FOOTER;
            bytes*=[self fps];
            bytes+=999;
            bytes/=1000;
            if (bytes<[self bandwidthOfUsbAltInterface:1]) return 1;
            else if (bytes<[self bandwidthOfUsbAltInterface:2]) return 2;
            else return 3;
            break;
    }
}

- (short) bandwidthOfUsbAltInterface:(short)ai {
    switch (ai) {
        case 1: return 448;
        case 2: return 704;
        case 3: return 960;
        default: return 0;
    }
}

- (BOOL) setupGrabContext {
    long i;

    BOOL ok=YES;
    [self cleanupGrabContext];					//cleanup in case there's something left in here

//Simple things first
    grabContext.bytesPerFrame=[self bandwidthOfUsbAltInterface:[self usbAltInterface]];
    grabContext.chunkBufferLength=CHUNK_HEADER+CHUNK_FOOTER+[self width]*(LINE_HEADER+LINE_FOOTER)
                             +[self width]*[self height]*3;	//That should be more than enough
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
//get the chunk buffers
    for (i=0;(i<CPIA_NUM_CHUNK_BUFFERS)&&(ok);i++) {
        MALLOC(grabContext.emptyChunkBuffers[i].buffer,unsigned char*,grabContext.chunkBufferLength,"CPIA chunk buffers");
        if (grabContext.emptyChunkBuffers[i].buffer) grabContext.numEmptyBuffers++;
        else ok=NO;
    }
//get the transfer buffers
    for (i=0;(i<CPIA_NUM_TRANSFERS)&&(ok);i++) {
        MALLOC(grabContext.transferContexts[i].buffer,unsigned char*,grabContext.bytesPerFrame*CPIA_FRAMES_PER_TRANSFER,"CPIA transfer buffers");
        if (!(grabContext.transferContexts[i].buffer)) ok=NO;
        else {
            long j;
            for (j=0;j<CPIA_FRAMES_PER_TRANSFER;j++) {	//init frameList
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
    
    for (i=0;(i<CPIA_NUM_TRANSFERS)&&(ok);i++) {
        if (grabContext.transferContexts[i].buffer) {
            FREE(grabContext.transferContexts[i].buffer,"transfer buffer");
            grabContext.transferContexts[i].buffer=NULL;
        }
    }
    return YES;
}

//StartNextIsochRead and isocComplete refer to each other, so here we need a declaration
static bool StartNextIsochRead(CPIAGrabContext* grabContext, int transferIdx);

static void isocComplete(void *refcon, IOReturn result, void *arg0) {
    int i;
    CPIAGrabContext* gCtx=(CPIAGrabContext*)refcon;
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
        while ((!frameListFound)&&(transferIdx<CPIA_NUM_TRANSFERS)) {
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
        for (i=0;i<CPIA_FRAMES_PER_TRANSFER;i++) {			//let's have a look into the usb frames we got
            currFrameLength=myFrameList[i].frActCount;			//Cache this - it won't change and we need it several times
            frameBase=gCtx->transferContexts[transferIdx].buffer+gCtx->bytesPerFrame*i;
//Chunk start detection
            if (!gCtx->fillingChunk) {				//Are we outside of a frame?
                if (currFrameLength>=2) {				//A start candidate has at very least two bytes
                    if ((frameBase[0]==MAGIC_0)&&(frameBase[1]==MAGIC_1)) {	//Start of chunk?
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
                }
            }
//Chunk copy
            if (gCtx->fillingChunk) {					//Are inside a frame?
                if (currFrameLength>0) {				//non-empty frame?
                    if (((gCtx->fillingChunkBuffer.numBytes)+currFrameLength)<=(gCtx->chunkBufferLength)) {
                                                                        //does it fit?
                        memcpy(gCtx->fillingChunkBuffer.buffer+gCtx->fillingChunkBuffer.numBytes,
                               frameBase,currFrameLength);
                        gCtx->fillingChunkBuffer.numBytes+=currFrameLength;
//                        NSLog(@"filling chunk with %i bytes, is now %i",currFrameLength,gCtx->fillingChunkBuffer.numBytes);

                    } else {	//buffer is full -> discard current buffer and chunk
#ifdef VERBOSE
                        NSLog(@"Chunk buffer overflow - dropping");
#endif
                        [gCtx->chunkListLock lock];		//Get permission to manipulate buffer lists
                        gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers]=gCtx->fillingChunkBuffer;
                        gCtx->numEmptyBuffers++;
                        gCtx->fillingChunk=false;
                        gCtx->fillingChunkBuffer.buffer=NULL;	//it's redundant but to be safe...
                        [gCtx->chunkListLock unlock];		//Done manipulating buffer lists
                    }
                }
            }
//Chunk end detection
            if (gCtx->fillingChunk) {				//Are inside a frame?
                if (currFrameLength>=4) {			//non-empty frame?
                    if ((frameBase[currFrameLength-1]==EOI)
                        &&(frameBase[currFrameLength-2]==EOI)
                        &&(frameBase[currFrameLength-3]==EOI)
                        &&(frameBase[currFrameLength-4]==EOI)) {
                        //End of chunk detected: Finish and notify decodingThread
                        gCtx->framesSinceLastChunk=0;
                        [gCtx->chunkListLock lock];		//Get permission to manipulate chunk lists
                        gCtx->fullChunkBuffers[gCtx->numFullBuffers]=gCtx->fillingChunkBuffer;
                        gCtx->numFullBuffers++;			//our fresh chunk has been added to the full ones
                        gCtx->fillingChunk=false;
                        gCtx->fillingChunkBuffer.buffer=NULL;	//it's redundant but to be safe...
                        [gCtx->chunkListLock unlock];		//exit critical section
                    }
                }
            }
        }
        gCtx->framesSinceLastChunk+=CPIA_FRAMES_PER_TRANSFER;	//Count frames (not necessary to be too precise here...)
        if ((gCtx->framesSinceLastChunk)>1000) {		//One second without a frame?
#ifdef VERBOSE
            NSLog(@"CPiA grab aborted because of invalid data stream");
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
        if ((gCtx->finishedTransfers)>=(CPIA_NUM_TRANSFERS)) {
            CFRunLoopStop(CFRunLoopGetCurrent());
        }
    }
}

static bool StartNextIsochRead(CPIAGrabContext* grabContext, int transferIdx) {
    IOReturn err;
    err=(*(grabContext->intf))->ReadIsochPipeAsync(grabContext->intf,
                                                   1,
                                                   grabContext->transferContexts[transferIdx].buffer,
                                                   grabContext->initiatedUntil,
                                                   CPIA_FRAMES_PER_TRANSFER,
                                                   grabContext->transferContexts[transferIdx].frameList,
                                                   (IOAsyncCallback1)(isocComplete),
                                                   grabContext);
    switch (err) {
        case 0:
            grabContext->initiatedUntil+=CPIA_FRAMES_PER_TRANSFER;	//update frames
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

    if (![self usbSetAltInterfaceTo:[self usbAltInterface] testPipe:1]) {
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
        for (i=0;(i<CPIA_NUM_TRANSFERS)&&ok;i++) {	//Initiate transfers
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
    [pool release];
    grabbingThreadRunning=NO;
    [NSThread exit];
}

- (CameraError) doChunkReadyThings {
    return CameraErrorOK;
}

- (CameraError) decodingThread {
    CPIAChunkBuffer currChunk;
    long i;
    CameraError err=CameraErrorOK;
    grabbingThreadRunning=NO;
    
    if (![self setupGrabContext]) {
        err=CameraErrorNoMem;
        shouldBeGrabbing=NO;
    }
    mergeBuffer=NULL;
    if ((shouldBeGrabbing)&&(compression>0)) {
        MALLOC(mergeBuffer,unsigned char*,[self width]*[self height]*2,"mergeBuffer");
        if (!mergeBuffer) {
            err=CameraErrorNoMem;
            shouldBeGrabbing=NO;	//Atomic - no lock needed
        } else memset(mergeBuffer,0,[self width]*[self height]*2);
    }


    if (shouldBeGrabbing) {
        grabbingThreadRunning=YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];    //start grabbingThread
    }

//Following: The decoding loop
    while (shouldBeGrabbing) {
        if (grabContext.numFullBuffers == 0) 
            usleep(1000); // 1 ms (1000 micro-seconds)

        err = [self doChunkReadyThings ];
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
            if (compression>0) {
                if (frameCounter==3) {
                    [self usbWriteCmdWithBRequest:SET_COMPRESSION wValue:1 wIndex:0 buf:NULL len:0];
                }
                [self decodeCompressedChunk:&currChunk];
            } else {
                [self decodeUncompressedChunk:&currChunk];
            }
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
    if (mergeBuffer) {
        FREE(mergeBuffer,"mergeBuffer");		//don't need the merge buffer any more
        mergeBuffer=NULL;
    }
    if (!err) err=grabContext.err;			//Forward decoding thread error
    return grabContext.err;				//notify delegate
}

- (void) decodeUncompressedChunk:(CPIAChunkBuffer*) chunkBuffer {
    short width=[self width];
    short height=[self height];
    if (!nextImageBufferSet) return;			//No need to decode
    [imageBufferLock lock];				//lock image buffer access
    if (nextImageBuffer!=NULL) {
        long lineExtra=nextImageBufferRowBytes-width*nextImageBufferBPP;	//bytes to skip after each line in target buffer
        unsigned char* src=chunkBuffer->buffer+CHUNK_HEADER+LINE_HEADER;	//Our chunk starts here
        yuv2rgb (width,height,YUVCPIA420Style,src,nextImageBuffer,nextImageBufferBPP,
                 LINE_HEADER+LINE_FOOTER,lineExtra,hFlip);	//decode
    }
    lastImageBuffer=nextImageBuffer;			//Copy nextBuffer info into lastBuffer
    lastImageBufferBPP=nextImageBufferBPP;
    lastImageBufferRowBytes=nextImageBufferRowBytes;
    nextImageBufferSet=NO;				//nextBuffer has been eaten up
    [imageBufferLock unlock];				//release lock
    [self mergeImageReady];				//notify delegate about the image. perhaps get a new buffer
}

- (void) decodeCompressedChunk:(CPIAChunkBuffer*) chunkBuffer {
    short width=[self width];
    short height=[self height];
    unsigned char* srcRun=chunkBuffer->buffer+CHUNK_HEADER;
    unsigned char* dstRun=mergeBuffer;
    short y;
    BOOL lineDone;
    BOOL decompError=NO;
    long lineChars;
    unsigned char ch;
    bool compImage=chunkBuffer->buffer[28];	//Is this image compressed?
//Do the decompression
    for (y=0;y<height;y++) {
        lineDone=NO;
        dstRun=mergeBuffer+y*width*2;
        lineChars=*(srcRun++);
        lineChars+=256*(*(srcRun++));
        while (lineDone==NO) {
            ch=*(srcRun++);
            if (ch==EOL) {		//Line is done
                lineDone=YES;
                lineChars--;
            } else if ((ch&1)&&(compImage)) {		//Skip bytes
                dstRun+=ch-1;
                lineChars--;
            } else {			//Pixel pair: Copy four bytes
                *(dstRun++)=ch;
                *(dstRun++)=*(srcRun++);
                *(dstRun++)=*(srcRun++);
                *(dstRun++)=*(srcRun++);
                lineChars-=4;
            }
            if ((lineChars<=0)&&(!lineDone)) {	//Line eaten up (according to length) but no EOL found
                decompError=YES;
                goto DecompEnd;
            }
            if ((lineDone)&&(lineChars!=0)) {	//Line end found but still in line (according to length)
                decompError=YES;
                goto DecompEnd;
            }
        }
    }
//End of decompression
DecompEnd:
    if (!nextImageBufferSet) return;			//No need to decode
    [imageBufferLock lock];				//lock image buffer access
    if (nextImageBuffer!=NULL) {
        long lineExtra=nextImageBufferRowBytes-width*nextImageBufferBPP;	//bytes to skip after each line in target buffer
        yuv2rgb (width,height,YUVCPIA422Style,mergeBuffer,nextImageBuffer,nextImageBufferBPP,0,lineExtra,hFlip);	//decode
    }
    lastImageBuffer=nextImageBuffer;			//Copy nextBuffer info into lastBuffer
    lastImageBufferBPP=nextImageBufferBPP;
    lastImageBufferRowBytes=nextImageBufferRowBytes;
    nextImageBufferSet=NO;				//nextBuffer has been eaten up
    [imageBufferLock unlock];				//release lock
    [self mergeImageReady];				//notify delegate about the image. perhaps get a new buffer
}    

- (BOOL) startupGrabStream {
    //wake up camera
    [self usbWriteCmdWithBRequest:GOTO_HI_POWER wValue:0 wIndex:0 buf:NULL len:0];
    //Set Video Processor Unit to defaults
    [self usbWriteCmdWithBRequest:SET_VP_DEFAULTS wValue:0 wIndex:0 buf:NULL len:0];
    [self setBrightness:[self brightness]];	//set brightness, contrast and saturation if not up-to-date
    [self setGain:[self gain]];			//set gain, shutter and autogain if not up-to-date
    [self setWhiteBalanceMode:[self whiteBalanceMode]];	//set white balance mode
    //Set Grab mode to continuous grabbing
    [self usbWriteCmdWithBRequest:SET_GRAB_MODE wValue:1 wIndex:0 buf:NULL len:0];
    //Set video format (CIF/QCIF 4:2:0 YUYV)
    [self usbWriteCmdWithBRequest:SET_FORMAT
                           wValue:((camNativeResolution==ResolutionCIF)?1:0)+((compression>0)?256:0)
                           wIndex:0 buf:NULL len:0];
    //Set Sensor fps
    [self usbWriteCmdWithBRequest:SET_SENSOR_FPS
                           wValue:(camSensorClkDivider)+((camSensorBaseRate==30)?256:0)
                           wIndex:0 buf:NULL len:0];
    //Set Range of Interest
    [self usbWriteCmdWithBRequest:SET_ROI
                           wValue:((camRangeOfInterest&0x00ff0000)>>8)+((camRangeOfInterest&0xff000000)>>24)
                           wIndex:((camRangeOfInterest&0x000000ff)<<8)+((camRangeOfInterest&0x0000ff00)>>8)
                              buf:NULL len:0];
    //Set Compression (here always off - will be enabled if needed after the first frame)
    [self usbWriteCmdWithBRequest:SET_COMPRESSION wValue:0 wIndex:0 buf:NULL len:0];
    frameCounter=0;
    //init streaming and set up streaming characteristics 
    [self usbWriteCmdWithBRequest:INIT_STREAM_CAP wValue:(camSkipFrames) wIndex:0 buf:NULL len:0];
    //start streaming 
    [self usbWriteCmdWithBRequest:START_STREAM_CAP wValue:0 wIndex:0 buf:NULL len:0];
    return YES;
}

- (BOOL) shutdownGrabStream {
    //stop streaming
    [self usbWriteCmdWithBRequest:END_STREAM_CAP wValue:0 wIndex:0 buf:NULL len:0];
    //finish streaming mode
    [self usbWriteCmdWithBRequest:FINI_STREAM_CAP wValue:0 wIndex:0 buf:NULL len:0];
    //Send the camera to sleep
    [self usbWriteCmdWithBRequest:GOTO_LO_POWER wValue:0 wIndex:0 buf:NULL len:0];
    return YES;
}

- (void) logCamState {
    unsigned char status[8];
    [self usbReadCmdWithBRequest:GET_CAMERA_STATUS wValue:0 wIndex:0 buf:status len:8];
    NSLog(@"Camera status");
    NSLog(@"System state :%d",status[0]);
    NSLog(@"Grab state   :%d",status[1]);
    NSLog(@"Stream state :%d",status[2]);
    NSLog(@"Fatal error  :%d",status[3]);
    NSLog(@"Cmd error    :%d",status[4]);
    NSLog(@"Debug flags  :%d",status[5]);
    NSLog(@"VPStatus     :%d",status[6]);
    NSLog(@"ErrorCode    :%d",status[7]);
}

@end
