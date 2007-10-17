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


#import "MyBridge.h"
#include "MiscTools.h"
#import "MyCameraDriver.h"
#import "MyCameraCentral.h"
#import "RGB888Scaler.h"

@interface MyBridge (Private)

- (BOOL) privUpdateFormat;		//check format and update it (including grab world) if needed 
- (BOOL) privSetImageBuffer;		//update all if neccessary, ensure grab running, set image buffer to our temp buffer

@end

@implementation MyBridge

- (id) initWithCentral:(MyCameraCentral*)in_central cid:(unsigned long)in_cid {
    BOOL ok=YES;
    self=[super init];
//Set private attributes
    central=in_central;
    cid=in_cid;
    driver=NULL;
    scaler=NULL;
    
    clientBufferIdx=0;
    driverBufferIdx=0;
    clientImagePending=NO;

    driverStarted=NO;
    driverShuttingDown=NO;
    driverGrabRunning=NO;
    driverFormatChangePending=NO;

    stateLock=NULL;
    formatChangeLock=NULL;
    shutdownLock=NULL;

    wantedResolution=ResolutionSIF;		//Just to have a default
    wantedFps=5;				//Just to have a default
    wantedCompression=0;			//Just to have a default

    memset(grabBuffers,0,NUM_BRIDGE_GRAB_BUFFERS*sizeof(BridgeGrabBuffer));	//Clear grab buffer array
    
//Start things up
    if (!central) ok=NO;
    if (ok) [central retain];
    if (ok) {
        formatChangeLock=[[NSLock alloc] init];
        if (!formatChangeLock) ok=NO;
    }
    if (ok) {
        stateLock=[[NSLock alloc] init];
        if (!stateLock) ok=NO;
    }
    if (ok) {
        shutdownLock=[[NSLock alloc] init];
        if (!shutdownLock) ok=NO;
        else [shutdownLock lock];		//locked by default
    }
    if (ok) {
        scaler=[[RGB888Scaler alloc] init];
        if (!scaler) ok=NO;
    }
    if (!ok) {
        if (stateLock) { [stateLock release]; stateLock=NULL; }
        if (formatChangeLock) { [formatChangeLock release]; formatChangeLock=NULL; }
        if (central) { [central release]; central=NULL; }
        if (central) { [central release]; central=NULL; }
        if (scaler) { [scaler release]; scaler=NULL; }
        return NULL;
    }
    return self;
}

- (unsigned long) cid {
    return cid;
}

- (void) dealloc {
    short i;
    [stateLock lock];
    NSAssert(!driverFormatChangePending,@"Bridge trying to dealloc with a format change still pending. This is going to be fun...");
    if (formatChangeLock) { [formatChangeLock release]; formatChangeLock=NULL; }
    if (shutdownLock) { [shutdownLock release]; shutdownLock=NULL; }
    if (central) { [central release]; central=NULL; }
    if (scaler) { [scaler release]; scaler=NULL; }
    [stateLock unlock];
    if (stateLock) { [stateLock release]; stateLock=NULL; }
    for (i=0;i<NUM_BRIDGE_GRAB_BUFFERS;i++) {
        if (grabBuffers[i].data) FREE(grabBuffers[i].data,"MyBridge dealloc grab buffer");
        grabBuffers[i].resolution=0;
        grabBuffers[i].data=NULL;
    }
    [super dealloc];
}

