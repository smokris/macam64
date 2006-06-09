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

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include "MiscTools.h"

#import "MyCameraInfo.h"
#import "MyCameraCentral.h"
#import "MyCameraDriver.h"
#import "MyKiaraFamilyDriver.h"
#import "MyKiaraFlippedDriver.h"
#import "MyTimonFamilyDriver.h"
#import "MyCPIACameraDriver.h"
#import "MyQX3Driver.h"
#import "MySTV680Driver.h"
#import "MyIntelPCCameraPro.h"
#import "MyDummyCameraDriver.h"
#import "MyQCExpressADriver.h"
#import "MyQCExpressBDriver.h"
#import "MyQCWebDriver.h"
#import "QCMessengerDriver.h"
#import "MyVicamDriver.h"
#import "MySPCA504Driver.h"
#import "MyOV511Driver.h"
#import "MySonix2028Driver.h"
#import "MySE401Driver.h"
#import "MyQCProBeigeDriver.h"
#import "MySPCA500Driver.h"
#import "MyQCOrbitDriver.h"
#import "SQ905.h"
#import "SQ930C.h"
#import "MyPixartDriver.h"
#import "PixartDriver.h"
#import "PAC7311Driver.h"
#import "SPCA5XXDriver.h"
#import "PAC207Driver.h"
#import "SPCA561ADriver.h"
#import "SPCA508Driver.h"
#import "TV8532Driver.h"
#import "ZC030xDriver.h"
#import "CTDC1100Driver.h"
#import "KworldTV300UDriver.h"
#import "QuickCamVCDriver.h"
#import "OV519Driver.h"
#import "SonixDriver.h"

#include "unistd.h"


void DeviceAdded(void *refCon, io_iterator_t iterator);

static NSString* driverBundleName=@"net.sourceforge.webcam-osx.common";
static NSMutableDictionary* prefsDict=NULL;
MyCameraCentral* sharedCameraCentral=NULL;


@interface MyCameraCentral (Private)

//Internal preferences handling. We cannot use NSUserDefaults here because we might be in someone else's bundle (in a lib)
- (id) prefsForKey:(NSString*) key;
- (void) setPrefs:(id)prefs forKey:(NSString*)key;
- (void) registerCameraDriver:(Class)driver;
- (CameraError) locationIdOfUSBDeviceRef:(io_service_t)usbDeviceRef to:(UInt32*)outVal;

@end
    

@implementation MyCameraCentral


//MyCameraCentral is a singleton. Use this function to get the shared instance
+ (MyCameraCentral*) sharedCameraCentral {
    if (!sharedCameraCentral) sharedCameraCentral=[[MyCameraCentral alloc] init];
    return sharedCameraCentral;
}

//See if someone has requested MyCameraCentral before
+ (BOOL) isCameraCentralExisting {
    return (sharedCameraCentral!=NULL)?YES:NO;
}


//Localization for driver-specific stuff. As a component, the standard stuff won't work...

+ (NSString*) localizedStringFor:(NSString*) str {
    NSBundle* bundle=[NSBundle bundleForClass:[self class]];
    NSString* ret=[bundle localizedStringForKey:str value:@"" table:@"DriverLocalizable"];
    return ret;
}

+ (void) localizedCStrFor:(char*)cKey into:(char*)cValue {
    NSAutoreleasePool* pool;
    NSString* string;
    const char* tmpCStr;
    if (!cValue) return;
    if (!cKey) return;
    pool=[[NSAutoreleasePool alloc] init];
    string=[NSString stringWithCString:cKey];
    string=[self localizedStringFor:string];
    tmpCStr=[string lossyCString];
    CStr2CStr(tmpCStr,cValue);	//Note: No bounds check! Don't write dramas...
    [pool release];
}

- (char*) localizedCStrForError:(CameraError)err {
    char* cstr;
    switch (err) {
        case CameraErrorOK:
        case CameraErrorBusy:
        case CameraErrorNoPower:
        case CameraErrorNoCam:
        case CameraErrorNoMem:
        case CameraErrorNoBandwidth:
        case CameraErrorTimeout:
        case CameraErrorUSBProblem:
        case CameraErrorInternal:
            cstr=localizedErrorCStrs[err];
            break;
        default:
            cstr=localizedUnknownErrorCStr;
            break;
    }
    return cstr;
}
    

