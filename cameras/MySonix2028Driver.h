/*

    MySonix2028Driver - Driver class for the Sonix SN9C2028F chip, e.g. used in the AEL Auracam DC-31UC

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

#import <Cocoa/Cocoa.h>
#import "MyCameraDriver.h"
#import "BayerConverter.h"
#include "GlobalDefs.h"

#define SONIX_NUM_CHUNK_BUFFERS 5
#define SONIX_NUM_TRANSFERS 10
#define SONIX_FRAMES_PER_TRANSFER 50

#define SONIX_AE_WANTED_BRIGHTNESS 5000
#define SONIX_AE_ACCEPTED_TOLERANCE 1000
#define SONIX_AE_ADJUST_LATENCY 3
#define SONIX_AE_MIN_ADJUST_STEP 0.01
#define SONIX_AE_MAX_ADJUST_STEP 0.02

typedef struct SONIXTransferContext {	//Everything a usb completion callback need to know
    IOUSBIsocFrame frameList[SONIX_FRAMES_PER_TRANSFER];		//The results of the usb frames I received
    unsigned char* buffer;		//This is the place the transfer goes to
} SONIXTransferContext;

typedef struct SONIXChunkBuffer {
    unsigned char* buffer;		//The data
    long numBytes;			//The amount of valid data filled in
} SONIXChunkBuffer;

typedef struct SONIXGrabContext {
    short bytesPerFrame;		//So many bytes are at max transferred per usb frame
    long chunkBufferLength;		//The chunk buffers have each this size
    short numEmptyBuffers;		//So many empty buffers are there
    SONIXChunkBuffer emptyChunkBuffers[SONIX_NUM_CHUNK_BUFFERS];	//The pool of empty, ready-to-use chunk buffers
    short numFullBuffers;		//So many full buffers are there
    SONIXChunkBuffer fullChunkBuffers[SONIX_NUM_CHUNK_BUFFERS];	//A list of full buffers waiting to be decoded
    bool fillingChunk;			//If there is currently a chunk buffer being read
    SONIXChunkBuffer fillingChunkBuffer;	//The buffer that is currently being filled up (valid only if fillingChunk==true)
    short finishedTransfers;		//So many transfers have already finished (for cleanup)
    SONIXTransferContext transferContexts[SONIX_NUM_TRANSFERS];	//The transfer contexts
    IOUSBInterfaceInterface** intf;	//Just a copy from our interface interface so the callback can issue usb
    UInt64 initiatedUntil;		//next usb frame number to initiate a transfer for
    NSLock* chunkReadyLock;		//Our "traffic light" for decodingThread
    NSLock* chunkListLock;		//Mutex for chunkBuffer manipulation
    BOOL* shouldBeGrabbing;		//Ref to the global indicator if the grab should go on
    CameraError err;			//Return value for common errors during grab
    long framesSinceLastChunk;		//Counter to find out an invalid data stream
    long underexposuredFrames;		//Counter for the sequence of underexposured frames
    long overexposuredFrames;		//Counter for the sequence of overexposured frames
    float autoExposure;			//Value for shutter/exposure [0..1] - higher means less amplification
} SONIXGrabContext;

@interface MySonix2028Driver : MyCameraDriver {
//Parameters set by setResolution:fps: 
    CameraResolution 	camNativeResolution;
    unsigned long 	camRangeOfInterest;	//4 bytes: colstart, colend, rowstart, rowend
    short 	camSensorBaseRate;
    short 	camSensorClkDivider;
    short 	camSkipFrames;
//The context for grabbingThread
   SONIXGrabContext grabContext;		//the grab context (everything the async usb read callbacks need)
   BOOL grabbingThreadRunning;		//For active wait for grabbingThread finish

   BayerConverter* bayerConverter;
   UInt8* bayerBuffer;
}

+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId;
- (void) dealloc;

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr;
- (CameraResolution) defaultResolutionAndRate:(short*)dFps;

- (BOOL) canSetSharpness;
- (void) setSharpness:(float)v;
- (BOOL) canSetBrightness;
- (void) setBrightness:(float)v;
- (BOOL) canSetContrast;
- (void) setContrast:(float)v;
- (BOOL) canSetSaturation;
- (void) setSaturation:(float)v;
- (BOOL) canSetGamma;
- (void) setGamma:(float)v;
- (BOOL) canSetShutter;
- (void) setShutter:(float)val;
- (BOOL) canSetAutoGain;
- (void) setAutoGain:(BOOL)v;
- (BOOL) canSetWhiteBalanceMode;
- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode;
- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode;
- (BOOL) canSetHFlip;

    
//DSC Image download
- (BOOL) canStoreMedia;
- (long) numberOfStoredMediaObjects;
- (NSDictionary*) getStoredMediaObject:(long)idx;

@end


@interface MyViviCam3350BDriver : MySonix2028Driver 

+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;

// decoding is slightly different
- (void) decode:(UInt8*)src to:(UInt8*)pixmap width:(int)width height:(int) height bpp:(short)bpp rowBytes:(long)rb;

@end