- (BOOL) startup {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    BOOL ok=YES;
    NSAssert(!driver,@"Bridge: There's already a driver on startup!");
    [stateLock lock];				//mutex
    if (driverStarted) ok=NO;
    if (ok) {
        driverShuttingDown=NO;
        [central setDelegate:self];			//The delegate is propagated to new cameras
        [central useCameraWithID:cid to:&driver acceptDummy:YES];
        if (!driver) [central useDummyForError:CameraErrorNoCam];
        [central setDelegate:NULL];
        if (driver) [driver retain];
        else ok=NO;
    }
    if (ok) {
        wantedResolution=[driver resolution];
        wantedFps=[driver fps];
        wantedCompression=[driver compression];        
        ok=[self privUpdateFormat];
    }
    if (ok) {
        ok=[scaler setDestinationWidth:[driver width] height:[driver height]];	//reset scaling
    }
    if (ok) {
        clientBufferIdx=0;
        driverBufferIdx=0;
        clientImagePending=NO;
        driverStarted=YES;
    }
    [stateLock unlock];				//mutex
    [pool release];
    return ok;
}

- (void) shutdown {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    if (!driverStarted) return;
    if (driverShuttingDown) return;
    driverShuttingDown=YES;
    [driver shutdown];
    [shutdownLock lock];			//Wait until driver has been shut down
    [stateLock lock];				//mutex
    driverStarted=NO;
    driverShuttingDown=NO;
    [stateLock unlock];				//mutex
    [pool release];
}


//-----------------
//   Doing grabs
//-----------------

- (BOOL) grabOneFrameCompressedAsync {
    [stateLock lock];				//mutex
    if (!clientImagePending) {
        clientImagePending=YES;
        if (!driverGrabRunning) {
            if (![self privSetImageBuffer]) clientImagePending=NO;
        }
    }
    [stateLock unlock];				//mutex
    return clientImagePending;
}

- (BOOL) compressionDoneTo:(unsigned char **)data		//Returns if grabOneFrameCompressedAsync has finished
                      size:(long*)size
                similarity:(UInt8*)similarity 
                      time:(struct timeval *)time
{
    BOOL ok=NO;
    if (clientImagePending) return NO;		//fast skip without lock
    [stateLock lock];				//mutex
    if (!clientImagePending) {
        if (data) {
            *data=[scaler convertSourceData:grabBuffers[clientBufferIdx].data
                                      width:WidthOfResolution(grabBuffers[clientBufferIdx].resolution)
                                     height:HeightOfResolution(grabBuffers[clientBufferIdx].resolution)];
            if (*data) {
                if (size) *size=[scaler destinationDataSize];
                if (similarity) *similarity=0;
                if (time) *time = grabBuffers[clientBufferIdx].tv;
                ok=YES;
            }
        }
    }
    [stateLock unlock];				//mutex
    return ok;
}

- (void) takeBackCompressionBuffer:(Ptr)buf {
    // Something to be done here? Let's hope no checking is necessary... ***
}

- (BOOL) setDestinationWidth:(long) width height:(long)height {
    return [scaler setDestinationWidth:width height:height];
}

- (BOOL) getAnImageDescriptionCopy:(ImageDescriptionHandle)outHandle {
    ImageDescription* desc;
    long size=sizeof(ImageDescription);
    BOOL ok=YES;
    [stateLock lock];				//mutex
    SetHandleSize((Handle)outHandle,size);
    if (GetHandleSize((Handle)outHandle)!=size) ok=NO;
    if (ok) {
        HLock((Handle)outHandle);
        desc=(ImageDescription*)(*outHandle);
        desc->idSize=size;
        desc->cType=kRawCodecType;
        desc->resvd1=0;
        desc->resvd2=0;
        desc->dataRefIndex=0;
        desc->version=1;
        desc->revisionLevel=1;
        desc->vendor='APPL';
        desc->temporalQuality=codecLosslessQuality;
        desc->spatialQuality=codecLosslessQuality;
        desc->width=[scaler destinationWidth];
        desc->height=[scaler destinationHeight];
        desc->hRes=Long2Fix(36);
        desc->vRes=Long2Fix(36);
        desc->dataSize=0;
        desc->frameCount=1;
        CStr2PStr("Raw RGB data",desc->name);
        desc->depth=24;
        desc->clutID=-1;
        HUnlock((Handle)outHandle);
    }
    [stateLock unlock];				//mutex
    return ok;
}

