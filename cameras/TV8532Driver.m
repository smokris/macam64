//
//  TV8532Driver.m
//
//  macam - webcam app and QuickTime driver component
//  TV8532Driver - driver for TV8532-based cameras
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


#import "TV8532Driver.h"

#include "MiscTools.h"
#include "spcadecoder.h"
#include "USB_VendorProductIDs.h"


@implementation TV8532Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_EXPRESS_C], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Express (C)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LABTEC_WEBCAM_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LABTEC], @"idVendor",
            @"Labtec Webcam (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GENERIC_TV8532], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENERIC_TV8532], @"idVendor",
            @"Generic TV8532 Webcam", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_STINGRAY_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_VEO], @"idVendor",
            @"Veo Stingray (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_STINGRAY_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_VEO], @"idVendor",
            @"Veo Stingray (B)", @"name", NULL], 
        
        NULL];
}


#include "tv8532.h"


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    hardwareBrightness = YES;
    
    MALLOC(decodingBuffer, UInt8 *, 356 * 292 + 1000, "decodingBuffer");
/*
    spca50x->compress = 1;
*/    
    spca50x->bridge = BRIDGE_TV8532;
    spca50x->sensor = SENSOR_INTERNAL;
    spca50x->header_len = 4;
    spca50x->i2c_ctrl_reg = 0;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    spca50x->cameratype = GBGR;
    
    cameraOperation = &ftv8532;
    
	return self;
}


/*
static __u16 tv8532_ext_modes[][6] = {
    // x , y , Code, clk, n/a,  pipe 
    {352, 288, 0x00, 0x28, 0x00, 1023}, // mode 0
    {320, 240, 0x10, 0x28, 0x00, 1023}, // mode 0, software crop
    {176, 144, 0x01, 0x23, 0x00, 1023}, // mode 1
    //{160, 120, 0x03, 0x23, 0x00, 1023}, 
    {0, 0, 0, 0, 0}
};
*/


static int scanningHeight = 0;  // Need this for the scanning function later...


- (void) spcaSetResolution: (int) spcaRes
{
    if (spcaRes == SIF)  // Actually CIF... (spca5xx is confused)
    {
        spca50x->mode = 0;
        scanningHeight = HeightOfResolution(ResolutionCIF);
    }
    else                 // And this is QCIF
    {
        spca50x->mode = 1;
        scanningHeight = HeightOfResolution(ResolutionQCIF);
    }
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

/*
 {
     iPix = 0;
     spca50x->header_len = 0;
     
     if (cdata[0] == 0x80) 
     {
         // counter is limited so we need few header for a frame :) 
         
         // header 0x80 0x80 0x80 0x80 0x80 
         // packet  00   63  127  145  00   
         // sof     0     1   1    0    0   
         // update sequence
         
         if ((spca50x->packet == 63) || (spca50x->packet == 127))
             tv8532 = 1;
         
         // is there a frame start ?
         
         if (spca50x->packet >= ((spca50x->hdrheight >> 1) - 1)) 
         {
             if (!tv8532) 
             {
                 sequenceNumber = 0;
                 spca50x->packet = 0;
             }
         } 
         else 
         {
             if (!tv8532) 
             {
                 // Drop packet frame corrupt
                 frame->last_packet = sequenceNumber = 0;
                 spca50x->packet = 0;
                 continue;
             }
             
             tv8532 = 1;
             sequenceNumber++;
             spca50x->packet++;
         }
    } 
     else 
     {
         sequenceNumber++;
         spca50x->packet++;
     }
}
*/

//
// Scan the frame and return the results
//
IsocFrameResult  tv8532IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
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
//  if (frameNumber == 0x80 && packet != 63 && packet != 127) // start a new image
    {
        packet = 0;
        
        if (packet >= (scanningHeight / 2) - 1) 
        {
#ifdef REALLY_VERBOSE
            printf("New image start!\n");
#endif
            return newChunkFrame;
        }
        else 
        {
#ifdef REALLY_VERBOSE
            printf("Drop current image, invalid!\n");
#endif
            return invalidChunk;
        }
    }
    
    packet++;
    lastWasInvalid = 0;
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = tv8532IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// other stuff, including decompression
//
- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
    printf("Need to decode a buffer with %ld bytes.\n", buffer->numBytes);
    
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
                         rotate180:NO];
}

@end
