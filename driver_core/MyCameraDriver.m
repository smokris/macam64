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

#import "MyCameraDriver.h"
#import "MyCameraCentral.h"
#import "Resolvers.h"
#import "MiniGraphicsTools.h"
#import "MiscTools.h"
#include <unistd.h>		//usleep

@implementation MyCameraDriver

+ (unsigned short) cameraUsbProductID {
    NSAssert(0,@"You must override cameraUsbProductID or cameraUsbDescriptions");
    return 0;
}

+ (unsigned short) cameraUsbVendorID {
    NSAssert(0,@"You must override cameraUsbVendorID or cameraUsbDescriptions");
    return 0;
}

+ (NSString*) cameraName {
    NSAssert(0,@"You must override cameraName or cameraUsbDescriptions");
    return @"";
}

+ (NSArray*) cameraUsbDescriptions {
    NSDictionary* dict=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:[self cameraUsbProductID]],@"idProduct",
        [NSNumber numberWithUnsignedShort:[self cameraUsbVendorID]],@"idVendor",
        [self cameraName],@"name",NULL];
    return [NSArray arrayWithObject:dict];
}

- (id) initWithCentral:(id)c {
//init superclass
    self=[super init];
    if (self==NULL) return NULL;
//setup simple defaults
    central=c;
    dev=NULL;
    intf=NULL;
    brightness=0.0f;
    contrast=0.0f;
    saturation=0.0f;
    gamma=0.0f;
    shutter=0.0f;
    gain=0.0f;
    autoGain=NO;
    hFlip=NO;
    compression=0;
    whiteBalanceMode=WhiteBalanceLinear;
    blackWhiteMode = FALSE;
    isStarted=NO;
    isGrabbing=NO;
    shouldBeGrabbing=NO;
    isShuttingDown=NO;
    isShutDown=NO;
    isUSBOK=YES;
    lastImageBuffer=NULL;
    lastImageBufferBPP=0;
    lastImageBufferRowBytes=0;
    nextImageBuffer=NULL;
    nextImageBufferBPP=0;
    nextImageBufferRowBytes=0;
    nextImageBufferSet=NO;
    imageBufferLock=[[NSLock alloc] init];
    //allocate lock
    if (imageBufferLock==NULL) {
#ifdef VERBOSE
        NSLog(@"MyCameraDriver:init: cannot instantiate imageBufferLock");
#endif
        return NULL;
    }
    stateLock=[[NSLock alloc] init];
    //allocate lock
    if (stateLock==NULL) {
#ifdef VERBOSE
        NSLog(@"MyCameraDriver:init: cannot instantiate stateLock");
#endif
        [imageBufferLock release];
        return NULL;
    }
    doNotificationsOnMainThread=[central doNotificationsOnMainThread];
    mainThreadRunLoop=[NSRunLoop currentRunLoop];
    mainThreadConnection=NULL;
    decodingThreadConnection=NULL;
    return self;    
}

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId {
    CameraResolution r;
    short fr;
    WhiteBalanceMode wb;
    r=[self defaultResolutionAndRate:&fr];
    wb=[self defaultWhiteBalanceMode];
    [self setResolution:r fps:fr];
    [self setWhiteBalanceMode:wb];
    isStarted=YES;
    return CameraErrorOK;
}

- (void) shutdown {
    BOOL needsShutdown;
    [stateLock lock];
    isShuttingDown=YES;
    shouldBeGrabbing=NO;
    needsShutdown=!isShutDown;
    [stateLock unlock];
    [imageBufferLock lock];	//Make sure no external image buffer is used after this method returns
    nextImageBufferSet=NO;
    nextImageBuffer=NULL;
    [imageBufferLock unlock];
    if (!needsShutdown) return;
    if (![self stopGrabbing]) {	//We can handle it here - if not, do it on the end of the decodingThread
        [self usbCloseConnection];
        [stateLock lock];
        isShutDown=YES;
        [stateLock unlock];
        [self mergeCameraHasShutDown];
    }
}	