- (BOOL) isStarted {
    BOOL ret;
    [stateLock lock];				//mutex - prabably not necessary
    ret=driverStarted;
    [stateLock unlock];				//mutex
    return ret;
}

- (BOOL) isCameraValid {
    BOOL valid=YES;
    [stateLock lock];				//mutex
    if (!driver) valid=NO;
    else if (![driver realCamera]) valid=NO;
    [stateLock unlock];				//mutex
    return valid;
}

- (BOOL) getName:(char*)name {
    if (!driverStarted) return NO;
    return [central getName:name forID:cid];
}

- (short) getIndexOfCamera 
{
    return [central indexOfCamera:driver];
	// FIXME: do I need to check for validity of central here?
}

- (BOOL)canSetContrast {
    if (driver) return [driver canSetContrast];
    else return NO;
}

- (unsigned short)contrast {
    if (driver) return (unsigned short)([driver contrast]*65535.0f);
    else return 0;
}

- (void)setContrast:(unsigned short)c {
    if (driver) [driver setContrast:((float)c)/65535.0f];
}

- (BOOL)canSetBrightness {
    if (driver) return [driver canSetBrightness];
    else return NO;
}

- (unsigned short)brightness {
    if (driver) return (unsigned short)([driver brightness]*65535.0f);
    else return 0;
}

- (void)setBrightness:(unsigned short)c {
    if (driver) [driver setBrightness:((float)c)/65535.0f];
}

- (BOOL)canSetSaturation {
    if (driver) return [driver canSetSaturation];
    else return NO;
}

- (unsigned short)saturation {
    if (driver) return (unsigned short)([driver saturation]*65535.0f);
    else return 0;
}

- (void)setSaturation:(unsigned short)c {
    if (driver) [driver setSaturation:((float)c)/65535.0f];
}

- (BOOL)canSetSharpness {
    if (driver) return [driver canSetSharpness];
    else return NO;
}

- (unsigned short)sharpness {
    if (driver) return (unsigned short)([driver sharpness]*65535.0f);
    else return 0;
}

- (void)setSharpness:(unsigned short)c {
    if (driver) [driver setSharpness:((float)c)/65535.0f];
}

- (BOOL)canSetGamma {
    if (driver) return [driver canSetGamma];
    else return NO;
}

- (unsigned short)gamma {
    if (driver) return (unsigned short)([driver gamma]*65535.0f);
    else return 0;
}

- (void)setGamma:(unsigned short)c {
    if (driver) [driver setGamma:((float)c)/65535.0f];
}

- (BOOL)canSetHFlip {
    if (driver) return [driver canSetHFlip];
    else return NO;
}

- (BOOL)hFlip {
    if (driver) return [driver hFlip];
    else return NO;
}

- (void)setHFlip:(BOOL)c {
    if (driver) [driver setHFlip:c];
}

- (BOOL)canSetGain {
    if (driver) return [driver canSetGain];
    else return NO;
}

- (void)setGain:(unsigned short)v {
    if (driver) [driver setGain:((float)v)/65535.0f];
}

- (unsigned short)gain {
    if (driver) return (unsigned short)([driver gain]*65535.0f);
    else return NO;
}

- (BOOL)canSetShutter {
    if (driver) return [driver canSetShutter];
    else return NO;
}

- (void)setShutter:(unsigned short)v {
    if (driver) [driver setShutter:((float)v)/65535.0f];
}

- (unsigned short)shutter {
    if (driver) return (unsigned short)([driver shutter]*65535.0f);
    else return 0;
}

- (BOOL)canSetAutoGain {
    if (driver) return [driver canSetAutoGain];
    else return NO;
}

- (void)setAutoGain:(BOOL)v {
    if (driver) [driver setAutoGain:v];
}

- (BOOL)isAutoGain {
    if (driver) return [driver isAutoGain];
    else return NO;
}