//Init, startup, shutdown, dealloc

- (id) init {
    [super init];
    cameraTypes=[[NSMutableArray alloc] initWithCapacity:10];
    cameras=[[NSMutableArray alloc] initWithCapacity:10];
    delegate=NULL;

    //Cache localized error codes
    [[self class] localizedCStrFor:"CameraErrorOK" into:localizedErrorCStrs[CameraErrorOK]];
    [[self class] localizedCStrFor:"CameraErrorBusy" into:localizedErrorCStrs[CameraErrorBusy]];
    [[self class] localizedCStrFor:"CameraErrorNoPower" into:localizedErrorCStrs[CameraErrorNoPower]];
    [[self class] localizedCStrFor:"CameraErrorNoCam" into:localizedErrorCStrs[CameraErrorNoCam]];
    [[self class] localizedCStrFor:"CameraErrorNoMem" into:localizedErrorCStrs[CameraErrorNoMem]];
    [[self class] localizedCStrFor:"CameraErrorNoBandwidth" into:localizedErrorCStrs[CameraErrorNoBandwidth]];
    [[self class] localizedCStrFor:"CameraErrorTimeout" into:localizedErrorCStrs[CameraErrorTimeout]];
    [[self class] localizedCStrFor:"CameraErrorUSBProblem" into:localizedErrorCStrs[CameraErrorUSBProblem]];
    [[self class] localizedCStrFor:"CameraErrorUnimplemented" into:localizedErrorCStrs[CameraErrorUnimplemented]];
    [[self class] localizedCStrFor:"CameraErrorInternal" into:localizedErrorCStrs[CameraErrorInternal]];
    [[self class] localizedCStrFor:"UnknownError" into:localizedUnknownErrorCStr];
    return self;
}

- (void) dealloc 
{
    [self shutdown];	//Make sure everything's shut down
    if (cameraTypes!=NULL) 
        [cameraTypes release]; 
    cameraTypes=NULL;
    
    if (cameras!=NULL) 
        [cameras release]; 
    cameras=NULL;
    
    [super dealloc]; // where is the constructor?
}