- (void) dealloc {
    if (imageBufferLock!=NULL) [imageBufferLock release]; imageBufferLock=NULL;
    [super dealloc];
}

- (id) delegate {
    return delegate;
}

- (void) setDelegate:(id)d {
    delegate=d;
}

- (void) enableNotifyOnMainThread {
    doNotificationsOnMainThread=YES;
}

- (void) setCentral:(id)c {
    central=c;
}

- (id) central {
    return central;
}

- (BOOL) realCamera {	//Returns if the camera is a real image grabber or a dummy
    return YES;		//By default, subclasses are real cams. Dummys should override this
}

//Image / camera properties get/set
- (BOOL) canSetBrightness {
    return NO;
}

- (float) brightness {
    return brightness;
}

- (void) setBrightness:(float)v {
    brightness=v;
}

- (BOOL) canSetContrast {
    return NO;
}

- (float) contrast {
    return contrast;
}

- (void) setContrast:(float)v {
    contrast=v;
}

- (BOOL) canSetSaturation {
    return NO;
}

- (float) saturation {
    return saturation;
}

- (void) setSaturation:(float)v {
    saturation=v;
}

- (BOOL) canSetGamma {
    return NO;
}

- (float) gamma {
    return gamma;
}

- (void) setGamma:(float)v {
    gamma=v;
}

- (BOOL) canSetSharpness {
    return NO;
}

- (float) sharpness {
    return sharpness;
}

- (void) setSharpness:(float)v {
    sharpness=v;
}

- (BOOL) canSetGain {
    return NO;
}

- (float) gain {
    return gain;
}

- (void) setGain:(float)v {
    gain=v;
}

- (BOOL) canSetShutter {
    return NO;
}

- (float) shutter {
    return shutter;
}

- (void) setShutter:(float)v {
    shutter=v;
}

- (BOOL) canSetAutoGain {	//Gain and shutter combined (so far - let's see what other cams can do...)
    return NO;
}

- (BOOL) isAutoGain {
    return autoGain;
}

- (void) setAutoGain:(BOOL)v{
    autoGain=v;
}

- (BOOL) canSetHFlip {
    return NO;
}

- (BOOL) hFlip {
    return hFlip;
}

- (void) setHFlip:(BOOL)v {
    hFlip=v;
}

- (short) maxCompression {
    return 0;
}

- (short) compression {
    return compression;
}

- (void) setCompression:(short)v {
    [stateLock lock];
    if (!isGrabbing) compression=CLAMP(v,0,[self maxCompression]);
    [stateLock unlock];
}

- (BOOL) canSetWhiteBalanceMode {
    return NO;
}

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode {
    return (newMode==[self defaultWhiteBalanceMode]);
}

- (WhiteBalanceMode) defaultWhiteBalanceMode {
    return WhiteBalanceLinear;
}

- (WhiteBalanceMode) whiteBalanceMode {
    return whiteBalanceMode;
}

- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode {
    if ([self canSetWhiteBalanceModeTo:newMode]) {
        whiteBalanceMode=newMode;
    }
}


// ============== Color Mode ======================

- (BOOL) canBlackWhiteMode {
    return NO;
}


- (BOOL) blackWhiteMode {
    return blackWhiteMode;
}

- (void) setBlackWhiteMode:(BOOL)newMode {
    if ([self canBlackWhiteMode]) {
        blackWhiteMode=newMode;
    }
}
 
 
//================== Light Emitting Diode

- (BOOL) canSetLed {
    return NO;
}


- (BOOL) isLedOn {
    return LEDon;
}

- (void) setLed:(BOOL)v {
    if ([self canSetLed]) {
        LEDon=v;
    }
}
 

// =========================

- (short) width {						//Current image width
    return WidthOfResolution(resolution);
}

- (short) height {						//Current image height
    return HeightOfResolution(resolution);
}