- (short) maxCompression {
    if (driver) return [driver maxCompression];
    else return 0;
}

- (short) compression {
    if (driver) return [driver compression];
    else return 0;
}

- (void) setCompression:(short)v {
    [stateLock lock];
    wantedCompression=v;
    if ([self privUpdateFormat]) {		//change could be done right now
        [stateLock unlock];
    } else {					//Was deferred
        driverFormatChangePending=YES;
        [formatChangeLock tryLock];		//Make sure it's locked
        [stateLock unlock];
        [formatChangeLock lock];		//Block until lock is released
    }
}

- (BOOL) canSetWhiteBalanceMode {
    if (driver) return [driver canSetWhiteBalanceMode];
    else return NO;
}

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)m {
    if (driver) return [driver canSetWhiteBalanceModeTo:m];
    else return (m==WhiteBalanceLinear);
}

- (WhiteBalanceMode) whiteBalanceMode {
    if (driver) return [driver whiteBalanceMode];
    else return WhiteBalanceLinear;
}

- (void) setWhiteBalanceMode:(WhiteBalanceMode)m {
    if (driver) [driver setWhiteBalanceMode:m];
}


// ================= Color & Grey Mode

- (BOOL) canBlackWhiteMode {
    if (driver) return [driver canBlackWhiteMode];
    else return NO;
}


- (BOOL) blackWhiteMode {
    if (driver)
		return [driver blackWhiteMode];
    else
		return NO; // default to color mode
}

- (void) setBlackWhiteMode:(BOOL)m {
    if (driver) [driver setBlackWhiteMode:m];
}

// =================== LED state

- (BOOL) canSetLed {
    if (driver) return [driver canSetLed];
    else return NO;
}


- (BOOL) isLedOn {
    if (driver) return [driver isLedOn];
    else return FALSE;
}

- (void) setLed:(BOOL)v {
    if (driver) [driver setLed:v];
}

// =============================

- (short) width {
    if (driver) return [driver width];
    else return 1;
}

- (short) height {
    if (driver) return [driver height];
    else return 1;
}

- (void) nativeBounds:(Rect*)r { 
//Note that when called un-state-locked, this might be inconsistent. But the client model is serial (and it doesn't matter)
    if (r) {
        r->left=0;
        r->top=0;
        r->right=[self width];
        r->bottom=[self height];
    }
}

- (short) fps {
    if (driver) return [driver fps];
    else return 5;
}

- (CameraResolution) resolution {
    if (driver) return [driver resolution];
    else return ResolutionSQSIF;
}

- (BOOL) supportsResolution:(CameraResolution)res fps:(short)fps {
    if (driver) return [driver supportsResolution:res fps:fps];
    else return ((res==ResolutionSIF)&&(fps==5));
}

- (void) setResolution:(CameraResolution)res fps:(short)fps {
    [stateLock lock];
    wantedResolution=res;
    wantedFps=fps;
    if ([self privUpdateFormat]) {		//could be done right now
        [stateLock unlock];
    } else {					//Was deferred
        driverFormatChangePending=YES;
        [formatChangeLock tryLock];		//Make sure it's locked
        [stateLock unlock];
        [formatChangeLock lock];		//Block until format change is done
    }
}

- (void) imageReady:(id)cam {
//This call comes from decodingThread, except if we've called makeErrorImage
    [stateLock lock];	 			//mutex
    if (driver==cam) {
        if ([driver imageBuffer]) {
            if (clientImagePending) 
            {
                grabBuffers[driverBufferIdx].tv = [driver imageBufferTimeVal];
                
                clientBufferIdx=driverBufferIdx;
                clientImagePending=NO;
                driverBufferIdx=(driverBufferIdx+1)%NUM_BRIDGE_GRAB_BUFFERS;
            }
        }
        [self privSetImageBuffer];
    }
    [stateLock unlock];				//mutex
}

