/*
 macam - webcam app and QuickTime driver component
 Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

 Some parts were inspired by Jeroen B. Vreeken's SE401 Linux driver (although no code was copied) 
 
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

#import "MySE401Driver.h"
#import "MyCameraCentral.h"
#include "Resolvers.h"
#include "MiscTools.h"
#include "unistd.h"	//usleep

#define VENDOR_PHILIPS 0x0471
#define PRODUCT_VESTA_FUN 0x030b

#define VENDOR_ENDPOINTS 0x03e8
#define PRODUCT_SE401 0x0004

#define VENDOR_KENSINGTON 0x047d
#define PRODUCT_VIDEOCAM_67014 0x5001
#define PRODUCT_VIDEOCAM_67015 0x5002
#define PRODUCT_VIDEOCAM_67016 0x5003

/* se401 registers */
#define SE401_OPERATINGMODE	0x2000


@interface MySE401Driver (Private)

- (void) doAutoExposure;
- (void) doAutoResetLevel;
- (CameraError) adjustSensorSensitivityWithForce:(BOOL)force;	//Without force, it's only updated if something changes
- (CameraError) setExternalRegister:(UInt16)sel to:(UInt16)val;
- (UInt8) readExternalRegister:(UInt16)sel;
- (CameraError) setInternalRegister:(UInt16)sel to:(UInt16)val;
- (UInt16) readInternalRegister:(UInt16)sel;
    
@end
@implementation MySE401Driver

+ (NSArray*) cameraUsbDescriptions {
    NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_KENSINGTON],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_VIDEOCAM_67014],@"idProduct",
        @"Kensington VideoCAM 67014",@"name",NULL];
    NSDictionary* dict2=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_KENSINGTON],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_VIDEOCAM_67015],@"idProduct",
        @"Kensington VideoCAM 67015/67017",@"name",NULL];
    NSDictionary* dict3=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_KENSINGTON],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_VIDEOCAM_67016],@"idProduct",
        @"Kensington VideoCAM 67016",@"name",NULL];
    NSDictionary* dict4=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_VESTA_FUN],@"idProduct",
        @"Philips Vesta Fun (PCVC665K)",@"name",NULL];
    NSDictionary* dict5=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_ENDPOINTS],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_SE401],@"idProduct",
        @"Endpoints SE401-based camera",@"name",NULL];
    return [NSArray arrayWithObjects:dict1,dict2,dict3,dict4,dict5,NULL];
}
- (id) initWithCentral:(id)c {
    self=[super initWithCentral:c];
    if (!self) return NULL;
    bayerConverter=[[BayerConverter alloc] init];
    if (!bayerConverter) return NULL;
    [bayerConverter setSourceFormat:2];
    return self;
}

- (void) dealloc {
    if (bayerConverter) [bayerConverter release]; bayerConverter=NULL;
    [super dealloc];
}

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err;
    UInt8 buf[64];
    int numSizes;
    int i;
    int width,height;

    //setup connection to camera
    err=[self usbConnectToCam:usbDeviceRef];
    if (err!=CameraErrorOK) return err;

    //Do the camera startup sequence
    [self setInternalRegister:0x5f to:1];					//Switch LED on
    [self usbReadCmdWithBRequest:0x06 wValue:0 wIndex:0 buf:buf len:64];	//Get camera description
    DumpMem(buf,64);
    if (buf[1]!=0x41) {
        NSLog(@"SE401-Camera sent wrong description.");
        return CameraErrorUSBProblem;
    }
    numSizes=buf[4]+buf[5]*256;
    for (i=0; i<numSizes; i++) {
        width =buf[6+i*4+0]+buf[6+i*4+1]*256;
        height=buf[6+i*4+2]+buf[6+i*4+3]*256;
        NSLog(@"Resolution %i: %i * %i",i,width,height);
    }
    [self setInternalRegister:0x56 to:0];					//Switch camera power off
    [self setInternalRegister:0x57 to:0];					//Switch LED off
    
    //set some defaults
    [self setBrightness:0.5];
    [self setContrast:0.5];
    [self setGamma:0.5];
    [self setSaturation:0.5];
    [self setSharpness:0.5];
    [self setGain:0.5];
    [self setShutter:0.1];
    aeGain=0.5f;
    aeShutter=0.1f;
    lastExposure=-1;
    lastRedGain=-1;
    lastGreenGain=-1;
    lastBlueGain=-1;
    lastResetLevel=-1;
    resetLevel=32;

    //Do the ramining, usual connection stuff
    err=[super startupWithUsbDeviceRef:usbDeviceRef];
    if (err!=CameraErrorOK) return err;

    return err;
}