- (BOOL) startupWithNotificationsOnMainThread:(BOOL)nomt recognizeLaterPlugins:(BOOL)rlp{
    MyCameraInfo* 		info=NULL;
    long 			i;
    long 			numTestCameras=0;
    id 				obj=NULL;
    mach_port_t 		masterPort;
    CFMutableDictionaryRef 	matchingDict;
    CFRunLoopSourceRef		runLoopSource;
    CFNumberRef			numberRef;
    kern_return_t		ret;
    SInt32			usbVendor;
    SInt32			usbProduct;
    io_iterator_t		iterator;
    
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    assert(cameraTypes);
    assert(cameras);

    doNotificationsOnMainThread=nomt;
    recognizeLaterPlugins=rlp;
    
    //Add Driver classes (this is where we have to add new model classes!)
    [self registerCameraDriver:[MySPCA500Driver class]];
    [self registerCameraDriver:[MyAiptekPocketDV class]];
    [self registerCameraDriver:[MyKiaraFamilyDriver class]];
    [self registerCameraDriver:[MyKiaraFlippedDriver class]];
    [self registerCameraDriver:[MyTimonFamilyDriver class]];
    [self registerCameraDriver:[MyCPIACameraDriver class]];
    [self registerCameraDriver:[MyQX3Driver class]];
    [self registerCameraDriver:[MyQX5Driver class]];
    [self registerCameraDriver:[MySTV680Driver class]];
    [self registerCameraDriver:[MyQCExpressADriver class]];
    [self registerCameraDriver:[MyQCExpressBDriver class]];
    [self registerCameraDriver:[MyQCWebDriver class]];
    [self registerCameraDriver:[QCMessengerDriver class]];
    [self registerCameraDriver:[MyVicamDriver class]];
    [self registerCameraDriver:[MySPCA504Driver class]];
    [self registerCameraDriver:[MyOV511Driver class]];
    [self registerCameraDriver:[MyOV511PlusDriver class]];
    [self registerCameraDriver:[MySonix2028Driver class]];
	[self registerCameraDriver:[MyViviCam3350BDriver class]];
	[self registerCameraDriver:[MySwedaSSP09BDriver class]];
    [self registerCameraDriver:[MySE401Driver class]];
    [self registerCameraDriver:[MyQCProBeigeDriver class]];
#if EXPERIMENTAL
    [self registerCameraDriver:[QuickCamVCDriver class]];
#else
    [self registerCameraDriver:[MyQCVCDriver class]]; // Trying a different route
#endif
    [self registerCameraDriver:[MyQCOrbitDriver class]];
    [self registerCameraDriver:[SQ905 class]];
#if EXPERIMENTAL
    [self registerCameraDriver:[SQ930C class]];
#endif
//  [self registerCameraDriver:[MyPixartDriver class]]; // Deprecated in favor of PixartDriver - has problems
//  [self registerCameraDriver:[PixartDriver class]];   // Disabled because working on SPCA5XX-based version instead
#if EXPERIMENTAL
    [self registerCameraDriver:[PAC7311Driver class]];
//  [self registerCameraDriver:[OV518Driver class]];
//  [self registerCameraDriver:[OV518PlusDriver class]];
#endif
    [self registerCameraDriver:[OV519Driver class]];
    [self registerCameraDriver:[PAC207Driver class]];     // Based on SPCA5XX - seems to work pretty well
    [self registerCameraDriver:[SPCA561ADriver class]];   // Based on SPCA5XX - seems to work now
    [self registerCameraDriver:[TV8532Driver class]];     // Based on SPCA5XX - testing!
    [self registerCameraDriver:[ZC030xDriver class]];     // Based on SPCA5XX - testing!
    
    [self registerCameraDriver:[SPCA508Driver class]];  // Based on SPCA5XX - Works, but not too pretty
    [self registerCameraDriver:[SPCA508CS110Driver class]];
    [self registerCameraDriver:[SPCA508SightcamDriver class]];
    [self registerCameraDriver:[SPCA508Sightcam2Driver class]];
    [self registerCameraDriver:[SPCA508CreativeVistaDriver class]];
    
    [self registerCameraDriver:[SonixDriver class]];  // Based on SPCA5XX - Have no idea if it works
    [self registerCameraDriver:[SonixDriverVariant1 class]];
    [self registerCameraDriver:[SonixDriverVariant2 class]];
    [self registerCameraDriver:[SonixDriverVariant3 class]];
    [self registerCameraDriver:[SonixDriverVariant4 class]];
    [self registerCameraDriver:[SonixDriverVariant5 class]];
    [self registerCameraDriver:[SonixDriverVariant6 class]];
    [self registerCameraDriver:[SonixDriverVariant7 class]];
    [self registerCameraDriver:[SN9CxxxDriver class]];
    [self registerCameraDriver:[SN9CxxxDriverVariant1 class]];
    [self registerCameraDriver:[SN9CxxxDriverVariant2 class]];
    [self registerCameraDriver:[SN9CxxxDriverVariant3 class]];
    [self registerCameraDriver:[SN9CxxxDriverVariant4 class]];
    [self registerCameraDriver:[SN9CxxxDriverVariant5 class]];
    [self registerCameraDriver:[SN9CxxxDriverVariant6 class]];
    
#if EXPERIMENTAL
    [self registerCameraDriver:[CTDC1100Driver class]];      // This is incomplete st this time
    [self registerCameraDriver:[KworldTV300UDriver class]];  // This is very incomplete at this time
#endif
    
    
    //Get the IOKit master port (needed for communication with IOKit)
    ret = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (ret||(!masterPort)) { NSLog(@"MyCameraCentral: IOMasterPort failed (%08x)", ret); return NO;}

    //Get a notification port, get its event source and connect it to the current thread
    notifyPort = IONotificationPortCreate(masterPort);
    runLoopSource = IONotificationPortGetRunLoopSource(notifyPort);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);

    //Go through all our drivers and add plug-in notifications for them
    for (i=0;i<[cameraTypes count];i++) {

        //Get info about the current camera
        info=[cameraTypes objectAtIndex:i];
        if (info==NULL) { NSLog(@"MyCameraCentral:wiringThread: bad info"); return NO; }
        usbVendor =[info vendorID];
        usbProduct=[info productID];

        // Set up the matching criteria for the devices we're interested in
        matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
        if (!matchingDict) { NSLog(@"MyCameraCentral:IOServiceMatching failed"); return NO; }

        // Add our vendor and product IDs to the matching criteria
        numberRef = CFNumberCreate(kCFAllocatorDefault,kCFNumberSInt32Type,&usbVendor);
        CFDictionarySetValue(matchingDict,CFSTR(kUSBVendorID),numberRef);
        CFRelease(numberRef); numberRef=NULL;

        numberRef = CFNumberCreate(kCFAllocatorDefault,kCFNumberSInt32Type,&usbProduct);
        CFDictionarySetValue(matchingDict,CFSTR(kUSBProductID),numberRef);
        CFRelease(numberRef); numberRef=NULL;

        if (recognizeLaterPlugins) {
            //Request notification if matching devices are plugged in or...
            ret = IOServiceAddMatchingNotification(notifyPort,
                                                   kIOFirstMatchNotification,
                                                   matchingDict,
                                                   DeviceAdded,
                                                   info,
                                                   &iterator);
        } else {
            //... just get the currently connected devices
            ret = IOServiceGetMatchingServices(masterPort,
                                               matchingDict,
                                               &iterator);
            
        }
        if (ret==0) {
            //Get first devices and trigger notification process
            DeviceAdded(info, iterator);

            //If we don't later notifications, we can release the enumerator
            if (!recognizeLaterPlugins) {
                IOObjectRelease(iterator);
            }
        }
    }
    //Try to find out how many test cameras we have
    obj=[self prefsForKey:@"Dummy cameras"];
    if (obj) numTestCameras=[obj longValue];
    else numTestCameras=0;

    //Add the dummy test image cameras to the list of available cameras
    for (i=0;i<numTestCameras;i++) {
        info=[[MyCameraInfo alloc] init];
        [info setDriverClass:[MyDummyCameraDriver class]];
        [info setProductID:[MyDummyCameraDriver cameraUsbProductID]];
        [info setVendorID:[MyDummyCameraDriver cameraUsbVendorID]];
        [info setCameraName: [NSString stringWithFormat:@"%@ #%i", [MyDummyCameraDriver cameraName], i+1]];
        [info setCentral: self];
        [cameras addObject:info];
    }
    
    [pool release];
    return YES;
}

