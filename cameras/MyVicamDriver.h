/*
 MyVicamDriver.h - Vista Imaging Vicam driver

 Copyright (C) 2002 Dave Camp (dave@thinbits.com)
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


#include "GlobalDefs.h"
#import "MyCameraDriver.h"
#import "MyCameraCentral.h"



#define HOMECONNECT_NUM_CHUNKS 3
//The number of chunk buffers to queue for decoding 

#define CHUNK_SIZE (gVicamInfo[requestIndex].pad1+gVicamInfo[requestIndex].pad2\
                    +gVicamInfo[requestIndex].cameraWidth*gVicamInfo[requestIndex].cameraHeight)
//The chunk size in bytes - for use inside object methods

@class RGBScaler;

@interface MyVicamDriver : MyCameraDriver {

    BOOL			controlChange;

    UInt8*			cameraBuffer;
    UInt32			cameraBufferSize;

    UInt8*			decodeRGBBuffer;
    UInt8			decodeRGBBufferBPP;
    UInt32			decodeRGBBufferSize;
    
//Grabbing Thread state and variables
    BOOL			grabbingThreadRunning;	//State of grabbingThread (set by decodingThread, reset by grabbingThread)
    NSLock*			chunkReadyLock;		//Notification lock about freshly filled chunks
    NSLock*			fullChunkLock;		//Access lock to fullChunks array
    NSLock*			emptyChunkLock;		//Access lock to ep
    NSMutableArray*		fullChunks;		//An Array of NSMutableData objects for raw image data ("chunks") - filled, for decoding
    NSMutableArray*		emptyChunks;		//An Array of NSMutableData objects for raw image data ("chunks") - empty, to be filled
    NSMutableData* 		fillingChunk;		//The Chunk currently filling up
    CameraError			grabbingError;		//Error that resulted inside drabbingThread
    int 			videoBulkReadsPending;	//A counter of open async usb reads - we collect all transfers before shutting down the grab
    int				requestIndex;		//The camera setting index

    RGBScaler*			rgbScaler;		//Scaler to resize image to standard format

    float			redGain;		//current white balance setting (for auto white balance)
    float			blueGain;

    double			corrSum;		//Integrated exposure corrections
    BOOL			buttonWasPressed;	//the last state of the snapshot button
}

//Get info about the camera specifics.
+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;

//gain - electronic amplification
- (BOOL) canSetGain;
- (float) gain;
- (void) setGain:(float)v;

//Automatic exposure - will affect shutter and gain
- (BOOL) canSetAutoGain;

//Shutter speed
- (BOOL) canSetShutter;
- (float) shutter;
- (void) setShutter:(float)v;

//Start/stop
- (id) initWithCentral:(MyCameraCentral*)c;
- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId;
- (void) dealloc;

//Camera introspection
- (BOOL) realCamera;

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr;
- (CameraResolution) defaultResolutionAndRate:(short*)dFps;
- (void) setResolution:(CameraResolution)r fps:(short)fr;
- (short) preferredBPP;

//Grabbing
- (CameraError) decodingThread;				//We don't actually grab but draw images..

- (BOOL) usbIntfWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;
    

@end
