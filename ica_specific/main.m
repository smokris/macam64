
#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>
#include <Carbon/Carbon.h>
#include <CoreServices/CoreServices.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <mach/mach.h>
#include "ICD_CameraCalls.h"

#include "GlobalDefs.h"
#import "MyCameraCentral.h"
#import "MyCameraDriver.h"

#include <unistd.h>	//sleep()

//---------------------------------------------
// Dummy delegate

@interface MyDriverDelegate:NSObject
{}
- (void) imageReady:(id)cam;
- (void) grabFinished:(id)cam withError:(CameraError*)err;
- (void)cameraHasShutDown:(id)cam;
- (void) cameraEventHappened:(id)sender event:(CameraEvent)evt;
@end
@implementation MyDriverDelegate
- (void) imageReady:(id)cam {}
- (void) grabFinished:(id)cam withError:(CameraError*)err {}
- (void)cameraHasShutDown:(id)cam {}
- (void) cameraEventHappened:(id)sender event:(CameraEvent)evt {}
@end

//---------------------------------------------

//---------------------------------------------
// Private data structure

typedef struct MyICAPrivateData {
    MyCameraDriver* driver;
    NSMutableDictionary* fileCache;
    long numFiles;
    BOOL cacheValid;
} MyICAPrivateData;

//---------------------------------------------

//---------------------------------------------
// Tool functions

void CheckCache(MyICAPrivateData* data);
void CacheFile(MyICAPrivateData* data,long index);
void CacheFileInfo(MyICAPrivateData* data,long index);

//---------------------------------------------

//---------------------------------------------
// Globals

mach_port_t		g_masterPort = 0;
MyCameraCentral* 	central=NULL;
MyDriverDelegate*	delegate;

