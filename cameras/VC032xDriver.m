//
//  VC032xDriver.m
//
//  macam - webcam app and QuickTime driver component
//  VC032xDriver - driver for VC032x controllers
//
//  Created by HXR on 2/23/07.
//  Copyright (C) 2007 HXR (hxr@users.sourceforge.net). 
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


// Vimicro claims VC0321 is UVC compatible, but it isn't
// endpoint 2
// YUY2 (like iMage?) [would be consistent with UVC]


#import "VC032xDriver.h"

#include "MiscTools.h"
#include "gspcadecoder.h"
#include "USB_VendorProductIDs.h"


@implementation VC032xDriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_ORBICAM_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech Orbicam [A]", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_ORBICAM_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech Orbicam [B]", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VIMICRO_GENERIC_321], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Vimicro Generic VC0321", @"name", NULL], 
        
        //  "Sony Visual Communication VGP-VCC1"

        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SONY_C001], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Sony Embedded Notebook Webcam (C001)", @"name", NULL], 
        
        //  "Motion Eye Webcamera in Sony Vaio FE11M"
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SONY_C002], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Sony Embedded Notebook Webcam (C002)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LENOVO_USB_WEBCAM], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LENOVO], @"idVendor",
            @"Lenovo USB Webcam (40Y8519)", @"name", NULL], 
        
        NULL];
}


#undef CLAMP

#include "vc032x.h"


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    // Don't know if these work yet
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    compressionType = proprietaryCompression;
    
    forceRGB = 1;
    invert = NO;
    
    // Set to reflect actual values
//    spca50x->desc = Vimicro0321;
    spca50x->bridge = BRIDGE_VC032X;
    spca50x->sensor = SENSOR_OV7660;
    spca50x->cameratype = YUY2;
    
//    spca50x->header_len = 4;
//    spca50x->i2c_ctrl_reg = 0;
//    spca50x->i2c_base = 0;
//    spca50x->i2c_trigger_on_write = 0;
    
    // This is important
    cameraOperation = &fvc0321;
    
    decodingSkipBytes = 46;
    
	return self;
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionCIF:
            if (rate > 30)  // what is the spec?
                return NO;
            return YES;
            break;
            
        case ResolutionQCIF:
            if (rate > 30)  // what is the spec?
                return NO;
            return YES;
            break;
            
        default: 
            return NO;
    }
}

//
// Scan the frame and return the results
//
IsocFrameResult  vc032xIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                          UInt32 * dataStart, UInt32 * dataLength, 
                                          UInt32 * tailStart, UInt32 * tailLength)
{
    int frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    
    if (frameLength < 1) 
    {
        *dataLength = 0;
        
#ifdef REALLY_VERBOSE
        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
#ifdef REALLY_VERBOSE
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [129] = 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
            buffer[0], frameLength, buffer[1], buffer[129], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (buffer[0] == 0xff && buffer[1] == 0xd8) // start a new image
    {
#ifdef REALLY_VERBOSE
        printf("New image start!\n");
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
    grabContext.isocFrameScanner = vc032xIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

- (UInt8) getGrabbingPipe
{
    return 2;
}

//
// other stuff, including decompression
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
    int i, error;
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
#ifdef VERBOSE
    printf("Need to decode a buffer with %ld bytes.\n", buffer->numBytes);
#endif
    
	// Decode the bytes
    
    spca50x->frame->width = rawWidth;
    spca50x->frame->height = rawHeight;
    spca50x->frame->hdrwidth = rawWidth;
    spca50x->frame->hdrheight = rawHeight;
    
    spca50x->frame->tmpbuffer = buffer->buffer + decodingSkipBytes;
    spca50x->frame->data = nextImageBuffer;
    
    spca50x->frame->decoder = &spca50x->maindecode;
    
    for (i = 0; i < 256; i++) 
    {
        spca50x->frame->decoder->Red[i] = i;
        spca50x->frame->decoder->Green[i] = i;
        spca50x->frame->decoder->Blue[i] = i;
    }
    
    spca50x->frame->cameratype = spca50x->cameratype;
    
    spca50x->frame->format = VIDEO_PALETTE_RGB24;
    
    spca50x->frame->cropx1 = 0;
    spca50x->frame->cropx2 = 0;
    spca50x->frame->cropy1 = 0;
    spca50x->frame->cropy2 = 0;
    
    error = yvyu_translate(spca50x->frame, forceRGB);
    
    if (error != 0) 
        return NO;
    
    [LUT processImage:nextImageBuffer numRows:rawHeight rowBytes:nextImageBufferRowBytes bpp:nextImageBufferBPP invert:invert];
    
    return YES;
}

@end