- (CameraResolution) resolution {				//Current image predefined format constant
    return resolution;
}

- (short) fps {							//Current frames per second
    return fps;
}

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {	//Does this combination work?
    return NO;
}
- (void) setResolution:(CameraResolution)r fps:(short)fr {	//Set a resolution and frame rate. Returns success.
    if (![self supportsResolution:r fps:fr]) return;
    [stateLock lock];
    if (!isGrabbing) {
        resolution=r;
        fps=fr;
    }
    [stateLock unlock];
}

- (CameraResolution) findResolutionForWidth:(short)width height:(short) height {
//Find the largest resolution that is supported and smaller than the given dimensions
    CameraResolution res=ResolutionVGA;
    BOOL found=NO;
    while ((!found)&&(res>=(ResolutionSQSIF))) {
        if (WidthOfResolution(res)<=width) {
            if (HeightOfResolution(res)<=height) {
                if ([self findFrameRateForResolution:res]>0) {
                    found=YES;
                }
            }
        }
        if (!found) res=(CameraResolution)(((short)res)-1);
    }
    //If there is no smaller resolution: Find the smallest availabe resolution
    if (!found) {
        res=ResolutionSQSIF;
        while ((!found)&&(res<=(ResolutionVGA))) {
            if ([self findFrameRateForResolution:res]>0) found=YES;
            if (!found) res=(CameraResolution)(((short)res)+1);
        }
    }
    if (!found) {
#ifdef VERBOSE
        NSLog(@"MyCameraDriver:findResolutionForWidth:height: Cannot find any resolution");
#endif
        return ResolutionQSIF;
    }
    return res;
}

