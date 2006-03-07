//
//  GenericDriver.h
//
//  macam - webcam app and QuickTime driver component
//  GenericDriver - generic driver for many cameras
//
//  Created by HXR on 3/6/06.
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net). 
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA
//


// The idea here is to simplify further development
// Provide more functionality in a driver base-class
// Simply sub-class the GenericDriver and implement
// the following methods for a complete driver
// - 
// -
// -

// Should work with Bayer as well as JPEG


#import <Cocoa/Cocoa.h>

#include "MyCameraDriver.h"
#include "BayerConverter.h"


#define GENERIC_FRAMES_PER_TRANSFER 50
#define GENERIC_NUM_TRANSFERS       10
#define GENERIC_NUM_CHUNK_BUFFERS   5

//
// Everything a USB completion callback needs to know
//
typedef struct GenericTransferContext 
{
    IOUSBIsocFrame frameList[GENERIC_FRAMES_PER_TRANSFER]; // The results of the USB frames received
    UInt8 * buffer; // This is the place the transfer goes to
} GenericTransferContext;

typedef struct GenericChunkBuffer 
{
    unsigned char * buffer; // The data
    long numBytes; // The amount of valid data filled in
} GenericChunkBuffer;

typedef struct GenericGrabContext 
{
    IOUSBInterfaceInterface ** intf; // Just a copy of our interface interface so the callback can issue USB
    BOOL* shouldBeGrabbing;          // Ref to the global indicator if the grab should go on
    CameraError contextError;        // Return value for common errors during grab
    
    UInt64 initiatedUntil;		// The next USB frame number to initiate a transfer for
    short bytesPerFrame;		// So many bytes are at max transferred per USB frame
    short finishedTransfers;	// So many transfers have already finished (for cleanup)
    
    GenericTransferContext transferContexts[GENERIC_NUM_TRANSFERS]; // The transfer contexts
    NSLock* chunkReadyLock;		//Unlocked to signal decodingThread that there's an image
    long framesSinceLastChunk;		//Watchdog counter to detect invalid isoc data stream
    long chunkBufferLength;		//The size of the chunk buffers
    short numEmptyBuffers;		//The number of empty (ready-to-fill) buffers in the array below
    GenericChunkBuffer emptyChunkBuffers[GENERIC_NUM_CHUNK_BUFFERS];	//The pool of empty (ready-to-fill) chunk buffers
    short numFullBuffers;		//The number of full (ready-to-decode) buffers in the array below
    GenericChunkBuffer fullChunkBuffers[GENERIC_NUM_CHUNK_BUFFERS];	//The queue of full (ready-to-decode) chunk buffers (oldest=last)
    bool fillingChunk;			//If we're currently filling a buffer
    GenericChunkBuffer fillingChunkBuffer;	//The chunk buffer currently filling up (if fillingChunk==true)
    NSLock* chunkListLock;		//The lock for access to the empty buffer pool/ full chunk queue
    BOOL compressed;			//If YES, it's JPEG, otherwise YUV420
    
} GenericGrabContext;


@interface GenericDriver : MyCameraDriver 
{
    GenericGrabContext grabContext;
    BOOL grabbingThreadRunning;
    
    BayerConverter * bayerConverter;    // Our decoder for Bayer Matrix sensors
    
}


- (void) decodeBuffer: (GenericChunkBuffer *) buffer;


@end
