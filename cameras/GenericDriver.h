//
//  GenericDriver.h
//
//  macam - webcam app and QuickTime driver component
//  GenericDriver - base driver code for many cameras
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

// 
// This driver provides more of the common code that most drivers need, while 
// separating out the code that make cameras different into smaller routines. 
//
// To implement a new driver, subclass this class (GenericDriver) and implement
// all the required methods and any other methods that are necessary for the 
// specific camera. See the ExampleDriver for an example.
//

//
// Functionality still neeed:
// - working with JPEG images
// - USB2 high-speed transfers
//

#include "MyCameraDriver.h"
#include "BayerConverter.h"

// These seem to work well for many cameras

#define GENERIC_FRAMES_PER_TRANSFER  50
#define GENERIC_NUM_TRANSFERS        10
#define GENERIC_NUM_CHUNK_BUFFERS     5

// Some constants and functions for proccessing isochronous frames

typedef enum IsocFrameResult
{
    invalidFrame = 0,
    validFrame,
    newChunkFrame
} IsocFrameResult;

// The scanner is just a placeholder whereas the copier is fully usable

IsocFrameResult genericIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, UInt32 * dataStart, UInt32 * dataLength, UInt32 * tailStart, UInt32 * tailLength);
int genericIsocDataCopier(void * destination, const void * source, size_t length, size_t available);

// Other versions can be added here in case of commonalities

// ...

// Everything a USB completion callback needs to know is stored in the GrabContext and related structures

typedef struct GenericTransferContext 
{
    IOUSBIsocFrame frameList[GENERIC_FRAMES_PER_TRANSFER]; // The results of the USB frames received
    UInt8 * buffer;                                        // This is the place the transfer goes to
} GenericTransferContext;

typedef struct GenericChunkBuffer 
{
    unsigned char * buffer; // The raw data for an image, it will need to be decoded in various ways
    long numBytes;          // The amount of valid data filled in so far
} GenericChunkBuffer;

typedef struct GenericGrabContext 
{
    int numberOfFramesPerTransfer;
    int numberOfTransfers;
    int numberOfChunkBuffers;
    
    IOUSBInterfaceInterface ** intf; // Just a copy of our interface interface so the callback can issue USB
    BOOL* shouldBeGrabbing;          // Ref to the global indicator if the grab should go on
    CameraError contextError;        // Return value for common errors during grab
    
    // function pointers for scanning the frames, different cameras have different frame information
    
    IsocFrameResult (* isocFrameScanner)(IOUSBIsocFrame * frame, UInt8 * buffer, UInt32 * dataStart, UInt32 * dataLength, UInt32 * tailStart, UInt32 * tailLength);
    int (* isocDataCopier)(void * destination, const void * source, size_t length, size_t available);
    
    UInt64 initiatedUntil;		  // The next USB frame number to initiate a transfer for
    short bytesPerFrame;		  // So many bytes are at max transferred per USB frame
    short finishedTransfers;	  // So many transfers have already finished (for cleanup)
    long framesSinceLastChunk;	  // Watchdog counter to detect invalid isoc data stream
    
    UInt8 grabbingPipe;           // The pipe used by the camer for grabbing, usually 1, but not always
    
    NSLock * chunkReadyLock;	  // Unlocked to signal decodingThread that there's an image
    
    NSLock * chunkListLock;		  // The lock for access to the empty buffer pool/ full chunk queue
    long chunkBufferLength;		  // The size of the chunk buffers
    GenericTransferContext transferContexts[GENERIC_NUM_TRANSFERS];  // The transfer contexts
    GenericChunkBuffer emptyChunkBuffers[GENERIC_NUM_CHUNK_BUFFERS]; // The pool of empty (ready-to-fill) chunk buffers
    GenericChunkBuffer fullChunkBuffers[GENERIC_NUM_CHUNK_BUFFERS];	 // The queue of full (ready-to-decode) chunk buffers (oldest=last)
    GenericChunkBuffer fillingChunkBuffer; // The chunk buffer currently filling up (only if fillingChunk == true)
    short numEmptyBuffers;		  // The number of empty (ready-to-fill) buffers in the array above
    short numFullBuffers;		  // The number of full (ready-to-decode) buffers in the array above
    bool  fillingChunk;			  // (true) if we're currently filling a buffer
    
//  ImageType imageType;          // Is it Bayer, JPEG or something else?
} GenericGrabContext;

// Define the driver proper

@interface GenericDriver : MyCameraDriver 
{
    GenericGrabContext grabContext;
    BOOL grabbingThreadRunning;
    
    BayerConverter * bayerConverter; // Our decoder for Bayer Matrix sensors, will be NULL if not a Bayer image
}

#pragma mark -> Subclass Unlikely to Implement (generic impementation) <-

- (CameraError) startupWithUsbLocationId: (UInt32) usbLocationId;
- (void) dealloc;
- (BOOL) setupGrabContext;
- (void) cleanupGrabContext;
- (void) grabbingThread: (id) data;
- (CameraError) decodingThread;

#pragma mark -> Subclass Might Implement (default impementation works) <-

- (void) startupCamera;
- (UInt8) getGrabbingPipe;
// specificIsocDataCopier()   // The existing version should work for most
// specificIsocFrameScanner() // If a suitable one does not already exist

#pragma mark -> Subclass Must Implement! (No impementation) <-

- (BOOL) setGrabInterfacePipe;
- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;
- (void) setIsocFrameFunctions;
- (void) decodeBuffer: (GenericChunkBuffer *) buffer;

@end
