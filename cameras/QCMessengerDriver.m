//
//  QCMessengerDriver.m
//  macam
//
//  Created by masakazu on Sun May 08 2005.
//  Copyright (c) 2005 masakazu (masa0038@users.sourceforge.net)
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

#import "QCMessengerDriver.h"
#import "VV6450Sensor.h"

#include "USB_VendorProductIDs.h"
#include "Resolvers.h"
#include "MiscTools.h"
#include "unistd.h"


#define USE_SCALER


@interface QCMessengerDriver (Private)

- (BOOL) setupGrabContext;				//Sets up the grabContext structure for the usb async callbacks
- (BOOL) cleanupGrabContext;				//Cleans it up
#if 0
- (void) read:(id)data;			//Entry method for the usb data grabbing thread
#endif
- (void) decodeChunk:(STV600ChunkBuffer*)chunk;

- (BOOL) camBoot;
- (BOOL) camInit;
- (BOOL) camStartStreaming;
- (BOOL) camStopStreaming;

@end


void  DEBUGLOG(NSString * arg)
{
}


void  DEBUGLOG2(NSString * arg1, unsigned long value)
{
}


@implementation QCMessengerDriver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_MESSENGER], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Messenger", @"name", NULL], 
        
        NULL];
}


- (BOOL) isDebugging { return f_debug; }

- (id) initWithCentral:(id)c {
    scaler = NULL;
    srcWidth = srcHeight = 0;

    // init superclass
    self = [super initWithCentral:c];
    if (self == NULL) return NULL;

    // setup defaults
    f_debug = NO;
    scaler = [[RGB888Scaler alloc] init];
    imgBufLen = 352 * 288 * 3 + 100;
    MALLOC(imgBuf, unsigned char*, imgBufLen, "MyQCMessengerDriver: alloc: imgBuf");
    return self;
}

- (void) dealloc {
    if (scaler) { [scaler release]; scaler = NULL; }
    if (imgBuf) { FREE(imgBuf, "MyQCMessengerDriver: free: imgBuf"); imgBuf = NULL; imgBufLen = 0; }
    [super dealloc];
}

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    BOOL rOK;
    BOOL frOK = (fr == 5);
    rOK = (r == ResolutionQSIF || r == ResolutionSIF
#ifdef USE_SCALER
           || r == ResolutionQCIF || r == ResolutionCIF
           || r == ResolutionVGA || r == ResolutionSVGA
           || r == ResolutionSQSIF
#endif
        );
    return (rOK && frOK);
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {	//This is a start
    if (dFps) *dFps=5;
    return ResolutionSIF;
}