- (void) shutdown {
    MyCameraInfo* info;
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];	//Get a pool to catch the remaining drivers

    //shutdown all cameras
    while ([cameras count]>0) {
        info=[cameras lastObject];
        [cameras removeLastObject];
        //disconnect from the driver and autorelease our retain
        if ([info driver]!=NULL) {
            [[info driver] setCentral:NULL];
            [[info driver] shutdown];
        }
        [info release];
    }
    //This would be a great place to release all USB notifications *****

    //release cameryTypes cameraInfos
    while ([cameraTypes count]>0) {
        info=[cameraTypes lastObject];
        [cameraTypes removeLastObject];
        [info release];
    }
    [pool release];
}

- (id) delegate {
    return delegate;
}

- (void) setDelegate:(id)d {
    delegate=d;
}

- (BOOL) doNotificationsOnMainThread {
    return doNotificationsOnMainThread;
}

- (short) numCameras {
    return [cameras count];
}

- (short) indexOfCamera:(MyCameraDriver*)driver {
    short i=0;
    while (i<[cameras count]) {
        if ([[cameras objectAtIndex:i] driver]==driver) return i;
        else i++;
    }
    return -1;
}

- (unsigned long) idOfCameraWithIndex:(short)idx {
    if ((idx<0)||(idx>=[self numCameras])) return 0;
    return [[cameras objectAtIndex:idx] cid];
}

- (unsigned long) idOfCameraWithLocationID:(UInt32)locID {
    short i;
    for (i=0;i<[cameras count];i++) {
        if ([[cameras objectAtIndex:i] locationID]==locID) return [[cameras objectAtIndex:i] cid];
    }
    return 0;    
}