//---------------------------------------------

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_OpenDevice
//	When a device is plugged in, the ICNotification service launches the camera app that matches
//	the characteristics of the device (see project file's Application Setting, the devices array
//	and the interface array).  The camera app (ICACameraPriv.framework) will call into this hook
//	with the location id of the new device.  This routine should use this id to locate the new device
//	and return information about the device in an objectInfo structure.  The camera app framework
//	will use this information to create a device object for this device.
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_OpenDevice(UInt32 locationID, ObjectInfo * objectInfo)
{
    MyICAPrivateData* data;
    OSErr err=noErr;

    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];

    //Fill object info with defaults
    objectInfo->uniqueID = locationID;
    objectInfo->flags = 0;
    objectInfo->thumbnailSize = 0;
    objectInfo->dataSize = 0;
    sprintf(objectInfo->name,"Macam camera");
    objectInfo->icaObjectInfo.objectType = kICADevice;
    objectInfo->icaObjectInfo.objectSubtype = kICADeviceCamera;

 //Try to get private data
    MALLOC(data,MyICAPrivateData*,sizeof(MyICAPrivateData),"ICA private data struct");
    objectInfo->privateData = (Ptr)data;
    if (!data) err=memFullErr;
    if (err==noErr) {
        data->driver=NULL;
        data->numFiles=0;
        data->cacheValid=NO;
        data->fileCache=[[NSMutableDictionary alloc] initWithCapacity:100];
        if (!(data->fileCache)) err=memFullErr;
    }

    //Open connection to camera
    if (!err) {
        if (!central) err=memFullErr;
    }
    if (!err) {
        unsigned long cid=[central idOfCameraWithLocationID:locationID];
        MyCameraDriver* driver;
        CameraError camErr=[central useCameraWithID:cid to:&driver acceptDummy:NO];
        if (camErr!=CameraErrorOK) {
            err=kICADeviceNotFoundErr;
        } else data->driver=driver;
    }
    //Cleanup if error
    if (err) {
        if (data) {
            if (data->driver) {
                [(data->driver) shutdown];
                [(data->driver) release];
                data->driver=NULL;
            }
            if (data->fileCache) {
                [(data->fileCache) release];
                data->fileCache=NULL;
            }
            FREE(data,"ICA private data struct");
            data=NULL;
        }
    }

    [pool release];
    return err;
}

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_CloseDevice
//	We are done with the device.  All device related resources should be de-allocated.
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_CloseDevice(ObjectInfo * objectInfo)
{
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];

    if (objectInfo) {
        MyICAPrivateData* data=(MyICAPrivateData*)(objectInfo->privateData);
        if (data) {
            if (data->driver) {
                [(data->driver) shutdown];
                data->driver=NULL;
            }
            if (data->fileCache) {
                [(data->fileCache) release];
                data->fileCache=NULL;
            }
            FREE(data,"ICA private data struct");
            data=NULL;
        }
        objectInfo->privateData=NULL;
    }
 
    [pool release];
    return noErr;
}

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_PeriodicTask
//	This hook is called at fixed intervals.  You can use this hook to poll or check the status
//	of your device.
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_PeriodicTask(ObjectInfo * objectInfo)
{
    return noErr;
}

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_GetObjectInfo
//	This hook gets called in 2 ways:
//	1. When a device is plugged in, the camera app use this call to enumerate/iterate thru all the
//	image/video/audeo files on the device.  The enumeration process terminates when the hook returns
//	an err (kICAIndexOutOfRangeErr).
//	2. After the file enumeration is done, the hooks can still get called when a new file is created
//	on the device (e.g. via capturing a new image).
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_GetObjectInfo(const ObjectInfo * parentInfo,
                         UInt32				index,
                         ObjectInfo *		newInfo)
{
    MyICAPrivateData* data;
    NSDictionary* fileInfo;
    NSString* key;
    OSErr err=noErr;
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];

    data=(MyICAPrivateData*)(parentInfo->privateData);
    key=[NSString stringWithFormat:@"%i",index];
    CheckCache(data);
    if (index>=(data->numFiles)) err=kICAIndexOutOfRangeErr;
    if (!err) {
        CacheFileInfo(data,index);
        fileInfo=[(data->fileCache) objectForKey:key];
        if (!fileInfo) err=kICAFileCorruptedErr;
    }
    if (!err) {
        newInfo->uniqueID = index;
        newInfo->privateData = (Ptr)data;
        newInfo->flags = 0;
        newInfo->thumbnailSize=0;
        newInfo->dataSize = [[fileInfo objectForKey:@"size"] longValue];
        newInfo->dataWidth =[[fileInfo objectForKey:@"width"] longValue];
        newInfo->dataHeight = [[fileInfo objectForKey:@"height"] longValue];
        sprintf(newInfo->name,"Macam image");
        sprintf(newInfo->creationDate, "%s",
                [[[NSDate date] descriptionWithCalendarFormat:@"%Y:%m:%d %H:%M:%S" timeZone:nil locale:nil] cString]);
        newInfo->icaObjectInfo.objectType = kICAFile;
        newInfo->icaObjectInfo.objectSubtype = kICAFileImage;
    }
    [pool release];
    return err;
}

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_Cleanup
//	This hook is called when a file object is no longer needed.  All resources allocated for this
//	file object should be de-allocated.
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_Cleanup(ObjectInfo * objectInfo)
{
    return noErr;
}

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_GetPropertyData
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_GetPropertyData(const ObjectInfo * objectInfo,
                           ICD_GetPropertyDataPB	* pb)
{
    return ICDGetStandardPropertyData(objectInfo, pb);
}

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_SetPropertyData
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_SetPropertyData(const ObjectInfo * objectInfo,
                           const ICD_SetPropertyDataPB * pb)
{
    return unimpErr;
}

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_ReadFileData
//	This hook implements the standard mechanism to read file data or thumbnail data of a file object.
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_ReadFileData(const ObjectInfo *	objectInfo,
                        UInt32				dataType,
                        Ptr					buffer,
                        UInt32				offset,
                        UInt32 *			length)
{
    OSErr err=noErr;
    MyICAPrivateData* privateData;
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];

    privateData=(MyICAPrivateData*)(objectInfo->privateData);
    if (dataType==kICD_FileData) {
        long index=objectInfo->uniqueID;
        NSString* key=[NSString stringWithFormat:@"%i",index];
        NSData* data;
        CacheFile(privateData,index);
        data=[[(privateData->fileCache) objectForKey:key] objectForKey:@"data"];
        if (data) {
            long size=[data length];
            if (offset>=size) err=paramErr;
            else {
                if ((offset+(*length))>size) *length=size-offset;
                memcpy(buffer,[data bytes]+offset,*length);
            }
        } else err=kICAFileCorruptedErr;
    } else err=unimpErr;

    [pool release];
    return err;
}

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_WriteFileData
//	When implemented, can be used to upload file to the device.
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_WriteFileData(const ObjectInfo *	objectInfo,
                         UInt32		dataType,
                         Ptr		buffer,
                         UInt32		offset,
                         UInt32 *	length)
{
    return unimpErr;
}

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_SendMessage
//	Message are used to control the device.  Some standard messages include:
//	- kICAMessageCameraCaptureNewImage: capturing a new image
//	- kICAMessageCameraDeleteOne: deleting a file
//	- kICAMessageCameraSyncClock: setting the date and time on the device
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_SendMessage (const ObjectInfo * 			objectInfo,
                        ICD_ObjectSendMessagePB * 	pb,
                        ICDCompletion           	completion)
{
    OSErr err = noErr;
    CameraError camErr = CameraErrorOK;
    MyICAPrivateData* data;
    MyCameraDriver* driver;
    
    data=(MyICAPrivateData*)(objectInfo->privateData);
    if (!data) return paramErr;
    driver=(data->driver);
    if (!driver) return paramErr;
    
    switch (pb->message.messageType) {
        case kICAMessageCameraCaptureNewImage:
            camErr=[driver captureOne];
            if (camErr!=CameraErrorOK) err=kICACommunicationErr;
            else err=ICDStatusChanged(objectInfo->icaObject, kICAMessageCameraCaptureNewImage);
            break;
        case kICAMessageCameraDeleteAll:
            camErr=[driver deleteAll];
            if (camErr!=CameraErrorOK) err=kICACommunicationErr;
            else err=ICDStatusChanged(objectInfo->icaObject, kICAMessageCameraDeleteAll);
            break;
        default:
            err = paramErr;
            break;
    }
    pb->result = err;
    pb->header.err = err;
    if ((err==noErr)&&(completion!=NULL)) completion((ICDHeader*)pb);
    return err;

}

