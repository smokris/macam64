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

#import "MySTV680Driver.h"
#import "MyCameraCentral.h"
#include "Resolvers.h"
#include "MiscTools.h"
#include "unistd.h"

#define PRODUCT_STV680 0x202
#define VENDOR_STM 0x553

@implementation MySTV680Driver

+ (unsigned short) cameraUsbProductID { return PRODUCT_STV680; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_STM; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"STV680-based camera"]; }

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
    UInt8 cameraInfoBuffer[16];
    err=[self usbConnectToCam:usbLocationId configIdx:0];
    //setup connection to camera
    if (err!=CameraErrorOK) return err;
    //wake up camera
    [self usbWriteCmdWithBRequest:SET_CAMERA_IDLE wValue:0 wIndex:0 buf:NULL len:0];

    [self usbReadCmdWithBRequest:GET_CAMERA_INFO wValue:0 wIndex:0 buf:cameraInfoBuffer len:16];
    resolutionBits=cameraInfoBuffer[7];
    [self setBrightness:0.5];
    [self setContrast:0.5];
    [self setGamma:0.5];
    [self setSaturation:0.5];
    [self setSharpness:0.5];

    return [super startupWithUsbLocationId:usbLocationId];
}

- (BOOL) canSetBrightness { return YES; }

- (void) setBrightness:(float)v {
    [super setBrightness:v];
    [bayerConverter setBrightness:[self brightness]-0.5f];
}

- (BOOL) canSetContrast { return YES; }

- (void) setContrast:(float)v {
    [super setContrast:v];
    [bayerConverter setContrast:[self contrast]+0.5f];
}

- (BOOL) canSetGamma { return YES; }

- (void) setGamma:(float)v {
    [super setGamma:v];
    [bayerConverter setGamma:[self gamma]+0.5f];
}

- (BOOL) canSetSaturation { return YES; }

- (void) setSaturation:(float)v {
    [super setSaturation:v];
    [bayerConverter setSaturation:[self saturation]*2.0f];
}

- (BOOL) canSetSharpness {
    return YES;
}

- (void) setSharpness:(float)v {
    [super setSharpness:v];
    [bayerConverter setSharpness:[self sharpness]];
}

- (BOOL) canSetHFlip {
    return YES;
}

- (BOOL) supportsResolution:(CameraResolution)res fps:(short)rate {
    switch (res) {
        case ResolutionCIF:
            if (rate>10) return NO;
            return (resolutionBits&0x01)?YES:NO;
            break;
        case ResolutionVGA:
            if (rate>5) return NO;
            return (resolutionBits&0x02)?YES:NO;
            break;
        case ResolutionQCIF:
            if (rate>15) return NO;
            return (resolutionBits&0x04)?YES:NO;
            break;
        case ResolutionSIF:
            if (rate>15) return NO;
            return (resolutionBits&0x08)?YES:NO;
            break;
        default: return NO;
    }
}
- (CameraResolution) defaultResolutionAndRate:(short*)rate {
    if (rate) *rate=5;
    if (resolutionBits&0x08) return ResolutionSIF;
    else if (resolutionBits&0x02) return ResolutionVGA;
    else if (resolutionBits&0x01) return ResolutionCIF;
    else if (resolutionBits&0x04) return ResolutionQCIF;
    else {
#ifdef VERBOSE
        NSLog(@"defaultResolutionAndRate: No resolution supported!");
#endif
        return 0;
    }
}

- (BOOL) canSetWhiteBalanceMode { return YES; }

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode {
    BOOL ok=YES;
    switch (newMode) {
        case WhiteBalanceLinear:
        case WhiteBalanceIndoor:
        case WhiteBalanceOutdoor:
        case WhiteBalanceAutomatic:
            break;
        default:
            ok=NO;
            break;
    }
    return ok;
}

- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode {
    [super setWhiteBalanceMode:newMode];
    switch (whiteBalanceMode) {
        case WhiteBalanceLinear:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:1.0f green:1.0f blue:1.0f];
            break;
        case WhiteBalanceIndoor:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:0.8f green:0.97f blue:1.25f];
            break;
        case WhiteBalanceOutdoor:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:1.1f green:0.95f blue:0.95f];
            break;
        case WhiteBalanceAutomatic:
            [bayerConverter setGainsDynamic:YES];
            break;
        case WhiteBalanceManual:
            // not handled yet
            break;
    }
}