- (short) findFrameRateForResolution:(CameraResolution)res {
    short fpsRun=30;
    while (fpsRun>=5) {
        if ([self supportsResolution:res fps:fpsRun]) return fpsRun;
        else fpsRun-=5;
    }
    return 0;
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {	//Just some defaults. You should always override this.
    if (dFps) *dFps=5;
    return ResolutionSQSIF;
}

//Grabbing
- (BOOL) startGrabbing {					//start async grabbing
    id threadData=NULL;
    BOOL needStartUp=YES;
    BOOL ret=NO;
    [stateLock lock];
    needStartUp=isStarted&&(!isShuttingDown)&&(!isGrabbing);
    if (needStartUp) { //update driver state
        shouldBeGrabbing=YES;
        isGrabbing=YES;
    }
    ret=isGrabbing;	
    [stateLock unlock];
    if (!needStartUp) return ret;
    if (doNotificationsOnMainThread) {
        NSPort* port1=[NSPort port];
        NSPort* port2=[NSPort port];
        mainThreadConnection=[[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
        [mainThreadConnection setRootObject:self];
        threadData=[NSArray arrayWithObjects:port2,port1,NULL];
    }
    [NSThread detachNewThreadSelector:@selector(decodingThreadWrapper:) toTarget:self withObject:threadData];    //start decodingThread
    return ret;
}

- (BOOL) stopGrabbing {		//Stop async grabbing
    BOOL res;
    [stateLock lock];
    if (isGrabbing) shouldBeGrabbing=NO;
    res=isGrabbing;
    [stateLock unlock];
    return res;
}

- (BOOL) isGrabbing {	// Returns if the camera is grabbing
    BOOL res;
    [stateLock lock];
        res = shouldBeGrabbing;
    [stateLock unlock];
    return res;
}

- (void) decodingThreadWrapper:(id)data {
    CameraError err;
    NSConnection* myMainThreadConnection;	//local copies for the end where possibly a new thread is using the object's variables
    NSConnection* myDecodingThreadConnection;
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    if (data) {
        decodingThreadConnection=[[NSConnection alloc] initWithReceivePort:[data objectAtIndex:0] sendPort:[data objectAtIndex:1]];
    }
    err=[self decodingThread];
    myMainThreadConnection=mainThreadConnection;
    myDecodingThreadConnection=decodingThreadConnection;
    [stateLock lock];	//We have to lock because other tasks rely on a constant state within their lock
    isGrabbing=NO;
    [stateLock unlock];
    [self mergeGrabFinishedWithError:err];
    if (isShuttingDown) {
        [self usbCloseConnection];
        [self mergeCameraHasShutDown];
        [stateLock lock];
        isShutDown=YES;
        [stateLock unlock];
    }
    if (myDecodingThreadConnection) [myDecodingThreadConnection release]; 
    if (myMainThreadConnection) [myMainThreadConnection release];
    [pool release];
    [NSThread exit];
}

- (CameraError) decodingThread {
    return CameraErrorInternal;
}

- (void) setImageBuffer:(unsigned char*)buffer bpp:(short)bpp rowBytes:(long)rb {
    if (((bpp!=3)&&(bpp!=4))||(rb<0)) return;
    [imageBufferLock lock];
    if ((!isShuttingDown)&&(!isShutDown)) {	//When shutting down, we don't accept buffers any more
        nextImageBuffer=buffer;
    } else {
        nextImageBuffer=NULL;
    }
    nextImageBufferBPP=bpp;
    nextImageBufferRowBytes=rb;
    nextImageBufferSet=YES;
    [imageBufferLock unlock];
}

- (unsigned char*) imageBuffer {
    return lastImageBuffer;
}

- (short) imageBufferBPP {
    return lastImageBufferBPP;
}

- (long) imageBufferRowBytes {
    return lastImageBufferRowBytes;
}

- (BOOL) canStoreMedia {
    return NO;
}

- (long) numberOfStoredMediaObjects {
    return 0;
}

- (NSDictionary*) getStoredMediaObject:(long)idx {
    return NULL;
}

- (BOOL) canGetStoredMediaObjectInfo {
    return NO;
}

- (NSDictionary*) getStoredMediaObjectInfo:(long)idx {
    return NULL;
}

- (BOOL) canDeleteAll {
    return NO;
}

- (CameraError) deleteAll {
    return CameraErrorUnimplemented;
}

- (BOOL) canDeleteOne {
    return NO;
}

- (CameraError) deleteOne:(long)idx {
    return CameraErrorUnimplemented;
}

- (BOOL) canDeleteLast {
    return NO;
}

- (CameraError) deleteLast {
    return CameraErrorUnimplemented;
}

- (BOOL) canCaptureOne {
    return NO;
}

- (CameraError) captureOne {
    return CameraErrorUnimplemented;
}


- (BOOL) supportsCameraFeature:(CameraFeature)feature {
    BOOL supported=NO;
    switch (feature) {
        case CameraFeatureInspectorClassName:
            supported=YES;
            break;
        default:
            break;
    }
    return supported;
}

- (id) valueOfCameraFeature:(CameraFeature)feature {
    id ret=NULL;
    switch (feature) {
        case CameraFeatureInspectorClassName:
            ret=@"MyCameraInspector";
            break;
        default:
            break;
    }
    return ret;
}

- (void) setValue:(id)val ofCameraFeature:(CameraFeature)feature {
    switch (feature) {
        default:
            break;
    }
}


//Merging Notification forwarders - use these if you want to notify from decodingThread

- (void) mergeGrabFinishedWithError:(CameraError)err {
    if (doNotificationsOnMainThread) {
        if ([NSRunLoop currentRunLoop]!=mainThreadRunLoop) {
            [(id)[decodingThreadConnection rootProxy] mergeGrabFinishedWithError:err];
            return;
        }
    }
    [self grabFinished:self withError:err];
}

- (void) mergeImageReady {
    if (doNotificationsOnMainThread) {
        if ([NSRunLoop currentRunLoop]!=mainThreadRunLoop) {
            [(id)[decodingThreadConnection rootProxy] mergeImageReady];
            return;
        }
    }
    [self imageReady:self];
}

- (void) mergeCameraHasShutDown {
    if (doNotificationsOnMainThread) {
        if ([NSRunLoop currentRunLoop]!=mainThreadRunLoop) {
            [(id)[decodingThreadConnection rootProxy] mergeCameraHasShutDown];
            return;
        }
    }
    [self cameraHasShutDown:self];
}

//Simple Notification forwarders

- (void) imageReady:(id)sender {
    if (delegate!=NULL) {
        if ([delegate respondsToSelector:@selector(imageReady:)]) {
            [delegate imageReady:sender];
        }
    }
}

- (void) grabFinished:(id)sender withError:(CameraError)err{
    if (delegate!=NULL) {
        if ([delegate respondsToSelector:@selector(grabFinished:withError:)]) [delegate grabFinished:sender withError:err];
    }
}

- (void) cameraHasShutDown:(id)sender {
    if (delegate!=NULL) {
        if ([delegate respondsToSelector:@selector(cameraHasShutDown:)]) [delegate cameraHasShutDown:sender];
    }
    if (central) {
        [central cameraHasShutDown:self];
    }
}

- (void) cameraEventHappened:(id)sender event:(CameraEvent)evt {
    if (delegate!=NULL) {
        if ([delegate respondsToSelector:@selector(cameraEventHappened:event:)]) {
            [delegate cameraEventHappened:sender event:evt];
        }
    }
}

- (MyCameraInfo*) getCameraInfo {
       return cameraInfo;
}

- (void) setCameraInfo:(MyCameraInfo *)info {
       cameraInfo = info;
}

//USB Tool functions for subclasses

//Sends a generic command
- (BOOL) usbCmdWithBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len {
    IOReturn err;
    IOUSBDevRequest req;
    req.bmRequestType=bReqType;
    req.bRequest=bReq;
    req.wValue=wVal;
    req.wIndex=wIdx;
    req.wLength=len;
    req.pData=buf;
    if ((!isUSBOK)||(!intf)) return NO;
    err=(*intf)->ControlRequest(intf,0,&req);
#ifdef LOG_USB_CALLS
    NSLog(@"usb command reqType:%i req:%i val:%i idx:%i len:%i ret:%i",bReqType,bReq,wVal,wIdx,len,err);
    if (len>0) DumpMem(buf,len);
#endif
    CheckError(err,"usbCmdWithBRequestType");
    if ((err==kIOUSBPipeStalled)&&(intf)) (*intf)->ClearPipeStall(intf,0);
    return (!err);
}

//sends a USB IN|VENDOR|DEVICE command
- (BOOL) usbReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBDevice)
                               bRequest:bReq
                                 wValue:wVal
                                 wIndex:wIdx
                                    buf:buf
                                    len:len];
}