- (CameraError) useCameraWithID:(unsigned long)cid to:(MyCameraDriver**)outCam acceptDummy:(BOOL)acceptDummy {
    long l;
    MyCameraInfo* dev=NULL;
    MyCameraDriver* cam=NULL;
    CameraError err=CameraErrorOK;
    if (outCam) *outCam=NULL;
    for (l=0;(l<[cameras count])&&(dev==NULL);l++) {
        dev=[cameras objectAtIndex:l];
        if ([dev cid]!=cid) dev=NULL;
    }
    if (dev==NULL) {
#ifdef VERBOSE
        NSLog(@"MyCameraCentral: cid not found");
#endif
        err=CameraErrorInternal;
    }
    if (!err) {
        if ([dev driver]) err=CameraErrorBusy;
    }
    if (!err) {
        cam=[[[dev driverClass] alloc] initWithCentral:self];
        if (!cam) {
#ifdef VERBOSE
            NSLog(@"MyCameraCentral: could not instantiate driver");
#endif
            err=CameraErrorNoMem;
        }
    }
    if (!err) {
        [cam setDelegate:delegate];
        err=[cam startupWithUsbLocationId:[dev locationID]];
        if (err!=CameraErrorOK) {
            [cam release];
            cam=NULL;
        }
    }
    if (err&&acceptDummy) {	//We have an error and the sender wants a dummy in case of an error
        cam=[self useDummyForError:err];
    }
    if (cam!=NULL) {
        [dev setDriver:cam];
        [cam setCameraInfo:dev];
        [self setCameraToDefaults:cam];
        if (outCam) *outCam=cam;
    }
    return err;
}

- (MyCameraDriver*) useDummyForError:(CameraError)err {
    MyCameraDriver* driver=[[MyDummyCameraDriver alloc] initWithError:err central:self];
    if (driver) {
        [driver setDelegate:delegate];
        [driver startupWithUsbLocationId:0];
    }
    return driver;
}

- (NSString*) nameForID:(unsigned long)cid {
    long l=0;
    while (l<[cameras count]) {
        if ([[cameras objectAtIndex:l] cid]==cid) {
            return [[cameras objectAtIndex:l] cameraName];
        } else {
            l++;
        }
    }
    return NULL;
}

- (NSString*) nameForDriver:(MyCameraDriver*)driver {
    long l=0;
    while (l<[cameras count]) {
        if ([[cameras objectAtIndex:l] driver]==driver) {
            return [[cameras objectAtIndex:l] cameraName];
        } else l++;
    }
    return NULL;
}

- (BOOL) getName:(char*)name forID:(unsigned long)cid {
    NSString* camName=[self nameForID:cid];
    if (!camName) return NO;
    [camName getCString:name];
    return YES;
}

- (BOOL) getName:(char*)name forDriver:(MyCameraDriver*)driver {
    NSString* camName=[self nameForDriver:driver];
    if (!camName) return NO;
    [camName getCString:name];
    return YES;
}

/*These functions read and write the camera settings. We cannot use the direct user defaults mechanism because we're sometimes a client in another app and we don't want to mess up the app's preferences. So we use the lower-level persistentDomainForName mechanism. */