- (void) cameraHasShutDown:(id)cam {
    [stateLock lock];				//mutex
    if (driver==cam) {
        [driver release];
        driver=NULL;
        if (driverShuttingDown) {
            [shutdownLock unlock];
        } else {
            [central setDelegate:self];
            driver=[central useDummyForError:CameraErrorNoCam];	//There's no callback
            NSAssert(driver,@"MyBridge: cameraHasShutDown: Could not allocate dummy camera driver");
            [central setDelegate:NULL];
            [driver retain];
            [self privSetImageBuffer];
        }
        if (driverFormatChangePending) {		//Hopefully there's no such situation
            driverFormatChangePending=NO;
            [formatChangeLock unlock];
        }
    }
    [stateLock unlock];				//mutex
}

- (void) grabFinished:(id)cam withError:(CameraError)err {
    BOOL doErrorImage=NO;
    [stateLock lock];				//mutex
    if (driver==cam) {
        [driver setImageBuffer:NULL bpp:3 rowBytes:1];	//Make sure the driver doesn't render any more
        driverGrabRunning=NO;
        [self privUpdateFormat];		//Make sure the format is up to date
        if (clientImagePending) {
            if (err) doErrorImage=YES;
            else [self privSetImageBuffer];
        }
    }
    [stateLock unlock];				//mutex
    if (doErrorImage) [cam makeErrorImage:err];
}

- (void) saveAsDefaults {
    if (driver) [central saveCameraSettingsAsDefaults:driver];
}

//------------------------------------
//   Private method implementations
//------------------------------------

//Private methods are not mutexed since they are all called internally - they have to be encapsulated by a stateLock

- (BOOL) privUpdateFormat {
    BOOL ok=YES;
    if (([self resolution]==wantedResolution)&&
        ([self fps]==wantedFps)&&
        ([self compression]==wantedCompression)) return YES;	//It's alright

    driverGrabRunning=[driver stopGrabbing];			//We need to stop
    if (driverGrabRunning) return NO;				//Could not stop for now - we'll get called on finish
    [driver setResolution:wantedResolution fps:wantedFps];	//Set resolution and fps
    [driver setCompression:wantedCompression];			//Set compression
    wantedResolution=[driver resolution];			//set wanted to current (it's all we can do for now)
    wantedFps=[driver fps];					//set wanted to current (it's all we can do for now)
    wantedCompression=[driver compression];			//set wanted to current (it's all we can do for now)
    if (driverFormatChangePending) {				//In case the a call is locked:
        driverFormatChangePending=NO;				//Now not any more
        [formatChangeLock unlock];				//The call may finish now
    }
    return ok;
}

- (BOOL) privSetImageBuffer {
    long bufferSize;
    CameraResolution dRes;
    
//Make sure the format is ok
    if (!driverGrabRunning) {
        if (![self privUpdateFormat]) return NO;
    }

//Check the buffer
    dRes=[driver resolution];
    if (dRes!=grabBuffers[driverBufferIdx].resolution) {
        if (grabBuffers[driverBufferIdx].data) FREE(grabBuffers[driverBufferIdx].data,"privSetImageBuffer");
        grabBuffers[driverBufferIdx].data=NULL;
    }
//If needed, allocate a new one
    if (!(grabBuffers[driverBufferIdx].data)) {
        grabBuffers[driverBufferIdx].resolution=dRes;
        bufferSize=WidthOfResolution(dRes)*HeightOfResolution(dRes)*3;
        MALLOC(grabBuffers[driverBufferIdx].data,unsigned char*,bufferSize,@"privSetImageBuffer");
    }
//Set image buffer
    if (!(grabBuffers[driverBufferIdx].data)) return NO;
    [driver setImageBuffer:grabBuffers[driverBufferIdx].data bpp:3 rowBytes:WidthOfResolution(dRes)*3];
    if (!driverGrabRunning) driverGrabRunning=[driver startGrabbing];
    return driverGrabRunning;
}


@end