//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
// _ICD_AddPropertiesToCFDictionary
//	This hook addes the device capability information to the device's dictionary.
//	Note that we query the device on the fly to determine it's capabilities.
//ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
OSErr _ICD_AddPropertiesToCFDictionary(ObjectInfo * 			objectInfo,
                                       CFMutableDictionaryRef  	dict)
{
    OSErr err=noErr;
    NSMutableArray* array=NULL;
    NSNumber* number=NULL;
    MyICAPrivateData* data=(MyICAPrivateData*)(objectInfo->privateData);
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    if (!data) {err=paramErr; goto bail;}
    if (!(data->driver)) {err=paramErr; goto bail;}

    array=[[NSMutableArray alloc] initWithCapacity:10];
    if (!array) {err=memFullErr; goto bail;}
    if ([(data->driver) canDeleteAll]) {
        number=[[NSNumber alloc] initWithLong:kICAMessageCameraDeleteAll];
        if (!number) {err=memFullErr; goto bail;}
        [array addObject:number];
        [number release];
    }
    if ([(data->driver) canCaptureOne]) {
        number=[[NSNumber alloc] initWithLong:kICAMessageCameraCaptureNewImage];
        if (!number) {err=memFullErr; goto bail;}
        [array addObject:number];
        [number release];
    }
    
bail:
    if (array) {
        [(NSMutableDictionary*)dict setObject:array forKey:@"capa"];
        [array release];
    }
    [pool release];
    return err;
}



//----------------------------------------------------------------
//	main							   
//----------------------------------------------------------------
int main (int argc, const char * argv[])
{
    
    gICDCallbackFunctions.f_ICD_OpenUSBDevice			= _ICD_OpenDevice;
    gICDCallbackFunctions.f_ICD_CloseDevice			= _ICD_CloseDevice;
    gICDCallbackFunctions.f_ICD_PeriodicTask			= _ICD_PeriodicTask;
    gICDCallbackFunctions.f_ICD_GetObjectInfo			= _ICD_GetObjectInfo;
    gICDCallbackFunctions.f_ICD_Cleanup				= _ICD_Cleanup;
    gICDCallbackFunctions.f_ICD_GetPropertyData			= _ICD_GetPropertyData;
    gICDCallbackFunctions.f_ICD_SetPropertyData			= _ICD_SetPropertyData;
    gICDCallbackFunctions.f_ICD_ReadFileData			= _ICD_ReadFileData;
    gICDCallbackFunctions.f_ICD_WriteFileData			= _ICD_WriteFileData;
    gICDCallbackFunctions.f_ICD_SendMessage			= _ICD_SendMessage;
    gICDCallbackFunctions.f_ICD_AddPropertiesToCFDictionary	= _ICD_AddPropertiesToCFDictionary;
    gICDCallbackFunctions.f_ICD_AddPropertiesToCFDictionary	= _ICD_AddPropertiesToCFDictionary;
    //Init QuickTime
    EnterMovies();
    //Init camera central
    central=[[MyCameraCentral alloc] init];
    delegate=[[MyDriverDelegate alloc] init];
    [central setDelegate:delegate];
    if (central) {
        if (![central startupWithNotificationsOnMainThread:YES recognizeLaterPlugins:YES]) {
            [central release];
            central=NULL;
        }
    }
    
    return ICD_main(argc, argv);
}


void CheckCache(MyICAPrivateData* data) {
    if (!data) return;
    if (data->cacheValid) return;
    if (data->fileCache) [(data->fileCache) removeAllObjects];
    data->numFiles=0;
    data->cacheValid=YES;
    if (!(data->driver)) return;
    if (!([(data->driver) canStoreMedia])) return;
    data->numFiles=[(data->driver) numberOfStoredMediaObjects];
}