//sends a USB IN|VENDOR|INTERFACE command
- (BOOL) usbReadVICmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBInterface)
                               bRequest:bReq
                                 wValue:wVal
                                 wIndex:wIdx
                                    buf:buf
                                    len:len];
}

//sends a USB OUT|VENDOR|DEVICE command
- (BOOL) usbWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice)
                               bRequest:bReq
                                 wValue:wVal
                                 wIndex:wIdx
                                    buf:buf
                                    len:len];
}

//sends a USB OUT|VENDOR|INTERFACE command
- (BOOL) usbWriteVICmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBInterface)
                               bRequest:bReq
                                 wValue:wVal
                                 wIndex:wIdx
                                    buf:buf
                                    len:len];
}

- (BOOL) usbSetAltInterfaceTo:(short)alt testPipe:(short)pipe {
    IOReturn err;
    BOOL ok=YES;
    if ((!isUSBOK)||(!intf)) ok=NO;
    if (ok) {
        err=(*intf)->SetAlternateInterface(intf,alt);			//set alternate interface
        CheckError(err,"setAlternateInterface");
        if (err) ok=NO;
    }
    if ((!isUSBOK)||(!intf)) ok=NO;
    if (ok&&(alt!=0)&&(pipe!=0)) {
        err=(*intf)->GetPipeStatus(intf,pipe);				//is the pipe ok?
        CheckError(err,"getPipeStatus");
        if (err) ok=NO;
    }
#ifdef LOG_USB_CALLS
    if (ok) NSLog(@"alt interface switch to %i ok");
    else NSLog(@"alt interface switch to %i failed");
#endif
    return ok;
}

