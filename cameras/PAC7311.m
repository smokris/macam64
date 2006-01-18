//
//  PAC7311.m
//
//  macam - webcam app and QuickTime driver component
//  PAC7311 - driver for PixArt PAC7311 single chip VGA webcam solution
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


#import "PAC7311.h"
#include "USB_VendorProductIDs.h"


#define OUTVI USBmakebmRequestType(kUSBOut,kUSBVendor,kUSBInterface)
#define OUTSD USBmakebmRequestType(kUSBOut,kUSBStandard,kUSBDevice)


@implementation PAC7311


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera", @"name", NULL], 
        
        NULL];
}


- (CameraError) startupGrabbing
{
	CameraError err = CameraErrorOK;
    
	if (![self usbSetAltInterfaceTo:8 testPipe:5]) 
        return CameraErrorNoBandwidth;
    
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x0041 buf:NULL len:0]; // Bit0=Image Format, Bit1=LED, Bit2=Compression test mode enable
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x000f buf:NULL len:0]; // Power Control
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x30 wIndex:0x0011 buf:NULL len:0]; // Analog Bias
    
	// Front gain 2bits, Color gains 4bits X 3, Global gain 5bits
	// mode 1-5
	// 0x42-0x4A:data rate of compressed image
    
	static UInt8 pac207_sensor_init[][8] = {
    {0x04,0x12,0x0d,0x00,0x6f,0x03,0x29,0x00},		// 0:0x0002
    {0x00,0x96,0x80,0xa0,0x04,0x10,0xF0,0x30},		// 1:0x000a reg_10 digital gain Red Green Blue Ggain
    {0x00,0x00,0x00,0x70,0xA0,0xF8,0x00,0x00},		// 2:0x0012
    {0x00,0x00,0x32,0x00,0x96,0x00,0xA2,0x02},		// 3:0x0040
    {0x32,0x00,0x96,0x00,0xA2,0x02,0xAF,0x00},		// 4:0x0042 reg_66 rate control
    {0x00,0x00,0x36,0x00,   0,   0,   0,   0},		// 5:0x0048 reg_72 rate control end BalSize_4a = 0x36
	};
    
    
	static UInt8 pac7311_sensor_init[][8] = {		
    {0x40, 0x00, 0x00, 0x00, 0x78, 0x00, 0x01, 0x00},
    {0x40, 0x00, 0x80, 0x00, 0x7d, 0x00, 0x01, 0x00},
    {0x40, 0x00, 0x00, 0x00, 0x78, 0x00, 0x01, 0x00},
    {0x40, 0x00, 0x04, 0x00, 0x78, 0x00, 0x01, 0x00},
    {0x40, 0x00, 0x04, 0x00, 0xff, 0x00, 0x01, 0x00},
    {0x40, 0x00, 0x80, 0x00, 0x27, 0x00, 0x01, 0x00},
	};
    
    //	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x10 wIndex:0x000f buf:NULL len:0]; // Power Control
    
    // this is not right [hxr] those numbers are pipe adresses, and should probably be register addresses
    
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0081 buf:pac7311_sensor_init[0] len:8]; // 0x0002
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac7311_sensor_init[1] len:8]; // 0x000a
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0083 buf:pac7311_sensor_init[2] len:8]; // 0x0012
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0004 buf:pac7311_sensor_init[3] len:8]; // 0x0040
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0085 buf:pac7311_sensor_init[4] len:8]; // 0x0042
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0006 buf:pac7311_sensor_init[5] len:4]; // 0x0048
    
/*    
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac207_sensor_init[0] len:8]; // 0x0002
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x000a buf:pac207_sensor_init[1] len:8]; // 0x000a
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0012 buf:pac207_sensor_init[2] len:8]; // 0x0012
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0040 buf:pac207_sensor_init[3] len:8]; // 0x0040
//	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0042 buf:pac207_sensor_init[4] len:8]; // 0x0042
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0048 buf:pac207_sensor_init[5] len:4]; // 0x0048
*/    
    /*
     if(compression){
         [self usbWriteCmdWithBRequest:0x00 wValue:0x88 wIndex:0x004a buf:NULL len:0]; // Compression Balance size 0x88
         NSLog(@"compression");
     } else {
         [self usbWriteCmdWithBRequest:0x00 wValue:0xff wIndex:0x004a buf:NULL len:0]; // Compression Balance size
     }
     */
    
    //	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x004b buf:NULL len:0]; // SRAM test value
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x02 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)
    
	static UInt8 pac207_video_mode[][7]={ 
    {0x07,0x12,0x05,0x52,0x00,0x03,0x29},		// 0:Driver
    {0x04,0x12,0x05,0x0B,0x76,0x02,0x29},		// 1:ResolutionQCIF
    {0x04,0x12,0x05,0x22,0x80,0x00,0x29},		// 2:ResolutionCIF
	};
    
	static UInt8 pac7311_video_mode[][8]={ 
    {0x40, 0x00, 0xca, 0x00, 0x28, 0x00, 0x01, 0x00},		// 0:Driver
    {0x40, 0x00, 0x53, 0x00, 0x29, 0x00, 0x01, 0x00},		// ? 1:ResolutionQCIF
    {0x40, 0x00, 0x0e, 0x00, 0x2a, 0x00, 0x01, 0x00},		// ? 2:ResolutionCIF
    {0x40, 0x00, 0x01, 0x00, 0xff, 0x00, 0x01, 0x00},		// No idea yet
    {0x40, 0x00, 0x20, 0x00, 0x3e, 0x00, 0x01, 0x00},		// No idea yet VGA?
	};
    
    
	switch (resolution) 
    {
        case ResolutionQCIF: // 176 x 144
        //	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x03 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)
            [self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac7311_video_mode[1] len:8];	// ?????
            break;
        case ResolutionCIF: // 352 x 288
        //	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x02 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)
            [self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac7311_video_mode[2] len:8];	// ?????
        //	if(compression){
        //		[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x04 wIndex:0x0002 buf:NULL len:0]; // PXCK = 12MHz /n
        //	} else {
        //		[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x0a wIndex:0x0002 buf:NULL len:0]; // PXCK = 12MHz /n
        //	}
            break;
        case ResolutionVGA:
            [self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac7311_video_mode[3] len:8];	// ????? hope this is right here		
            [self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac7311_video_mode[4] len:8];	// ?????
            break;
        default:
#ifdef VERBOSE
            NSLog(@"startupGrabbing: Invalid resolution!");
#endif
            return CameraErrorUSBProblem;
	}
    
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x0a wIndex:0x000e buf:NULL len:0]; // PGA global gain (Bit 4-0)
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x0018 buf:NULL len:0]; // ???
    
//	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0042 buf:pac207_sensor_init[4] len:8]; // 0x0042
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0042 buf:pac7311_sensor_init[4] len:8]; // 0x0042
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x7e wIndex:0x004a buf:NULL len:0]; // ???
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x0040 buf:NULL len:0]; // Start ISO pipe
    
    return err;
}


@end