- (BOOL) setCameraToDefaults:(MyCameraDriver*) cam {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    BOOL ok=YES;
    short idx;
    unsigned long cid;
    NSDictionary* camDict;
    if (ok) {
        if (!cam) ok=NO;
    }
    if (ok) {
        idx=[self indexOfCamera:cam];
        if (idx<0) ok=NO;		//This camera is not listed as connected
    }
    if (ok) {
        cid=[self idOfCameraWithIndex:idx];
        if (cid<1) ok=NO;		//This camera has no cid (should not happen ever)
    }
    if (ok) {
        //We use the driver class instead of the camera name to prevent differences due to localization
        camDict=[self prefsForKey:NSStringFromClass([[cameras objectAtIndex:idx] driverClass])];
        if (!camDict) ok=NO;		//There are no defaults for the camera listed
    }
    if (ok) {
        if ([camDict objectForKey:@"brightness"])
            [cam setBrightness:[[camDict objectForKey:@"brightness"] floatValue]];
        if ([camDict objectForKey:@"contrast"])
            [cam setContrast:[[camDict objectForKey:@"contrast"] floatValue]];
        if ([camDict objectForKey:@"saturation"])
            [cam setSaturation:[[camDict objectForKey:@"saturation"] floatValue]];
        if ([camDict objectForKey:@"gamma"])
            [cam setGamma:[[camDict objectForKey:@"gamma"] floatValue]];
        if ([camDict objectForKey:@"sharpness"])
            [cam setSharpness:[[camDict objectForKey:@"sharpness"] floatValue]];
        if ([camDict objectForKey:@"gain"])
            [cam setGain:[[camDict objectForKey:@"gain"] floatValue]];
        if ([camDict objectForKey:@"shutter"])
            [cam setShutter:[[camDict objectForKey:@"shutter"] floatValue]];
        if ([camDict objectForKey:@"autogain"])
            [cam setAutoGain:[[camDict objectForKey:@"autogain"] boolValue]];
        if ([camDict objectForKey:@"hflip"])
            [cam setHFlip:[[camDict objectForKey:@"hflip"] boolValue]];
        if ([camDict objectForKey:@"compression"])
            [cam setCompression:[[camDict objectForKey:@"compression"] shortValue]];
        if ([camDict objectForKey:@"resolution"]&&[camDict objectForKey:@"fps"])
            [cam setResolution:[[camDict objectForKey:@"resolution"] shortValue] fps:[[camDict objectForKey:@"fps"] shortValue]];
       	if ([camDict objectForKey:@"white balance"])
            [cam setWhiteBalanceMode:(WhiteBalanceMode)[[camDict objectForKey:@"white balance"] shortValue]];
    }
    [pool release];
    return ok;
}

- (BOOL) saveCameraSettingsAsDefaults:(MyCameraDriver*) cam {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    BOOL ok=YES;
    short idx;
    unsigned long cid;
    NSMutableDictionary* camDict;
    if (ok) {
        if (!cam) ok=NO;
    }
    if (ok) {
        idx=[self indexOfCamera:cam];
        if (idx<0) ok=NO;		//This camera is not listed as connected
    }
    if (ok) {
        cid=[self idOfCameraWithIndex:idx];
        if (cid<1) ok=NO;		//This camera has no cid (should not happen ever)
    }
    if (ok) {
        camDict=[NSMutableDictionary dictionaryWithCapacity:11];
        if (!camDict) ok=NO;
    }
    if (ok) {
        if ([cam canSetBrightness])
            [camDict setObject:[NSNumber numberWithFloat:[cam brightness]] forKey:@"brightness"];
        if ([cam canSetContrast])
            [camDict setObject:[NSNumber numberWithFloat:[cam contrast]] forKey:@"contrast"];
        if ([cam canSetSaturation])
            [camDict setObject:[NSNumber numberWithFloat:[cam saturation]] forKey:@"saturation"];
        if ([cam canSetGamma])
            [camDict setObject:[NSNumber numberWithFloat:[cam gamma]] forKey:@"gamma"];
        if ([cam canSetSharpness])
            [camDict setObject:[NSNumber numberWithFloat:[cam sharpness]] forKey:@"sharpness"];
        if ([cam canSetGain])
            [camDict setObject:[NSNumber numberWithFloat:[cam gain]] forKey:@"gain"];
        if ([cam canSetShutter])
            [camDict setObject:[NSNumber numberWithFloat:[cam shutter]] forKey:@"shutter"];
        if ([cam canSetAutoGain])
            [camDict setObject:[NSNumber numberWithBool:[cam isAutoGain]] forKey:@"autogain"];
        if ([cam canSetHFlip])
            [camDict setObject:[NSNumber numberWithBool:[cam hFlip]] forKey:@"hflip"];
        if ([cam maxCompression]>0)
            [camDict setObject:[NSNumber numberWithShort:[cam compression]] forKey:@"compression"];
        if ([cam canSetWhiteBalanceMode])
            [camDict setObject:[NSNumber numberWithShort:(short)[cam whiteBalanceMode]] forKey:@"white balance"];
        
        [camDict setObject:[NSNumber numberWithShort:[cam resolution]] forKey:@"resolution"];
        [camDict setObject:[NSNumber numberWithShort:[cam fps]] forKey:@"fps"];
        //We use the driver class instead of the camera name to prevent differences due to localization
        [self setPrefs:camDict forKey:NSStringFromClass([[cameras objectAtIndex:idx] driverClass])];
    }
    [pool release];
    return ok;
}