- (CameraError) usbConnectToCam:(UInt32)usbLocationId configIdx:(short)configIdx{
    IOReturn				err;
    IOCFPlugInInterface 		**iodev;		// requires <IOKit/IOCFPlugIn.h>
    SInt32 				score;
    UInt8				numConf;
    IOUSBConfigurationDescriptorPtr	confDesc;
    IOUSBFindInterfaceRequest		interfaceRequest;
    io_iterator_t			iterator;
    io_service_t			usbInterfaceRef;
    short    				retries;
    kern_return_t			ret;
    io_service_t			usbDeviceRef=IO_OBJECT_NULL;
    mach_port_t				masterPort;
    CFMutableDictionaryRef 		matchingDict;
    
//Get a master port (we should rlease it later...) *******

    ret=IOMasterPort(MACH_PORT_NULL,&masterPort);
    if (ret) {
#ifdef VERBOSE
        NSLog(@"usbConnectToCam: Could not get master port (err:%08x)",ret);
#endif
        return CameraErrorInternal;
    }

//Search device with given location Id
    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matchingDict) {
#ifdef VERBOSE
            NSLog(@"usbConnectToCam: Could not build matching dict");
#endif
            return CameraErrorNoMem;
    }
    ret = IOServiceGetMatchingServices(masterPort,
                                       matchingDict,
                                       &iterator);
    
    if ((ret)||(!iterator)) {
#ifdef VERBOSE
        NSLog(@"usbConnectToCam: Could not build iterate services");
#endif
        return CameraErrorNoMem;
    }

    //Go through results
    
    while (usbDeviceRef=IOIteratorNext(iterator)) {
        UInt32 locId;
        
        err = IOCreatePlugInInterfaceForService(usbDeviceRef, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
        CheckError(err,"usbConnectToCam-IOCreatePlugInInterfaceForService");
        if ((!iodev)||(err)) return CameraErrorInternal;	//Bail - find better error code ***

        //ask plugin interface for device interface
        err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID)&dev);
        //IOPlugin interface is done
        (*iodev)->Release(iodev);
        if ((!dev)||(err)) return CameraErrorInternal;		//Bail - find better error code ***
        CheckError(err,"usbConnectToCam-QueryInterface1");

        ret = (*dev)->GetLocationID(dev,&locId);
        if (ret) {
#ifdef VERBOSE
            NSLog(@"could not get location id (err:%08x)",ret);
#endif
            (*dev)->Release(dev);
            return CameraErrorUSBProblem;
        }
        if (usbLocationId==locId) break;	//We found our device
        else {
            (*dev)->Release(dev);
            IOObjectRelease(usbDeviceRef);
            dev=NULL;
        }            
    }

    IOObjectRelease(iterator); iterator=IO_OBJECT_NULL;
    
    if (!dev) return CameraErrorNoCam;
    
    //Now we should have the correct device interface.    

    //open device interface. Retry this to get it from Classic (see ClassicUSBDeviceArb.html - simplified mechanism)
    for (retries=10;retries>0;retries--) {
        err = (*dev)->USBDeviceOpen(dev);
        CheckError(err,"usbConnectToCam-USBDeviceOpen");
        if (err!=kIOReturnExclusiveAccess) break;	//Loop only if the device is busy
        usleep(500000);
    }
    if (err) {			//If soneone else has our device, bail out as if nothing happened...
        err = (*dev)->Release(dev);
        CheckError(err,"usbConnectToCam-Release Device (exclusive access)");
        dev=NULL;
        return CameraErrorBusy;
    }

    if (configIdx>=0) {	//Set configIdx to -1 if you don't want a config to be selected
        //do a device reset. Shouldn't harm.
        err = (*dev)->ResetDevice(dev);
        CheckError(err,"usbConnectToCam-ResetDevice");
        //Count configurations
        err = (*dev)->GetNumberOfConfigurations(dev, &numConf);
        CheckError(err,"usbConnectToCam-GetNumberOfConfigurations");
        if (numConf<configIdx) {
            NSLog(@"Invalid configuration index");
            err = (*dev)->Release(dev);
            dev=NULL;
            return CameraErrorInternal;
        }
        err = (*dev)->GetConfigurationDescriptorPtr(dev, configIdx, &confDesc);		        	CheckError(err,"usbConnectToCam-GetConfigurationDescriptorPtr");
        retries=3;
        do {
            err = (*dev)->SetConfiguration(dev, confDesc->bConfigurationValue);
            CheckError(err,"usbConnectToCam-SetConfiguration");
            if (err==kIOUSBNotEnoughPowerErr) {		//no power?
                err = (*dev)->Release(dev);
                CheckError(err,"usbConnectToCam-Release Device (low power)");
                dev=NULL;
                return CameraErrorNoPower;
            }
        } while((err)&&((--retries)>0));
        if (err) {					//error opening interface?
            err = (*dev)->Release(dev);
            CheckError(err,"usbConnectToCam-Release Device (low power)");
            dev=NULL;
            return CameraErrorUSBProblem;
        }
    }

    interfaceRequest.bInterfaceClass = kIOUSBFindInterfaceDontCare;		// requested class
    interfaceRequest.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;		// requested subclass
    interfaceRequest.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;		// requested protocol
    interfaceRequest.bAlternateSetting = kIOUSBFindInterfaceDontCare;		// requested alt setting
    