void CacheFile(MyICAPrivateData* data,long index) {
    NSMutableDictionary* cache;
    NSMutableDictionary* fileInfo;
    NSString* key=[NSString stringWithFormat:@"%i",index];
    BOOL needToCache=NO;
    
    if (!data) return;
    CheckCache(data);

    cache=data->fileCache;
    fileInfo=[cache objectForKey:key];
    if (!fileInfo) needToCache=YES;	//Cache if there's no info at all or
    else {				//... if there's info but no ...
        if ([fileInfo objectForKey:@"data"]==NULL) needToCache=YES;	//... data
        if ([fileInfo objectForKey:@"type"]==NULL) needToCache=YES;	//... type
        if ([fileInfo objectForKey:@"size"]==NULL) needToCache=YES;	//... size
        if ([fileInfo objectForKey:@"width"]==NULL) needToCache=YES;	//... width
        if ([fileInfo objectForKey:@"height"]==NULL) needToCache=YES;	//... height
    }
        
    if (needToCache) {
        fileInfo=[[[(data->driver) getStoredMediaObject:index] mutableCopy] autorelease];
        if (fileInfo) {
            NSString* type=[fileInfo objectForKey:@"type"];
            if ([type isEqualToString:@"jpeg"]) {
                NSData* data=[fileInfo objectForKey:@"data"];
                NSBitmapImageRep* ir=[[[NSBitmapImageRep alloc] initWithData:data] autorelease];
                [fileInfo setObject:[NSNumber numberWithLong:[data length]] forKey:@"size"];
                [fileInfo setObject:[NSNumber numberWithLong:[ir pixelsWide]] forKey:@"width"];
                [fileInfo setObject:[NSNumber numberWithLong:[ir pixelsHigh]] forKey:@"height"];
            } else if ([type isEqualToString:@"bitmap"]) {
                NSBitmapImageRep* ir=[fileInfo objectForKey:@"data"];
                NSData* tiffData=[ir TIFFRepresentation];
                [fileInfo setObject:[NSNumber numberWithLong:[ir pixelsWide]] forKey:@"width"];
                [fileInfo setObject:[NSNumber numberWithLong:[ir pixelsHigh]] forKey:@"height"];
                [fileInfo setObject:[NSNumber numberWithLong:[tiffData length]] forKey:@"size"];
                [fileInfo setObject:tiffData forKey:@"data"];
                [fileInfo setObject:@"tiff" forKey:@"type"];

            } else {
                [[fileInfo retain] release];
                fileInfo=NULL;
            }
            if (fileInfo) {
                [cache setObject:fileInfo forKey:key];
            }
        }
    }
}

void CacheFileInfo(MyICAPrivateData* data,long index) {
    NSMutableDictionary* cache;
    NSMutableDictionary* fileInfo;
    NSDictionary* origInfo;
    NSString* key=[NSString stringWithFormat:@"%i",index];
    BOOL needToCache=NO;

    if (!data) return;
    CheckCache(data);

    cache=data->fileCache;
    fileInfo=[cache objectForKey:key];
    if (!fileInfo) needToCache=YES;	//Cache if there's no info at all or
    else {				//... if there's info but no ...
        if ([fileInfo objectForKey:@"type"]==NULL) needToCache=YES;	//... type
        if ([fileInfo objectForKey:@"width"]==NULL) needToCache=YES;	//... width
        if ([fileInfo objectForKey:@"height"]==NULL) needToCache=YES;	//... height
    }

    if (needToCache) {							//info cahing
        if ([(data->driver) canGetStoredMediaObjectInfo]) {		//Get info
            origInfo=[(data->driver) getStoredMediaObjectInfo:index];	//Get info
            if (origInfo) {						//If we got info successfully
                fileInfo=[[origInfo mutableCopy] autorelease];		//copy it
                if (fileInfo) {						//If the copy is ok
                    NSNumber* size=[fileInfo objectForKey:@"size"];	//Test if size is there
                    if (!size) {					//missing? do an own guess
                        long width=[[fileInfo objectForKey:@"width"] longValue];
                        long height=[[fileInfo objectForKey:@"height"] longValue];
                        long size=5*width*height+100000;		//That should be enough...
                        [fileInfo setObject:[NSNumber numberWithLong:size] forKey:@"size"];	//add it
                    }
                    [cache setObject:fileInfo forKey:key];
                    needToCache=NO;
                }
            }
        }
    }
    if (needToCache) {	//We needed info, but the quick way didn't work
        CacheFile(data,index);
    }
}
