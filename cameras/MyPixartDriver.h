/*
 macam - webcam app and QuickTime driver component
 Copyright (C) 2005 Hidekazu UCHIDA.

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

typedef struct transfer {
	IOUSBIsocFrame*	frameList;		// The results of the usb frames I received
	UInt8*			buffer;			// This is the place the transfer goes to
} Transfer;

/*
struct code_table_t {
	int is_abs;
	int len;
	int val;
};
*/

@interface MyPixartDriver : MyCameraDriver {
	BOOL grabbingThreadRunning;		// For active wait until grabbingThread has finished
    CameraError grabbingError;		// The error code passed back from grabbingThread

	short	bytesPerFrame;			// How many bytes are at max transferred per usb frame
	UInt64	initiatedUntil;			// next usb frame number to initiate a transfer for

	IOUSBIsocFrame*	frameList;		// The results of the usb frames I received
	UInt8*			transferBuffer;	// This is the place the transfer goes to
	UInt8*			tmpBuffer;

	struct code_table codeTable[256];

//	Transfer* transfers;
	short	fillingTransfer;
//	short	filledTransfer;

    NSMutableData*	fillingChunk;	// The Chunk currently filling up
    NSMutableArray*	emptyChunks;	// Array of empty raw chunks (NSMutableData objects)
    NSMutableArray*	fullChunks;		// Array of filled raw chunks (NSMutableData objects) - fifo queue: idx 0 = oldest

    NSLock* emptyChunkLock;			// Lock to access the empty chunk array
    NSLock* fullChunkLock;			// Lock to access the full chunk array
    NSLock* chunkReadyLock;			// Lock to message a new chunk from grabbingThread to decodingThread

	long framesSinceLastChunk;		// Watchdog counter to detect invalid isoc data stream

	BOOL compressed;				// If YES, it's JPEG

	BayerConverter* bayerConverter;	// Our decoder for Bayer Matrix sensors
}

+ (NSArray *) cameraUsbDescriptions;

// private
- (BOOL) startTransfer;
- (void) cleanupGrabContext;

@end
