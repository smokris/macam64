//
//  SPCA5xxExampleDriver.m
//
//  macam - webcam app and QuickTime driver component
//  SPCA5xxExampleDriver - example driver to use for drivers based on the spca5xx Linux driver
//
//  Created by HXR on 06/07/2006.
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


#import "SPCA5xxExampleDriver.h"

#include "MiscTools.h"
#include "gspcadecoder.h"
#include "USB_VendorProductIDs.h"


@implementation SPCA5xxExampleDriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_EXPRESS_C], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Express (C)", @"name", NULL], 
        
        NULL];
}


#include "bridge-specific-spca5xx-file.h"


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    // Include if needed
    bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    // Set as appropriate
    hardwareBrightness = YES;
    hardwareContrast = NO;
    
    // Again, use if needed
    MALLOC(decodingBuffer, UInt8 *, 356 * 292 + 1000, "decodingBuffer");
    
    // Set to reflect actual values
    spca50x->bridge = BRIDGE_TV8532;
    spca50x->sensor = SENSOR_INTERNAL;
    spca50x->header_len = 4;
    spca50x->i2c_ctrl_reg = 0;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    spca50x->cameratype = GBGR;
    
    // This is important
    cameraOperation = &ftv8532;
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  spca5xxExampleIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                          UInt32 * dataStart, UInt32 * dataLength, 
                                          UInt32 * tailStart, UInt32 * tailLength)
{
    static int packet = 0;
    static int lastWasInvalid = 0;
    
    int frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    
    if (frameLength < 1) 
    {
        packet = 0;
        lastWasInvalid = 1;
        
        *dataLength = 0;
        
#ifdef REALLY_VERBOSE
        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
    int frameNumber = buffer[0];
    
#ifdef REALLY_VERBOSE
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [129] = 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
            buffer[0], frameLength, buffer[1], buffer[129], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (frameNumber == 0x80 && lastWasInvalid) // start a new image
    {
#ifdef REALLY_VERBOSE
        printf("New image start!\n");
#endif
        lastWasInvalid = 0;
        
        return newChunkFrame;
    }
    
    lastWasInvalid = 0;
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = spca5xxExampleIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// other stuff, including decompression
//
- (void) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
#ifdef REALLY_VERBOSE
    printf("Need to decode a buffer with %ld bytes.\n", buffer->numBytes);
#endif
    
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
	// Decode the bytes
    
    spca50x->frame->hdrwidth = rawWidth;
    spca50x->frame->hdrheight = rawHeight;
    spca50x->frame->data = buffer->buffer;
    spca50x->frame->tmpbuffer = decodingBuffer;
    
    tv8532_preprocess(spca50x->frame);  // Re-use the spca5xx code
    
    // Turn the Bayer data into an RGB image
    
    [bayerConverter setSourceFormat:6];
    [bayerConverter setSourceWidth:rawWidth height:rawHeight];
    [bayerConverter setDestinationWidth:rawWidth height:rawHeight];
    [bayerConverter convertFromSrc:decodingBuffer
                            toDest:nextImageBuffer
                       srcRowBytes:rawWidth
                       dstRowBytes:nextImageBufferRowBytes
                            dstBPP:nextImageBufferBPP
                              flip:hFlip
                         rotate180:YES];
    
    return YES;
}

@end