- (BOOL) supportsResolution:(CameraResolution)res fps:(short)rate {
    return YES;
}

- (CameraResolution) defaultResolutionAndRate:(short*)rate {
    if (rate) *rate=5;
    return ResolutionVGA;
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

- (void) setGain:(float)v {
    [super setGain:v];
    [self adjustSensorSensitivityWithForce:NO];
}

- (BOOL) canSetShutter {
    return YES;
}

- (void) setShutter:(float)v {
    [super setShutter:v];
    [self adjustSensorSensitivityWithForce:NO];
}

- (BOOL) canSetHFlip {
    return YES;
}

- (CameraError) startupGrabbing {
    CameraError err=CameraErrorOK;
    int mode=0x03;	//Mode: 0x03=raw, 0x40=JangGu compr. (2x2 subsample), 0x42=JangGu compr. (4x4 subsample)

    //Set needed variables, calculate values
    videoBulkReadsPending=0;
    grabBufferSize=([self width]*[self height]+4096)&0xfffff000;
    resetLevelFrameCounter=0;
    //Allocate memory, locks
    emptyChunks=NULL;
    fullChunks=NULL;
    emptyChunkLock=NULL;
    fullChunkLock=NULL;
    chunkReadyLock=NULL;
    emptyChunks=[[NSMutableArray alloc] initWithCapacity:SE401_NUM_CHUNKS];
    if (!emptyChunks) return CameraErrorNoMem;
    fullChunks=[[NSMutableArray alloc] initWithCapacity:SE401_NUM_CHUNKS];
    if (!fullChunks) return CameraErrorNoMem;
    emptyChunkLock=[[NSLock alloc] init];
    if (!emptyChunkLock) return CameraErrorNoMem;
    fullChunkLock=[[NSLock alloc] init];
    if (!fullChunkLock) return CameraErrorNoMem;
    chunkReadyLock=[[NSLock alloc] init];
    if (!chunkReadyLock) return CameraErrorNoMem;
    [chunkReadyLock tryLock];								//Should be locked by default

    //Initialize bayer decoder
    if (!err) {
        [bayerConverter setSourceWidth:[self width] height:[self height]];
        [bayerConverter setDestinationWidth:[self width] height:[self height]];
    }

    //Startup camera
    if (!err) err=[self setInternalRegister:0x56 to:1];					//Switch power on
    if (!err) err=[self setInternalRegister:0x57 to:1];					//Switch LED on
    if (!err) err=[self setExternalRegister:0x01 to:0x05];				//Set win+pix intg.
    if (!err) err=[self adjustSensorSensitivityWithForce:YES];				//Set exposure, gain etc.
    if (!err) err=[self setInternalRegister:0x4d to:[self width]];			//Set width
    if (!err) err=[self setInternalRegister:0x4f to:[self height]];			//Set height
    if (!err) err=[self setExternalRegister:SE401_OPERATINGMODE to:mode];		//Set data mode
    if (!err) err=[self setInternalRegister:0x41 to:0];					//Start cont. capture

    return err;
}

- (void) shutdownGrabbing {

    //Stop grabbing action
    [self setInternalRegister:0x42 to:0];						//Stop cont. capture
    [self setInternalRegister:0x57 to:0];						//Switch LED off
    [self setInternalRegister:0x56 to:0];						//Switch power off

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

}

/*Structure of a grab buffer: An unsigned long containing the offset to image data (including this long) followed by the raw bulk data from the camera*/


static void handleFullChunk(void *refcon, IOReturn result, void *arg0) {
    MySE401Driver* driver=(MySE401Driver*)refcon;
    long size=((long)arg0);
    [driver handleFullChunkWithReadBytes:size error:result];
}

- (void) handleFullChunkWithReadBytes:(UInt32)readSize error:(IOReturn)err  {
    NSMutableData* tmpChunk;
    videoBulkReadsPending--;
    if (err) {
        if (!grabbingError) grabbingError=CameraErrorUSBProblem;
        shouldBeGrabbing=NO;
    }
    if (shouldBeGrabbing) {				//no usb error.
        if ([fullChunks count]>SE401_NUM_CHUNKS) {	//the full chunk list is already full - discard the oldest
            [fullChunkLock lock];
            tmpChunk=[fullChunks objectAtIndex:0];
            [tmpChunk retain];
            [fullChunks removeObjectAtIndex:0];
            [fullChunkLock unlock];
            /*Note that the locking here is a bit stupid since we lock fullChunkLock twice when we have a buffer overflow. But this hopefully happens not too often and I don't want a sequence to require two locks at the same time since this could be likely to introduce deadlocks */
            [emptyChunkLock lock];
            [emptyChunks addObject:tmpChunk];
            [tmpChunk release];
            tmpChunk=NULL;		//to be sure...
            [emptyChunkLock unlock];
        }
        [fullChunkLock lock];		//Append our full chunk to the list
        [fullChunks addObject:fillingChunk];
        [fillingChunk release];
        fillingChunk=NULL;			//to be sure...
        [fullChunkLock unlock];
        [chunkReadyLock tryLock];	//New chunk is there. Try to wake up the decoder
        [chunkReadyLock unlock];
    } else {				//Incorrect chunk -> ignore (but back to empty chunks)
        [emptyChunkLock lock];
        [emptyChunks addObject:fillingChunk];
        [fillingChunk release];
        fillingChunk=NULL;			//to be sure...
        [emptyChunkLock unlock];
    }
    [self doAutoResetLevel];
    if (shouldBeGrabbing) [self fillNextChunk];
//We can only stop if there's no read request left. If there is an error, no new one was issued
    if (videoBulkReadsPending<=0) CFRunLoopStop(CFRunLoopGetCurrent());

}



- (void) fillNextChunk {
    IOReturn err;
    //Get an empty chunk
    if (shouldBeGrabbing) {
        if ([emptyChunks count]>0) {						//We have a recyclable buffer
            [emptyChunkLock lock];
            fillingChunk=[emptyChunks lastObject];
            [fillingChunk retain];
            [emptyChunks removeLastObject];
            [emptyChunkLock unlock];
        } else {								//We need to allocate a new one
            fillingChunk=[[NSMutableData alloc] initWithCapacity:grabBufferSize];
            if (!fillingChunk) {
                if (!grabbingError) grabbingError=CameraErrorNoMem;
                shouldBeGrabbing=NO;
            }
        }
    }
//start the bulk read
    if (shouldBeGrabbing) {
        err=((IOUSBInterfaceInterface182*)(*intf))->ReadPipeAsyncTO(intf,1,
                                     [fillingChunk mutableBytes],
                                     grabBufferSize,1000,2000,
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
    NSLog(@"grabbing thread exits");
    grabbingThreadRunning=NO;
    [NSThread exit];
}

- (CameraError) decodingThread {
    CameraError err=CameraErrorOK;
    NSMutableData* currChunk;
    unsigned char* imgData;
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
        width=[self width];				//Should remain constant during grab
        height=[self height];				//Should remain constant during grab
        while (shouldBeGrabbing) {
            [chunkReadyLock lock];				//wait for new chunks to arrive
            while ((shouldBeGrabbing)&&([fullChunks count]>0)) {	//decode all full chunks we have
                [fullChunkLock lock];			//Take the oldest chunk to decode
                currChunk=[fullChunks objectAtIndex:0];
                [currChunk retain];
                [fullChunks removeObjectAtIndex:0];
                [fullChunkLock unlock];
                [imageBufferLock lock];			//Get image data
                lastImageBuffer=nextImageBuffer;
                lastImageBufferBPP=nextImageBufferBPP;
                lastImageBufferRowBytes=nextImageBufferRowBytes;
                bufferSet=nextImageBufferSet;
                nextImageBufferSet=NO;
                if (bufferSet) {
                    imgData=[currChunk mutableBytes];
                    [bayerConverter convertFromSrc:imgData+width
                                            toDest:lastImageBuffer
                                       srcRowBytes:width
                                       dstRowBytes:lastImageBufferRowBytes
                                            dstBPP:lastImageBufferBPP
                                              flip:!hFlip];
                    [imageBufferLock unlock];
                    [self mergeImageReady];
                    if (autoGain) [self doAutoExposure];
                } else {
                    [imageBufferLock unlock];
                }
                [emptyChunkLock lock];			//recycle our chunk - it's empty again
                [emptyChunks addObject:currChunk];
                [currChunk release];
                currChunk=NULL;
                [emptyChunkLock unlock];
            }
        }
    }
    NSLog(@"waiting for grabbing thread exit");
    while (grabbingThreadRunning) { usleep(10000); }	//Wait for grabbingThread finish
    //We need to sleep here because otherwise the compiler would optimize the loop away
    if (!err) err=grabbingError;	//Take error from grabbing thread
    [self shutdownGrabbing];
    return err;
}

//Tool functions

- (void) doAutoExposure {
}

- (void) doAutoResetLevel {
    int lowCount=0;
    int highCount=0;
    NSLog(@"doAutoResetLevel");

    resetLevelFrameCounter++;
    if (resetLevelFrameCounter<2) return;
    resetLevelFrameCounter=0;

    //Read high/low pixel statistics
    lowCount +=[self readExternalRegister:0x57]*256;
    lowCount +=[self readExternalRegister:0x58];
    highCount+=[self readExternalRegister:0x59]*256;
    highCount+=[self readExternalRegister:0x5a];

    //see if we have to change the reset level
    if(lowCount>10) resetLevel++;
    if(highCount>20) resetLevel--;
    if (resetLevel<0) resetLevel=0;
    if (resetLevel>63) resetLevel=63;

    //Trigger second time to reset
    [self readExternalRegister:0x57];
    [self readExternalRegister:0x58];
    [self readExternalRegister:0x59];
    [self readExternalRegister:0x5a];

    NSLog(@"Low count: %i high count:%i level:%i",lowCount,highCount,resetLevel);
    //Commit changes
    [self adjustSensorSensitivityWithForce:NO];
}

- (CameraError) adjustSensorSensitivityWithForce:(BOOL)force {
    CameraError err=CameraErrorOK;
    SInt32 exposure=(autoGain?aeShutter:shutter)*((float)0xffffff);
    SInt16 redGain=63.0f-((autoGain?aeGain:gain)*33.0f);
    SInt16 greenGain=63.0f-((autoGain?aeGain:gain)*33.0f);
    SInt16 blueGain=63.0f-((autoGain?aeGain:gain)*33.0f);
    if (isGrabbing) {
        if (force||(exposure!=lastExposure)) {
            if (!err) err=[self setExternalRegister:0x25 to:((exposure>>16)&0xff)];		//Set exposure high
            if (!err) err=[self setExternalRegister:0x26 to:((exposure>>8)&0xff)];		//Set exposure mid
            if (!err) err=[self setExternalRegister:0x27 to:(exposure&0xff)];			//Set exposure low
            lastExposure=exposure;
        }
        if (force||(resetLevel!=lastResetLevel)) {
            if (!err) err=[self setExternalRegister:0x30 to:resetLevel];			//Set reset level
            lastResetLevel=resetLevel;
        }
        if (force||(redGain!=lastRedGain)) {
            if (!err) err=[self setExternalRegister:0x31 to:redGain];				//Set red gain
            lastRedGain=redGain;
        }
        if (force||(greenGain!=lastGreenGain)) {
            if (!err) err=[self setExternalRegister:0x32 to:greenGain];				//Set green gain
            lastGreenGain=greenGain;
        }
        if (force||(blueGain!=lastBlueGain)) {
            if (!err) err=[self setExternalRegister:0x33 to:blueGain];				//Set blue gain
            lastBlueGain=blueGain;
        }
    }
    return err;
}

- (CameraError) setExternalRegister:(UInt16)sel to:(UInt16)val {
    BOOL ok=[self usbWriteCmdWithBRequest:0x53 wValue:val wIndex:sel buf:NULL len:0];
    return (ok)?CameraErrorOK:CameraErrorUSBProblem;
}

- (UInt8) readExternalRegister:(UInt16)sel {
    UInt8 buf[2];
    BOOL ok=[self usbReadCmdWithBRequest:0x52 wValue:0 wIndex:sel buf:buf len:2];
    if (!ok) return 0;
    return buf[0]+256*buf[1];
}

- (CameraError) setInternalRegister:(UInt16)sel to:(UInt16)val {
    BOOL ok=[self usbWriteCmdWithBRequest:sel wValue:val wIndex:0 buf:NULL len:0];
    return (ok)?CameraErrorOK:CameraErrorUSBProblem;
}

- (UInt16) readInternalRegister:(UInt16)sel {
    UInt8 buf[2];
    BOOL ok=[self usbReadCmdWithBRequest:sel wValue:0 wIndex:0 buf:buf len:2];
    if (!ok) return 0;
    return buf[0]+256*buf[1];
}


@end	