- (void) setResolution:(CameraResolution)r fps:(short)fr {
    BOOL ok = YES;
    long sw, sh;

    [super setResolution:r fps:fr];

    sw = sh = 0;

// 0x0f: 162x124
// 0x08: 162x248
// 0x04: 324x124
// 0x02: 324x248

    switch (r) {
    case ResolutionQSIF:
        ok = [self writeSTVRegister:0x1505 value:0x0f];
        sw = 162; sh = 124;
        break;
    case ResolutionSIF:
        ok = [self writeSTVRegister:0x1505 value:0x02];
        sw = 324; sh = 248;
        break;
#ifdef USE_SCALER
    case ResolutionSQSIF:
        ok = [self writeSTVRegister:0x1505 value:0x0f];
        sw = 162; sh = 124;
        break;
    case ResolutionQCIF:
        ok = [self writeSTVRegister:0x1505 value:0x0f];
        sw = 162; sh = 124;
        break;
    case ResolutionCIF:
        ok = [self writeSTVRegister:0x1505 value:0x02];
        sw = 324; sh = 248;
        break;
    case ResolutionVGA:
        ok = [self writeSTVRegister:0x1505 value:0x02];
        sw = 324; sh = 248;
        break;
    case ResolutionSVGA:
        ok = [self writeSTVRegister:0x1505 value:0x02];
        sw = 324; sh = 248;
        break;
#endif
    default:
        NSAssert(0, @"unsupported resolution:");
    }

    srcWidth = sw;
    srcHeight = sh;
    [bayerConverter setSourceWidth:srcWidth height:srcHeight];
    [bayerConverter setDestinationWidth:srcWidth height:srcHeight];
    [scaler setDestinationWidth:[self width] height:[self height]];
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
        err=(*intf)->GetBusFrameNumber(intf, &(grabContext.initiatedUntil), &at);
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

- (BOOL) canSetLed {
#ifdef DEBUG
    return YES;
#else
    return NO;
#endif
}

- (BOOL) isLedOn {
#ifdef DEBUG
    return [self isDebugging];
#else
    return NO;
#endif
}

- (void) setLed:(BOOL)v {
#ifdef DEBUG
    if ([self canSetLed]) f_debug = v;
#endif
}

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId {
    return [super startupWithUsbLocationId:usbLocationId];
}

//StartNextIsochRead and isocComplete refer to each other, so here we need a declaration
static bool StartNextIsochRead(STV600GrabContext* grabContext, int transferIdx);

static void isocComplete(void *refcon, IOReturn result, void *arg0) {
    int i;
    STV600GrabContext* gCtx = (STV600GrabContext*)refcon;
    IOUSBIsocFrame* myFrameList = (IOUSBIsocFrame*)arg0;
    short transferIdx = 0;
    bool frameListFound = false;
    unsigned char* frameBase;
    unsigned long frameRun;
    unsigned long dataRunCode;
    unsigned long dataRunLength;
    
    gCtx->framesSinceLastChunk += STV600_FRAMES_PER_TRANSFER;
    
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
        if (!gCtx->err)
            gCtx->err = CameraErrorTimeout;		
        break;
            
    default:
        *(gCtx->shouldBeGrabbing) = NO;
        if (!gCtx->err)
            gCtx->err = CameraErrorUSBProblem;
        
        // log to console
        CheckError(result, "isocComplete");
	}
    
    if (*(gCtx->shouldBeGrabbing)) {
        //look up which transfer we are
        while ((!frameListFound) && (transferIdx < STV600_NUM_TRANSFERS)) {
            if ((gCtx->transferContexts[transferIdx].frameList) == myFrameList) frameListFound = true;
            else transferIdx++;
        }
        
        if (!frameListFound) {
#ifdef VERBOSE
            NSLog(@"isocComplete: Didn't find my frameList");
#endif
            *(gCtx->shouldBeGrabbing) = NO;
        }
    }
    
    if (*(gCtx->shouldBeGrabbing)) {
        //let's have a look into the usb frames we got
        for (i = 0; i < STV600_FRAMES_PER_TRANSFER; i++) {
            // cache this - it won't change and we need it several times
            const long currFrameLength = myFrameList[i].frActCount;
            
            frameRun = 0;
            frameBase = gCtx->transferContexts[transferIdx].buffer + gCtx->bytesPerFrame * i;
            
            while (frameRun < currFrameLength) {
                dataRunCode = (frameBase[frameRun] << 8) + frameBase[frameRun + 1];
                dataRunLength = (frameBase[frameRun + 2] << 8) + frameBase[frameRun + 3];
                frameRun += 4;

                if (0x0200 <= dataRunCode && dataRunCode <= 0x02ff ||
                    0x4200 <= dataRunCode && dataRunCode <= 0x42ff) {
                    if (gCtx->fillingChunk) {
                        if (gCtx->fillingChunkBuffer.numBytes + dataRunLength <= gCtx->chunkBufferLength) {
                            // copy the data run to our chunk
                            memcpy (gCtx->fillingChunkBuffer.buffer + gCtx->fillingChunkBuffer.numBytes,
                                    frameBase + frameRun,
                                    dataRunLength);
                            gCtx->fillingChunkBuffer.numBytes += dataRunLength;
#if 1
                            if (dataRunCode == 0x02ff || dataRunCode == 0x42ff) {
                                NSLog(@"flush frame since dataRunCode is 0x%04x", dataRunCode);
                                DiscardFillingChunk(gCtx);
                            }
#endif
                        } else {
                            //Buffer Overflow
                            NSLog (@"buffer overflow");
                            DiscardFillingChunk(gCtx);
                        }
                    } else {
                        DEBUGLOG2(@"chunk: missing fillingChunk!: dataRunCode = 0x%04x", dataRunCode);
                    }
                } else {
                    switch (dataRunCode) {
                    case 0x42ff:
                        DEBUGLOG(@"ignore chunk 0x42ff");
                        break;
                    case 0x8005:	//Start of image chunk - sensor change pending (???)
                    case 0xc001:	//Start of image chunk - some exposure error (???)
                    case 0xc005:	//Start of image chunk - some exposure error (???)
                        DEBUGLOG(@"flagged start chunk");
                    case 0x8001:	//Start of image chunk
                        if (dataRunLength != 0) NSLog(@"start frame: len != 0!");
                        GetFillingChunk(gCtx);
                        break;
                    case 0x8006:	//End of image chunk - sensor change pending (???)
                    case 0xc002:	//End of image chunk - some exposure error (???)
                    case 0xc006:	//End of image chunk - some exposure error (???)
                        DEBUGLOG(@"flagged end chunk");
                    case 0x8002:	//End of image chunk
                        if (dataRunLength != 0) NSLog(@"end frame: len != 0!");
                        gCtx->framesSinceLastChunk = 0;
                        FinishFillingChunk(gCtx);
                        break;
                    case 0x4200:	//Data run with some flag set (lighting? timing?)
                        DEBUGLOG(@"flagged data chunk");
                    case 0x0200:	//Data run
                        if (gCtx->fillingChunk) {
                            if (gCtx->fillingChunkBuffer.numBytes + dataRunLength <= gCtx->chunkBufferLength) {
                                // copy the data run to our chunk
                                memcpy (gCtx->fillingChunkBuffer.buffer + gCtx->fillingChunkBuffer.numBytes,
                                        frameBase + frameRun,
                                        dataRunLength);
                                gCtx->fillingChunkBuffer.numBytes += dataRunLength;
                            } else {
                                //Buffer Overflow
                                NSLog (@"buffer overflow");
                                DiscardFillingChunk(gCtx);
                            }
                        } else {
                            DEBUGLOG(@"chunk: missing fillingChunk!");
                        }
                        break;
                    default:
                        NSLog(@"unknown chunk %04x, length: %i", (unsigned short)dataRunCode, dataRunLength);
                        if (dataRunLength) DumpMem(frameBase + frameRun, dataRunLength);
                        break;
                    }
                }
                frameRun += dataRunLength;
            }
        }
    }
    
    if (gCtx->framesSinceLastChunk > 1000) {
        // more than a second without data?
        *(gCtx->shouldBeGrabbing) = NO;
        if (!gCtx->err) gCtx->err = CameraErrorUSBProblem;
    }
    
    if (*(gCtx->shouldBeGrabbing)) {
        // initiate next transfer
        if (!StartNextIsochRead(gCtx,transferIdx)) *(gCtx->shouldBeGrabbing) = NO;
    }
    
    if (!(*(gCtx->shouldBeGrabbing))) {
        // on error: collect finished transfers and exit if all transfers have ended
        gCtx->finishedTransfers++;
        if ((gCtx->finishedTransfers) >= (STV600_NUM_TRANSFERS)) {
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
        grabContext->initiatedUntil += STV600_FRAMES_PER_TRANSFER;	//update frames
        break;
    case 0x1000003:
        if (!grabContext->err)
            grabContext->err = CameraErrorNoCam;
        break;
    default:
        CheckError(err,"StartNextIsochRead-ReadIsochPipeAsync");
        if (!grabContext->err)
            grabContext->err = CameraErrorUSBProblem;
        break;
    }
    return !err;
}

- (BOOL) camBoot {
    if (![self writeSTVRegister:0x1440 value:0]) return NO;
    sensor = [[VV6450Sensor alloc] initWithCamera:self];
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
    int i, j;
    
    struct stv_init {
        const UInt8 *data;	/* If NULL, only single value to write, stored in len */
        UInt16 start;
        UInt16 len;
    };    

    static const struct stv_init stv_init[] = {
        /* LOGTAG */ { NULL, 0x1440, 0x00 },	/* disable capture */
        /* LOGTAG */ { NULL, 0x1436, 0x00 },
        /* LOGTAG */ { NULL, 0x1432, 0x03 },	/* 0x00-0x1F contrast ? */
        /* LOGTAG */ { NULL, 0x143a, 0xF9 },	/* 0x00-0x0F - gain */
        /* LOGTAG */ { NULL, 0x0509, 0x38 },	/* R */
        /* LOGTAG */ { NULL, 0x050a, 0x38 },	/* G */
        /* LOGTAG */ { NULL, 0x050b, 0x38 },	/* B */
        /* LOGTAG */ { NULL, 0x050c, 0x2A },
        /* LOGTAG */ { NULL, 0x050d, 0x01 },

        /* LOGTAG */ { NULL, 0x1431, 0x00 },	/* 0x00-0x07 ??? */
        /* LOGTAG */ { NULL, 0x1433, 0x34 },	/* 160x120 */		/* 0x00-0x01 night filter */
        /* LOGTAG */ { NULL, 0x1438, 0x18 },	/* 640x480 */
// 18 bayes
// 10 compressed?

        /* LOGTAG */ { NULL, 0x1439, 0x00 },
// antiflimmer??  0xa2 ger perfekt bild mot monitor

        /* LOGTAG */ { NULL, 0x143b, 0x05 },
        /* LOGTAG */ { NULL, 0x143c, 0x00 },	/* 0x00-0x01 - ??? */

// shutter time 0x0000-0x03FF
// low value  give good picures on moving objects (but requires much light)
// high value gives good picures in darkness (but tends to be overexposed)
        /* LOGTAG */ { NULL, 0x143e, 0x01 },
        /* LOGTAG */ { NULL, 0x143d, 0x00 },

        /* LOGTAG */ { NULL, 0x1442, 0xe2 },
// write: 1x1x xxxx
// read:  1x1x xxxx
//        bit 5 == button pressed and hold if 0
// write 0xe2,0xea

// 0x144a
// 0x00 init
// bit 7 == button has been pressed, but not handled

// interrupt
//if(urb->iso_frame_desc[i].status == 0x80) {
//if(urb->iso_frame_desc[i].status == 0x88) {

        /* LOGTAG */ { NULL, 0x1500, 0xd0 },
        /* LOGTAG */ { NULL, 0x1500, 0xd0 },
        /* LOGTAG */ { NULL, 0x1500, 0x50 },	/* 0x00 - 0xFF  0x80 == compr ? */

        /* LOGTAG */ { NULL, 0x1501, 0xaf },
// high val-> ljus area blir morkare.
// low val -> ljus area blir ljusare.
        /* LOGTAG */ { NULL, 0x1502, 0xc2 },
// high val-> ljus area blir morkare.
// low val -> ljus area blir ljusare.
        /* LOGTAG */ { NULL, 0x1503, 0x45 },
// high val-> ljus area blir morkare.
// low val -> ljus area blir ljusare.

//        /* LOGTAG */ { NULL, 0x1505, 0x02 },
// 2  : 324x248  80352 bytes
// 7  : 248x162  40176 bytes
// c+f: 162*124  20088 bytes

        /* LOGTAG */ { NULL, 0x150e, 0x8e },
        /* LOGTAG */ { NULL, 0x150f, 0x37 },
        /* LOGTAG */ { NULL, 0x15c0, 0x00 },
#if 0
        /* LOGTAG */ { NULL, 0x15c1, 1023 },	/* 160x120 */ /* ISOC_PACKET_SIZE */
        /* LOGTAG */ { NULL, 0x15c3, 0x08 },	/* 0x04/0x14 ... test pictures ??? */

        /* LOGTAG */ { NULL, 0x143f, 0x01 },	/* commit settings */
#endif
    };
	
	DEBUGLOG(@"camInit:");

    if (ok) ok = [sensor resetSensor];
    
    if (ok) {
        if (intf && isUSBOK) {
            err = (*intf)->GetPipeProperties(intf, 1, &direction, &number, &transferType, &maxPacketSize, &interval);
            if (err) {
                ok = NO;
            } else {
                if (f_debug) NSLog(@"direction: 0x%02x number: 0x%02x transferType: 0x%02x maxPacketSize: 0x%04x interval: 0x%02x",
                      direction & 0x00ff, number & 0x00ff, transferType & 0x00ff, maxPacketSize & 0x0ffff, interval & 0x00ff);
            }
        } else ok = NO;
    }

    for (i = 0, ok = YES; i < sizeof(stv_init) / sizeof(struct stv_init) && ok == YES; i++) {
        if (stv_init[i].data == NULL) {
            if (stv_init[i].len & 0xff00)
                ok = [self writeWideSTVRegister:stv_init[i].start value:stv_init[i].len];
            else
                ok = [self writeSTVRegister:stv_init[i].start value:(stv_init[i].len & 0x00ff)];
        } else {
            for (j = 0; j < stv_init[i].len && ok == YES; j++) {
                ok = [self writeSTVRegister:(stv_init[i].start + j) value:stv_init[i].data[j]];
            }
        }
    }

    if (ok) ok = [self writeWideSTVRegister:0x15c1 value:maxPacketSize];		//isoch frame size

    if (ok) ok = [sensor resetSensor];

    if (ok) ok = [self writeSTVRegister:0x15c3 value:8];
    if (ok) ok = [self writeSTVRegister:0x143f value:0x01];		//commit settings

    return ok;
}

- (void) grabbingThread:(id)data
{
    NSAutoreleasePool   * pool = [[NSAutoreleasePool alloc] init];
    long                  i;
    IOReturn              err;
    CFRunLoopSourceRef    cfSource;
    BOOL                  ok = YES;

    ChangeMyThreadPriority(10);	//We need to update the isoch read in time, so timing is important for us

    if (ok) {
        if (![self usbSetAltInterfaceTo:1 testPipe:1]) {	//*** Check this for QuickCam Express! was alt 3!
            if (!grabContext.err)
				grabContext.err = CameraErrorNoBandwidth;
            ok = NO;
        }
    }
    if (ok) {
        if (![self camInit]) {
            if (!grabContext.err) grabContext.err = CameraErrorUSBProblem;
            ok = NO;
        }
    }
    if (ok) {
        [sensor adjustExposure];
        if (![sensor startStream]) {
            if (!grabContext.err) grabContext.err = CameraErrorUSBProblem;
            ok = NO;
        }
    }
    if (ok)	{
        if (![self writeSTVRegister:0x1440 value:1]) {
            if (!grabContext.err) grabContext.err = CameraErrorUSBProblem;
            ok = NO;
        }
    }

    if (ok) {
        err = (*intf)->CreateInterfaceAsyncEventSource(intf, &cfSource);	//Create an event source
        CheckError(err,"CreateInterfaceAsyncEventSource");
        CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//Add it to our run loop
        for (i=0; (i < STV600_NUM_TRANSFERS) && ok; i++) {	//Initiate transfers
            ok = StartNextIsochRead(&grabContext, i);
        }
    }
    if (ok) {
        CFRunLoopRun();					//Do our run loop
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//remove the event source
    }

    shouldBeGrabbing = NO;	//error in grabbingThread or abort? initiate shutdown of everything else

    //Stopping doesn't check for ok any more - clean up what we can
    if (![self writeSTVRegister:0x1440 value:0]) {
        if (!grabContext.err) grabContext.err = CameraErrorUSBProblem;
        ok = NO;
    }

    if (![sensor stopStream]) {
        if (!grabContext.err) grabContext.err = CameraErrorUSBProblem;
        ok = NO;
    }
	
	[self camInit];

    if (![self usbSetAltInterfaceTo:0 testPipe:0]) {
        if (!grabContext.err) grabContext.err = CameraErrorUSBProblem;
        ok = NO;
    }

    [grabContext.chunkReadyLock unlock];	//give the decodingThread a chance to abort
    [pool release];
    grabbingThreadRunning = NO;
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
#ifdef USE_SCALER
    unsigned char *imgbuf = NULL;

    [bayerConverter convertFromSrc: bayerData
                            toDest: imgBuf
                       srcRowBytes: srcWidth + extraBytesInLine
                       dstRowBytes: srcWidth * 3
                            dstBPP: nextImageBufferBPP
                              flip: hFlip
						 rotate180: NO];

    // just in case
    if (![scaler setDestinationWidth:[self width] height:[self height]]) {
        [imageBufferLock unlock];
        NSLog(@"scaler: setDestinationWidth: failed");
        return;
    }

    imgbuf = [scaler convertSourceData:imgBuf width:srcWidth height:srcHeight];

    if (!imgbuf) {
        // release lock
        [imageBufferLock unlock];
        NSLog (@"no image buffer");
        return;
    }
    
    memcpy(nextImageBuffer, imgbuf, [scaler destinationDataSize]);
#else
    [bayerConverter convertFromSrc: bayerData
                            toDest: nextImageBuffer
                       srcRowBytes: srcWidth + extraBytesInLine
                       dstRowBytes: nextImageBufferRowBytes
                            dstBPP: nextImageBufferBPP
                              flip: hFlip
						 rotate180: NO];

#endif

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

@end
