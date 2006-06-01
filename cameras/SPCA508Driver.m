//
//  SPCA508Driver.m
//
//  macam - webcam app and QuickTime driver component
//  SPCA508Driver - driver for SPCA508-based cameras
//
//  Created by HXR on 3/30/06.
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


// Status:
//
// doesn't seem to work in a hub
//
// always starts with 5 timeouts:
// usbCmdWithBRequestType: Error: kIOUSBTransactionTimeout - time out
//
// images are way too bright (whitish or light grayish actually)
// Red is too orange
// Blue is fine
// Green is a little too yellow
//
// first chunk 4052 bytes is crap
// CIF works    // 152242 bytes per chunk
// SIF works    // 115450 bytes per chunk
// QCIF does *not* work // 38800
// QSIF works   // 29602 bytes per chunk


#import "SPCA508Driver.h"

#include "USB_VendorProductIDs.h"
#include "spcadecoder.h"


// These defines are needed by the spca5xx code

enum 
{
    ViewQuestVQ110,
    MicroInnovationIC200,
    IntelEasyPCCamera,
    HamaUSBSightcam,
    HamaUSBSightcam2,
    CreativeVista,
};


// The actual driver

@implementation SPCA508Driver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VQ110], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_VIEWQUEST], @"idVendor",
            @"ViewQuest VQ110", @"name", NULL], 
        
        NULL];
}


#include "spca508_init.h"


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = ViewQuestVQ110;
    spca50x->bridge = BRIDGE_SPCA508;
    spca50x->sensor = SENSOR_INTERNAL;;
    spca50x->header_len = SPCA508_OFFSET_DATA;
    spca50x->i2c_ctrl_reg = 0;
    spca50x->i2c_base = SPCA508_INDEX_I2C_BASE;
    spca50x->i2c_trigger_on_write = 1;
    spca50x->cameratype = YUVY;
    
    // YUVY - whatever that means
    
    hardwareContrast = NO;
    
    cameraOperation = &fspca508;
    
	return self;
}


//
// This is an example that will have to be tailored to the specific camera or chip
// Scan the frame and return the results
//
IsocFrameResult  spca508IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength)
{
    int frameLength = frame->frActCount;
    
//  frame->seq = cdata[SPCA508_OFFSET_FRAMSEQ];
//  header length SPCA508_OFFSET_DATA
    
    *dataStart = 1;
    *dataLength = frameLength - 1;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
//  printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
    
    if (frameLength < 1 || buffer[0] == 0xFF) 
    {
        *dataLength = 0;
        
        return invalidFrame;
    }
    
//  printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
    
    if (buffer[0] == 0x00) 
    {
        *dataStart = SPCA508_OFFSET_DATA;
        *dataLength = frameLength - SPCA508_OFFSET_DATA;
        
        return newChunkFrame;
    }
    
    return validFrame;
}


//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = spca508IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


//
// other stuff, including decompression
//
- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
    int i;
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
//  printf("decoding buffer with %ld bytes\n", buffer->numBytes);
    
    spca50x->frame->hdrwidth = rawWidth;
    spca50x->frame->hdrheight = rawHeight;
    spca50x->frame->width = rawWidth;
    spca50x->frame->height = rawHeight;
    
    spca50x->frame->data = nextImageBuffer;
    spca50x->frame->tmpbuffer = buffer->buffer;
    spca50x->frame->scanlength = buffer->numBytes;
    
    spca50x->frame->decoder = &spca50x->maindecode;  // has the code table
    
    // control gamma, contrast, etc right here?
    
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
    
    // do the decoding
    
    yuv_decode(spca50x->frame, 1);
}

@end


@implementation SPCA508CS110Driver  

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0110], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x8086], @"idVendor",
            @"Intel Easy PC Camera", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0815], @"idProduct", // IC200
            [NSNumber numberWithUnsignedShort:0x0461], @"idVendor", // MicroInnovation
            @"Micro Innovation IC 200", @"name", NULL], 
        
        NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = IntelEasyPCCamera;
    spca50x->bridge = BRIDGE_SPCA508;
    spca50x->sensor = SENSOR_PB100_BA;
    spca50x->header_len = SPCA508_OFFSET_DATA;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = SPCA508_INDEX_I2C_BASE;
    spca50x->i2c_trigger_on_write = 1;
    spca50x->cameratype = YUVY;
    
	return self;
}

@end


@implementation SPCA508SightcamDriver  

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // HamaUSBSightcam
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0010], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0af9], @"idVendor",
            @"Hama Sightcam 100 (A) or MagicVision DRCM200", @"name", NULL], 
        
        NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = HamaUSBSightcam;
    spca50x->bridge = BRIDGE_SPCA508;
    spca50x->sensor = SENSOR_INTERNAL;
    spca50x->header_len = SPCA508_OFFSET_DATA;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    spca50x->cameratype = YUVY;
    
	return self;
}

@end


@implementation SPCA508Sightcam2Driver  

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // HamaUSBSightcam2
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0011], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0af9], @"idVendor",
            @"Hama Sightcam 100 (B)", @"name", NULL], 
        
        NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = HamaUSBSightcam2;
    spca50x->bridge = BRIDGE_SPCA508;
    spca50x->sensor = SENSOR_INTERNAL;
    spca50x->header_len = SPCA508_OFFSET_DATA;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    spca50x->cameratype = YUVY;
    
	return self;
}

@end


@implementation SPCA508CreativeVistaDriver  

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // CreativeVista
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x401a], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x041e], @"idVendor",
            @"Creative Vista (A)", @"name", NULL], 
        
        NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    // header-length = SPCA50X_OFFSET_DATA
    
    spca50x->desc = CreativeVista;
    spca50x->bridge = BRIDGE_SPCA508;
    spca50x->sensor = SENSOR_PB100_BA;
    spca50x->header_len = SPCA50X_OFFSET_DATA;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    spca50x->cameratype = YUVY;
    
	return self;
}

@end
