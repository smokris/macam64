/*
    macam - webcam app and QuickTime driver component
    Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)
    Copyright (C) 2002 Hiroki Mori

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
*/

#import <Cocoa/Cocoa.h>
#import "MyCameraDriver.h"
#include <Carbon/Carbon.h>
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

#define VENDOR_OVT 0x05A9
#define PRODUCT_OV511 0x511
#define PRODUCT_OV511PLUS 0xA511

//Conversions into the values of the camera

#define SAA7111A_BRIGHTNESS(a) ((UInt8)(a*255.0f))
#define SAA7111A_CONTRAST(a) ((UInt8)(a*127.0f))
#define SAA7111A_GAMMA(a) ((UInt8)(a*31.0f))
#define SAA7111A_SATURATION(a) ((UInt8)(a*127.0f))
#define SAA7111A_GAIN(a) ((UInt8)(a*63.0f))
#define SAA7111A_SHUTTER(a) ((UInt8)(a*255.0f))
#define SAA7111A_AUTOGAIN(a) ((a)?0x0:0xff)
#define SAA7111A_POWERSAVE(a) ((a)?0x0:0xff)
#define CLAMP_UNIT(a) (CLAMP((a),0.0f,1.0f))

#define OV7610_BRIGHTNESS(a) ((UInt8)(a*63.0f))
#define OV7610_CONTRAST(a) ((UInt8)(a*255.0f))
#define OV7610_SATURATION(a) ((UInt8)(a*255.0f))

#define OV511_REG_DLYM		0x10
#define OV511_REG_PEM		0x11
#define OV511_REG_PXCNT		0x12
#define OV511_REG_LNCNT		0x13
#define OV511_REG_PXDV		0x14
#define OV511_REG_LNDV		0x15
#define OV511_REG_M400		0x16
#define OV511_REG_LSTR		0x17
#define OV511_REG_M420_YFIR	0x18
#define OV511_REG_SPDLY		0x19
#define OV511_REG_SNPX		0x1A
#define OV511_REG_SNLN		0x1B
#define OV511_REG_SNPD		0x1C
#define OV511_REG_SNLD		0x1D
#define OV511_REG_SN400		0x1E
#define OV511_REG_SNAF		0x1F
#define OV511_REG_ENFC		0x20
#define OV511_REG_ARCP		0x21
#define OV511_REG_MRC		0x22
#define OV511_REG_RFC		0x23
#define OV511_REG_PKSZ		0x30
#define OV511_REG_PKFMT		0x31
#define OV511_REG_PIO		0x38
#define OV511_REG_PDATA		0x39
#define OV511_REG_ENTP		0x3E
#define OV511_REG_I2C_CONTROL	0x40
#define OV511_REG_SID		0x41
#define OV511_REG_SWA		0x42
#define OV511_REG_SMA		0x43
#define OV511_REG_SRA		0x44
#define OV511_REG_SDA		0x45
#define OV511_REG_PSC		0x46
#define OV511_REG_TMO		0x47
#define OV511_REG_SPA		0x48
#define OV511_REG_SPD		0x49
#define OV511_REG_RST		0x50
#define OV511_REG_CLKDIV	0x51
#define OV511_REG_SNAP		0x52
#define OV511_REG_EN_SYS	0x53
#define OV511_REG_USR		0x5E
#define OV511_REG_CID		0x5F
#define OV511_REG_PRH_Y		0x70
#define OV511_REG_PRH_UV	0x71
#define OV511_REG_PRV_Y		0x72
#define OV511_REG_PRV_UV	0x73
#define OV511_REG_QTH_Y		0x74
#define OV511_REG_QTH_UV	0x75
#define OV511_REG_QTV_Y		0x76
#define OV511_REG_QTV_UV	0x77
#define OV511_REG_CE_EN		0x78
#define OV511_REG_LT_EN		0x79
#define OV511_REG_LT_V		0x80

#define OV7610_REG_GC		0x00
#define OV7610_REG_BLU		0x01
#define OV7610_REG_RED		0x02
#define OV7610_REG_SAT		0x03
#define OV7610_REG_CTR		0x05
#define OV7610_REG_BRT		0x06
#define OV7610_REG_AS		0x07
#define OV7610_REG_BBS		0x0C
#define OV7610_REG_RBS		0x0D
#define OV7610_REG_GAM		0x0E
#define OV7610_REG_RWB		0x0F
#define OV7610_REG_EC		0x10
#define OV7610_REG_SYN_CLK	0x11
#define OV7610_REG_COMA		0x12
#define OV7610_REG_COMB		0x13
#define OV7610_REG_COMC		0x14
#define OV7610_REG_COMD		0x15
#define OV7610_REG_FD		0x16
#define OV7610_REG_HS		0x17
#define OV7610_REG_HE		0x18
#define OV7610_REG_VS		0x19
#define OV7610_REG_VE		0x1A
#define OV7610_REG_PS		0x1B
#define OV7610_REG_MIDH		0x1C
#define OV7610_REG_MIDL		0x1D
#define OV7610_REG_COME		0x20
#define OV7610_REG_YOF		0x21
#define OV7610_REG_UOF		0x22
#define OV7610_REG_ECW		0x24
#define OV7610_REG_ECB		0x25
#define OV7610_REG_COMF		0x26
#define OV7610_REG_COMG		0x27
#define OV7610_REG_COMH		0x28
#define OV7610_REG_COMI		0x29
#define OV7610_REG_EHSH		0x2A
#define OV7610_REG_EHSL		0x2B
#define OV7610_REG_EXBK		0x2C
#define OV7610_REG_COMJ		0x2D
#define OV7610_REG_VOF		0x2E
#define OV7610_REG_ABS		0x2F
#define OV7610_REG_YGAM		0x33
#define OV7610_REG_BADJ		0x34
#define OV7610_REG_COML		0x35
#define OV7610_REG_COMK		0x38

