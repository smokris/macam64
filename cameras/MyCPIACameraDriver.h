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
#import "MyCameraDriver.h"
#include <Carbon/Carbon.h>
#include <QuickTime/QuickTime.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include "GlobalDefs.h"
#import "MyPhilipsCameraDriver.h"

/* Here's the plot:

This is - after MyPhilipsCameraDriver - the second class that has an own implementation of the async isoc pipe reading process. There are some different requirements here that make it useful not to merge the different approaches. The Philips cameras send a constant number of bytes each frame during a chunk (maybe the end is shorter, of course). This makes the reading quite easy: The bytes can be stored in a ring buffer and in most cases, there is no need to re-copy the data to a continuous buffer for image decoding. This is something we want to leave this way because the isoc completion calls are timing sensitive and we don't want to do lengthly operations such as copying in there. For CPIA cams, the situation is different: It is not guaranteed that the camera will send a constant stream - when compression or roi (range of interest) features are enabled, the camera will sometimes send a varying number of bytes each frame (starts and ends of chunks are detected by magic numbers). This results in fragmentation of chunk data in the receiving buffer. So we have to copy the data. Since that, there's no need to maintain a ring buffer which makes other things more complicated.

The idea here is the following: There is grabbingContext that holds all data that is needed from the grabbingThread. A constant number of concurrent transfers is running. Each one has an associated transferContext, holding the frames structure used in the IOUSBLib call and an own buffer for receiving the frames. When such a call has completed, it scans for chunk starts or ends in the received data (depending on the current state). If a chunk has started, a fresh ChunkBuffer is taken from the empty list (if that one is empty, it's taken from the full list and the chunk in there is discarded), marked as empty and frame data is copied in there until the chunk buffer is full (which results in discarding the data and restarting to fill the buffer) or it has ended. If it has been validly filled, it is put to the list of full chunks and the decodingThread is notified (which will do almost the same thing as in the Philips driver). Synchronisation between grabbingThread and decodingThread is handled via a lock: ChunkListLock (similar to the uses in the Phips driver). There have been some simplifications: The array lengths are now static - they are defined by preprocessor constants. This is far less elegant, but it simplifies handling and memory access. And who needs to change that? Maybe later, when the task is dynamic signal delay optimization (if it will be done at all, it will be some time in the far, far future...).

Btw: Yes, I know, the name is "CPiA", not "CPIA". All UI messages show "CPiA", but the internal names use "CPIA" since it's easier to type...

*/

#define CPIA_NUM_CHUNK_BUFFERS 5
#define CPIA_NUM_TRANSFERS 2
#define CPIA_FRAMES_PER_TRANSFER 50

typedef struct CPIATransferContext {	//Everything a usb completion callback need to know
    IOUSBIsocFrame frameList[CPIA_FRAMES_PER_TRANSFER];		//The results of the usb frames I received
    unsigned char* buffer;		//This is the place the transfer goes to
} CPIATransferContext;

typedef struct CPIAChunkBuffer {
    unsigned char* buffer;		//The data
    long numBytes;			//The amount of valid data filled in
} CPIAChunkBuffer;

typedef struct CPIAGrabContext {
    short bytesPerFrame;		//So many bytes are at max transferred per usb frame
    long chunkBufferLength;		//The chunk buffers have each this size
    short numEmptyBuffers;		//So many empty buffers are there
    CPIAChunkBuffer emptyChunkBuffers[CPIA_NUM_CHUNK_BUFFERS];	//The pool of empty, ready-to-use chunk buffers
    short numFullBuffers;		//So many full buffers are there
    CPIAChunkBuffer fullChunkBuffers[CPIA_NUM_CHUNK_BUFFERS];	//A list of full buffers waiting to be decoded
    bool fillingChunk;			//If there is currently a chunk buffer being read
    CPIAChunkBuffer fillingChunkBuffer;	//The buffer that is currently being filled up (valid only if fillingChunk==true)
    short finishedTransfers;		//So many transfers have already finished (for cleanup)
    CPIATransferContext transferContexts[CPIA_NUM_TRANSFERS];	//The transfer contexts
    IOUSBInterfaceInterface** intf;	//Just a copy from our interface interface so the callback can issue usb
    UInt64 initiatedUntil;		//next usb frame number to initiate a transfer for
    NSLock* chunkListLock;		//Mutex for chunkBuffer manipulation
    BOOL* shouldBeGrabbing;		//Ref to the global indicator if the grab should go on
    CameraError err;			//Return value for common errors during grab
    long framesSinceLastChunk;		//Counter to find out an invalid data stream
} CPIAGrabContext;

@interface MyCPIACameraDriver : MyCameraDriver {
//Parameters set by setResolution:fps: 
    CameraResolution 	camNativeResolution;
    unsigned long 	camRangeOfInterest;	//4 bytes: colstart, colend, rowstart, rowend
    short 	camSensorBaseRate;
    short 	camSensorClkDivider;
    short 	camSkipFrames;
//The context for grabbingThread
   CPIAGrabContext grabContext;		//the grab context (everything the async usb read callbacks need)
   unsigned char *mergeBuffer;		//a CPIA-style 422 yuv buffer to merge compressed images
   BOOL grabbingThreadRunning;		//For active wait for grabbingThread finish
   long frameCounter;			//The first frame of a sequence will always be sent uncompressed to avoid old pixels
}

+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId;
- (void) dealloc;

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr;
- (void) setResolution:(CameraResolution)r fps:(short)fr;
- (CameraResolution) defaultResolutionAndRate:(short*)dFps;

- (BOOL) canSetBrightness;
- (void) setBrightness:(float)v;
- (BOOL) canSetContrast;
- (void) setContrast:(float)v;
- (BOOL) canSetSaturation;
- (void) setSaturation:(float)v;

- (BOOL) canSetGain;
- (void) setGain:(float)v;
- (BOOL) canSetShutter;
- (void) setShutter:(float)v;
- (BOOL) canSetAutoGain;
- (void) setAutoGain:(BOOL)v;

- (void) setGPIO:(unsigned char)port and:(unsigned char)andMask or:(unsigned char)orMask;
- (unsigned int) getGPIO;
    
- (short) maxCompression;
- (void) setSensorMatrix:(int)a1 a2:(int)a2 a3:(int)a3 a4:(int)a4 a5:(int)a5 a6:(int)a6 a7:(int)a7 a8:(int)a8 a9:(int)a9;

// why 80 ??
#define CPIA_COLOR_GAIN_FACTOR (212)

- (BOOL) canSetWhiteBalanceMode;
- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode;
- (WhiteBalanceMode) defaultWhiteBalanceMode;
- (void) setColourBalance:(unsigned short int)mode red:(float)redGain green:(float)greenGain blue:(float)blueGain;
- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode;

- (short) usbAltInterface;
- (short) bandwidthOfUsbAltInterface:(short)ai;

// Post grab hook
- (CameraError) doChunkReadyThings;

//Grab internals
- (BOOL) setupGrabContext;				//Sets up the grabContext structure for the usb async callbacks
- (BOOL) cleanupGrabContext;				//Cleans it up
- (void) grabbingThread:(id)data;			//Entry method for the usb data grabbing thread
- (CameraError) decodingThread;				//Entry method for the chunk to image decoding thread
- (void) decodeUncompressedChunk:(CPIAChunkBuffer*) chunkBuffer;
- (void) decodeCompressedChunk:(CPIAChunkBuffer*) chunkBuffer;
- (BOOL) startupGrabStream;				//Initiates camera streaming
- (BOOL) shutdownGrabStream;				//stops camera streaming
- (void) logCamState;
@end
