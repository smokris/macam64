//
//  SQ905.h
//  macam
//
//  Created by Harald Ruda on 9/19/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "MyCameraDriver.h"
#include "BayerConverter.h"


// Constants and enums applicable to this driver onlly

#define     REGISTER_CLEAR      0xa0

#define     COMMAND_CAPTURE     0x61
#define     COMMAND_REQUEST     0x0c
#define     COMMAND_ZERO        0x00
#define     COMMAND_ID          0xf0
#define     COMMAND_CONFIG      0x20
#define     COMMAND_DATA        0x30
#define     COMMAND_GET         0xc1
#define     COMMAND_SIZE        0x50

typedef enum 
{
    SQ_MODEL_POCK_CAM_ETC,
    SQ_MODEL_PRECISION_MINI,
    SQ_MODEL_MAGPIX_B350_BINOCULARS,
    SQ_MODEL_ARGUS_DC_1510_ETC,
    SQ_MODEL_VIVICAM_3350,
    SQ_MODEL_DC_N130T,
    SQ_MODEL_DEFAULT,
    SQ_MODEL_UNKNOWN
} SQModel;

// 
@interface SQ905 : MyCameraDriver 
{
    BayerConverter * bayerConverter;  // Our decoder for Bayer Matrix sensors
    
    char modelID[0x4];
    char catalog[0x4000];
    
    SQModel sqModel;
    int numEntries;
    int numImages;
    
    char ** pictureData;
    
    NSString * usbNameString;
    NSString * sqModelName;
    
    char * chunkBuffer;
    int chunkLength;
    int chunkHeader;
}

// Choose which USB Vendor and Product IDs to activate for
+ (NSArray*) cameraUsbDescriptions;

// Start/stop
- (id) initWithCentral:(id) c;
- (void) dealloc;

- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId;

/*
- (void) shutdown; // shuts the driver down or initiates this procedure. You will receive a [cameraHasShutDown] message.
- (void) stopUsingUSB; //Makes sure no further USB calls to intf and dev are sent.

    //delegate management
- (id) delegate;
- (void) setDelegate:(id)d;
- (void) enableNotifyOnMainThread;	//Has to be enabled before [startupWithUsbLocationId]! Cannot be unset - anymore!
- (void) setCentral:(id)c;		//Don't use unless you know what you're doing!
- (id) central;				//Don't use unless you know what you're doing!

    //Camera introspection
- (BOOL) realCamera;	//Returns if the camera is a real image grabber or a dummy

    //Image / camera property get/set: All continuous data in the range [0 .. 1]. Their use should be quite obvious.

    //Brightness
- (BOOL) canSetBrightness;
- (float) brightness;
- (void) setBrightness:(float)v;

    //Contrast
- (BOOL) canSetContrast;
- (float) contrast;
- (void) setContrast:(float)v;

    //Saturation - colorfulness
- (BOOL) canSetSaturation;
- (float) saturation;
- (void) setSaturation:(float)v;

    //Gamma value - grey value
- (BOOL) canSetGamma;
- (float) gamma;
- (void) setGamma:(float)v;

    //Sharpness value - contour enhancement
- (BOOL) canSetSharpness;
- (float) sharpness;
- (void) setSharpness:(float)v;

    //gain - electronic amplification
- (BOOL) canSetGain;
- (float) gain;
- (void) setGain:(float)v;

    //Shutter speed
- (BOOL) canSetShutter;
- (float) shutter;
- (void) setShutter:(float)v;

    //Automatic exposure - will affect shutter and gain
- (BOOL) canSetAutoGain;
- (BOOL) isAutoGain;
- (void) setAutoGain:(BOOL)v;

    //LED ON / OFF
- (BOOL) canSetLed;
- (BOOL) isLedOn;
- (void) setLed:(BOOL)v;

    //Horizontal flipping
- (BOOL) canSetHFlip;		//Horizontal flipping
- (BOOL) hFlip;
- (void) setHFlip:(BOOL)v;

    //Compression
- (short) maxCompression;	//0 = no compression available
- (short) compression;
- (void) setCompression:(short)v;

    //White Balance
- (BOOL) canSetWhiteBalanceMode;
- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode;
- (WhiteBalanceMode) defaultWhiteBalanceMode;
- (WhiteBalanceMode) whiteBalanceMode;
- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode;

    //Black & White Mode
- (BOOL) canBlackWhiteMode;
- (BOOL) blackWhiteMode;
- (void) setBlackWhiteMode:(BOOL)newMode;


    //Resolution and frame rate
- (short) width;						//Current image width
- (short) height;						//Current image height
- (CameraResolution) resolution;				//Current image predefined format constant
- (short) fps;							//Current frames per second
- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr;	//Does this combination work?
- (void) setResolution:(CameraResolution)r fps:(short)fr;	//Set a resolution and frame rate

    //Resolution and fps negotiation - the default implementation will use [supportsResolution:fps:] to find something.
    //Override these if you want to.
- (CameraResolution) findResolutionForWidth:(short)width height:(short) height;	//returns a (hopefully) good native resolution
- (short) findFrameRateForResolution:(CameraResolution)res;	//returns fps or <=0 if resolution not supported
- (CameraResolution) defaultResolutionAndRate:(short*)fps;	//Override this to set the startup resolution

    //Grabbing
- (BOOL) startGrabbing;					//start async grabbing. Returns if the camera is grabbing
- (BOOL) stopGrabbing;					//Stop async grabbing. Returns if the camera is grabbing
- (void) setImageBuffer:(unsigned char*)buffer bpp:(short)bpp rowBytes:(long)rb;	//Set next image buffer to fill
- (BOOL) isGrabbing;					// Returns if the camera is grabbing

    //Grabbing internal
- (void) decodingThreadWrapper:(id)data;		//Don't subclass this...
*/
- (CameraError) decodingThread;				//Subclass this!
- (CameraError) startupGrabbing;
- (CameraError) shutdownGrabbing;