- (CameraError) startupGrabbing {
    UInt16 val=0x0000;
    UInt8 buf[16];
    UInt8 originalPhotoResolution;
    CameraError ret=CameraErrorOK;
    [self deleteAll];//Erase images. They are lost anyway and doing so, we get correct stream info
    videoBulkReadsPending=0;
    emptyChunks=NULL;
    fullChunks=NULL;
    emptyChunkLock=NULL;
    fullChunkLock=NULL;
    emptyChunks=[[NSMutableArray alloc] initWithCapacity:STV680_NUM_CHUNKS];
    if (!emptyChunks) return CameraErrorNoMem;
    fullChunks=[[NSMutableArray alloc] initWithCapacity:STV680_NUM_CHUNKS];
    if (!fullChunks) return CameraErrorNoMem;
    emptyChunkLock=[[NSLock alloc] init];
    if (!emptyChunkLock) return CameraErrorNoMem;
    fullChunkLock=[[NSLock alloc] init];
    if (!fullChunkLock) return CameraErrorNoMem;

    if (![self usbSetAltInterfaceTo:1 testPipe:1]) return CameraErrorNoBandwidth;

/*I don't know how to find out the settings of the video stream directly. So this is the workaround: I set the camera photo mode to be identical with the video stream. Then I read out the settings of the photos and set back the photo mode. The streaming mode is set separately.*/

//Remember the current photo resolution
    if (![self usbReadCmdWithBRequest:GET_CAMERA_MODE wValue:0 wIndex:0 buf:buf len:8]) {
#ifdef VERBOSE
        NSLog(@"STV680:startupGrabbing: Remember current camera resolution failed");
#endif
        ret=CameraErrorUSBProblem;
    }

    originalPhotoResolution=buf[0];
    memset(buf,0,8);

//Set the photo resolution to the desired grab resolution
    switch (resolution) {
        case ResolutionCIF:  buf[0]=0x00; val=0x0000; break;
        case ResolutionVGA:  buf[0]=0x01; val=0x0100; break;
        case ResolutionQCIF: buf[0]=0x02; val=0x0200; break;
        case ResolutionSIF:  buf[0]=0x03; val=0x0300; break;
        default:
#ifdef VERBOSE
            NSLog(@"startupGrabbing: Invalid resolution!");
#endif
            ret=CameraErrorUSBProblem;
            break;
    }
    if (!ret) {
        if (![self usbWriteCmdWithBRequest:SET_CAMERA_MODE wValue:0x0100 wIndex:0 buf:buf len:8]) {
#ifdef VERBOSE
            NSLog(@"STV680:startupGrabbing:Set test resolution failed");
#endif
            ret=CameraErrorUSBProblem;
        }
    }
//Read out image size
    if (!ret) {
        if (![self usbReadCmdWithBRequest:GET_PICTURE_HEADER wValue:0 wIndex:0 buf:buf len:16]) {
#ifdef VERBOSE
            NSLog(@"STV680:startupGrabbing: Get picture header failed");
#endif
            ret=CameraErrorUSBProblem;
        }
    }
    
//Find our values
    grabWidth = buf[4] *256 + buf[5];
    grabHeight = buf[6] *256 + buf[7];
    grabBufferSize = (buf[0]<<24)+(buf[1]<<16)+(buf[2]<<8)+buf[3];

//Set back the resolution
    memset(buf,0,8);
    buf[0]=originalPhotoResolution;

    if (!ret) {
        if (![self usbWriteCmdWithBRequest:SET_CAMERA_MODE wValue:0x0100 wIndex:0 buf:buf len:8]) {
#ifdef VERBOSE
            NSLog(@"STV680:startupGrabbing:Set back camera resolution failed");
#endif
            if (!ret) ret=CameraErrorUSBProblem;
        }
    }

//Initiate grabbing in our resolution
    if (!ret) {
        if (![self usbWriteCmdWithBRequest:SET_STREAMING_MODE wValue:val wIndex:0 buf:NULL len:0]) {
#ifdef VERBOSE
            NSLog(@"STV680:startupGrabbing:Set Streaming Mode failed");
#endif
            ret=CameraErrorUSBProblem;
        }
    }

//Initialize bayer decoder
    if (!ret) {
        [bayerConverter setSourceWidth:grabWidth height:grabHeight];
        [bayerConverter setDestinationWidth:[self width] height:[self height]];
    }
    return ret;
}

- (void) shutdownGrabbing {

//Stop grabbing action
    [self usbWriteCmdWithBRequest:SET_CAMERA_IDLE wValue:0 wIndex:0 buf:NULL len:0];

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

    [self usbSetAltInterfaceTo:0 testPipe:0];
}

/*Structure of a grab buffer: An unsigned long containing the offset to image data (including this long) followed by the raw bulk data from the camera*/


static void handleFullChunk(void *refcon, IOReturn result, void *arg0) {
    MySTV680Driver* driver=(MySTV680Driver*)refcon;
    long size=((long)arg0);
    [driver handleFullChunkWithReadBytes:size error:result];
}