void DeviceRemoved( void *refCon,io_service_t service,natural_t messageType,void *messageArgument ) {
    MyCameraInfo* dev=(MyCameraInfo*)refCon;
    if (messageType!=kIOMessageServiceIsTerminated) return;
    if (dev==NULL) {
#ifdef VERBOSE
        NSLog(@"MaCameraCentral:DeviceRemoved: bad refCon");
#endif
    } else {
        if ([dev driver]) [[dev driver] stopUsingUSB];	//Pass the info to the driver as fast as possible
        [[dev central] deviceRemoved:[dev cid]];
    }
}
    
- (void) deviceRemoved:(unsigned long)cid {
    kern_return_t	ret;
    long l;
    MyCameraInfo* dev=NULL;

    //remove the device in the cameras list
    for (l=0;l<[cameras count];l++) {
        if ([[cameras objectAtIndex:l] cid]==cid) {
            dev=[cameras objectAtIndex:l];
            [cameras removeObjectAtIndex:l];
        }
    }
    if (!dev) {
#ifdef VERBOSE
        NSLog(@"MyCameraInfo:deviceRemoved: Tried to unregister a device not registered");
#endif
        return;	//We didn't find the camera
    }
    //Release the usb stuff
    ret = IOObjectRelease([dev notification]);		//we don't need the usb notification any more
//Initiate the driver shutdown.
    if ([dev driver]!=NULL) {
        [[dev driver] shutdown];	//We don't release it here - it is done in the cameraHasShutDown notification
        [dev release];			//we still own it since we did not autorelease in [cameraAdded]
    }
}

void DeviceAdded(void *refCon, io_iterator_t iterator) {
    MyCameraInfo* info=(MyCameraInfo*)refCon;
    if (info!=NULL) {
        [[info central] deviceAdded:iterator info:info];
    }
}

- (void) deviceAdded:(io_iterator_t)iterator info:(MyCameraInfo*)type {
    kern_return_t	ret;
    io_service_t	usbDeviceRef;
    MyCameraInfo*	dev;
    io_object_t		notification;
    while (usbDeviceRef = IOIteratorNext(iterator)) {
        UInt32 locID;
        
        //Setup our data object we use to track the device while it is plugged
        dev=[type copy];
        if (!dev) {
#ifdef VERBOSE
            NSLog(@"Could not copy MyCameraInfo object on insertion of a device");
#endif
            continue;
        }

        //Request notification if the device is unplugged
        ret = IOServiceAddInterestNotification(notifyPort,
                                               usbDeviceRef,
                                               kIOGeneralInterest,
                                               DeviceRemoved,
                                               dev,
                                               &notification);
        if (ret!=KERN_SUCCESS) {
#ifdef VERBOSE
            NSLog(@"IOServiceAddInterestNotification returned %08x\n",ret);
#endif
            [dev release];
            continue;
        }
        //Try to find our USB location ID
        if ([self locationIdOfUSBDeviceRef:usbDeviceRef to:&locID]!=CameraErrorOK) {
#ifdef VERBOSE
            NSLog(@"failed to get location id");
#endif
            [dev release];
            continue;
        }
        //Remember the notification (we have to release it later)
        [dev setNotification:notification];
        [dev setLocationID:locID];

        //Put the new entry to the list of available cameras
        [cameras addObject:dev];

        //Spread the news that a camera was plugged in
        [self cameraDetected:[dev cid]];
    }
}

- (void) cameraDetected:(unsigned long) cid {
    if (delegate) {
        if ([delegate respondsToSelector:@selector(cameraDetected:)]) {
            [delegate cameraDetected:cid];
        }
    }
}

- (void) cameraHasShutDown:(id)sender {
    long i;
    MyCameraInfo* info;
    for(i=0;i<[cameras count];i++) {
        info=[cameras objectAtIndex:i];
        if ([info driver]==sender) {
            [info setDriver:NULL];	//If it's still in the list: mark it as available
        }
    }
    [sender autorelease];		//We clear our reference to that driver. When we receive this, we have built it.
}