/*
    //Grabbing get info
- (unsigned char*) imageBuffer;				//last filled image buffer
- (short) imageBufferBPP;				//last BYTES per pixel
- (long) imageBufferRowBytes;				//last bytes per image row

    //DSC (Digital Still Camera) management - for cameras that can store media / also operate USB-unplugged
- (BOOL) canStoreMedia;					//If the device supports DSC or similar functions
- (long) numberOfStoredMediaObjects;			//How many images are currently on the camera?
- (NSDictionary*) getStoredMediaObject:(long)idx;	//downloads a media object
                                                    //required keys: "type" and "data". Currently handled combinations:
                                                    //type		data
                                                    //"bitmap"	NSBitmapImageRep object
                                                    //"jpeg"	NSData with JPEG (JFIF) file contents

- (BOOL) canGetStoredMediaObjectInfo;	//does the camera support [getStoredMediaObjectInfo:]?
- (NSDictionary*) getStoredMediaObjectInfo:(long)idx;	//gets a media object info
                                                        //required fields: type (currently "bitmap","jpeg")
                                                        //required fields for type="bitmap" or "jpeg": "width", "height", recommended: "size"
*/

- (BOOL) canDeleteAll;			//Does the camera support [deleteAll]?
- (CameraError) deleteAll;		//Clears the camera media memory

- (BOOL) canDeleteOne;			//Does the camera support [deleteOne:]?
- (CameraError) deleteOne:(long)idx;	//Clears one camera media object

- (BOOL) canDeleteLast;			//Does the camera support [deleteLast]?
- (CameraError) deleteLast;		//Clears the last camera media object

- (BOOL) canCaptureOne;			//Does the camera support [CaptureOne]?
- (CameraError) captureOne;		//Captures one image (or whatever - camera's current setting)

/*
    //Camera Custom features
- (BOOL) supportsCameraFeature:(CameraFeature)feature;
- (id) valueOfCameraFeature:(CameraFeature)feature;
- (void) setValue:(id)val ofCameraFeature:(CameraFeature)feature;

//Note that "notifications" here are not exactly Cocoa notifications. They are delegate methods (the delegate concept matches a bit better to the Cocoa counterpart). But they also notify... 

    //Merged Notification forwarders - should be used for notifications from decodingThread
- (void) mergeImageReady;
- (void) mergeGrabFinishedWithError:(CameraError)err;
- (void) mergeCameraHasShutDown;
    //There's no mergeCameraEventHappened because most likely you won't call it from decodingThread. Merge yourself.

    //Notification forwarders - should not be called from outside but may be overridden by subclasses
- (void) imageReady:(id)sender;				//sends "notification" to "delegate"
- (void) grabFinished:(id)sender withError:(CameraError)err;	//sends "notification" to "delegate"
- (void) cameraHasShutDown:(id)sender;			//sends "notification" to "delegate"
- (void) cameraEventHappened:(id)sender event:(CameraEvent)evt;	//sends "notification" to "delegate"	

*/

- (CameraError) readEntry:(char *) data len:(int) size;
- (CameraError) readData:(void *) data len:(short) size;

- (CameraError) reset;
- (CameraError) accessRegister:(int) reg;

- (CameraError) rawWrite:(UInt16) value  index:(UInt16) index  buf:(void *) data  len:(short) size;
- (CameraError) rawRead:(UInt16) value  index:(UInt16) index  buf:(void *) data  len:(short) size;

@end
