//
//  PAC7311Driver.m
//
//  macam - webcam app and QuickTime driver component
//  PAC7311Driver - driver for PixArt PAC7311 single chip VGA webcam solution
//
//  Created by HXR on 1/15/06.
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net) and Roland Schwemmer (sharoz@gmx.de).
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


#import "PAC7311Driver.h"

#include "MiscTools.h"
#include "USB_VendorProductIDs.h"


/* Some documentation about various registers as determined by trial and error.
When the register addresses differ between the 7202 and the 7311 the 2
different addresses are written as 7302addr/7311addr, when one of the 2
addresses is a - sign that register description is not valid for the
matching IC.

Register page 1:

Address	Description
-/0x08	Unknown compressor related, must always be 8 except when not
    in 640x480 resolution and page 4 reg 2 <= 3 then set it to 9 !
-/0x1b	Auto white balance related, bit 0 is AWB enable (inverted)
    bits 345 seem to toggle per color gains on/off (inverted)
    0x78		Global control, bit 6 controls the LED (inverted)
-/0x80	JPEG compression ratio ? Best not touched

   Register page 3/4:

    Address	Description
    0x02		Clock divider 2-63, fps =~ 60 / val. Must be a multiple of 3 on
    the 7302, so one of 3, 6, 9, ..., except when between 6 and 12?
-/0x0f	Master gain 1-245, low value = high gain
    0x10/-	Master gain 0-31
-/0x10	Another gain 0-15, limited influence (1-2x gain I guess)
   0x21		Bitfield: 0-1 unused, 2-3 vflip/hflip, 4-5 unknown, 6-7 unused
-/0x27	Seems to toggle various gains on / off, Setting bit 7 seems to
    completely disable the analog amplification block. Set to 0x68
    for max gain, 0x14 for minimal gain.
    */


// PAC7311

static const UInt8 init_7311[] = 
{
    0x78, 0x40,	// Bit_0 = start stream, Bit_6 = LED
    0x78, 0x40,	// Bit_0 = start stream, Bit_6 = LED
    0x78, 0x44,	// Bit_0 = start stream, Bit_6 = LED
    0xff, 0x04,
    0x27, 0x80,
    0x28, 0xca,
    0x29, 0x53,
    0x2a, 0x0e,
    0xff, 0x01,
    0x3e, 0x20,
};

static const UInt8 start_7311[] = 
{
    //	index, len, [value]*
	0xff, 1,	0x01,		// page 1
	0x02, 43,	0x48, 0x0a, 0x40, 0x08, 0x00, 0x00, 0x08, 0x00,
    0x06, 0xff, 0x11, 0xff, 0x5a, 0x30, 0x90, 0x4c,
    0x00, 0x07, 0x00, 0x0a, 0x10, 0x00, 0xa0, 0x10,
    0x02, 0x00, 0x00, 0x00, 0x00, 0x0b, 0x01, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
	0x3e, 42,	0x00, 0x00, 0x78, 0x52, 0x4a, 0x52, 0x78, 0x6e,
    0x48, 0x46, 0x48, 0x6e, 0x5f, 0x49, 0x42, 0x49,
    0x5f, 0x5f, 0x49, 0x42, 0x49, 0x5f, 0x6e, 0x48,
    0x46, 0x48, 0x6e, 0x78, 0x52, 0x4a, 0x52, 0x78,
    0x00, 0x00, 0x09, 0x1b, 0x34, 0x49, 0x5c, 0x9b,
    0xd0, 0xff,
	0x78, 6,	0x44, 0x00, 0xf2, 0x01, 0x01, 0x80,
	0x7f, 18,	0x2a, 0x1c, 0x00, 0xc8, 0x02, 0x58, 0x03, 0x84,
    0x12, 0x00, 0x1a, 0x04, 0x08, 0x0c, 0x10, 0x14,
    0x18, 0x20,
	0x96, 3,	0x01, 0x08, 0x04,
	0xa0, 4,	0x44, 0x44, 0x44, 0x04,
	0xf0, 13,	0x01, 0x00, 0x00, 0x00, 0x22, 0x00, 0x20, 0x00,
    0x3f, 0x00, 0x0a, 0x01, 0x00,
	0xff, 1,	0x04,	// page 4
	0x00, 254,			// load the page 4
	0x11, 1,	0x01,
	0, 0				// end of sequence
};

// page 4 - the value 0xaa says skip the index - see reg_w_page()

static const UInt8 page4_7311[] = 
{
	0xaa, 0xaa, 0x04, 0x54, 0x07, 0x2b, 0x09, 0x0f,
	0x09, 0x00, 0xaa, 0xaa, 0x07, 0x00, 0x00, 0x62,
	0x08, 0xaa, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x03, 0xa0, 0x01, 0xf4, 0xaa,
	0xaa, 0x00, 0x08, 0xaa, 0x03, 0xaa, 0x00, 0x68,
	0xca, 0x10, 0x06, 0x78, 0x00, 0x00, 0x00, 0x00,
	0x23, 0x28, 0x04, 0x11, 0x00, 0x00
};


// pac 7302

static const UInt8 init_7302[] = 
{
    //	index, value
	0xff, 0x01,		// page 1
	0x78, 0x00,		// deactivate
	0xff, 0x01,
	0x78, 0x40,		// led off
};

static const UInt8 start_7302[] = 
{
    //	index, len, [value]*
	0xff, 1,	0x00,		// page 0
	0x00, 12,	0x01, 0x40, 0x40, 0x40, 0x01, 0xe0, 0x02, 0x80,
    0x00, 0x00, 0x00, 0x00,
	0x0d, 24,	0x03, 0x01, 0x00, 0xb5, 0x07, 0xcb, 0x00, 0x00,
    0x07, 0xc8, 0x00, 0xea, 0x07, 0xcf, 0x07, 0xf7,
    0x07, 0x7e, 0x01, 0x0b, 0x00, 0x00, 0x00, 0x11,
	0x26, 2,	0xaa, 0xaa,
	0x2e, 1,	0x31,
	0x38, 1,	0x01,
	0x3a, 3,	0x14, 0xff, 0x5a,
	0x43, 11,	0x00, 0x0a, 0x18, 0x11, 0x01, 0x2c, 0x88, 0x11,
    0x00, 0x54, 0x11,
	0x55, 1,	0x00,
	0x62, 4, 	0x10, 0x1e, 0x1e, 0x18,
	0x6b, 1,	0x00,
	0x6e, 3,	0x08, 0x06, 0x00,
	0x72, 3,	0x00, 0xff, 0x00,
	0x7d, 23,	0x01, 0x01, 0x58, 0x46, 0x50, 0x3c, 0x50, 0x3c,
    0x54, 0x46, 0x54, 0x56, 0x52, 0x50, 0x52, 0x50,
    0x56, 0x64, 0xa4, 0x00, 0xda, 0x00, 0x00,
	0xa2, 10,	0x22, 0x2c, 0x3c, 0x54, 0x69, 0x7c, 0x9c, 0xb9,
    0xd2, 0xeb,
	0xaf, 1,	0x02,
	0xb5, 2,	0x08, 0x08,
	0xb8, 2,	0x08, 0x88,
	0xc4, 4,	0xae, 0x01, 0x04, 0x01,
	0xcc, 1,	0x00,
	0xd1, 11,	0x01, 0x30, 0x49, 0x5e, 0x6f, 0x7f, 0x8e, 0xa9,
    0xc1, 0xd7, 0xec,
	0xdc, 1,	0x01,
	0xff, 1,	0x01,		// page 1
	0x12, 3,	0x02, 0x00, 0x01,
	0x3e, 2,	0x00, 0x00,
	0x76, 5,	0x01, 0x20, 0x40, 0x00, 0xf2,
	0x7c, 1,	0x00,
	0x7f, 10,	0x4b, 0x0f, 0x01, 0x2c, 0x02, 0x58, 0x03, 0x20,
    0x02, 0x00,
	0x96, 5,	0x01, 0x10, 0x04, 0x01, 0x04,
	0xc8, 14,	0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00,
    0x07, 0x00, 0x01, 0x07, 0x04, 0x01,
	0xd8, 1,	0x01,
	0xdb, 2,	0x00, 0x01,
	0xde, 7,	0x00, 0x01, 0x04, 0x04, 0x00, 0x00, 0x00,
	0xe6, 4,	0x00, 0x00, 0x00, 0x01,
	0xeb, 1,	0x00,
	0xff, 1,	0x02,		// page 2
	0x22, 1,	0x00,
	0xff, 1,	0x03,		// page 3
	0x00, 255,              // load page 3
	0x11, 1,	0x01,
	0xff, 1,	0x02,		// page 2
	0x13, 1,	0x00,
	0x22, 4,	0x1f, 0xa4, 0xf0, 0x96,
	0x27, 2,	0x14, 0x0c,
	0x2a, 5,	0xc8, 0x00, 0x18, 0x12, 0x22,
	0x64, 8,	0x00, 0x00, 0xf0, 0x01, 0x14, 0x44, 0x44, 0x44,
	0x6e, 1,	0x08,
	0xff, 1,	0x01,		// page 1
	0x78, 1,	0x00,
	0, 0                    // end of sequence
};

