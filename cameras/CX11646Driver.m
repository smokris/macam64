//
//  CX11646Driver.m
//
//  macam - webcam app and QuickTime driver component
//  CX11646Driver - driver for CX11646-based cameras
//
//  Created by HXR on 3/25/06.
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


#import "CX11646Driver.h"

#include "gspcadecoder.h"

#include "USB_VendorProductIDs.h"


@implementation CX11646Driver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CX11646_VERSION1], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CONEXANT], @"idVendor",
            @"Wondereye CP-115", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CX11646_VERSION2], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CONEXANT], @"idVendor",
            @"Creative Webcam Notebook (PD1170)", @"name", NULL], 
        
        NULL];
}


// 572:041 // Creative Webcam NoteBook PD1170 [CX11646 and CX28490]
// 572:040 // Wondereye CP-115

#include "cx11646.h"



- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    [self setCompression:0];
    
    spca50x->bridge = BRIDGE_CX11646;
    spca50x->sensor = SENSOR_INTERNAL;
    
    spca50x->cameratype = JPGC;
    
    if (YES) 
    {
        compressionType = gspcaCompression;
        decodingSkipBytes = 2;
    }
    else 
    {
        compressionType = jpegCompression;
        decodingSkipBytes = 0;
        jpegVersion = 1;
    }
    
    cameraOperation = &fcx11646;
    
	return self;
}



- (short) maxCompression 
{
    return 4;
}


- (void) setCompression: (short) v 
{
    [super setCompression:v];
    
    spca50x->qindex = [self maxCompression] - [self compression];
    init_jpeg_decoder(spca50x);  // Possibly irrelevant
    
#if VERBOSE
    printf("Compression set to %d (spca50x->qindex = %d)\n", v, spca50x->qindex);
#endif
}


//
// Scan the frame and return the results
//
IsocFrameResult  cx11646IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                          UInt32 * dataStart, UInt32 * dataLength, 
                                          UInt32 * tailStart, UInt32 * tailLength, 
                                          GenericFrameInfo * frameInfo)
{
    int frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 2) 
    {
        *dataLength = 0;
        
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
#endif
    
    if (buffer[0] == 0xFF && buffer[1] == 0xD8) // JPEG Image-Start marker
    {
#if REALLY_VERBOSE
        printf("New chunk!\n");
#endif
        
        return newChunkFrame;
    }
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = cx11646IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
    
    grabContext.maxFramesBetweenChunks = 2 * 1000;
}

@end
