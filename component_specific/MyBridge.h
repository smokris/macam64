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

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <QuickTime/QuickTime.h>
#include "GlobalDefs.h"

#define NUM_BRIDGE_GRAB_BUFFERS 2


typedef struct BridgeGrabBuffer {
    CameraResolution resolution;
    unsigned char* data;
} BridgeGrabBuffer;

typedef enum BridgeClientState {
    ClientFrameInvalid,
    ClientFramePending,
    ClientFrameValid
}BridgeClientState;

@class RGB888Scaler,MyCameraCentral,MyCameraDriver;

@interface MyBridge : NSObject {
    MyCameraCentral* central;			//A pointer to our camera central
    unsigned long cid;				//Our camera id for the central
    MyCameraDriver* driver;			//Our camera driver
    RGB888Scaler* scaler;			//Our handler for (primitive) scaling of images
    
//The client state
    short clientBufferIdx;			//The buffer in grabBuffers currently outputting
    BOOL clientImagePending;		

    BridgeClientState clientState;		//The state as seen from the client
    
//The driver state
    short driverBufferIdx;			//The buffer in grabBuffers currently inputting 
    BOOL driverStarted;				//YES from successful startup until shutdown
    BOOL driverShuttingDown;			//YES for the shutdown sequence (shutDownLock is locked)
    BOOL driverGrabRunning;			//YES if the driver is currently grabbing
    BOOL driverFormatChangePending;		//YES if formatCahngeLock is locked until change is done
    
    NSLock* stateLock;				//General lock to mutex all serious calls
    NSLock* formatChangeLock;			//Prevents a format change call from returning before the change is complete
    NSLock* shutdownLock;			//Prevents shutdown from returning before the shutdown is complete

    CameraResolution wantedResolution;		//Value to set in the next driver format update
    short wantedFps;				//Value to set in the next driver format update
    short wantedCompression;			//Value to set in the next driver format update

    BridgeGrabBuffer grabBuffers[NUM_BRIDGE_GRAB_BUFFERS];	//The buffers we're grabbing to

}

//----------------------
//   Startup/shutdown
//----------------------

- (id) initWithCentral:(MyCameraCentral*)central cid:(unsigned long)cid;
- (void) dealloc;
- (BOOL) startup;				//Opens the camera driver and starts up bridge (reflect VDOpen)
- (void) shutdown;				//Closes the camera driver shuts down bridge (reflect VDClose)

//-----------------
//   Doing grabs
//-----------------

- (BOOL) grabOneFrameCompressedAsync;		//Starts grabbing one frame to compressed target
- (BOOL) compressionDoneTo:(Ptr*)data		//Returns if grabOneFrameCompressedAsync has finished
                      size:(long*)size
                similarity:(UInt8*)similarity;
- (void) takeBackCompressionBuffer:(Ptr)buf;	//returns a buffer (they are taken out when starting a compressed grab)
- (BOOL) setDestinationWidth:(long)width height:(long)height;		//Set destination image size (we'll scale if necessary)
- (BOOL) getAnImageDescriptionCopy:(ImageDescriptionHandle)outHandle;	//Returns a copy of the image description in the given handle

//---------------------
//   Status requests
//---------------------

- (BOOL) isStarted;			//Returns if the bridge is currently started (in use) 
- (BOOL) isCameraValid;			//Returns if there currently is a real, valid camera that can deliver real video
- (BOOL) getName:(char*)name;		//Try to get the camera name

//-----------------------
//   Camera parameters
//-----------------------