// page 3 - the value 0xaa says skip the index - see reg_w_page()

static const UInt8 page3_7302[] = 
{
	0x90, 0x40, 0x03, 0x50, 0xc2, 0x01, 0x14, 0x16,
	0x14, 0x12, 0x00, 0x00, 0x00, 0x02, 0x33, 0x00,
	0x0f, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x47, 0x01, 0xb3, 0x01, 0x00,
	0x00, 0x08, 0x00, 0x00, 0x0d, 0x00, 0x00, 0x21,
	0x00, 0x00, 0x00, 0x54, 0xf4, 0x02, 0x52, 0x54,
	0xa4, 0xb8, 0xe0, 0x2a, 0xf6, 0x00, 0x00, 0x00,
	0x00, 0x1e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0xfc, 0x00, 0xf2, 0x1f, 0x04, 0x00, 0x00,
	0x00, 0x00, 0x00, 0xc0, 0xc0, 0x10, 0x00, 0x00,
	0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x40, 0xff, 0x03, 0x19, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0xc8, 0xc8, 0xc8,
	0xc8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x50,
	0x08, 0x10, 0x24, 0x40, 0x00, 0x00, 0x00, 0x00,
	0x01, 0x00, 0x02, 0x47, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x02, 0xfa, 0x00, 0x64, 0x5a, 0x28, 0x00,
	0x00
};


static int getPAC73xxJpegHeaderLength(void);
static void createPAC73xxJpegHeader(void * buffer, int width, int height);

int jpegProcessFrame(unsigned char * rq, unsigned char * fb, int good_img_width, int good_img_height, int bpp);


@implementation PAC7311Driver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // Most cameras appear to use the PAC7311 chip (according to the gpsca table)
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x00], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x00)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SPC_610NC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Philips SPC 610NC (probably)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x02], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x02)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SPC_500NC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Philips SPC 500NC (probably)", @"name", NULL],  // This supposedly uses a PAC7312 instead, not sure if that makes any difference
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x04], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x04)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x05], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x05)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x06], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x06)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x07], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x07)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_TRUST_WB_300P], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Trust WB 300P (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x09], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x09)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x0a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x0a)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x0b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x0b)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x0c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x0c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x0d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x0d)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_TRUST_WB_3500P], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Trust WB 3500P (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x0f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x0f)", @"name", NULL], 
        
        NULL];
}

//
// Initialize the camera to use the existing GSPCA code as much as posisble
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    [LUT setDefaultOrientation:Rotate180];
    
    compressionType = jpegCompression;
    jpegVersion = 3;
    
    compressionType = proprietaryCompression;
    
    jpegHeader = malloc(getPAC73xxJpegHeaderLength());
    
	return self;
}

//
//  reg_r
//
- (int) getRegister:(UInt16)reg
{
    UInt8 buffer[8];
    
    BOOL ok = [self usbReadCmdWithBRequest:0x00 wValue:0x00 wIndex:reg buf:buffer len:1];
    
    return (ok) ? buffer[0] : -1;
}

//
//  reg_w
//
- (int) setRegister:(UInt16)reg toValue:(UInt16)val
{
    UInt8 buffer[8];
    
    buffer[0] = val;
    
    BOOL ok = [self usbWriteCmdWithBRequest:0x00 wValue:0x00 wIndex:reg buf:buffer len:1];
    
    return (ok) ? val : -1;
}

//
//  reg_w_buf
//
- (int) setRegisterList:(UInt16)reg number:(int)length withValues:(UInt8 *)buffer
{
    BOOL ok = [self usbWriteCmdWithBRequest:0x01 wValue:0x00 wIndex:reg buf:buffer len:length];
    
    return (ok) ? length : -1;
}

//
//  reg_w_seq
//
- (int) setRegisterSequence:(const UInt8 *)sequence number:(int)length
{
    BOOL ok = YES;
    int index;
    
    for (index = 0; index < length; index += 2) 
    {
        BOOL bad = [self setRegister:sequence[index+0] toValue:sequence[index+1]];
        if (bad) 
            ok = NO;
    }
    
    return (ok) ? length : -1;
}

//
//  reg_w_page - load the beginning of a page 
//
- (void) loadPage:(const UInt8 *)page number:(int)length
{
    int  index;
    
    for (index = 0; index < length; index++) 
    {
        if (page[index] == 0xaa) // skip
            continue;
        
        [self setRegister:index toValue:page[index]];
    }
}

//
//  reg_w_var
//
- (void) setRegisterVariable:(const UInt8 *)sequence
{
	int index, length;
    
    while (TRUE) 
    {
		index = *sequence++;
		length = *sequence++;
        
		switch (length) 
        {
            case 0:
                return;  // Exit Strategy
                
            case 254:
                [self loadPage:page4_7311 number:sizeof(page4_7311)];
                break;
                
            case 255:
                [self loadPage:page3_7302 number:sizeof(page3_7302)];
                break;
                
            default:
                if (length > 64) 
                {
                    NSLog(@"Incorrect variable sequence in PAC7311:setRegisterVariable");
                    return;
                }
                while (length > 0) 
                {
                    int partial = (length >= 8) ? 8 : length;
                    
                    [self setRegisterList:index number:partial withValues:(UInt8 *)sequence];
                    
                    sequence += partial;
                    index += partial;
                    length -= partial;
                }
                break;
		}
	}
    
    // Should never get here
}


- (int) getSensorRegister:(UInt16)reg
{
    return [self getRegister:reg];
}

//
//  Same for all PixArt cameras
//
- (void) startupCamera
{
    [self initializeCamera];
    
    [super startupCamera];
}

//
//  Specific to PAC7311 cameras
//
- (void) initializeCamera
{
    [self setRegisterSequence:init_7311 number:sizeof(init_7311)];
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    if (rate > 30) 
        return NO;
    
    switch (res) 
    {
        case ResolutionVGA:
        case ResolutionSIF:
        case ResolutionQSIF:
            return YES;
            break;
            
        default: 
            return NO;
    }
}


- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 15;
    
	return ResolutionVGA;
}

