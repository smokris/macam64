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
//#include "gspcadecoder.h"
#include "USB_VendorProductIDs.h"


@implementation VC0321Driver

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
    
//  [LUT setDefaultOrientation:Rotate180];  // if necessary

    // Don't know if these work yet
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    cameraOperation = &fvc0321;
    
    decodingSkipBytes = 46;
    
//  spca50x->desc = Vimicro0321;
    spca50x->cameratype = YUY2;
    spca50x->bridge = BRIDGE_VC0321;
    spca50x->sensor = SENSOR_OV7660;
    
    compressionType = gspcaCompression;
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  vc032xIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                          UInt32 * dataStart, UInt32 * dataLength, 
                                          UInt32 * tailStart, UInt32 * tailLength, 
                                          GenericFrameInfo * frameInfo)
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

@end



@implementation VC0323Driver : VC0321Driver 

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VIMICRO_GENERIC_323], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Vimicro Generic VC0321", @"name", NULL], 
        
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
    
    cameraOperation = &fvc0321;
    
    decodingSkipBytes = 0;
    
//  spca50x->desc = Vimicro0323;
    spca50x->cameratype = JPGV;
    spca50x->bridge = BRIDGE_VC0323;
    spca50x->sensor = SENSOR_OV7670;  // Sensor detection overrides this
    
    compressionType = gspcaCompression;
    
	return self;
}

@end