//take an iterator over the device interfaces...
    err = (*dev)->CreateInterfaceIterator(dev, &interfaceRequest, &iterator);
    CheckError(err,"usbConnectToCam-CreateInterfaceIterator");
    
//and take the first one
    usbInterfaceRef = IOIteratorNext(iterator);
    assert (usbInterfaceRef);

    //we don't need the iterator any more
    IOObjectRelease(iterator);
    iterator = 0;
    
//get a plugin interface for the interface interface
    err = IOCreatePlugInInterfaceForService(usbInterfaceRef, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
    CheckError(err,"usbConnectToCam-IOCreatePlugInInterfaceForService");
    assert(iodev);
    IOObjectRelease(usbInterfaceRef);
    
//get access to the interface interface
    err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID)&intf);
    CheckError(err,"usbConnectToCam-QueryInterface2");
    assert(intf);
    (*iodev)->Release(iodev);					// done with this
    
//open interface
    err = (*intf)->USBInterfaceOpen(intf);
    CheckError(err,"usbConnectToCam-USBInterfaceOpen");
    
//set alternate interface
    err = (*intf)->SetAlternateInterface(intf,0);
    CheckError(err,"usbConnectToCam-SetAlternateInterface");

    return CameraErrorOK;
}

- (void) usbCloseConnection {
    IOReturn err;
    if (intf) {							//close our interface interface
        if (isUSBOK) {
            err = (*intf)->USBInterfaceClose(intf);
        }
        err = (*intf)->Release(intf);
        CheckError(err,"usbCloseConnection-Release Interface");
        intf=NULL;
    }
    if (dev) {							//close our device interface
        if (isUSBOK) {
            err = (*dev)->USBDeviceClose(dev);
        }
        err = (*dev)->Release(dev);
        CheckError(err,"usbCloseConnection-Release Device");
        dev=NULL;
    }
}

- (BOOL) usbGetSoon:(UInt64*)to {			//Get a bus frame number in the near future
    AbsoluteTime at;
    IOReturn err;
    UInt64 frame;
    
    if ((!to)||(!intf)||(!isUSBOK)) return NO;
    err=(*intf)->GetBusFrameNumber(intf, &frame, &at);
    CheckError(err,"usbGetSoon");
    if (err) return NO;
    *to=frame+100;					//give it a little time to start
    return YES;
}