- (id) prefsForKey:(NSString*) key {
    id val=NULL;
    if (!key) return NULL;		//No key, no value
    if (!prefsDict) {			//No prefs there. Try to load prefs file.
        NSString* pathName=[[NSString stringWithFormat:@"~/Library/Preferences/%@.plist",driverBundleName] stringByExpandingTildeInPath];
        NSDictionary* dict;
        dict=[NSDictionary dictionaryWithContentsOfFile:pathName];
        if (dict) prefsDict=[dict mutableCopy];
    }
    if (!prefsDict) {			//No file there. Try to open a new one
        prefsDict=[[NSMutableDictionary alloc] initWithCapacity:3];
    }
    if (!prefsDict) return NULL;	//Still no prefs dict there - give up
    val=[prefsDict objectForKey:key];
    if (!val) return NULL;		//No value for that key
    val=[val copy];
    if (!val) return NULL;		//Probably no mem or some non-copying object (could that happen? I guess not)
    [val autorelease];
    return val;
}

- (void) setPrefs:(id)value forKey:(NSString*)key {
    NSString* pathName;
    if (!key) return;			//No key, no change
    [self prefsForKey:key];		//Ensure the prefs are loaded
    if (!prefsDict) return;		//Still no prefs? Give up.
//Do the change
    if (value) {
        [prefsDict setObject:[[value copy] autorelease] forKey:key];
    } else {
        [prefsDict removeObjectForKey:key];
    }
//Write to file
    pathName=[[NSString stringWithFormat:@"~/Library/Preferences/%@.plist",driverBundleName] stringByExpandingTildeInPath];
    [prefsDict writeToFile:pathName atomically:YES];
}

- (void) registerCameraDriver:(Class)driver {
    NSArray* arr=[driver cameraUsbDescriptions];
    int i;
    for (i=0;i<[arr count];i++) {
        NSDictionary* dict=[arr objectAtIndex:i];
        MyCameraInfo* info=[[MyCameraInfo alloc] init];
        if (info!=NULL) {
            [info setCameraName:[dict objectForKey:@"name"]];
            [info setVendorID:[[dict objectForKey:@"idVendor"] unsignedShortValue]];
            [info setProductID:[[dict objectForKey:@"idProduct"] unsignedShortValue]];
            [info setDriverClass:driver];
            [info setCentral: self];
            [cameraTypes addObject:info];
        }
    }
}

- (CameraError) locationIdOfUSBDeviceRef:(io_service_t)usbDeviceRef to:(UInt32*)outVal {
    UInt32 locID=0;
    kern_return_t kernelErr;
    SInt32 score;
    IOCFPlugInInterface **plugin=NULL;
    CameraError err=CameraErrorOK;
    HRESULT res;
    IOUSBDeviceInterface** dev=NULL;

    kernelErr = IOCreatePlugInInterfaceForService(usbDeviceRef, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);

    if ((kernelErr!=kIOReturnSuccess)||(!plugin)) {
#ifdef VERBOSE
        NSLog(@"MyCameraCentral: IOCreatePlugInInterfaceForService; Could not get plugin");
#endif
        return CameraErrorUSBProblem;
    }
    if (!err) {
        res=(*plugin)->QueryInterface(plugin,CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),(LPVOID*)(&dev));
        (*plugin)->Release(plugin);
        plugin=NULL;
        if ((res)||(!dev)) {
#ifdef VERBOSE
            NSLog(@"MyCameraCentral: IOCreatePlugInInterfaceForService; Could not get device interface");
#endif
            err=CameraErrorUSBProblem;
        }
    }
    if (!err) {
        kernelErr = (*dev)->GetLocationID(dev,&locID);
        (*dev)->Release(dev);
        if (kernelErr!=KERN_SUCCESS) {
#ifdef VERBOSE
            NSLog(@"MyCameraCentral: IOCreatePlugInInterfaceForService; Could not get Location ID");
#endif
            err=CameraErrorUSBProblem;
        }
    }
    if (outVal) {
        if (!err) *outVal=locID;
        else *outVal=0;
    }
    return err;
}


    
    

@end