//
// Scan the frame and return the results
//
IsocFrameResult  pac73xxIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength, 
                                         GenericFrameInfo * frameInfo)
{
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
#if REALLY_VERBOSE
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
#endif
    
    if (frameLength < 6) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
        printf("Invalid frame! (length = %d)\n", frameLength);
#endif
        return invalidFrame;
    }
    
    //  the pattern to look for is: 00 1a ff ff 00 ff 96 62 44 // perhaps even more zeroes in front
    //      luminanceOffset = 61; // 24 for 7311  // no need to  include length of marker
    //      footerLength = 74;    // 26 for 7311 // no need to  include length of marker
    
    for (position = 0; position < frameLength - 6; position++) 
    {
        if ((buffer[position+0] == 0xFF) && 
            (buffer[position+1] == 0xFF) && 
            (buffer[position+2] == 0x00) && 
            (buffer[position+3] == 0xFF) && 
            (buffer[position+4] == 0x96))
        {
#if REALLY_VERBOSE
            printf("New chunk!\n");
#endif
            
            if (frameInfo != NULL && position >= frameInfo->locationHint) 
            {
                int luminanceOffset = frameInfo->locationHint;
                
//              printf("The average luminance (1) is %d\n", buffer[position - luminanceOffset]);
//              printf("The average luminance (2) is %d\n", buffer[position - luminanceOffset + 1]);
                
                frameInfo->averageLuminance = buffer[position - luminanceOffset] + buffer[position - luminanceOffset + 1];
                frameInfo->averageLuminanceSet = 1;
#if REALLY_VERBOSE
                printf("The average luminance is %d\n", frameInfo->averageLuminance);
#endif
            }
            
            if (position > 0) 
            {
                *tailStart = 0;
                *tailLength = position;
            }
            
            *dataStart = position + 5 + 2; // 2 works well, tested empirically
            *dataLength = frameLength - *dataStart;
            
            return newChunkFrame;
        }
    }
    
    return validFrame;
}

//
// return number of bytes copied
// does not appear to be needed
//
int  pac73xxIsocDataCopier(void * destination, const void * source, size_t length, size_t available)
{
    UInt8 * src = (UInt8 *) source;
    int position, copied = 0, start = 0;
    
    int end = length - 4;
    if (end < 0) 
        end = 0;
    
    if (length > available-1) 
        length = available-1;
    
    for (position = 0; position < end; position++) 
    {
        if (src[position + 0] == 0xFF && 
            src[position + 1] == 0xFF && 
            src[position + 2] == 0xFF) 
        {
            int tocopy = position - start;
            memcpy(destination, source + start, tocopy);
            
            destination += tocopy;
            copied += tocopy;
            
            start = position + 4;
            position += 3;
        }
    }
    
    memcpy(destination, source + start, length - start);
    
    copied += length - start;
    
    return copied;
}

//
// This chip uses a different pipe for the isochronous input
//
- (UInt8) getGrabbingPipe
{
    return 5;
}

//
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:8];
}

//
//
//
- (BOOL) canSetUSBReducedBandwidth
{
    return YES;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = pac73xxIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
    
    // set up the jpeg header
    
    createPAC73xxJpegHeader(jpegHeader, [self width], [self height]); // PAC7311
    grabContext.headerData = jpegHeader;
    grabContext.headerLength = getPAC73xxJpegHeaderLength();
}


- (BOOL) startupGrabStream 
{
    grabContext.frameInfo.locationHint = 24; // luminanceOffset
    
    [self setRegisterVariable:start_7311];
    
    /*
    setcontrast(gspca_dev);
	
	setgain(gspca_dev);
	setexposure(gspca_dev);
	sethvflip(gspca_dev);
    */
    
	// Set the correct resolution
    
    switch ([self resolution]) 
    {
        case ResolutionQSIF:
            [self setRegister:0xff toValue:0x01];
            [self setRegister:0x17 toValue:0x20];
            [self setRegister:0x87 toValue:0x10];
            break;
            
        case ResolutionSIF:
            [self setRegister:0xff toValue:0x01];
            [self setRegister:0x17 toValue:0x30];
            [self setRegister:0x87 toValue:0x11];
            break;
            
        default:
        case ResolutionVGA:
            [self setRegister:0xff toValue:0x01];
            [self setRegister:0x17 toValue:0x00];
            [self setRegister:0x87 toValue:0x12];
            break;
	}
    
    /*
	sd->sof_read = 0;
	sd->autogain_ignore_frames = 0;
	atomic_set(&sd->avg_lum, -1);
    */
	// Start the stream
    
    [self setRegister:0xff toValue:0x01];
    [self setRegister:0x78 toValue:0x05];
    
    return YES;
}


- (void) shutdownGrabStream 
{
    [self setRegister:0xff toValue:0x04];
    [self setRegister:0x27 toValue:0x80];
    [self setRegister:0x28 toValue:0xca];
    [self setRegister:0x29 toValue:0x53];
    
    [self setRegister:0x2a toValue:0x0e];
    [self setRegister:0xff toValue:0x01];
    [self setRegister:0x3e toValue:0x20];
    
    [self setRegister:0x78 toValue:0x44];
    [self setRegister:0x78 toValue:0x44];
    [self setRegister:0x78 toValue:0x44]; // Bit_0=start stream, Bit_6=LED
}


- (BOOL) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
    int footerLength = 26;

//  printf("decoding a chunk with %ld bytes\n", buffer->numBytes);
    
    if ((buffer->buffer[buffer->numBytes - footerLength - 2] != 0xff) || 
        (buffer->buffer[buffer->numBytes - footerLength - 1] != 0xd9)) 
    {
        return NO;
    }
    
    int result = jpegProcessFrame(buffer->buffer, nextImageBuffer, [self width], [self height], nextImageBufferBPP);
    
    if (result != 921600) 
        printf("jpeg processing returned %d\n", result);
    
    if (result < 0) 
    {
        NSLog(@"Oops: jpegProcessFrame() returned an error! [%i]", result);
        return NO;
    }
    
    [LUT processImage:nextImageBuffer numRows:[self height] rowBytes:nextImageBufferRowBytes bpp:nextImageBufferBPP];
    
    return YES;
}

@end 


#if 0 // Some old code is saved in case it becomes useful in the future

- (void) writeRegister: (UInt16) reg  value: (UInt16) value  buffer: (UInt8 *) buffer  length: (UInt32) length
{
    [self usbWriteCmdWithBRequest:0x00 wValue:value wIndex:reg buf:buffer len:length];
}

- (void) writeRegister: (UInt16) reg  value: (UInt16) value
{
    UInt8 buffer[8];
    
    buffer[0] = value;
    [self usbWriteCmdWithBRequest:0x00 wValue:value wIndex:reg buf:buffer len:1];
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    int maxRate = 0;
    
    switch (res) 
    {
        case ResolutionVGA:
            maxRate = 3;
            break;
            
        case ResolutionCIF:
        case ResolutionSIF:
            maxRate = 12;
            break;
            
        case ResolutionQCIF:
        case ResolutionQSIF:
            maxRate = 30;
            break;
            
        default: 
            return NO;
    }
    
    if (jpegCompression)
        maxRate = 30;
    
    if (rate > maxRate) 
        return NO;
    
    return YES;
}

#endif





@implementation PAC7302Driver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x00], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x00)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x01], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x01)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x02], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x02)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x03], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x03)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x04], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x04)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x05], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x05)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x06], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x06)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x07], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x07)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x08], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x08)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x09], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x09)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x0a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x0a)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x0b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x0b)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x0c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Philips SPC 230NC", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x0d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x0d)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x0e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x0e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7302_GENERIC + 0x0f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7302 based camera (0x0f)", @"name", NULL], 
        
        NULL];
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    if (rate > 30) 
        return NO;
    
    if (res != ResolutionVGA) 
        return NO;
    
    return YES;
}


- (short) width 
{
    return HeightOfResolution(resolution);
}


- (short) height 
{
    return WidthOfResolution(resolution);
}


- (void) initializeCamera
{
    [self setRegisterSequence:init_7302 number:sizeof(init_7302)];
}