#define OV7610_I2C_WRITE_ID	0x42
#define OV7610_I2C_READ_ID	0x43

#define OV7610_I2C_RETRIES	3
#define OV7610_I2C_CLOCK_DIV	4

#define SAA7111A_I2C_WRITE_ID	0x48
#define SAA7111A_I2C_READ_ID	0x49

#define FI1236MK2_I2C_WRITE_ID	0xC2
#define FI1236MK2_I2C_READ_ID	0xC3

#define OV6620_I2C_WRITE_ID	0xc0
#define OV6620_I2C_READ_ID	0xc1

#define SENS_OV7610			1
#define SENS_SAA7111A			2
#define SENS_OV7620			3
#define SENS_SAA7111A_WITH_FI1236MK2	4
#define SENS_OV6620			5

typedef struct OV511CompleteChunk {	//The description of a ready-to-decode chunk
    long start;			//start offset in grabBuffer
    long end;			//end offset in grabBuffer
    int isSeparate;
    long start2;		//start offset in grabBuffer
    long end2;			//end offset in grabBuffer
} OV511CompleteChunk;

typedef struct OV511TransferContext {//Everything a usb completion callback need to know
    IOUSBLowLatencyIsocFrame* frameList;	//The results of the usb frames I received
    long bufferOffset;		//Where did my data go in the buffer?
} OV511TransferContext;

typedef struct OV511GrabContext {	//Everything the grabbing thread internals need to know
    short bytesPerFrame;	//a usb frame should contain so many bytes (if full data rate is coming)
    short framesPerTransfer;	//every usb transfer (=readIsochPipeAsync call) should include so many usb frames
    short framesInRing;		//our ring buffer holds so many usb frames (excluding appendix part)
    short concurrentTransfers;	//number of concurrent calls readIsochPipeAsync
    short finishedTransfers;	//number of completed calls to readIsochPipeAsync - to find out when we're done
    long bytesPerChunk;		//number of bytes in a caomplete, valid chunk
    UInt64 initiatedUntil;	//next usb frame number to initiate a transfer for
    long nextReadOffset;	//offset to buffer position for the next transfer to be initiated
    unsigned char* buffer;	//our buffer!
    unsigned char* chunkBuffer;	//our buffer!
    unsigned char* tmpBuffer;	//our buffer!
    long bufferLength;		//complete length of buffer in bytes (including appendix)
    long tmpLength;		//
    OV511TransferContext* transferContexts;// A context for every transfer <concurrent_transfers> Arrays a <frames_per_transfer> IOUSBIsocFrames
    long droppedFrames;		//A counter of frames dropped due to usb transfer problems
    long currentChunkStart;	//offset to the chunk currently examined. -1 if there is no current chunk 
    long currentChunkEnd;	//
    long bytesInChunkSoFar;	//number of bytes in crrent chunks so far
    long maxCompleteChunks;	//maximum length of complete chunk list. If exceeded, the oldest chunk will be discarded
    long currCompleteChunks;	//current length of complete chunk list
    OV511CompleteChunk* chunkList;	//the complete chunk list itself
    NSLock* chunkListLock;	//lock for access to complete chunk list data (mutex between grabbingThread and decodingThread)
    IOUSBInterfaceInterface** intf;	//Just a copy from our interface interface so the callback can issue usb commands
    BOOL* shouldBeGrabbing;	//Reference to the object's shouldBeGrabbing property
    CameraError err;		//Collector f errors occurred during grab. [cleanupGrabContext] will leave this as it is
	NSPort*		decoderPort;	
} OV511GrabContext;

@interface MyOV511Driver : MyCameraDriver <NSPortDelegate> {
    
//Camera Type
    short customId;
    short sensorType;
    short sensorRead;
    short sensorWrite;

//Camera Status
    short usbFrameBytes;
    short usbAltInterface;
    
//Video grabbing stuff
    OV511GrabContext grabContext;		//the grab context (everything the async usb read callbacks need)

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

- (WhiteBalanceMode) defaultWhiteBalanceMode;

- (CameraError) decodingThread;				//Entry method for the chunk to image decoding thread

//I2C
- (int) i2cWrite:(UInt8) reg val:(UInt8) val;
- (int) i2cRead:(UInt8) reg;
- (int) i2cRead2;
- (void) seti2cid;

//Compress
- (int) ov511_upload_quan_tables;

- (void) mergeCameraEventHappened:(CameraEvent)evt;

@end

@interface MyOV511PlusDriver : MyOV511Driver 
+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;
@end