//Other tool functions
- (BOOL) makeErrorImage:(CameraError) err {
    switch (err) {
        case CameraErrorOK:		return [self makeOKImage]; break;
        default:			return [self makeMessageImage:[central localizedCStrForError:err]]; break;
    }
}

- (BOOL) makeMessageImage:(char*) msg {
    BOOL draw;
    [imageBufferLock lock];
    lastImageBuffer=nextImageBuffer;
    lastImageBufferBPP=nextImageBufferBPP;
    lastImageBufferRowBytes=nextImageBufferRowBytes;
    draw=nextImageBufferSet;
    nextImageBufferSet=NO;    
    if (draw) {
        if (lastImageBuffer) {
            memset(lastImageBuffer,0,lastImageBufferRowBytes*[self height]);
            MiniDrawString(lastImageBuffer,lastImageBufferBPP,lastImageBufferRowBytes,10,10,msg);
        }
        [imageBufferLock unlock];
        [self mergeImageReady];				//notify delegate about the image. perhaps get a new buffer
    } else {
        [imageBufferLock unlock];
    }
    return draw;
}	

- (BOOL) makeOKImage {
    BOOL draw;
    char cstr[20];
    short x,bar,y,width,height,barend;
    UInt8 r,g,b;
    UInt8* bufRun;
    BOOL alpha;
    CFTimeInterval time;
    short h,m,s,f;
    [imageBufferLock lock];
    lastImageBuffer=nextImageBuffer;
    lastImageBufferBPP=nextImageBufferBPP;
    lastImageBufferRowBytes=nextImageBufferRowBytes;
    draw=nextImageBufferSet;
    nextImageBufferSet=NO;
    [imageBufferLock unlock];
    if (draw) {
        if (lastImageBuffer) {
//Draw color stripes
            alpha=lastImageBufferBPP==4;
            width=[self width];
            height=[self height];
            bufRun=lastImageBuffer;
            for (y=0;y<height;y++) {
                x=0;
                for (bar=0;bar<8;bar++) {
                    switch (bar) {
                        case 0: r=255;g=255;b=255;break;
                        case 1: r=255;g=255;b=0  ;break;
                        case 2: r=255;g=0  ;b=255;break;
                        case 3: r=0  ;g=255;b=255;break;
                        case 4: r=255;g=0  ;b=0  ;break;
                        case 5: r=0  ;g=255;b=0  ;break;
                        case 6: r=0  ;g=0  ;b=255;break;
                        default:r=0  ;g=0  ;b=0  ;break;
                    }
                    barend=((bar+1)*width)/8;
                    while (x<barend) {
                        if (alpha) bufRun++;
                        *(bufRun++)=r;
                        *(bufRun++)=g;
                        *(bufRun++)=b;
                        x++;
                    }
                }
                bufRun+=lastImageBufferRowBytes-width*lastImageBufferBPP;
            }
            time=CFAbsoluteTimeGetCurrent();
            h=(((long long)time)/(60*60))%24;
            m=(((long long)time)/(60))%60;
            s=((long long)time)%60;
            time*=100.0;
            f=((long long)(time))%100;
            sprintf(cstr,"%02i:%02i:%02i:%02i",h,m,s,f);
            MiniDrawString(lastImageBuffer,lastImageBufferBPP,lastImageBufferRowBytes,10,10,cstr);
            MiniDrawString(lastImageBuffer,lastImageBufferBPP,lastImageBufferRowBytes,10,23,
                            (char*)[[[self getCameraInfo] cameraName] cString]);
        }
        [self mergeImageReady];				//notify delegate about the image. perhaps get a new buffer
    }
    return draw;
}


- (void) stopUsingUSB {
    isUSBOK=NO;
}

@end