- (BOOL) startupGrabStream 
{
    grabContext.frameInfo.locationHint = 61; // luminanceOffset
    
    [self setRegisterVariable:start_7302];
   /* 
    setbrightcont(gspca_dev);
    setcolors(gspca_dev);

    setgain(gspca_dev);
	setexposure(gspca_dev);
	sethvflip(gspca_dev);
    
	sd->sof_read = 0;
	sd->autogain_ignore_frames = 0;
	atomic_set(&sd->avg_lum, -1);
*/    
	// Start the stream
    
    [self setRegister:0xff toValue:0x01];
    [self setRegister:0x78 toValue:0x01];
    
    return YES;
}


- (void) shutdownGrabStream 
{
    [self setRegister:0xff toValue:0x01];
    [self setRegister:0x78 toValue:0x00];
    [self setRegister:0x78 toValue:0x00];
    
    [self setRegister:0xff toValue:0x01];
    [self setRegister:0x78 toValue:0x40];
}


- (BOOL) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
    int footerLength = 74;
    
//  printf("decoding a chunk with %ld bytes\n", buffer->numBytes);
    
    if (0) 
    {
        int b = buffer->numBytes - footerLength - 4;
        printf("buffer[%3d..%3d] = 0x%02x 0x%02x 0x%02x 0x%02x  0x%02x 0x%02x 0x%02x 0x%02x\n", b, b+7, buffer->buffer[b+0], buffer->buffer[b+1], buffer->buffer[b+2], buffer->buffer[b+3], buffer->buffer[b+4], buffer->buffer[b+5], buffer->buffer[b+6], buffer->buffer[b+7]);
        b += 8;
        printf("buffer[%3d..%3d] = 0x%02x 0x%02x 0x%02x 0x%02x  0x%02x 0x%02x 0x%02x 0x%02x\n", b, b+7, buffer->buffer[b+0], buffer->buffer[b+1], buffer->buffer[b+2], buffer->buffer[b+3], buffer->buffer[b+4], buffer->buffer[b+5], buffer->buffer[b+6], buffer->buffer[b+7]);
    }
    
    if ((buffer->buffer[buffer->numBytes - footerLength - 2] != 0xff) || 
        (buffer->buffer[buffer->numBytes - footerLength - 1] != 0xd9)) 
    {
        int b = buffer->numBytes - footerLength - 4;
        printf("buffer[%3d..%3d] = 0x%02x 0x%02x 0x%02x 0x%02x  0x%02x 0x%02x 0x%02x 0x%02x\n", b, b+7, buffer->buffer[b+0], buffer->buffer[b+1], buffer->buffer[b+2], buffer->buffer[b+3], buffer->buffer[b+4], buffer->buffer[b+5], buffer->buffer[b+6], buffer->buffer[b+7]);
        b += 8;
        printf("buffer[%3d..%3d] = 0x%02x 0x%02x 0x%02x 0x%02x  0x%02x 0x%02x 0x%02x 0x%02x\n", b, b+7, buffer->buffer[b+0], buffer->buffer[b+1], buffer->buffer[b+2], buffer->buffer[b+3], buffer->buffer[b+4], buffer->buffer[b+5], buffer->buffer[b+6], buffer->buffer[b+7]);
        return NO;
    }
    
    int result = jpegProcessFrame(buffer->buffer, nextImageBuffer, [self width], [self height], nextImageBufferBPP);
    
    if (result != 921600) 
        printf("jpeg processing returned %d\n", result);
    
    if (result < 0) 
    {
        NSLog(@"Oops: jpegProcessFrame() returned an error! [%i]", result);
        return NO;
    }
    
    [LUT processImage:nextImageBuffer numRows:[self height] rowBytes:nextImageBufferRowBytes bpp:nextImageBufferBPP];
    
    return YES;
}


@end


static const unsigned char pac7311_jpeg_header1[] = 
{
    0xff, 0xd8, 0xff, 0xc0, 0x00, 0x11, 0x08
};

static const unsigned char pac7311_jpeg_header2[] = 
{
    0x03, 0x01, 0x21, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01, 0xff, 0xda,
    0x00, 0x0c, 0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3f, 0x00
};


static int getPAC73xxJpegHeaderLength()
{
    int result = 0;
    
    result += sizeof pac7311_jpeg_header1;
    result += 4;
    result += sizeof pac7311_jpeg_header2;
    
    return result;
}


static void createPAC73xxJpegHeader(void * buffer, int width, int height)
{
    int current = 0;
	unsigned char tmpbuf[8];
    
    memcpy(buffer + current, pac7311_jpeg_header1, sizeof pac7311_jpeg_header1);
    current += sizeof pac7311_jpeg_header1;
    
    tmpbuf[0] = height >> 8;
    tmpbuf[1] = height & 0xff;
    tmpbuf[2] = width >> 8;
    tmpbuf[3] = width & 0xff;
    
    memcpy(buffer + current, tmpbuf, 4);
    current += 4;
    
    memcpy(buffer + current, pac7311_jpeg_header2, sizeof pac7311_jpeg_header2);
    current += sizeof pac7311_jpeg_header2;
}



#define __s8    SInt8
#define __u8    UInt8
#define __s16   SInt16
#define __u16   UInt16
#define __s32   SInt32
#define __u32   UInt32


/* -- from gspca helper -- */

/* variables set at init time */
static int width_out, height_out;

static int jpeg_type_offs = 0;
static int header_len;		/* jpeg header length */

/* ------------- jpeg decoder ------------- */

#define ISHIFT 11
#define IFIX(a) ((__s32)((a) * (1 << ISHIFT) + .5))
#define IMULT(a, b) (((a) * (b)) >> ISHIFT)
#define ITOINT(a) ((a) >> ISHIFT)

/* special markers */
#define M_BADHUFF	-1

#define MAXCOMP 4

struct dec_hufftbl;
struct scan {
	__s32 dc;		/* old dc value */
	struct dec_hufftbl *hudc; /* pointer to huffman table dc */
	struct dec_hufftbl *huac; /* pointer to huffman table ac */
	__u8 next;		/* when to switch to next scan */
	__u8 cid;		/* component id */
	__u8 tq;		/* quant tbl, copied from comp */
};
/*********************************/
#define DECBITS 10		/* seems to be the optimum */
struct dec_hufftbl {
	__u32 maxcode[17];
	__u32 valptr[16];
	__u8 vals[256];
	__u32 llvals[1 << DECBITS];
};
struct in {
	__u8 *p;
	__u32 bits;
	__u8 left;
	__u8 marker;
};
struct jpginfo {
	__u16 dri;		/* restart interval */
	__u16 nm;		/* mcus til next marker */
	__u16 rm;		/* next restart marker */
};
struct comp {
	__u8 cid;
	__u8 hv;
	__u8 tq;
};

static struct dec_data {
	struct in in;
	struct jpginfo info;
	struct scan dscans[MAXCOMP];
	__s32 dquant[3][64];
} decoder;

static __s32 v_dcts[6 * 64 + 16];
static __s32 v_out[6 * 64];
static __s32 v_max[6];

#define GSMART_JPG_HUFFMAN_TABLE_LENGTH 0x1a0