- (void) handleFullChunkWithReadBytes:(UInt32)readSize error:(IOReturn)err  {
    NSMutableData* tmpChunk;
    videoBulkReadsPending--;
    if (readSize>grabBufferSize) {	//Oversized data: ignore header sent to us
        *((unsigned long*)[fillingChunk mutableBytes])=sizeof(unsigned long)+readSize-grabBufferSize;
    } else {
        *((unsigned long*)[fillingChunk mutableBytes])=sizeof(unsigned long);
    }
    if (err) {
        if (!grabbingError) grabbingError=CameraErrorUSBProblem;
        shouldBeGrabbing=NO;
    }
    if (shouldBeGrabbing) {				//no usb error.
        if ([fullChunks count]>STV680_NUM_CHUNKS) {	//the full chunk list is already full - discard the oldest
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
    } else {				//Incorrect chunk -> ignore (but back to empty chunks)
        [emptyChunkLock lock];
        [emptyChunks addObject:fillingChunk];
        [fillingChunk release];
        fillingChunk=NULL;			//to be sure...
        [emptyChunkLock unlock];
    }
    if (shouldBeGrabbing) [self fillNextChunk];

//We can only stop if there's no read request left. If there is an error, no new one was issued
    if (videoBulkReadsPending<=0) CFRunLoopStop(CFRunLoopGetCurrent());

}

- (void) fillNextChunk {
    IOReturn err;
//Get an empty chunk
    if (shouldBeGrabbing) {
        if ([emptyChunks count]>0) {	//We have a recyclable buffer
            [emptyChunkLock lock];
            fillingChunk=[emptyChunks lastObject];
            [fillingChunk retain];
            [emptyChunks removeLastObject];
            [emptyChunkLock unlock];
        } else {			//We need to allocate a new one
            fillingChunk=[[NSMutableData alloc] initWithCapacity:grabBufferSize+STV680_CHUNK_SPARE];
            if (!fillingChunk) {
                if (!grabbingError) grabbingError=CameraErrorNoMem;
                shouldBeGrabbing=NO;
            }
        }
    }
//start the bulk read
    if (shouldBeGrabbing) {
        err=(*streamIntf)->ReadPipeAsync(streamIntf,1,
                                     [fillingChunk mutableBytes]+sizeof(unsigned long),
                                     grabBufferSize+STV680_CHUNK_SPARE-sizeof(unsigned long),
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
        err = (*streamIntf)->CreateInterfaceAsyncEventSource(streamIntf, &cfSource);	//Create an event source
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
    [pool release];
    grabbingThreadRunning=NO;
    [NSThread exit];
}

- (CameraError) decodingThread {
    CameraError err=CameraErrorOK;
    NSMutableData* currChunk;
    unsigned char* imgData;
    long imgWidth,imgHeight;
    BOOL bufferSet;
    grabbingThreadRunning=NO;

    err=[self startupGrabbing];

    if (err) shouldBeGrabbing=NO;
    
    if (shouldBeGrabbing) {
        grabbingError=CameraErrorOK;
        grabbingThreadRunning=YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];    //start grabbingThread
    }

    if (shouldBeGrabbing) {
        imgWidth=[self width];				//Should remain constant during grab
        imgHeight=[self height];				//Should remain constant during grab
    }
    
    while (shouldBeGrabbing) {
        if ([fullChunks count] == 0) 
            usleep(1000); // 1 ms (1000 micro-seconds)

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
                imgData+=*((unsigned long*)(imgData));	//Shift to start of image data
                [bayerConverter convertFromSrc:imgData
                                        toDest:lastImageBuffer
                                   srcRowBytes:grabWidth
                                   dstRowBytes:lastImageBufferRowBytes
                                        dstBPP:lastImageBufferBPP
                                          flip:hFlip
									 rotate180:NO];
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
        }
    }
    while (grabbingThreadRunning) { usleep(10000); }	//Wait for grabbingThread finish
    //We need to sleep here because otherwise the compiler would optimize the loop away
    if (!err) err=grabbingError;	//Take error from grabbing thread
    [self shutdownGrabbing];
    return err;
}

- (BOOL) canStoreMedia {
    return YES;
}

- (long) numberOfStoredMediaObjects {
    UInt8 buf[8];
    long num;
    [stateLock lock];
    if (isGrabbing) num=0;
    else {
        [self usbReadCmdWithBRequest:GET_PICTURE_COUNT wValue:0 wIndex:0 buf:buf len:8];
        num=buf[3];
    }
    [stateLock unlock];
    return num;
}

- (NSDictionary*) getStoredMediaObject:(long)idx {
    UInt8 buf[16];
    long rawWidth=1;
    long rawHeight=1;
    long rawBufferSize=1;
    CameraResolution dstRes=ResolutionQCIF;
    NSMutableData* rawBuffer=NULL;
    NSBitmapImageRep* imageRep=NULL;
    BOOL ok=YES;
    IOReturn err;
    UInt32 bulkSize;

    [stateLock lock];	//We don't want to be interrupted with grabbing or other stuff
    if (isGrabbing) ok=NO;
//Get picture properties
    if (ok) {
        [self usbReadCmdWithBRequest:GET_PICTURE_HEADER wValue:idx wIndex:0 buf:buf len:16];
        rawWidth = buf[4] *256 + buf[5];
        rawHeight = buf[6] *256 + buf[7];
        rawBufferSize = (buf[0]<<24)+(buf[1]<<16)+(buf[2]<<8)+buf[3];
    }
//Allocate raw buffer
    if (ok) {
        rawBuffer=[[NSMutableData alloc] initWithCapacity:rawBufferSize+STV680_CHUNK_SPARE];
        if (!rawBuffer) ok=NO;
    }
//Init camera to download image
    if (ok) {
        [self usbReadCmdWithBRequest:DOWNLOAD_PICTURE wValue:idx wIndex:0 buf:buf len:16];
        ok=[self usbSetAltInterfaceTo:1 testPipe:1];
    }
//Read image data
    if (ok) {
        bulkSize=rawBufferSize+STV680_CHUNK_SPARE;
        err=(*streamIntf)->ReadPipe(streamIntf,1, [rawBuffer mutableBytes], &bulkSize);	//Read one chunk
        CheckError(err,"getStoredMediaObject-ReadBulkPipe");
        if (err) ok=NO;
    }
    //Reset camera - no matter if an error occurred
    [self usbWriteCmdWithBRequest:SET_CAMERA_IDLE wValue:0 wIndex:0 buf:NULL len:0];
    [self usbSetAltInterfaceTo:0 testPipe:0];
//find resolution and allocate destination bitmap
    if (ok) {
        if      (rawWidth>=WidthOfResolution(ResolutionVGA)) dstRes=ResolutionVGA;
        else if (rawWidth>=WidthOfResolution(ResolutionCIF)) dstRes=ResolutionCIF;
        else if (rawWidth>=WidthOfResolution(ResolutionSIF)) dstRes=ResolutionSIF;
        else dstRes=ResolutionQCIF;
        imageRep=[[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL	//Set up just to avoid a NIL imageRep
                                                          pixelsWide:WidthOfResolution(dstRes)
                                                          pixelsHigh:HeightOfResolution(dstRes)
                                                       bitsPerSample:8
                                                     samplesPerPixel:3
                                                            hasAlpha:NO
                                                            isPlanar:NO
                                                      colorSpaceName:NSCalibratedRGBColorSpace
                                                         bytesPerRow:0
                                                        bitsPerPixel:0] autorelease];
        if (!imageRep) ok=NO;
    }
//Decode image
    if (ok) {
        [bayerConverter setSourceWidth:rawWidth height:rawHeight];
        [bayerConverter setDestinationWidth:WidthOfResolution(dstRes) height:HeightOfResolution(dstRes)];
        ok=[bayerConverter convertFromSrc:[rawBuffer mutableBytes]
                                   toDest:[imageRep bitmapData]
                              srcRowBytes:rawWidth
                              dstRowBytes:[imageRep bytesPerRow]
                                   dstBPP:[imageRep bitsPerPixel]/8
                                     flip:NO
								rotate180:NO];
    }
//Cleanup
    if (rawBuffer) [rawBuffer release]; rawBuffer=NULL;
    if ((imageRep)&&(!ok)) { [imageRep release]; imageRep=NULL; }
    [stateLock unlock];
    return [NSDictionary dictionaryWithObjectsAndKeys:
        imageRep,@"data",@"bitmap",@"type",NULL];
}

- (BOOL) canDeleteAll {
    return YES;
}

- (CameraError) deleteAll {
/* I don't know how to do this directly - so the approach is to setup streaming and stop immediately. This will also erase all stored images. */
    UInt16 val=0;
    CameraError err=CameraErrorOK;
    switch (resolution) {
        case ResolutionCIF:  val=0x0000; break;
        case ResolutionVGA:  val=0x0100; break;
        case ResolutionQCIF: val=0x0200; break;
        case ResolutionSIF:  val=0x0300; break;
        default:
#ifdef VERBOSE
            NSLog(@"deleteAll: Invalid resolution!");
#endif
            err=CameraErrorInternal;
            break;
    }
    if (err==CameraErrorOK) {
        if (![self usbWriteCmdWithBRequest:SET_STREAMING_MODE wValue:val wIndex:0 buf:NULL len:0]) {
            err=CameraErrorUSBProblem;
        }
        if (![self usbWriteCmdWithBRequest:SET_CAMERA_IDLE wValue:0 wIndex:0 buf:NULL len:0]) {
            err=CameraErrorUSBProblem;
        }
    }
    return err;
}



@end	
