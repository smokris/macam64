//
//  SQ905.h
//
//  macam - webcam app and QuickTime driver component
//  SQ905 - driver for SQ905-based cameras
//
//  Created by HXR on 9/19/05.
//  Based on the SQ905 application by paulotex@yahoo.com <http://www.geocities.com/paulotex/sq905/>
//  In turn based on the gphoto library (sq905) created by Theodore Kilgore.
//
//  Copyright (C) 2005 HXR (hxr@users.sourceforge.net). 
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

#import <Cocoa/Cocoa.h>

#include "MyCameraDriver.h"
#include "BayerConverter.h"

// Constants and enums applicable to this driver onlly

#define     USB_REQUEST             0x0c

// These are the values used for requests

#define     USB_REGISTER_SETUP      0x06
#define     USB_REGISTER_COMPLETE   0x07
#define     USB_READ_BULK_PIPE      0x03
#define     USB_GO_TO_NEXT_ENTRY    0xc0

// These appear to be the registers accessed

#define     REGISTER_CLEAR          0xa0
#define     REGISTER_GET_ID         0xf0
#define     REGISTER_GET_CATALOG    0x20
#define     REGISTER_GET_DATA       0x30
#define     REGISTER_CAPTURE_QSIF   0x60
#define     REGISTER_CAPTURE_SIF    0x61
#define     REGISTER_CAPTURE_VGA    0x62

// These are additional values passed to USB commands

#define     COMMAND_ZERO            0x00
#define     COMMAND_GETSIZE         0x50
#define     COMMAND_GET             0xc1 // Not used, but was present in previous source code

// Listing of the unique camera types, there may be more

typedef enum 
{
    SQ_MODEL_POCK_CAM_ETC,
    SQ_MODEL_PRECISION_MINI,
    SQ_MODEL_MAGPIX_B350_BINOCULARS,
    SQ_MODEL_ARGUS_DC_1510_ETC,
    SQ_MODEL_VIVICAM_3350,
    SQ_MODEL_DC_N130T,
    SQ_MODEL_ARGUS_DC_1730,
    SQ_MODEL_DEFAULT,
    SQ_MODEL_UNKNOWN
} SQModel;

// SQ905 driver proper, based on the default MyCameraDriver of course

@interface SQ905 : MyCameraDriver 
{
    BayerConverter * bayerConverter;    // Our decoder for Bayer Matrix sensors
    
    char modelID[0x4];                  // Store the model ID for later access, this is SQ905 specific, not the USB product ID
    char catalog[0x4000];               // Store the catalog of entries (images and clips) for easy access
    
    SQModel sqModel;                    // Camera model enum from above, derived from model ID
    int numEntries;                     // Number of entries in catalog
    int numImages;                      // Total number of images, including all the frames in clips
    
    char ** pictureData;                // Array used to store fetched data from camera, camera is sequential access
    
    NSString * usbNameString;           // Not used (yet)
    NSString * sqModelName;             // The model name in string form used to identify camera to user
    
    char * chunkBuffer;                 // Storage used in capture mode
    int chunkLength;                    // Size of storage
    int chunkHeader;                    // Length of header
}

// Choose which USB Vendor and Product IDs to activate for
+ (NSArray *) cameraUsbDescriptions;

// Start/stop
- (id) initWithCentral:(id) c;
- (void) dealloc;
- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId;

//Camera introspection
- (BOOL) hasSpecificName; // Returns is the camera has a more specific name (derived from USB connection perhaps)
- (NSString *) getSpecificName;

// Image / camera property can/get/set: All continuous data in the range [0 .. 1]. Their use should be quite obvious.

// Brightness
- (BOOL) canSetBrightness;
- (void) setBrightness:(float) v;

// Contrast
- (BOOL) canSetContrast;
- (void) setContrast:(float) v;

// Saturation (colorfulness)
- (BOOL) canSetSaturation;
- (void) setSaturation:(float) v;

// Gamma value (grey value)
- (BOOL) canSetGamma;
- (void) setGamma:(float) v;

// Sharpness value (contour enhancement)
- (BOOL) canSetSharpness;
- (void) setSharpness:(float) v;

// gain (electronic amplification)
- (BOOL) canSetGain;

// Shutter speed
- (BOOL) canSetShutter;

// Automatic exposure - will affect shutter and gain
- (BOOL) canSetAutoGain;
- (void) setAutoGain:(BOOL) v;

// LED ON / OFF
- (BOOL) canSetLed;

// Horizontal flipping
- (BOOL) canSetHFlip;

// Compression
- (short) maxCompression; // 0 = no compression available, images are compressed only in some DSC modes

// White Balance
- (BOOL) canSetWhiteBalanceMode;
- (WhiteBalanceMode) defaultWhiteBalanceMode;

// Black & White Mode
- (BOOL) canBlackWhiteMode;

// Resolution and frame rate
- (BOOL) supportsResolution:(CameraResolution) r fps:(short) fr;	//Does this combination work?

// Resolution and fps negotiation - the default implementation will use [supportsResolution:fps:] to find something.
- (CameraResolution) defaultResolutionAndRate:(short*) fps; // Override this to set the startup resolution

// Grabbing & decoding
- (CameraError) decodingThread;
- (CameraError) startupGrabbing;
- (CameraError) shutdownGrabbing;

// DSC (Digital Still Camera) management - for cameras that can store media / also operate USB-unplugged
- (BOOL) canStoreMedia;                                 // Does the device support DSC or similar functions
- (long) numberOfStoredMediaObjects;                    // How many images are currently on the camera?
- (NSDictionary *) getStoredMediaObject:(long) idx;     // Retrieve a media object
    // required keys: "type" and "data". Currently handled combinations:
    // type		data
    // "bitmap"	NSBitmapImageRep object
    // "jpeg"	NSData with JPEG (JFIF) file contents
    // "clip"   NSArray? of data elements
    //  for "clip", a "clip-type" type is also required, should be either "bitmap" or "jpeg"

- (BOOL) canGetStoredMediaObjectInfo; // Does the camera support [getStoredMediaObjectInfo:]?
- (NSDictionary *) getStoredMediaObjectInfo:(long) idx; // Gets a media object info
    // required fields: type (currently "bitmap", "jpeg", "clip")
    // required fields for type="bitmap", "jpeg", "clip": "width", "height"
    // recommended field for type="bitmap", "jpeg", "clip": "size"
    // recommended field for type="clip": "frames"

- (BOOL) canDeleteAll;                  // Does the camera support [deleteAll]?
- (CameraError) deleteAll;              // Clears the camera media memory

- (BOOL) canDeleteOne;                  // Does the camera support [deleteOne:]?
- (CameraError) deleteOne:(long) idx;	// Clears one camera media object

- (BOOL) canDeleteLast;                 // Does the camera support [deleteLast]?
- (CameraError) deleteLast;             // Clears the last camera media object

- (BOOL) canCaptureOne;                 // Does the camera support [CaptureOne]?
- (CameraError) captureOne;             // Captures one image (or whatever - camera's current setting)

@end