static const __u8 GsmartJPEGHuffmanTable[GSMART_JPG_HUFFMAN_TABLE_LENGTH] = {
	0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
	0x0A, 0x0B, 0x01, 0x00, 0x03,
	0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x01,
	0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x10,
	0x00, 0x02, 0x01, 0x03, 0x03,
	0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D,
	0x01, 0x02, 0x03, 0x00, 0x04,
	0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
	0x22, 0x71, 0x14, 0x32, 0x81,
	0x91, 0xA1, 0x08, 0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0,
	0x24, 0x33, 0x62, 0x72, 0x82,
	0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
	0x29, 0x2A, 0x34, 0x35, 0x36,
	0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
	0x4A, 0x53, 0x54, 0x55, 0x56,
	0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
	0x6A, 0x73, 0x74, 0x75, 0x76,
	0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
	0x8A, 0x92, 0x93, 0x94, 0x95,
	0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
	0xA8, 0xA9, 0xAA, 0xB2, 0xB3,
	0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5,
	0xC6, 0xC7, 0xC8, 0xC9, 0xCA,
	0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
	0xE3, 0xE4, 0xE5, 0xE6, 0xE7,
	0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8,
	0xF9, 0xFA, 0x11, 0x00, 0x02,
	0x01, 0x02, 0x04, 0x04, 0x03, 0x04, 0x07, 0x05, 0x04, 0x04, 0x00,
	0x01, 0x02, 0x77, 0x00, 0x01,
	0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51,
	0x07, 0x61, 0x71, 0x13, 0x22,
	0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xA1, 0xB1, 0xC1, 0x09, 0x23,
	0x33, 0x52, 0xF0, 0x15, 0x62,
	0x72, 0xD1, 0x0A, 0x16, 0x24, 0x34, 0xE1, 0x25, 0xF1, 0x17, 0x18,
	0x19, 0x1A, 0x26, 0x27, 0x28,
	0x29, 0x2A, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45,
	0x46, 0x47, 0x48, 0x49, 0x4A,
	0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65,
	0x66, 0x67, 0x68, 0x69, 0x6A,
	0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x82, 0x83, 0x84,
	0x85, 0x86, 0x87, 0x88, 0x89,
	0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2,
	0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
	0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9,
	0xBA, 0xC2, 0xC3, 0xC4, 0xC5,
	0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7,
	0xD8, 0xD9, 0xDA, 0xE2, 0xE3,
	0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF2, 0xF3, 0xF4, 0xF5,
	0xF6, 0xF7, 0xF8, 0xF9, 0xFA
};

static const __u8 GsmartJPEGScanTable[6] = {
	0x01, 0x00,
	0x02, 0x11,
	0x03, 0x11
};
static const __u8 GsmartQTable[][64] = {

/* index0, Q40 */
	{
	 20, 14, 15, 18, 15, 13, 20, 18, 16, 18, 23, 21, 20, 24, 30, 50,
	 33, 30, 28, 28, 30, 61, 44, 46, 36, 50, 73, 64, 76, 75, 71, 64,
	 70, 69, 80, 90, 115, 98, 80, 85, 109, 86, 69, 70, 100, 136, 101,
	 109,
	 119, 123, 129, 130, 129, 78, 96, 141, 151, 140, 125, 150, 115,
	 126, 129, 124},
	{
	 21, 23, 23, 30, 26, 30, 59, 33, 33, 59, 124, 83, 70, 83, 124, 124,
	 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124,
	 124, 124, 124,
	 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124,
	 124, 124, 124,
	 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124,
	 124, 124, 124},
/* index1, Q50 */
	{
	 16, 11, 12, 14, 12, 10, 16, 14, 13, 14, 18, 17, 16, 19, 24, 40,
	 26, 24, 22, 22, 24, 49, 35, 37, 29, 40, 58, 51, 61, 60, 57, 51,
	 56, 55, 64, 72, 92, 78, 64, 68, 87, 69, 55, 56, 80, 109, 81, 87,
	 95, 98, 103, 104, 103, 62, 77, 113, 121, 112, 100, 120, 92, 101,
	 103, 99},
	{
	 17, 18, 18, 24, 21, 24, 47, 26, 26, 47, 99, 66, 56, 66, 99, 99,
	 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
	 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
	 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99},
/* index2, Q60 */
	{
	 13, 9, 10, 11, 10, 8, 13, 11, 10, 11, 14, 14, 13, 15, 19, 32,
	 21, 19, 18, 18, 19, 39, 28, 30, 23, 32, 46, 41, 49, 48, 46, 41,
	 45, 44, 51, 58, 74, 62, 51, 54, 70, 55, 44, 45, 64, 87, 65, 70,
	 76, 78, 82, 83, 82, 50, 62, 90, 97, 90, 80, 96, 74, 81, 82, 79},
	{
	 14, 14, 14, 19, 17, 19, 38, 21, 21, 38, 79, 53, 45, 53, 79, 79,
	 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79,
	 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79,
	 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79},
/* index3, Q70 */
	{
	 10, 7, 7, 8, 7, 6, 10, 8, 8, 8, 11, 10, 10, 11, 14, 24,
	 16, 14, 13, 13, 14, 29, 21, 22, 17, 24, 35, 31, 37, 36, 34, 31,
	 34, 33, 38, 43, 55, 47, 38, 41, 52, 41, 33, 34, 48, 65, 49, 52,
	 57, 59, 62, 62, 62, 37, 46, 68, 73, 67, 60, 72, 55, 61, 62, 59},
	{
	 10, 11, 11, 14, 13, 14, 28, 16, 16, 28, 59, 40, 34, 40, 59, 59,
	 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59,
	 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59,
	 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59},
/* index4, Q80 */
	{
	 6, 4, 5, 6, 5, 4, 6, 6, 5, 6, 7, 7, 6, 8, 10, 16,
	 10, 10, 9, 9, 10, 20, 14, 15, 12, 16, 23, 20, 24, 24, 23, 20,
	 22, 22, 26, 29, 37, 31, 26, 27, 35, 28, 22, 22, 32, 44, 32, 35,
	 38, 39, 41, 42, 41, 25, 31, 45, 48, 45, 40, 48, 37, 40, 41, 40},
	{
	 7, 7, 7, 10, 8, 10, 19, 10, 10, 19, 40, 26, 22, 26, 40, 40,
	 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40,
	 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40,
	 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40},
/* index5 Q85 */
	{
	 5, 3, 4, 4, 4, 3, 5, 4, 4, 4, 5, 5, 5, 6, 7, 12,
	 8, 7, 7, 7, 7, 15, 11, 11, 9, 12, 17, 15, 18, 18, 17, 15,
	 17, 17, 19, 22, 28, 23, 19, 20, 26, 21, 17, 17, 24, 33, 24, 26,
	 29, 29, 31, 31, 31, 19, 23, 34, 36, 34, 30, 36, 28, 30, 31, 30},
	{
	 5, 5, 5, 7, 6, 7, 14, 8, 8, 14, 30, 20, 17, 20, 30, 30,
	 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
	 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
	 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},
/* Qindex= 86 */
	{0x04, 0x03, 0x03, 0x04, 0x03, 0x03, 0x04, 0x04,
	 0x04, 0x04, 0x05, 0x05, 0x04, 0x05, 0x07, 0x0B,
	 0x07, 0x07, 0x06, 0x06, 0x07, 0x0E, 0x0A, 0x0A,
	 0x08, 0x0B, 0x10, 0x0E, 0x11, 0x11, 0x10, 0x0E,
	 0x10, 0x0F, 0x12, 0x14, 0x1A, 0x16, 0x12, 0x13,
	 0x18, 0x13, 0x0F, 0x10, 0x16, 0x1F, 0x17, 0x18,
	 0x1B, 0x1B, 0x1D, 0x1D, 0x1D, 0x11, 0x16, 0x20,
	 0x22, 0x1F, 0x1C, 0x22, 0x1A, 0x1C, 0x1D, 0x1C,},
	{0x05, 0x05, 0x05, 0x07, 0x06, 0x07, 0x0D, 0x07,
	 0x07, 0x0D, 0x1C, 0x12, 0x10, 0x12, 0x1C, 0x1C,
	 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
	 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
	 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
	 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
	 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
	 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,},
/* Qindex= 88 */
	{0x04, 0x03, 0x03, 0x03, 0x03, 0x02, 0x04, 0x03,
	 0x03, 0x03, 0x04, 0x04, 0x04, 0x05, 0x06, 0x0A,
	 0x06, 0x06, 0x05, 0x05, 0x06, 0x0C, 0x08, 0x09,
	 0x07, 0x0A, 0x0E, 0x0C, 0x0F, 0x0E, 0x0E, 0x0C,
	 0x0D, 0x0D, 0x0F, 0x11, 0x16, 0x13, 0x0F, 0x10,
	 0x15, 0x11, 0x0D, 0x0D, 0x13, 0x1A, 0x13, 0x15,
	 0x17, 0x18, 0x19, 0x19, 0x19, 0x0F, 0x12, 0x1B,
	 0x1D, 0x1B, 0x18, 0x1D, 0x16, 0x18, 0x19, 0x18,},
	{0x04, 0x04, 0x04, 0x06, 0x05, 0x06, 0x0B, 0x06,
	 0x06, 0x0B, 0x18, 0x10, 0x0D, 0x10, 0x18, 0x18,
	 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
	 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
	 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
	 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
	 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
	 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,}
};

