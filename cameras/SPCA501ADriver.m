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

#include "USB_VendorProductIDs.h"


enum
{
    ThreeComHomeConnectLite, // Variant1
    
    Arowana300KCMOSCamera, // Variant2
    
    SmileIntlCamera, // same, but different sensor // Variant3
    
    MystFromOriUnknownCamera, // not connected // Variant4
    
    IntelCreateAndShare, // generic
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
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    cameraOperation = &fspca501;
    
    spca50x->cameratype = YUYV;
    compressionType = gspcaCompression;

    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    
    spca50x->bridge = BRIDGE_SPCA501;
    spca50x->sensor = SENSOR_INTERNAL;
    
    spca50x->desc = IntelCreateAndShare;
    
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
    *dataLength = frameLength - *dataStart;
    
    *tailStart = 0;
    *tailLength = 0;
    
    if ((frameLength < 1) || (buffer[0] == SPCA50X_SEQUENCE_DROP)) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
//            buffer[0], frameLength, buffer[1], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (buffer[0] == 0) 
    {
#if REALLY_VERBOSE
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
    
	return self;
}

@end


@implementation SPCA501ADriverVariant3

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xC001], @"idProduct",  // SPCA501C
            [NSNumber numberWithUnsignedShort:0x0497], @"idVendor",   // Smile International
            @"Smile International Camera (SPCA501C?)", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = SmileIntlCamera;
    
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
    
	return self;
}

@end
