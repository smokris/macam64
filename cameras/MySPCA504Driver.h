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
#import "JFIFHeaderTemplate.h"

#define SPCA504_NUM_TRANSFERS 2
#define SPCA504_FRAMES_PER_TRANSFER 50
#define SPCA504_NUM_CHUNK_BUFFERS 5

typedef struct SPCA504TransferContext {	//Everything a usb completion callback need to know
    IOUSBIsocFrame frameList[SPCA504_FRAMES_PER_TRANSFER];	//The results of the usb frames I received
    UInt8* buffer;		//This is the place the transfer goes to
} SPCA504TransferContext;

typedef struct SPCA504ChunkBuffer {
    unsigned char* buffer;		//The data
    long numBytes;			//The amount of valid data filled in
} SPCA504ChunkBuffer;

typedef struct SPCA504GrabContext {
    UInt64 initiatedUntil;		//next usb frame number to initiate a transfer for
    short bytesPerFrame;		//So many bytes are at max transferred per usb frame
    short finishedTransfers;		//So many transfers have already finished (for cleanup)
    SPCA504TransferContext transferContexts[SPCA504_NUM_TRANSFERS];	//The transfer contexts
    IOUSBInterfaceInterface** intf;	//Just a copy from our interface interface so the callback can issue usb
    BOOL* shouldBeGrabbing;		//Ref to the global indicator if the grab should go on
    CameraError err;			//Return value for common errors during grab
    NSLock* chunkReadyLock;		//Unlocked to signal decodingThread that there's an image
    long framesSinceLastChunk;		//Watchdog counter to detect invalid isoc data stream
    long chunkBufferLength;		//The size of the chunk buffers
    short numEmptyBuffers;		//The number of empty (ready-to-fill) buffers in the array below
    SPCA504ChunkBuffer emptyChunkBuffers[SPCA504_NUM_CHUNK_BUFFERS];	//The pool of empty (ready-to-fill) chunk buffers
    short numFullBuffers;		//The number of full (ready-to-decode) buffers in the array below
    SPCA504ChunkBuffer fullChunkBuffers[SPCA504_NUM_CHUNK_BUFFERS];	//The queue of full (ready-to-decode) chunk buffers (oldest=last)
    bool fillingChunk;			//If we're currently filling a buffer
    SPCA504ChunkBuffer fillingChunkBuffer;	//The chunk buffer currently filling up (if fillingChunk==true)
    NSLock* chunkListLock;		//The lock for access to the empty buffer pool/ full chunk queue
} SPCA504GrabContext;

/* Note that the memory pointers of the chunk buffer do not directly point to the start of the allocated memory. Instead, there's space for a JFIF header before - this eliminates the need to copy them again for decompression and makes the grabbing thread more readable. */


@interface MySPCA504Driver : MyCameraDriver {
    IOUSBInterfaceInterface** dscIntf;

    SPCA504GrabContext grabContext;
    BOOL grabbingThreadRunning;
    
    int firmwareVersion;	//The camera's firmware revision (*256)
    UInt32 sdramSize;		//SDRAM size in MB
    BOOL flashPresent;		//If there's internal NAND Flash ROM to hold media data
    BOOL cardPresent;		//If there's a Smart Media card to hold media data
    int cardClusterSize;	//The card cluster size (do we need this infop?)

    UInt8 pccamJfifHeader[JFIF_HEADER_LENGTH];		//Prepared JFIF Header for JPEG->JFIF reconstruction (PC Cam video)
    ImageDescriptionHandle pccamImgDesc;		//Image Description for JFIF decompress (PC Cam video)
    short pccamQTabIdx;					//Current Q Table index

    NSMutableArray* sdramFileInfo;	//Array of Dictionaries for each object
    NSMutableArray* flashFileInfo;	//Array of Dictionaries for each object
    NSMutableArray* cardFileInfo;	//Array of Dictionaries for each object

    
}

+ (NSArray*) cameraUsbDescriptions;

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef;
- (void) shutdown;

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr;
- (void) setResolution:(CameraResolution)r fps:(short)fr;
- (CameraResolution) defaultResolutionAndRate:(short*)dFps;
- (short) maxCompression;
- (void) setCompression:(short)v;
- (BOOL) canSetBrightness;
- (void) setBrightness:(float)v;
- (BOOL) canSetContrast;
- (void) setContrast:(float)v;
- (BOOL) canSetSaturation;
- (void) setSaturation:(float)v;

- (CameraError) decodingThread;

- (BOOL) canStoreMedia;
- (long) numberOfStoredMediaObjects;
- (NSDictionary*) getStoredMediaObject:(long)idx;
- (void) eraseStoredMedia;



@end