#undef CLIP
#define CLIP(color) (((color) > 0xff) \
	? 0xff : (((color) < 0) ? 0 : (color)))

/*************************************************/
/**************	  huffman decoder  ***************/
/*************************************************/

/*need to be on init jpeg jfm:why??*/
static struct comp comp_template[MAXCOMP] = {
	{0x01, 0x22, 0x00},
	{0x02, 0x11, 0x01},
	{0x03, 0x11, 0x01},
	{0x00, 0x00, 0x00}
};

/* Huffman's table - global for all */
static struct dec_hufftbl dhuff[4];
#define dec_huffdc (dhuff + 0)
#define dec_huffac (dhuff + 2)
#define M_RST0	0xd0

static int dec_rec2(struct in *, struct dec_hufftbl *, int *, int, int);

static int fillbits(struct in *in, int le, unsigned int bi)
{
	__u8 b, m;

	if (in->marker) {
		if (le <= 16)
			in->bits = bi << 16, le += 16;
		return le;
	}
	while (le <= 24) {
		b = *in->p++;
		if (b == 0xff && (m = *in->p++) != 0) {
			if (m == 0xff) {
				/* pac7311 - remove ff ff ff xx */
				in->p += 2;
				continue;
			}
			in->marker = m;
			if (le <= 16)
				bi = bi << 16, le += 16;
			break;
		}
		bi = bi << 8 | b;
		le += 8;
	}
	in->bits = bi;		/* tmp... 2 return values needed */
	return le;
}

#define LEBI_GET(in)	(le = in->left, bi = in->bits)
#define LEBI_PUT(in)	(in->left = le, in->bits = bi)

#define GETBITS(in, n) (					\
  (le < (n) ? le = fillbits(in, le, bi), bi = in->bits : 0),	\
  (le -= (n)),							\
  bi >> le & ((1 << (n)) - 1)					\
)

#define UNGETBITS(in, n) (	\
  le += (n)			\
)

static void dec_makehuff(struct dec_hufftbl *hu,
			 __u8 *hufflen, __u8 *huffvals)
{
	int code, k, i, j, d, x, c, v;

	for (i = 0; i < (1 << DECBITS); i++)
		hu->llvals[i] = 0;

/*
 * llvals layout:
 *
 * value v already known, run r, backup u bits:
 *  vvvvvvvvvvvvvvvv 0000 rrrr 1 uuuuuuu
 * value unknown, size b bits, run r, backup u bits:
 *  000000000000bbbb 0000 rrrr 0 uuuuuuu
 * value and size unknown:
 *  0000000000000000 0000 0000 0 0000000
 */
	code = 0;
	k = 0;
	for (i = 0; i < 16; i++, code <<= 1) {	/* sizes */
		hu->valptr[i] = k;
		for (j = 0; j < hufflen[i]; j++) {
			hu->vals[k] = *huffvals++;
			if (i < DECBITS) {
				c = code << (DECBITS - 1 - i);
				v = hu->vals[k] & 0x0f;	/* size */
				for (d = 1 << (DECBITS - 1 - i); --d >= 0;) {
					if (v + i < DECBITS) {
						/* both fit in table */
						x = d >> (DECBITS - 1 - v - i);
						if (v
						    && x < (1 << (v - 1)))
							x += (-1 << v) + 1;
						x = (x << 16) | ((hu-> vals[k]
								& 0xf0) << 4)
							| (DECBITS -
							    (i + 1 + v)) | 128;
					} else
						x = v << 16 | (hu->
							       vals[k] &
							       0xf0) << 4 |
						    (DECBITS - (i + 1));
					hu->llvals[c | d] = x;
				}
			}
			code++;
			k++;
		}
		hu->maxcode[i] = code;
	}
	hu->maxcode[16] = 0x20000;	/* always terminate decode */
}

static __u8 zig[64] = {
	0, 1, 5, 6, 14, 15, 27, 28,
	2, 4, 7, 13, 16, 26, 29, 42,
	3, 8, 12, 17, 25, 30, 41, 43,
	9, 11, 18, 24, 31, 40, 44, 53,
	10, 19, 23, 32, 39, 45, 52, 54,
	20, 22, 33, 38, 46, 51, 55, 60,
	21, 34, 37, 47, 50, 56, 59, 61,
	35, 36, 48, 49, 57, 58, 62, 63
};

static __s32 aaidct[8] = {
	IFIX(0.3535533906), IFIX(0.4903926402),
	IFIX(0.4619397663), IFIX(0.4157348062),
	IFIX(0.3535533906), IFIX(0.2777851165),
	IFIX(0.1913417162), IFIX(0.0975451610)
};

inline static void idctqtab(const __u8 *qin, __s32 *qout)
{
	int i, j;

	for (i = 0; i < 8; i++)
		for (j = 0; j < 8; j++)
			qout[zig[i * 8 + j]] = qin[zig[i * 8 + j]] *
						IMULT(aaidct[i], aaidct[j]);
}

static int init_jpeg_decoder(__u8 *data)
{
	unsigned int i, j, k, l;
	int tc, th, tt, tac, tdc;
	struct comp *comps;
	int done;
	const __u8 *ptr, *sof0;
	const __u8 *quant[2];

	if (jpeg_type_offs == 0) {

		/* set up the huffman table */
		comps = comp_template;
		ptr = GsmartJPEGHuffmanTable;
		l = GSMART_JPG_HUFFMAN_TABLE_LENGTH;
		while (l > 0) {
			__u8 hufflen[16];
			__u8 huffvals[256];

			tc = *ptr++;
			th = tc & 15;
			tc >>= 4;
			tt = tc * 2 + th;
			for (i = 0; i < 16; i++)
				hufflen[i] = *ptr++;
			l -= 1 + 16;
			k = 0;
			for (i = 0; i < 16; i++) {
				for (j = 0; j < (unsigned int) hufflen[i]; j++)
					huffvals[k++] = *ptr++;
				l -= hufflen[i];
			}
			dec_makehuff(dhuff + tt, hufflen, huffvals);
		}

		/* set up the scan table */
		ptr = GsmartJPEGScanTable;
		for (i = 0; i < 3; i++) {
			decoder.dscans[i].cid = *ptr++;
			tdc = *ptr++;
			tac = tdc & 15;
			tdc >>= 4;
			/* for each component */
			for (j = 0; j < 3; j++)
				if (comps[j].cid == decoder.dscans[i].cid)
					break;
			decoder.dscans[i].tq = comps[j].tq;
			decoder.dscans[i].hudc = dec_huffdc + tdc;
			decoder.dscans[i].huac = dec_huffac + tac;
		}

		decoder.dscans[0].next = 6 - 4;
		decoder.dscans[1].next = 6 - 4 - 1;
		decoder.dscans[2].next = 6 - 4 - 1 - 1;	/* 411 encoding */
	}

	/* scan the header */
	quant[0] = quant[1] = 0;
	decoder.info.dri = 0;
	sof0 = 0;
	done = 0;
	ptr = data + 2;
	while (*ptr == 0xff) {
//        printf("ptr{1] = 0x%2x\n", ptr[1]);
		switch (ptr[1]) {
		case 0xc0:		/* SOF0 */
			sof0 = ptr;
			break;
		case 0xda:		/* SOS */
			done = 1;
			break;
		case 0xdb:		/* DQT */
			if (ptr[4] == 0x00) {
				quant[0] = &ptr[5];
				if (ptr[3] == 0x84)
					quant[1] = &ptr[0x45];	/* 2 tables */
			} else {
				quant[1] = &ptr[5];
			}
			break;
		case 0xdd:		/* DRI */
			decoder.info.dri = (ptr[2] << 8) | ptr[3];
			break;
		}
		ptr += (ptr[2] << 8) + ptr[3] + 2;
		if (done)
			break;
	}

	/* set up a quantization table */
	if (quant[0] == 0 || quant[1] == 0) 
    {
        int index = 6; // 0 .. 7
        quant[0] = GsmartQTable[index * 2 + 0];
        quant[1] = GsmartQTable[index * 2 + 1];
//		printf("No quantization tables\n");
//		return -1;
	}
	idctqtab(quant[decoder.dscans[0].tq], decoder.dquant[0]);
	idctqtab(quant[decoder.dscans[1].tq], decoder.dquant[1]);
	idctqtab(quant[decoder.dscans[2].tq], decoder.dquant[2]);

	if (sof0 == 0) {
		printf("No SOF0\n");
		return -1;
	}
	header_len = ptr - data;
//	printf("jpeg header length: %d type: %02x\n", header_len, sof0[11]);
	jpeg_type_offs = sof0 - data + 11;	/* offset of jpeg type */
	return 0;
}

