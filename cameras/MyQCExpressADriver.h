/*
 MyQCExpressADriver.h - macam camera driver class for QuickCam Express (STV600)

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
#include <Carbon/Carbon.h>
#include <QuickTime/QuickTime.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include "GlobalDefs.h"
//#import "MyPhilipsCameraDriver.h"
#import "BayerConverter.h"
#import "MySTV600Sensor.h"


#define STV600_NUM_CHUNK_BUFFERS 5
#define STV600_NUM_TRANSFERS 2
#define STV600_FRAMES_PER_TRANSFER 50

typedef struct STV600TransferContext {	//Everything a usb completion callback need to know
    IOUSBIsocFrame frameList[STV600_FRAMES_PER_TRANSFER];		//The results of the usb frames I received
    unsigned char* buffer;		//This is the place the transfer goes to
} STV600TransferContext;

typedef struct STV600ChunkBuffer {
    unsigned char* buffer;		//The data
    long numBytes;			//The amount of valid data filled in
} STV600ChunkBuffer;

typedef struct STV600GrabContext {
    short bytesPerFrame;		//So many bytes are at max transferred per usb frame
    long chunkBufferLength;		//The chunk buffers have each this size
    short numEmptyBuffers;		//So many empty buffers are there
    STV600ChunkBuffer emptyChunkBuffers[STV600_NUM_CHUNK_BUFFERS];	//The pool of empty, ready-to-use chunk buffers
    short numFullBuffers;		//So many full buffers are there
    STV600ChunkBuffer fullChunkBuffers[STV600_NUM_CHUNK_BUFFERS];	//A list of full buffers waiting to be decoded
    bool fillingChunk;			//If there is currently a chunk buffer being read
    STV600ChunkBuffer fillingChunkBuffer;	//The buffer that is currently being filled up (valid only if fillingChunk==true)
    short finishedTransfers;		//So many transfers have already finished (for cleanup)
    STV600TransferContext transferContexts[STV600_NUM_TRANSFERS];	//The transfer contexts
    IOUSBInterfaceInterface** intf;	//Just a copy from our interface interface so the callback can issue usb
    UInt64 initiatedUntil;		//next usb frame number to initiate a transfer for
    NSLock* chunkReadyLock;		//Our "traffic light" for decodingThread
    NSLock* chunkListLock;		//Mutex for chunkBuffer manipulation
    BOOL* shouldBeGrabbing;		//Ref to the global indicator if the grab should go on
    CameraError err;			//Return value for common errors during grab
    long framesSinceLastChunk;		//Number of frames since the last chunk was completed
} STV600GrabContext;

@interface MyQCExpressADriver : MyCameraDriver {
//The context for grabbingThread
    STV600GrabContext grabContext;		//the grab context (everything the async usb read callbacks need)
    BayerConverter* bayerConverter;
    MySTV600Sensor* sensor;
    BOOL grabbingThreadRunning;
    long extraBytesInLine;	

/*

 Concerning the extraBytesInLine: I only had a QC Express (STV600/HDCS1020), a DexxaCam (STV600/PB0100) and a QuickCam Web (STV610/VV6410) to test. The Dexxa and the Express aren't available to me any more, so this code is quite speculative. The QC Web has four more padding bytes - I don't know if this comes from the VV6410 sensor or from the STV610 controller. Please correct me if I'm wrong. Someone with a  QC Express with a VV6410 sensor? Or a QC Web with a HDCS?

*/

}

+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId;
- (void) dealloc;

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr;
- (CameraResolution) defaultResolutionAndRate:(short*)dFps;
- (void) setResolution:(CameraResolution)r fps:(short)fr;

- (BOOL) canSetBrightness;
- (void) setBrightness:(float)v;
- (BOOL) canSetContrast;
- (void) setContrast:(float)v;
- (BOOL) canSetSaturation;
- (void) setSaturation:(float)v;
- (BOOL) canSetGamma;
- (void) setGamma:(float)v;
- (BOOL) canSetSharpness;
- (void) setSharpness:(float)v;
- (BOOL) canSetGain;
- (void) setGain:(float)v;
- (BOOL) canSetShutter;
- (void) setShutter:(float)v;
- (BOOL) canSetAutoGain;
- (BOOL) canSetHFlip;

//White Balance
- (BOOL) canSetWhiteBalanceMode;
- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode;
- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode;

- (CameraError) decodingThread;				//Entry method for the chunk to image decoding thread


/// Set a controller chip register. Public for the sensors.
- (BOOL) writeSTVRegister:    (long)reg   value:(unsigned char)val; 

/// Set two controller chip registers with hi- and lo-word. Public for the sensors.
- (BOOL) writeWideSTVRegister:(long)reg   value:(unsigned short int)val; 

@end
