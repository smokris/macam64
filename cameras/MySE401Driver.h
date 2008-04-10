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


@interface MySE401Driver : MyCameraDriver {
    NSMutableArray* emptyChunks;	//Array of empty raw chunks (NSMutableData objects)
    NSMutableArray* fullChunks;		//Array of filled raw chunks (NSMutableData objects) - fifo queue: idx 0 = oldest
    NSLock* emptyChunkLock;		//Lock to access the empty chunk array
    NSLock* fullChunkLock;		//Lock to access the full chunk array
    long grabWidth;			//The real width the camera is sending (usually there's a border for interpolation)
    long grabHeight;			//The real height the camera is sending (usually there's a border for interpolation)
    unsigned long grabBufferSize;	//The number of bytes the cam will send in the bulk pipe for each chunk
    BayerConverter* bayerConverter;	//Our decoder for Bayer Matrix sensors
    CameraError grabbingError;		//The error code passed back from grabbingThread
    NSMutableData* fillingChunk;	//The Chunk currently filling up
    NSMutableData* collectingChunk;	//The Chunk collecting the depacketized data (in compressed mode)
    long collectingChunkBytes;		//The amount of valid, collected data currently in collectingChunk
    long videoBulkReadsPending;		//The number of USB bulk reads we still expect a read from - to see when we can stop grabbingThread
    BOOL grabbingThreadRunning;		//For active wait until grabbingThread has finished

    float aeGain;			
    float aeShutter;
    
    SInt32 lastExposure;		//The last shutter setting sent to the sensor
    SInt16 lastRedGain;			//The last red gain setting sent to the sensor
    SInt16 lastGreenGain;		//The last green gain setting sent to the sensor
    SInt16 lastBlueGain;		//The last blue gain setting sent to the sensor
    SInt16 lastResetLevel;		//The last reset level setting sent to the sensor
    SInt16 resetLevel;			//The current reset level
    int resetLevelFrameCounter;		//The reset level shouldn't be changed each frame (see Hynix docs)

    float whiteBalanceRed;		//White balance gain correction
    float whiteBalanceGreen;		//White balance gain correction
    float whiteBalanceBlue;		//White balance gain correction

    int maxWidth;			//real camera sensor size
    int maxHeight;			//real camera sensor size
    int resolutionSupport[ResolutionSVGA+1];	//Resolution support bit mask
    // 1=Resolution supported natively,	2=supported (2*subsampling), 4=supported (4*subsampling)
    BOOL streamIsCompressed;		//If the stream is JangGu-compressed or raw Bayer
    NSMutableData* jangGuBuffer;	//Buffer to hold the JangGu-decompressed data
    float lastMeanBrightness;		//Our average brightness (for JangGu - where no BayerConverter is used)

    int cameraID;
}

#define SE401_NUM_CHUNKS 3
#define SE401_CHUNK_SPARE 400000

+ (NSArray*) cameraUsbDescriptions;

- (id) initWithCentral:(id)c;
- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId;
- (void) dealloc;

- (BOOL) supportsResolution:(CameraResolution)res fps:(short)rate;
- (CameraResolution) defaultResolutionAndRate:(short*)rate;

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
- (BOOL) canSetWhiteBalanceMode;
- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode;
- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode;
- (BOOL) canSetGain;
- (void) setGain:(float)val;
- (BOOL) canSetShutter;
- (void) setShutter:(float)val;
- (BOOL) canSetAutoGain;
- (void) setAutoGain:(BOOL)v;
- (BOOL) canSetHFlip;
- (short) maxCompression;

//Grabbing
- (CameraError) startupGrabbing;
- (void) shutdownGrabbing;
- (void) handleFullChunkWithReadBytes:(UInt32)readSize error:(IOReturn)err;
- (void) fillNextChunk;
- (void) grabbingThread:(id)data;
- (CameraError) decodingThread;

@end


@interface SE402Driver : MySE401Driver 
{
}

+ (NSArray*) cameraUsbDescriptions;

@end


@interface EP800Driver : SE402Driver 
{
}

+ (NSArray*) cameraUsbDescriptions;

@end