static void jpeg_reset_input_context(struct dec_data *decode,
				     __u8 *buf)
{
	struct in *in = &decode->in;
	struct jpginfo *info = &decode->info;
	struct scan *dscans = decode->dscans;
	int i;

	/* set input context */
	in->p = buf;
	in->left = 0;
	in->bits = 0;
	in->marker = 0;

	/* reset dc values */
	info->nm = info->dri + 1;	/* macroblock count */
	info->rm = M_RST0;
	for (i = 0; i < MAXCOMP; i++)
		dscans[i].dc = 0;
}

static int dec_rec2(struct in *in,
		    struct dec_hufftbl *hu, int *runp, int c, int i)
{
	int le, bi;

	le = in->left;
	bi = in->bits;
	if (i) {
		UNGETBITS(in, i & 127);
		*runp = i >> 8 & 15;
		i >>= 16;
	} else {
		for (i = DECBITS;
		     (c = ((c << 1) | GETBITS(in, 1))) >= (hu->maxcode[i]);
		     i++)
			;
		if (i >= 16) {
			in->marker = M_BADHUFF;
			return 0;
		}
		i = hu->vals[hu->valptr[i] + c - hu->maxcode[i - 1] * 2];
		*runp = i >> 4;
		i &= 15;
	}
	if (i == 0) {		/* sigh, 0xf0 is 11 bit */
		LEBI_PUT(in);
		return 0;
	}
	/* receive part */
	c = GETBITS(in, i);
	if (c < (1 << (i - 1)))
		c += (-1 << i) + 1;
	LEBI_PUT(in);
	return c;
}

#define DEC_REC(in, hu, r, i)	 (	\
  r = GETBITS(in, DECBITS),		\
  i = hu->llvals[r],			\
  i & 128 ?				\
    (					\
      UNGETBITS(in, i & 127),		\
      r = i >> 8 & 15,			\
      i >> 16				\
    )					\
  :					\
    (					\
      LEBI_PUT(in),			\
      i = dec_rec2(in, hu, &r, r, i),	\
      LEBI_GET(in),			\
      i					\
    )					\
)

inline static void decode_mcus(struct in *in,
				__s32 *dct, int n,
				struct scan *sc, __s32 *maxp)
{
	struct dec_hufftbl *hu;
	int i, r, t;
	int le, bi;
	char trash;

	memset(dct, 0, n * 64 * sizeof *dct);
	le = in->left;
	bi = in->bits;

	while (--n >= 0) {
		hu = sc->hudc;
		*dct++ = (sc->dc += DEC_REC(in, hu, r, t));

		hu = sc->huac;
		i = 63;
		while (i > 0) {
			t = DEC_REC(in, hu, r, t);
			if (t == 0 && r == 0) {
				dct += i;
				break;
			}
			dct += r;
			*dct++ = t;
			i -= r + 1;
		}
		*maxp++ = 64 - i;
		if (n == sc->next)
			sc++;
	}
	/* pac7311 - 8 bits unused */
	trash = GETBITS(in, 8);
	LEBI_PUT(in);
}

/*************************************/
/**************  idct  ***************/
/*************************************/

#define S22 IFIX(2 * 0.382683432)
#define C22 IFIX(2 * 0.923879532)
#define IC4 IFIX(1 / 0.707106781)

static __u8 zig2[64] = {
	0, 2, 3, 9, 10, 20, 21, 35,
	14, 16, 25, 31, 39, 46, 50, 57,
	5, 7, 12, 18, 23, 33, 37, 48,
	27, 29, 41, 44, 52, 55, 59, 62,
	15, 26, 30, 40, 45, 51, 56, 58,
	1, 4, 8, 11, 19, 22, 34, 36,
	28, 42, 43, 53, 54, 60, 61, 63,
	6, 13, 17, 24, 32, 38, 47, 49
};

