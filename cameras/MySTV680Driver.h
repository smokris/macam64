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
#import "BayerConverter.h"

//constants for camera commands. See the stv680 docs. They are only here to make the source code more readable.

#define SET_ERROR 0x00
#define SET_CAMERA_IDLE 0x04
#define SET_CAMERA_MODE 0x07
#define SET_STREAMING_MODE 0x09
#define GET_ERROR 0x80
#define GET_CAMERA_INFO 0x85
#define GET_CAMERA_MODE 0x87
#define GET_PICTURE_COUNT 0x8d
#define GET_PICTURE_HEADER 0x8f
#define DOWNLOAD_PICTURE 0x83

#define STV680_NUM_CHUNKS 5		//Maximum length of chunks-to-decode queue
#define STV680_CHUNK_SPARE 100		//Additional space to hold the image data start and other headers and trailers

@interface MySTV680Driver : MyCameraDriver {
    unsigned char resolutionBits;	//Result from the camera that indicates supported resolutions (depending on image sensor)
    NSMutableArray* emptyChunks;	//Array of empty raw chunks (NSMutableData objects)
    NSMutableArray* fullChunks;		//Array of filled raw chunks (NSMutableData objects) - fifo queue: idx 0 = oldest
    NSLock* emptyChunkLock;		//Lock to access the empty chunk array
    NSLock* fullChunkLock;		//Lock to access the full chunk array
    NSLock* chunkReadyLock;		//Lock to message a new chunk from grabbingThread to decodingThread
    long grabWidth;			//The real width the camera is sending (usually there's a border for interpolation)
    long grabHeight;			//The real height the camera is sending (usually there's a border for interpolation)
    unsigned long grabBufferSize;	//The number of bytes the cam will send in the bulk pipe for each chunk
    BayerConverter* bayerConverter;	//Our decoder for Bayer Matrix sensors
    CameraError grabbingError;		//The error code passed back from grabbingThread
    NSMutableData* fillingChunk;	//The Chunk currently filling up
    long videoBulkReadsPending;		//The number of USB bulk reads we still expect a read from - to see when we can stop grabbingThread
    BOOL grabbingThreadRunning;		//For active wait until grabbingThread has finished
}


+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;

- (id) initWithCentral:(id)c;
- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef;
- (void) dealloc;

- (BOOL) canSetBrightness;
- (void) setBrightness:(float)v;
- (BOOL) canSetContrast;
- (void) setContrast:(float)v;
- (BOOL) canSetGamma;
- (void) setGamma:(float)v;
- (BOOL) canSetSaturation;
- (void) setSaturation:(float)v;

//White Balance
- (BOOL) canSetWhiteBalanceMode;
- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode;
- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode;

//Grabbing
- (CameraError) startupGrabbing;
- (void) shutdownGrabbing;
- (void) handleFullChunkWithReadBytes:(UInt32)readSize error:(IOReturn)err;
- (void) fillNextChunk;
- (void) grabbingThread:(id)data;
- (CameraError) decodingThread;

//Image storage
- (BOOL) canStoreMedia;
- (long) numberOfStoredMediaObjects;
- (id) getStoredMediaObject:(long)idx;
- (void) eraseStoredMedia;

@end
