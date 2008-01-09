//
//  SPCA501ADriver.m
//
//  macam - webcam app and QuickTime driver component
//  SPCA501ADriver - example driver to use for drivers based on the spca5xx Linux driver
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


#import "SPCA501ADriver.h"

#include "MiscTools.h"
#include "gspcadecoder.h"
#include "USB_VendorProductIDs.h"


int yuv_decode(struct spca50x_frame * myframe, int force_rgb);


enum
{
    ThreeComHomeConnectLite,
    Arowana300KCMOSCamera, 
    SmileIntlCamera,
    MystFromOriUnknownCamera,
    IntelCreateAndShare,
};


@implementation SPCA501ADriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0401], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_VIEWQUEST], @"idVendor",
            @"Intel Create and Share CS330 (SPCA501)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0402], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_VIEWQUEST], @"idVendor",
            @"ViewQuest M318B (SPCA501A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0002], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_KODAK], @"idVendor", // Kodak
            @"Kodak DVC-325 (SPCA501A)", @"name", NULL], 
        
        NULL];
}


#include "spca501_init.h"


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
    
    // Set as appropriate
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    // This is important
    cameraOperation = &fspca501;
    
    // Set to reflect actual values
    spca50x->bridge = BRIDGE_SPCA501;
    spca50x->cameratype = YUYV;
    
    spca50x->desc = IntelCreateAndShare;
    spca50x->sensor = SENSOR_INTERNAL;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  spca501AIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                          UInt32 * dataStart, UInt32 * dataLength, 
                                          UInt32 * tailStart, UInt32 * tailLength, 
                                          GenericFrameInfo * frameInfo)
{
    int frameLength = frame->frActCount;
    
    *dataStart = 1;
    *dataLength = frameLength - 1;
    
    *tailStart = 0;
    *tailLength = 0;
    
    if (frameLength < 1 || buffer[0] == SPCA50X_SEQUENCE_DROP) 
    {
        *dataLength = 0;
        
#ifdef REALLY_VERBOSE
        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
#ifdef REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
//            buffer[0], frameLength, buffer[1], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (buffer[0] == 0) 
    {
#ifdef REALLY_VERBOSE
        printf("New image start!\n");
#endif
        *dataStart = SPCA501_OFFSET_DATA;
        *dataLength = frameLength - *dataStart;
        
        return newChunkFrame;
    }
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = spca501AIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// other stuff, including decompression
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
#ifdef REALLY_VERBOSE
    printf("Need to decode a buffer with %ld bytes.\n", buffer->numBytes);
#endif
    
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
    
    [LUT processImage:nextImageBuffer numRows:rawHeight rowBytes:nextImageBufferRowBytes bpp:nextImageBufferBPP];
    
    return YES;
}

@end


@implementation SPCA501ADriverVariant1

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_HOME_CONNECT_LITE], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_3COM], @"idVendor",
            @"3Com HomeConnect Lite (SPCA501A)", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = ThreeComHomeConnectLite;
    spca50x->sensor = SENSOR_INTERNAL;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SPCA501ADriverVariant2

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x501c], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x1776], @"idVendor", // Arowana
            @"Arowana 300K CMOS Camera (SPCA501C)", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Arowana300KCMOSCamera;
    spca50x->sensor = SENSOR_HV7131B;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SPCA501ADriverVariant3

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xC001], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0497], @"idVendor", // Smile International
            @"Smile International Camera (SPCA501A?)", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = SmileIntlCamera;
    spca50x->sensor = SENSOR_INTERNAL;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SPCA501ADriverVariant4

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0000], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0000], @"idVendor",
            @"Mystery CMOS Camera (SPCA501C)", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = MystFromOriUnknownCamera;
    spca50x->sensor = SENSOR_HV7131B;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end