static void idct(__s32 *in, __s32 *out, __s32 *quant, __s32 off, __s32 max)
{
	__s32 t0, t1, t2, t3, t4, t5, t6, t7;	/* t ; */
	__s32 tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6;
	__s32 tmp[64], *tmpp;
	int i, j, te;
	__u8 *zig2p;

	t0 = off;
	if (max == 1) {
		t0 += in[0] * quant[0];
		for (i = 0; i < 64; i++)
			out[i] = ITOINT(t0);
		return;
	}
	zig2p = zig2;
	tmpp = tmp;
	for (i = 0; i < 8; i++) {
		j = *zig2p++;
		t0 += in[j] * quant[j];
		j = *zig2p++;
		t5 = in[j] * quant[j];
		j = *zig2p++;
		t2 = in[j] * quant[j];
		j = *zig2p++;
		t7 = in[j] * quant[j];
		j = *zig2p++;
		t1 = in[j] * quant[j];
		j = *zig2p++;
		t4 = in[j] * quant[j];
		j = *zig2p++;
		t3 = in[j] * quant[j];
		j = *zig2p++;
		t6 = in[j] * quant[j];

		if ((t1 | t2 | t3 | t4 | t5 | t6 | t7) == 0) {
			tmpp[0 * 8] = t0;
			tmpp[1 * 8] = t0;
			tmpp[2 * 8] = t0;
			tmpp[3 * 8] = t0;
			tmpp[4 * 8] = t0;
			tmpp[5 * 8] = t0;
			tmpp[6 * 8] = t0;
			tmpp[7 * 8] = t0;

			tmpp++;
			t0 = 0;
			continue;
		}
		/* IDCT */
		tmp0 = t0 + t1;
		t1 = t0 - t1;
		tmp2 = t2 - t3;
		t3 = t2 + t3;
		tmp2 = IMULT(tmp2, IC4) - t3;
		tmp3 = tmp0 + t3;
		t3 = tmp0 - t3;
		tmp1 = t1 + tmp2;
		tmp2 = t1 - tmp2;
		tmp4 = t4 - t7;
		t7 = t4 + t7;
		tmp5 = t5 + t6;
		t6 = t5 - t6;
		tmp6 = tmp5 - t7;
		t7 = tmp5 + t7;
		tmp5 = IMULT(tmp6, IC4);
		tmp6 = IMULT((tmp4 + t6), S22);
		tmp4 = IMULT(tmp4, (C22 - S22)) + tmp6;
		t6 = IMULT(t6, (C22 + S22)) - tmp6;
		t6 = t6 - t7;
		t5 = tmp5 - t6;
		t4 = tmp4 - t5;

		tmpp[0 * 8] = tmp3 + t7;	/* t0 */
		tmpp[1 * 8] = tmp1 + t6;	/* t1 */
		tmpp[2 * 8] = tmp2 + t5;	/* t2 */
		tmpp[3 * 8] = t3 + t4;		/* t3 */
		tmpp[4 * 8] = t3 - t4;		/* t4 */
		tmpp[5 * 8] = tmp2 - t5;	/* t5 */
		tmpp[6 * 8] = tmp1 - t6;	/* t6 */
		tmpp[7 * 8] = tmp3 - t7;	/* t7 */
		tmpp++;
		t0 = 0;
	}
	for (i = 0, j = 0; i < 8; i++) {
		t0 = tmp[j + 0];
		t1 = tmp[j + 1];
		t2 = tmp[j + 2];
		t3 = tmp[j + 3];
		t4 = tmp[j + 4];
		t5 = tmp[j + 5];
		t6 = tmp[j + 6];
		t7 = tmp[j + 7];
		if ((t1 | t2 | t3 | t4 | t5 | t6 | t7) == 0) {
			te = ITOINT(t0);
			out[j + 0] = te;
			out[j + 1] = te;
			out[j + 2] = te;
			out[j + 3] = te;
			out[j + 4] = te;
			out[j + 5] = te;
			out[j + 6] = te;
			out[j + 7] = te;
			j += 8;
			continue;
		}
		/* IDCT */
		tmp0 = t0 + t1;
		t1 = t0 - t1;
		tmp2 = t2 - t3;
		t3 = t2 + t3;
		tmp2 = IMULT(tmp2, IC4) - t3;
		tmp3 = tmp0 + t3;
		t3 = tmp0 - t3;
		tmp1 = t1 + tmp2;
		tmp2 = t1 - tmp2;
		tmp4 = t4 - t7;
		t7 = t4 + t7;
		tmp5 = t5 + t6;
		t6 = t5 - t6;
		tmp6 = tmp5 - t7;
		t7 = tmp5 + t7;
		tmp5 = IMULT(tmp6, IC4);
		tmp6 = IMULT((tmp4 + t6), S22);
		tmp4 = IMULT(tmp4, (C22 - S22)) + tmp6;
		t6 = IMULT(t6, (C22 + S22)) - tmp6;
		t6 = t6 - t7;
		t5 = tmp5 - t6;
		t4 = tmp4 - t5;

		out[j + 0] = ITOINT(tmp3 + t7);
		out[j + 1] = ITOINT(tmp1 + t6);
		out[j + 2] = ITOINT(tmp2 + t5);
		out[j + 3] = ITOINT(t3 + t4);
		out[j + 4] = ITOINT(t3 - t4);
		out[j + 5] = ITOINT(tmp2 - t5);
		out[j + 6] = ITOINT(tmp1 - t6);
		out[j + 7] = ITOINT(tmp3 - t7);
		j += 8;
	}
}

static int dec_readmarker(struct in *in)
{
	int m;

	in->left = fillbits(in, in->left, in->bits);
	if ((m = in->marker) == 0)
		return 0;
	in->left = 0;
	in->marker = 0;
	return m;
}

static int dec_checkmarker(struct dec_data *decode)
{
	struct jpginfo *info = &decode->info;
	struct scan *dscans = decode->dscans;
	struct in *in = &decode->in;
	int i;

	if (dec_readmarker(in) != info->rm)
		return -1;
	info->nm = info->dri;
	info->rm = (info->rm + 1) & ~0x08;
	for (i = 0; i < MAXCOMP; i++)
		dscans[i].dc = 0;
	return 0;
}

static int jpeg422_to_rgb24(unsigned char *pic, unsigned char *buf)
{
	int width, height;
	int mcusx, mcusy, mx, my;
	__s32 *dcts = v_dcts;
	__s32 *out = v_out;
	__s32 *max = v_max;
	int k, j;
	int nextline, nextblk, nextnewline;
	__u8 *pic0, *pic1;
	int picy, picx;
	__s32 *outy, *inv, *inu;
	int outy1, outy2;
	int v, u, y1, v1, u1, u2;
	struct dec_data *decode = &decoder;
	int r_offset, g_offset, b_offset;

	init_jpeg_decoder(buf);

	buf += header_len;
	width = width_out;
	height = height_out;
	mcusx = width / 16;
	mcusy = height / 8;
	jpeg_reset_input_context(decode, buf);

	r_offset = 2;
	b_offset = 0;
	g_offset = 1;

	nextline = 3 * (width * 2 - 16);
	nextblk = 3 * width * 8;
	nextnewline = 3 * width;
	for (my = 0, picy = 0; my < mcusy; my++) {
		for (mx = 0, picx = 0; mx < mcusx; mx++) {
			if (decode->info.dri && !--decode->info.nm)
				if (dec_checkmarker(decode))
					return -1;
			decode_mcus(&decode->in, dcts, 4, decode->dscans, max);
			idct(dcts, out, decode->dquant[0],
			     IFIX(128.5), max[0]);
			idct(dcts + 64, out + 64, decode->dquant[0],
			     IFIX(128.5), max[1]);
			idct(dcts + 128, out + 256, decode->dquant[1],
			     IFIX(0.5), max[2]);
			idct(dcts + 192, out + 320, decode->dquant[2],
			     IFIX(0.5), max[3]);
			pic0 = pic + picx + picy;
			pic1 = pic0 + nextnewline;
			outy = out;
			outy1 = 0;
			outy2 = 8;
			inv = out + 64 * 4;
			inu = out + 64 * 5;
			for (j = 0; j < 4; j++) {
				for (k = 0; k < 8; k++) {
					if (k == 4) {
						outy1 += 56;
						outy2 += 56;
					}
					/* outup 4 pixels */
					v = *inv++;
					u = *inu++;
					/* MX color space why not? */
					v1 = ((v << 10) + (v << 9)) >> 10;
					u1 = ((u << 8) + (u << 7) +
					      (v << 9) + (v << 4)) >> 10;
					u2 = ((u << 11) + (u << 4)) >> 10;
					/* top pixel Right */
					y1 = outy[outy1++];
					pic0[r_offset] = CLIP((y1 + v1));
					pic0[g_offset] = CLIP((y1 - u1));
					pic0[b_offset] = CLIP((y1 + u2));
					pic0 += 3;
					/* top pixel Left */
					y1 = outy[outy1++];
					pic0[r_offset] = CLIP((y1 + v1));
					pic0[g_offset] = CLIP((y1 - u1));
					pic0[b_offset] = CLIP((y1 + u2));
					pic0 += 3;
					/* bottom pixel Right */
					y1 = outy[outy2++];
					pic1[r_offset] = CLIP((y1 + v1));
					pic1[g_offset] = CLIP((y1 - u1));
					pic1[b_offset] = CLIP((y1 + u2));
					pic1 += 3;
					/* bottom pixel Left */
					y1 = outy[outy2++];
					pic1[r_offset] = CLIP((y1 + v1));
					pic1[g_offset] = CLIP((y1 - u1));
					pic1[b_offset] = CLIP((y1 + u2));
					pic1 += 3;
				}
				outy += 16;
				outy1 = 0;
				outy2 = 8;
				pic0 += nextline;
				pic1 += nextline;
			}
			picx += 16 * 3;
		}
		picy += nextblk;
	}
	return width * height * 3;
}

/* --  fin gspca helper -- */


int jpegProcessFrame(unsigned char * rq, unsigned char * fb, int good_img_width, int good_img_height, int bpp)
{
    width_out = good_img_width;
    height_out = good_img_height;
    
    return jpeg422_to_rgb24(fb, rq);
}

