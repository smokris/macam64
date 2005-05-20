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
/*

 Maybe this is a good place to introduce the internal model:

 There are two additional threads: grabbingThread and decodingThread.

 The grabbingThread does the raw, low-level usb communication part. Data from the cam are coming from an isochronous usb pipe (see the USB docs from www.usb.org for more info) which can only be accessed asynchronously. A c function will be called when such a transfer is complete. Note that inside the grabbingThreat itself, there are multiple, usually two read transfers running. They are working interleavedly together so that we don't miss a usb data frame because they can't be repeated. Most of the work is done in the completion function, "isocComplete()". Since this is a low level standard c function, we should try to be real-time-safe. This especially means that we should avoid Obj-C method calls wherever possible. Since we need some variables from there, the c function "lives" in a data structure which contains everything it needs to know, the grabContext. The raw data is written to a Q-shaped (see below). From the grabbingThread's perspective, it's an ordinary ring buffer. The callback examines the data and detects if there is enough data to describe a image frame (in order to avoid naming conflicts, I call those raw image data blocks "chunks", usb data frames are "frames" and the decoded image frames "images"). A complete chunk can be detected by a small gap in the data stream. A chunk is considered to be valid if its length is correct. If detected, it's added to a list of complete chunks - a fifo buffer and the decodingThread is notified (to see how, read on). If that list is full, the oldest chunk is removed (causing a dropped image).

 The decodingThread decodes complete chunks if there is a valid destination bitmap. It's an Objective-C method which esentially includes a loop. To avoid active waiting for the next chunk to decode, there is a NSLock which works like a traffic light. In each iteration, the decoding threads tries to lock which puts it to sleep until it's unlocked (this is done from the grabbingThread). Once the loop has passed the lock, it can expect chunk in the chunks list so it decodes all the chunks it finds in the fifo list and notifies the delegate (or simply discards the chunks if there is no image buffer to decode them into). When the list is empty, it starts over and tries to lock. Because the chunks list is accessed from the decoding thread as well as from the grabbing thread, there is a second lock to mutex access to it. The special part about the "Q"-buffer is that it is a ring buffer with a appendix to hold one chunk. If we see that a complete chunk is wrapped around the end of the ring buffer, the second part can be copied to the end of the ring so we don't have to deal with wrapping in the decoding function. This reduces unnecessary copying of data to an acceptable level since only every fifth chunk os so is wrapped (and in average, only half of the chunk has to be copied). And such a copy is only done then we really want to use the chunk.

 The start and termination has changed since 0.2 to solve some racing condition problems: When a grab is started, the decodingThread is detached. Before decodingThread enters its loop, the grabContext is set up and the grabbingThread is detached from the decodingThread. The grabbingThread initiates the usb transfers before going to its run loop. The termination is the opposite direction: To terminate, shouldBeRunningis unset (if an error occurs while grabbing, the grabbingThread will unset this on its own). This will cause no more transfers to be spawned but to be collected. When all initiated transfers have finished, the grabbingThread will terminate. The last commands in the grabbingThread will decodingThread to leave the loop. So we can be sure that by the time decodingThread leaves the loop, grabbingThread is done (or can be neglected). So decodingThread may now clean up the grabbingContext, set the status to idle and finish.

If you wonder where wiringThread has gone, have a look into MyCameraCentral.

*/

/*
Next: Camera constants and conversions. This information has partly been obtained from the Open Source Linux drivers by nemoSoft Unv which also are avalilable under the GPL. It can be downloaded under: "http://www.smcc.demon.nl/webcam/usb-pwcx-7.0.tar.gz". Their home page is: "http://www.smcc.demon.nl/webcam" I didn't include their source files because no single line is the same - it would simply not make sense. I hope that's ok.

Doing these amounts of defines is often called bad style. We should find a better way.
*/

#define VENDOR_PHILIPS 0x0471
#define VENDOR_LOGITECH 0x046d
#define VENDOR_CREATIVE_LABS 0x041e

//Conversions into the values of the camera

#define TO_BRIGHTNESS(a) ((UInt8)(a*127.0f))
#define TO_CONTRAST(a) ((UInt8)(a*63.0f))
#define TO_GAMMA(a) ((UInt8)(a*31.0f))
#define TO_SATURATION(a) ((UInt8)(a*198.0f-99.0f))
#define TO_GAIN(a) ((UInt8)(a*63.0f))
#define TO_SHUTTER(a) ((UInt8)(a*255.0f))
#define TO_AUTOGAIN(a) ((a)?0x0:0xff)
#define TO_POWERSAVE(a) ((a)?0x0:0xff)
#define CLAMP_UNIT(a) (CLAMP((a),0.0f,1.0f))

#define TO_LEDON(a) ((a)?0xFF00:0x00FF) // OxFF00 is LED on 0x00FF is LED off