- (BOOL)canSetContrast;			//Returns if the camera supports contrast adjustment
- (unsigned short)contrast;		//Returns the contrast in the range [0..65535], if supported
- (void)setContrast:(unsigned short)c;	//sets the contrast in the range [0..65535], if supported
- (BOOL)canSetBrightness;		//Returns if the camera supports brightness adjustment
- (unsigned short)brightness;		//Returns the brightness in the range [0..65535], if supported
- (void)setBrightness:(unsigned short)c;//Sets the brightness in the range [0..65535], if supported
- (BOOL)canSetSaturation;		//Returns if the camera supports saturation adjustment
- (unsigned short)saturation;		//Returns the saturation in the range [0..65535], if supported
- (void)setSaturation:(unsigned short)c;//Sets the saturation in the range [0..65535], if supported
- (BOOL)canSetSharpness;		//Returns if the camera supports sharpness adjustment
- (unsigned short)sharpness;		//Returns the sharpness in the range [0..65535], if supported
- (void)setSharpness:(unsigned short)c; //Sets the sharpness in the range [0..65535], if supported
- (BOOL)canSetGamma;			//Returns if the camera supports gamma adjustment
- (unsigned short)gamma;		//Returns the gamma in the range [0..65535], if supported
- (void)setGamma:(unsigned short)c;	//Sets the gamma in the range [0..65535], if supported
- (BOOL)canSetHFlip;			//Returns if the camera supports horizonal flipping
- (BOOL)hFlip;				//Returns the horizontal flip state
- (void)setHFlip:(BOOL)c;		//Sets the horizontal flip state
- (BOOL)canSetGain;			//Returns if the camera supports gain adjustment
- (void)setGain:(unsigned short)v;	//Sets the gain in the range [0..65535], if supported
- (unsigned short)gain;			//Returns the gain in the range [0..65535], if supported
- (BOOL)canSetShutter;			//Returns if the camera supports shutter/exposure adjustment
- (void)setShutter:(unsigned short)v;	//Sets the shutter/exposure in the range [0..65535], if supported
- (unsigned short)shutter;		//Returns the shutter/exposure in the range [0..65535], if supported
- (BOOL)canSetAutoGain;			//Returns if the camera can be switched between auto/manual gain/shutter
- (void)setAutoGain:(BOOL)v;		//Sets the auto gain/shutter/exposure control state
- (BOOL)isAutoGain;			//Returns the auto gain/shutter/exposure control state
- (short) maxCompression;		//Returns the number of different compression strengths (0=uncompressed only)
- (short) compression;			//Returns the current compression [0 .. maxCompression]
- (void) setCompression:(short)v;	//Sets the current compression [0 .. maxCompression]
- (BOOL) canSetWhiteBalanceMode;	//If camera can adjust white balance at all
- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)m;	//If the camera supports a specific whiute balance setting
- (WhiteBalanceMode) whiteBalanceMode;	//The current white balance mode
- (void) setWhiteBalanceMode:(WhiteBalanceMode)m;	//Set the current white balance mode

- (BOOL) canBlackWhiteMode;		//If camera can adjust color/greyscale at all
- (BOOL) blackWhiteMode;		//The current color mode
- (void) setBlackWhiteMode:(BOOL)m;	//Set the current color mode

- (BOOL) canSetLed;			//Can the camera toggle its LED
- (BOOL) isLedOn;			//The current LED status
- (void) setLed:(BOOL)v;		//Set the LED status

- (short) width;			//Returns the current grabbing width in pixels
- (short) height;			//Returns the current grabbing height in pixels
- (void) nativeBounds:(Rect*)r;		//Returns the native grabbing rect ( = <0,0,[width],[height]> )
- (short) fps;				//Returns the current grabbing rate in frames per second (a bit unreliable)
- (CameraResolution)resolution;		//Returns the current grabbing image format
- (BOOL) supportsResolution:(CameraResolution)res fps:(short)fps;	//Returns if the resolution/fps combination is supported
- (void) setResolution:(CameraResolution)res fps:(short)fps;		//Sets the current resolution/fps combi if supported
- (void) saveAsDefaults;		//Takes a snapshot of the camera settings as default values for this camera type    

//------------------------
//   Delegate Callbacks
//------------------------

- (void) imageReady:(id)cam;
- (void) cameraHasShutDown:(id)cam;
- (void) grabFinished:(id)cam withError:(CameraError)err;


@end
