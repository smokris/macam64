/*
 macam - webcam app and QuickTime driver component
 MyQCProBeigeDriver.h - Driver class for the Logitech QuickCam Pro (beige focus ring)
 This might be also useful for other cameras using the USS-720 bridge (e.g. the QuickCam VC)

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

#import "MyQCProBeigeDriver.h"
#import "MyCameraCentral.h"
#include "Resolvers.h"
#include "MiscTools.h"
#include "unistd.h"	//usleep
#include "USB_VendorProductIDs.h"

@interface MyQCProBeigeDriver (Private)

- (void) decompressBuffer:(UInt8*)src;
- (CameraError) startup;

- (BOOL) resetUSS720;
- (CameraError) writeCameraRegister:(UInt16)reg to:(UInt32)val len:(long)len;
- (CameraError) writeCameraRegister:(UInt16)reg fromBuffer:(UInt8*)buf len:(long)len;
- (CameraError) readCameraRegister:(UInt16)reg toBuffer:(UInt8*)buf len:(long)len;

- (NSMutableData*) getOldestFullChunkBuffer;
- (NSMutableData*) getEmptyChunkBuffer;
- (void) disposeChunkBuffer:(NSMutableData*)buf;
- (void) passChunkBufferToFullOnes:(NSMutableData*)buf;
    
@end
@implementation MyQCProBeigeDriver

+ (unsigned short) cameraUsbProductID { return PRODUCT_QUICKCAM_PRO_BEIGE; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_LOGITECH; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"QuickCam Pro (beige)"]; }

- (id) initWithCentral:(id)c {
    self=[super initWithCentral:c];
    if (!self) return NULL;
    bayerConverter=[[BayerConverter alloc] init];
    if (!bayerConverter) return NULL;
    return self;
}

- (void) dealloc {
    if (bayerConverter) [bayerConverter release]; bayerConverter=NULL;
    [super dealloc];
}

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId {
    CameraError err;
    
    //setup connection to camera
    err=[self usbConnectToCam:usbLocationId configIdx:0];
    if (err!=CameraErrorOK) return err;

    //Do the general camera startup sequence, if any ***
    
    //set some defaults
    [self setBrightness:0.5];
    [self setContrast:0.5];
    [self setGamma:0.5];
    [self setSaturation:0.5];
    [self setSharpness:0.5];
    [self setGain:0.8];
    [self setShutter:0.5];
    [self setWhiteBalanceMode:WhiteBalanceLinear];
    
    //Do the remaining, usual connection stuff
    err=[super startupWithUsbLocationId:usbLocationId];
    if (err!=CameraErrorOK) return err;

    rotate = NO;
    
    return err;
}


- (BOOL) supportsResolution:(CameraResolution)res fps:(short)rate {
    if (rate!=5) return NO;
    if ((res!=ResolutionSIF)&&(res!=ResolutionVGA)) return NO;
    return YES;
}

- (CameraResolution) defaultResolutionAndRate:(short*)rate {
    if (rate) *rate=5;
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

- (BOOL) canSetWhiteBalanceMode {
    return YES;
}

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode {
    return ((newMode==WhiteBalanceLinear)
            ||(newMode==WhiteBalanceIndoor)
            ||(newMode==WhiteBalanceOutdoor)
            ||(newMode==WhiteBalanceAutomatic));
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
            [bayerConverter setGainsRed:0.8f green:1.0f blue:1.2f];
            break;
        case WhiteBalanceOutdoor:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:1.2f green:1.0f blue:0.8f];
            break;
        case WhiteBalanceAutomatic:
            [bayerConverter setGainsDynamic:YES];
            break;
        default:
            break;
    }
}

- (BOOL) canSetGain {
    return YES;
}

- (void) setGain:(float)v {
    [super setGain:v];
}

- (BOOL) canSetShutter {
    return YES;
}

- (void) setShutter:(float)v {
    [super setShutter:v];
}

- (BOOL) canSetAutoGain {
    return YES;
}

- (void) setAutoGain:(BOOL)v {
    [super setAutoGain:v];
    aeGain=0.8f;
    aeShutter=shutter;
}

- (BOOL) canSetHFlip {
    return YES;
}

- (short) maxCompression {
    return 0;	//It's usually 1, but I currently cannot get the uncompressed mode to run. 
}

- (CameraError) startupGrabbing {
    CameraError err=CameraErrorOK;

    lastGain=-1.0f;		//Don't change immediately (for testing) ************
    lastShutter=-1.0f;		//Don't change immediately (for testing) ************
    
    //Set needed variables, calculate values
    videoBulkReadsPending=0;
    grabBufferSize=([self width]*[self height]*6/8+64);

    //Allocate memory, locks
    emptyChunks=NULL;
    fullChunks=NULL;
    emptyChunkLock=NULL;
    fullChunkLock=NULL;
    chunkReadyLock=NULL;
    fillingChunk=NULL;
    decompressionBuffer=NULL;
    emptyChunks=[[NSMutableArray alloc] initWithCapacity:QCPROBEIGE_NUM_CHUNKS];
    if (!emptyChunks) return CameraErrorNoMem;
    fullChunks=[[NSMutableArray alloc] initWithCapacity:QCPROBEIGE_NUM_CHUNKS];
    if (!fullChunks) return CameraErrorNoMem;
    emptyChunkLock=[[NSLock alloc] init];
    if (!emptyChunkLock) return CameraErrorNoMem;
    fullChunkLock=[[NSLock alloc] init];
    if (!fullChunkLock) return CameraErrorNoMem;
    chunkReadyLock=[[NSLock alloc] init];
    if (!chunkReadyLock) return CameraErrorNoMem;
    [chunkReadyLock tryLock];								//Should be locked by default
    decompressionBuffer=[[NSMutableData alloc] initWithCapacity:[self width]*([self height]+1)];
    if (!decompressionBuffer) return CameraErrorNoMem;
    
    //Initialize bayer decoder
    if (!err) {
        [bayerConverter setSourceWidth:[self width] height:[self height]];
        [bayerConverter setDestinationWidth:[self width] height:[self height]];
        [bayerConverter setSourceFormat:(resolution==ResolutionSIF)?3:2];
        [bayerConverter setMakeImageStats:YES];
    }


    //Camera startup:
    //Set to alt 2 (most stuff will only work in this mode)
    if (!err) {
        if (![self usbSetAltInterfaceTo:2 testPipe:2]) err=CameraErrorUSBProblem;
    }

    if (!err) err=[self startup];

    return err;
}

- (void) shutdownGrabbing {

    UInt8 buf[0x40];
    [self  readCameraRegister:0x058f toBuffer:buf len:0x40];
    [self writeCameraRegister:0x000f to:0x4c len:1];
    [self usbSetAltInterfaceTo:0 testPipe:0];
    
    //Clean up the mess 
    if (emptyChunks) {
        [emptyChunks release];
        emptyChunks=NULL;
    }
    if (fullChunks) {
        [fullChunks release];
        fullChunks=NULL;
    }
    if (emptyChunkLock) {
        [emptyChunkLock release];
        emptyChunkLock=NULL;
    }
    if (fullChunkLock) {
        [fullChunkLock release];
        fullChunkLock=NULL;
    }
    if (chunkReadyLock) {
        [chunkReadyLock release];
        chunkReadyLock=NULL;
    }
    if (fillingChunk) {
        [fillingChunk release];
        fillingChunk=NULL;
    }
    if (decompressionBuffer) {
        [decompressionBuffer release];
        decompressionBuffer=NULL;
    }
}

static void handleFullChunk(void *refcon, IOReturn result, void *arg0) {
    MyQCProBeigeDriver* driver=(MyQCProBeigeDriver*)refcon;
    long size=((long)arg0);
    [driver handleFullChunkWithReadBytes:size error:result];
}

- (void) handleFullChunkWithReadBytes:(UInt32)readSize error:(IOReturn)err  {
    videoBulkReadsPending--;
    if (err) {
        if (!grabbingError) grabbingError=CameraErrorUSBProblem;
        shouldBeGrabbing=NO;
    }
    if (shouldBeGrabbing) {			//no usb error
        [self passChunkBufferToFullOnes:fillingChunk];
        fillingChunk=NULL;			//to be sure...
    } else {					//Incorrect chunk -> ignore (but back to empty chunks)
        [self disposeChunkBuffer:fillingChunk];
        fillingChunk=NULL;			//to be sure...
    }
    if (shouldBeGrabbing) [self fillNextChunk];
//We can only stop if there's no read request left. If there is an error, no new one was issued
    if (videoBulkReadsPending<=0) CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void) fillNextChunk {
    IOReturn err;
    //Get an empty chunk
    if (shouldBeGrabbing) {
        fillingChunk=[self getEmptyChunkBuffer];
        if (!fillingChunk) {
            if (!grabbingError) grabbingError=CameraErrorNoMem;
            shouldBeGrabbing=NO;
        }
    }
    //1. Reset
    if (shouldBeGrabbing) {
        if (![self resetUSS720]) {
            if (!grabbingError) grabbingError=CameraErrorUSBProblem;
            shouldBeGrabbing=NO;
        }
    }
    //2. Change settings. If there are no setting to change: Write a zero byte via bulk
    if (shouldBeGrabbing) {
        BOOL changedSetting=NO;
        float myGain=(autoGain)?aeGain:gain;
        float myShutter=(autoGain)?aeShutter:shutter;
        if (myShutter!=lastShutter) {
            UInt8 buf[2];
            //Shutter values: f001-0001, ff00-0000, (0002-ff02,0003-ff03, ... ,003f-ff3f)
            if (myShutter<0.3f) {
                buf[0]=(int)((((0.3f-myShutter)/0.3f))*240.0f);
                buf[1]=1;
            } else if (myShutter<0.6f) {
                buf[0]=(int)((((0.6f-myShutter)/0.3f))*255.0f);
                buf[1]=0;
            } else {
                buf[0]=((int)((((myShutter-0.6f)/0.4f))*12000.0f+512.0f))%0xff;
                buf[1]=(((int)((((myShutter-0.6f)/0.4f))*12000.0f+512.0f))>>8)%0xff;
            }
            [self writeCameraRegister:0x0004 fromBuffer:buf len:2];	//And do some illogical transfers
            [self writeCameraRegister:0x000d to:0 len:1];		//Don't ask me - ask Creative and Logitech :)
            lastShutter=myShutter;
            changedSetting=YES;
        }
        if (myGain!=lastGain) {				//Gain changes
            int iGain=myGain*255.0f;
            UInt8 buf[21];
            int i;
            for (i=18;i>=0;i-=2) {			//Produce a weird buffer (the cam likes it that way...)
                buf[i]=0x58+(iGain&1);
                buf[i+1]=0xd8+(iGain&1);
                iGain/=2;
            }
            buf[20]=0x5c;
            [self writeCameraRegister:0x000f fromBuffer:buf len:21];	//And do some illogical transfers
            [self writeCameraRegister:0x000d to:0 len:1];		//Don't ask me - ask Creative and Logitech :)
            lastGain=gain;
            changedSetting=YES;
        }
        if (!changedSetting) {
            UInt8 buf=0;
            IOReturn err=(*intf)->WritePipe(intf, 1, &buf, 1);
            CheckError(err,"MyQCProBeigeDriver: fillNextChunk: write a zero");
            if (err) {
                if (!grabbingError) grabbingError=CameraErrorUSBProblem;
                shouldBeGrabbing=NO;
            }
        }
    }
    //3. Start the bulk read
    if (shouldBeGrabbing) {
        err=((IOUSBInterfaceInterface182*)(*intf))->ReadPipeAsyncTO(intf,2,
                                     [fillingChunk mutableBytes],
                                     grabBufferSize,2000,3000,
                                     (IOAsyncCallback1)(handleFullChunk),self);	//Read one chunk
        CheckError(err,"grabbingThread:ReadPipeAsync");
        if (err) {
            grabbingError=CameraErrorUSBProblem;
            shouldBeGrabbing=NO;
        } else videoBulkReadsPending++;
    }
}

- (void) grabbingThread:(id)data {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    IOReturn err;
    CFRunLoopSourceRef cfSource;
    
    grabbingError=CameraErrorOK;

//Run the grabbing loob
    if (shouldBeGrabbing) {
        err = (*intf)->CreateInterfaceAsyncEventSource(intf, &cfSource);	//Create an event source
        CheckError(err,"CreateInterfaceAsyncEventSource");
        if (err) {
            if (!grabbingError) grabbingError=CameraErrorNoMem;
            shouldBeGrabbing=NO;
        }
    }

    if (shouldBeGrabbing) {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//Add it to our run loop
        [self fillNextChunk];
        CFRunLoopRun();
    }

    shouldBeGrabbing=NO;			//error in grabbingThread or abort? initiate shutdown of everything else
    [chunkReadyLock unlock];			//give the decodingThread a chance to abort
    [pool release];
    grabbingThreadRunning=NO;
    [NSThread exit];
}

- (CameraError) decodingThread {
    CameraError err=CameraErrorOK;
    NSMutableData* currChunk;
    long width=4;	//Just some stupid values to keep the compiler happy
    long height=4;
    BOOL bufferSet;
    grabbingThreadRunning=NO;
    
    err=[self startupGrabbing];

    if (err) shouldBeGrabbing=NO;
    
    if (shouldBeGrabbing) {
        grabbingError=CameraErrorOK;
        grabbingThreadRunning=YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];    //start grabbingThread
        width=[self width];						//Should remain constant during grab
        height=[self height];						//Should remain constant during grab
        while (shouldBeGrabbing) {
            [chunkReadyLock lock];					//wait for new chunks to arrive
            while ((shouldBeGrabbing)&&([fullChunks count]>0)) {	//decode all full chunks we have
                currChunk=[self getOldestFullChunkBuffer];
                [imageBufferLock lock];					//Get image data
                lastImageBuffer=nextImageBuffer;
                lastImageBufferBPP=nextImageBufferBPP;
                lastImageBufferRowBytes=nextImageBufferRowBytes;
                bufferSet=nextImageBufferSet;
                nextImageBufferSet=NO;
                if (bufferSet) {
                    UInt8* src=[currChunk mutableBytes];
                    UInt8* tmp=[decompressionBuffer mutableBytes];
                    [self decompressBuffer:src];
                    [bayerConverter convertFromSrc:tmp
                                            toDest:lastImageBuffer
                                       srcRowBytes:width
                                       dstRowBytes:lastImageBufferRowBytes
                                            dstBPP:lastImageBufferBPP
                                              flip:hFlip
										 rotate180:rotate];
                    [imageBufferLock unlock];
                    [self mergeImageReady];
                } else {
                    [imageBufferLock unlock];
                }
                [emptyChunkLock lock];			//recycle our chunk - it's empty again
                [emptyChunks addObject:currChunk];
                [currChunk release];
                currChunk=NULL;
                [emptyChunkLock unlock];
                //Do Auto exposure
                if (autoGain) {
                    float wanted=0.45f;
                    float corridor=0.1f;
                    float error=[bayerConverter lastMeanBrightness]-wanted;
                    if (error>corridor) error-=corridor;
                    else if (error<-corridor) error+=corridor;
                    else error=0.0f;
                    if (error!=0.0f) {
                        float correction=0.0f;
                        if (error>0.0f) correction=-(error*error);
                        else correction=(error*error);
                        correction*=0.2f;
                        if (correction<-0.1f) correction=-0.1f;
                        if (correction> 0.1f) correction= 0.1f;
                        aeShutter+=correction;
                        aeShutter=CLAMP(aeShutter,0.0f,1.0f);
                    }
                }
            }
        }
    }
    while (grabbingThreadRunning) { usleep(10000); }	//Wait for grabbingThread finish
    //We need to sleep here because otherwise the compiler would optimize the loop away

    if (!err) err=grabbingError;			//Take error from grabbing thread
    [self shutdownGrabbing];
    return err;
}

//(internal) tool functions

- (void) decompressBuffer:(UInt8*)src {
    int i;
    UInt32* dst=(UInt32*)[decompressionBuffer mutableBytes];
    UInt32 bits=0;
    src+=4;		//Skip past header
    for (i=[self width]*[self height]/4;i>0;i--) {
        bits=src[0]+(src[1]<<8)+(src[2]<<16);
        src+=3;
        *(dst++)=((bits<<26)&0xfc000000)|((bits<<12)&0x00fc0000)|((bits>>2)&0x0000fc00)|((bits>>16)&0x000000fc);
    }
}

//Chunk buffer queues management

- (NSMutableData*) getEmptyChunkBuffer {
    NSMutableData* buf;
    if ([emptyChunks count]>0) {						//We have a recyclable buffer
        [emptyChunkLock lock];
        buf=[emptyChunks lastObject];
        [buf retain];
        [emptyChunks removeLastObject];
        [emptyChunkLock unlock];
    } else {									//We need to allocate a new one
        buf=[[NSMutableData alloc] initWithCapacity:grabBufferSize+1000];	//Some safety...
    }
    return buf;
}

- (void) disposeChunkBuffer:(NSMutableData*)buf {
    if (buf) {
        [emptyChunkLock lock];
        [emptyChunks addObject:buf];
        [buf release];
        [emptyChunkLock unlock];
    }
}

- (void) passChunkBufferToFullOnes:(NSMutableData*)buf {
    if ([fullChunks count]>QCPROBEIGE_NUM_CHUNKS) {	//the full chunk list is already full - discard the oldest
        [self disposeChunkBuffer:[self getOldestFullChunkBuffer]];
    }
    [fullChunkLock lock];			//Append our full chunk to the list
    [fullChunks addObject:fillingChunk];
    [buf release];
    [fullChunkLock unlock];
    [chunkReadyLock tryLock];			//New chunk is there. Try to wake up the decoder
    [chunkReadyLock unlock];
}

- (NSMutableData*) getOldestFullChunkBuffer {
    NSMutableData* buf;
    [fullChunkLock lock];					//Take the oldest chunk to decode
    buf=[fullChunks objectAtIndex:0];
    [buf retain];
    [fullChunks removeObjectAtIndex:0];
    [fullChunkLock unlock];
    return buf;
}

//Camera internal functions

- (CameraError) startup {
    UInt8* buf;
    long i;
    CameraError err=CameraErrorOK;

    //Init sequence - analogous to the Windows init
    MALLOC(buf,UInt8*,0x20000,"QCProBeige startupGrabbing transfer buffer");

    if (!err) err=[self writeCameraRegister:0x000f to:0x78 len:1];
    if (!err) err=[self writeCameraRegister:0x000a to:0x00 len:1];
    if (!err) err=[self writeCameraRegister:0x000f to:0x58 len:1];
    if (!err) err=[self writeCameraRegister:0x000f to:0x18 len:1];
    if (!err) err=[self  readCameraRegister:0x058f toBuffer:buf len:0x40];
    if (!err) err=[self  readCameraRegister:0x0580 toBuffer:buf len:0x40];
    if (!err) err=[self writeCameraRegister:0x0008 to:0x0e len:1];
    if (!err) err=[self writeCameraRegister:0x0006 to:0x0f len:1];
    if (!err) err=[self writeCameraRegister:0x0009 to:0x86 len:1];
    if (!err) err=[self writeCameraRegister:0x0007 to:0xaf len:1];

    buf[ 0]=0x58; buf[ 1]=0xd8; buf[ 2]=0x58; buf[ 3]=0xd8; buf[ 4]=0x59; buf[ 5]=0xd9;
    buf[ 6]=0x58; buf[ 7]=0xd8; buf[ 8]=0x58; buf[ 9]=0xd8; buf[10]=0x58; buf[11]=0xd8;
    buf[12]=0x58; buf[13]=0xd8; buf[14]=0x58; buf[15]=0xd8; buf[16]=0x58; buf[17]=0xd8;
    buf[18]=0x58; buf[19]=0xd8; buf[20]=0x5c;

    if (!err) err=[self writeCameraRegister:0x000f fromBuffer:buf len:0x15];
    if (!err) err=[self writeCameraRegister:0x0002 to:0x7f81 len:2];
    if (!err) err=[self writeCameraRegister:0x000a to:0x00 len:1];
    if (!err) err=[self writeCameraRegister:0x000e to:0x00 len:1];

    for (i=0;i<0x20000;i+=2) {
        buf[i]=i/0x0800;
        buf[i+1]=0xc0;
    }
    
    if (!err) err=[self writeCameraRegister:0x000d fromBuffer:buf len:0x20000];
    if (!err) err=[self writeCameraRegister:0x000e to:0x00 len:1];
    if (!err) err=[self  readCameraRegister:0x058d toBuffer:buf len:0x20000];
    if (!err) err=[self writeCameraRegister:0x000e to:0x01 len:1];

    if (!err) err=[self writeCameraRegister:0x000a to:0x00 len:1];
    if (!err) err=[self writeCameraRegister:0x000f to:0x78 len:1];
    if (!err) err=[self writeCameraRegister:0x000a to:0x00 len:1];
    if (!err) err=[self writeCameraRegister:0x000f to:0x58 len:1];
    buf[ 0]=0x58; buf[ 1]=0xd8; buf[ 2]=0x58; buf[ 3]=0xd8; buf[ 4]=0x59; buf[ 5]=0xd9;
    buf[ 6]=0x58; buf[ 7]=0xd8; buf[ 8]=0x58; buf[ 9]=0xd8; buf[10]=0x58; buf[11]=0xd8;
    buf[12]=0x58; buf[13]=0xd8; buf[14]=0x58; buf[15]=0xd8; buf[16]=0x58; buf[17]=0xd8;
    buf[18]=0x58; buf[19]=0xd8; buf[20]=0x5c;
    if (!err) err=[self writeCameraRegister:0x000f fromBuffer:buf len:0x15];		//set brightness
    if (!err) err=[self writeCameraRegister:0x0004 to:0x7100 len:2];			//set exposure
    if (!err) err=[self writeCameraRegister:0x000a to:0x11 len:1];
    if (!err) err=[self writeCameraRegister:0x000a to:0x11 len:1];
    
    if (!err) err=[self writeCameraRegister:0x0008 to:0x02 len:1];			//set window start y
    if (!err) err=[self writeCameraRegister:0x0006 to:0x03 len:1];			//set window start x
    if (!err) err=[self writeCameraRegister:0x0009 to:0x7a len:1];			//set window stop y
    if (!err) err=[self writeCameraRegister:0x0007 to:0xa3 len:1];			//set window stop x
    if (resolution==ResolutionSIF) {
        if (!err) err=[self writeCameraRegister:0x000a to:0x11 len:1];			//set subsampling
    } else {
        if (!err) err=[self writeCameraRegister:0x000a to:0x15 len:1];			//set subsampling
    }
    if (!err) err=[self  readCameraRegister:0x058e toBuffer:buf len:0x40];
    if (!err) err=[self writeCameraRegister:0x000d to:0x00 len:1];
    
    if (buf) FREE(buf,"QCProBeige startupGrabbing transfer buffer");
    return err;
}

- (BOOL) resetUSS720 {
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBOut, kUSBClass, kUSBOther)
                               bRequest:0x02
                                 wValue:0x0000
                                 wIndex:0x0000
                                    buf:NULL
                                    len:0];
}

- (CameraError) writeCameraRegister:(UInt16)reg to:(UInt32)val len:(long)len {
    return [self writeCameraRegister:reg fromBuffer:((UInt8*)(&val))+(sizeof(UInt32)-len) len:len];
}

- (CameraError) writeCameraRegister:(UInt16)reg fromBuffer:(UInt8*)buf len:(long)len {
    BOOL ok=YES;
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x07f8 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x020c wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0010 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0206 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0207 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0204 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0206 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:reg    wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0207 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0206 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self resetUSS720];
    if ((ok)&&(len>0)) {
        IOReturn ret=(*intf)->WritePipe(intf, 1, buf, len);
        CheckError(ret,"MyQCProBeigeDriver:writeCameraRegister");
        ok=(ret)?NO:YES;
    }
    return (ok)?CameraErrorOK:CameraErrorUSBProblem;
}

- (CameraError) readCameraRegister:(UInt16)reg toBuffer:(UInt8*)retBuf len:(long)len {
    BOOL ok=YES;
    UInt8 buf[7];
    ok=ok&&[self resetUSS720];
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0100 wIndex:0x0000 buf:buf len:7]; //<-- 0a 4c a3 f9 00 00
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x07f8 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0100 wIndex:0x0000 buf:buf len:7]; //<-- 0a 4c 03 f8 00 00
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x07f8 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02cc wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0010 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02c6 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0100 wIndex:0x0000 buf:buf len:7]; //<-- ba c6 03 f8 10 00
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02c7 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02c4 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0100 wIndex:0x0000 buf:buf len:7]; //<-- da c4 03 f8 10 00
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02c6 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0100 wIndex:0x0000 buf:buf len:7]; //<-- fa c6 03 f8 10 00
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0000 wIndex:0x0000 buf:buf len:7]; //<-- fa c6 03 f8 10 00
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0663 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02c4 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:reg wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self resetUSS720];
    if (ok) {
        UInt32 actLen=len;
        IOReturn ret=((IOUSBInterfaceInterface182*)(*intf))->ReadPipeTO(intf, 2, retBuf, &actLen, 2000, 3000);
        CheckError(ret,"MyQCProBeigeDriver:writeCameraRegister");
        ok=(ret)?NO:YES;
    }
    ok=ok&&[self resetUSS720];
    return (ok)?CameraErrorOK:CameraErrorUSBProblem;
}    

@end		


@implementation MyQCVCDriver

+ (NSArray*) cameraUsbDescriptions 
{
	NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_VC],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_CONNECTIX],@"idVendor",
        @"Logitech QuickCam VC",@"name",NULL];
	
    return [NSArray arrayWithObjects:dict1,NULL];
}

- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId 
{
	CameraError err = [super startupWithUsbLocationId:usbLocationId];
    if (err != CameraErrorOK) 
		return err;
	
	rotate = YES;
	
	return CameraErrorOK;
}

@end