//Command groups and selectors

#define INTF_CONTROL	3
#define GRP_SET_LUMA		0x01
#define SEL_BRIGHTNESS			0x2b00
#define SEL_CONTRAST			0x2700
#define SEL_GAMMA			0x2c00
#define SEL_SHUTTER			0x2300
#define SEL_AUTOGAIN			0x2000
#define SEL_GAIN			0x2100

#define GRP_SET_CHROMA		0x03
#define SEL_COLORMODE			0x1500
#define SEL_SATURATION			0x1600

#define GRP_SET_STATUS		0x05
#define SEL_POWER			0x3200
#define SEL_MIRROR			0x3300
#define SEL_LED				0x3400

#define INTF_VIDEO	4
#define GRP_SET_STREAM		0x07
#define	SEL_FORMAT			0x0100


typedef struct PhilipsCompleteChunk {	//The description of a ready-to-decode chunk
    long start;			//start offset in grabBuffer
    long end;			//end offset in grabBuffer
} PhilipsCompleteChunk;

typedef struct PhilipsTransferContext {//Everything a usb completion callback need to know
    IOUSBIsocFrame* frameList;	//The results of the usb frames I received
    long bufferOffset;		//Where did my data go in the buffer?
} PhilipsTransferContext;

typedef struct PhilipsGrabContext {	//Everything the grabbing thread internals need to know
    short bytesPerFrame;	//a usb frame should contain so many bytes (if full data rate is coming)
    short framesPerTransfer;	//every usb transfer (=readIsochPipeAsync call) should include so many usb frames
    short framesInRing;		//our ring buffer holds so many usb frames (excluding appendix part)
    short concurrentTransfers;	//number of concurrent calls readIsochPipeAsync
    short finishedTransfers;	//number of completed calls to readIsochPipeAsync - to find out when we're done
    long bytesPerChunk;		//number of bytes in a caomplete, valid chunk
    UInt64 initiatedUntil;	//next usb frame number to initiate a transfer for
    long nextReadOffset;	//offset to buffer position for the next transfer to be initiated
    unsigned char* buffer;	//our buffer!
    long bufferLength;		//complete length of buffer in bytes (including appendix)
    PhilipsTransferContext* transferContexts;// A context for every transfer <concurrent_transfers> Arrays a <frames_per_transfer> IOUSBIsocFrames
    long droppedFrames;		//A counter of frames dropped due to usb transfer problems
    long currentChunkStart;	//offset to the chunk currently examined. -1 if there is no current chunk 
    long bytesInChunkSoFar;	//number of bytes in crrent chunks so far
    long maxCompleteChunks;	//maximum length of complete chunk list. If exceeded, the oldest chunk will be discarded
    long currCompleteChunks;	//current length of complete chunk list
    PhilipsCompleteChunk* chunkList;	//the complete chunk list itself
    NSLock* chunkListLock;	//lock for access to complete chunk list data (mutex between grabbingThread and decodingThread)
    NSLock* chunkReadyLock;	//remote wake up for decodingThread from grabbingThread
    IOUSBInterfaceInterface** intf;	//Just a copy from our interface interface so the callback can issue usb commands
    BOOL* shouldBeGrabbing;	//Reference to the object's shouldBeGrabbing property
    CameraError err;		//Collector f errors occurred during grab. [cleanupGrabContext] will leave this as it is
} PhilipsGrabContext;

@interface MyPhilipsCameraDriver : MyCameraDriver {
    
//Camera Status
    short usbFrameBytes;
    short usbAltInterface;
    
//Video grabbing stuff
    PhilipsGrabContext grabContext;		//the grab context (everything the async usb read callbacks need)

//Camera model specifics - set in startup
    BOOL camHFlip;			//does the cam mirror by default? do not mix up with hFlip (user settings)
    short chunkHeader;			//chunk header size (commonly known as frame header size)
    short chunkFooter;			//chunk footer size (commonly known as frame footer size)
    BOOL grabbingThreadRunning;		//For active wait for finishing grabbing
}

+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;

//start/stop
- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId;
- (void) dealloc;

//Note that we never read properties directly from the cam but use our own caches for the properties
//For a new cam, defaults are set for it. This is not the best solution since we can get out
//of sync if a usb set command fails, but at least we don't have to deal with communication errors
//for getting a value

- (void) setBrightness:(float)v;
- (void) setContrast:(float)v;
- (void) setGamma:(float)v;
- (void) setSaturation:(float)v;

- (void) setGain:(float)v;
- (void) setShutter:(float)v;
- (void) setAutoGain:(BOOL)v;
- (void) setBlackWhiteMode:(BOOL)newMode;	// set to color / black & white


- (WhiteBalanceMode) defaultWhiteBalanceMode;

- (CameraError) decodingThread;				//Entry method for the chunk to image decoding thread


@end
