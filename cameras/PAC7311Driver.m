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


#import "PAC7311Driver.h"

#include "USB_VendorProductIDs.h"
#include "JpgDecompress.h"
#include "spcadecoder.h"

#define OUTVI USBmakebmRequestType(kUSBOut,kUSBVendor,kUSBInterface)
#define OUTSD USBmakebmRequestType(kUSBOut,kUSBStandard,kUSBDevice)


@implementation PAC7311Driver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (probably)", @"name", NULL], 
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
	bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    jpegCompression = NO;
    
	return self;
}


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
- (void) startupCamera
{
    /*
    // usbsnoop.log
    // all vendor-device, except interrupt, etc
    // request is always 0x00
    //  value index 
// start initialization
        00  78   //// 40 78
        80  7d
        00  78   //// 40 78
        04  78   //// 44 78
        04  ff
        08  27   //// 80 27
        ca  28
        53  29
        0e  2a
        01  ff
        20  3e
    // interrupt 00 00  ->  00  11
// end of start
    // interrupt 00 11 //// not present
        00  3e
        04  ff
        00  27  // URB 20
        ca  28
        10  29
        06  2a
    // alternate 8
    // interrupt 00 11 //// interrupt 00 00 
    // alternate 7
    // interrupt 00 11 //// interrupt 00 00
    00  01  ff
    00  00  02  [48 0a 40 08 00 00 08 00]  // URB 29 
    00  00  0a  [06 ff 11 ff 5a 30 9f 4c]  // URB 30 [06 ff 11 f0 64 30 9f 4c]
    00  00  12  [00 07 00 0d 10 00 a0 10]  // URB 31
    and so on 
    00  04  ff  // URB 49 back to nromal
    00  02  02
    00  54  03  [54]  // URB 51
    00  09  04  [09]  // URB 52
    00  10  05  [10]
    00  09  06  [09]
    00  0f  07  [0f]
    00  09  08  [09]  // 56
    00  00  09  [00]  // 57
    00  07  0c  [07]
    00  00  0d  [00]
    00  00  0e  [00]
    00  01  0f  [01]  // 61
    blah blah
    00  ca  28  [ca]  // URB 81
    00  10  29  [10]
    00  06  2a  [06]
    00  78  2b  [78]
    00  00  2c  [00]
    blah
    00  01  ff  [01]  // URB 96
    00  44  78  [44]
    00  45  78  [45]
    00  04  ff  [04]
        80  27
        ca  28
        53  29
        0e  2a
        01  ff
        20  3e
        44  78
        04  78          //  URB 107
        

    // alternate 0 // URB 110
    // interrupt 00  11
        00  3e
        04  ff
        
    // alternate 8 // URB 118
    // interrupt 00 11
    // alternate 7
    // interrup 00 11
        01  ff  // URB 122
    
    
    
        01  11  // URB 189
        01  ff
        44  78
        45  78  //  URB 192
    // reset isoc (85)  // URB 193
    // get current frame number 
    // URB 195 strat of isoc transfer
     
     
        0c  1f  [0c]  // URB 208
        0a  03  [0a]
        60  04  [60]
     //iso
        00  15  [00]  // URB 212
        0e  80  [0e]
        04  ff  [04]
        ba  03  [ba]
        09  04  [09]
        0f  05  [0f]
        0b  10  [0b]
        01  11  [01]  // URB 219
     // iso 220, 221, 222
        01  ff  [01]  // URB 223
     // iso 224
        0a  03  [0a]  // URB 225
        40  04  [40]  // URB 226
        04  ff  [04]
        0b  04  [0b]
        05  05  [05]
        0f  10  [0f]  // URB 230
        01  11  [01]  // URB 231
     // iso 232, 233, 234, 235, 236
        01  ff  [01]  // URB 237
        18  1f  [18]
        0a  03  [0a]
        00  04  [00]  // URB 240
     // iso 241
        12  80  [12]  // URB 242
        04  ff  [04]
        03  02  [03]
        54  03  [54]
        0c  04  [0c]
        15  05  [15]
        04  10  [04]
        05  32  [05]
        01  11  [01]  // URB 250
     // iso 251, 252, 253, 254
        0b  10  [0b]  // URB 255
     // iso 256
        01  11  [01]  // URB 257
     // iso 258, 259, 260, 261, 262, 263, 264
        0f  10  [0f]  // UEB 265
        01  11  [01]  // URB 266
     // is 267 ... 290 ... 450 ... 599
    // abort pipe  //  URB 600
    // reset pipe  //  URB 601
    // abort pipe  //  URB 602
    */
    
    /*
     00 1a ff ff 00 ff 96 62 44 // perhaps even more zeroes in front
     // ff ff 00 ff 96 62 - start of image? at 0x28 of first packet after a bunch of zeroes
     // ff ff 00 ff 96 62 44 f2 // 7a 5c 8a c1 00 88 a0 d3 81 a3 a8 08 8e cd 2e 68
     
     
     00000000: 80 11 0a 28 01 10 a2 80 11 0a 28 03 ff d9 16 48
     00000010: 08 06 42 0a 01 00 00 00 00 00 00 00 00 00 00 00
     00000020: 00 00 00 00 00 00 00 1a ff ff 00 ff 96 62 44 f2
     00000030: 7a 5c 8a c1 00 88 a0 d3 81 a3 a8 08 8e cd 2e 68
     
     00000000: 88 51 40 08 85 14 00 88 51 40 1f 00 ff d9 17 48
     00000010: 0e 0a 48 0d 03 01 00 01 00 00 00 00 00 00 11 00
     00000020: 00 00 00 00 00 00 00 1a ff ff 00 ff 96 62 44 f2
     00000030: 80 4f b8 a7 66 b0 40 22 26 4d 38 35 00 22 3f 34
     
     00000000: 00 00 00 00 00 00 00 1a ff ff 00 ff 96 62 44 f3
     00000010: dd c2 9c 1b a5 72 ad 40 44 50 46 7b 0a 70 6c d1
     00000020: a8 08 8e 0d 4e dd ef 4e e0 22 38 35 01 85 20 11
     
     00000000: 21 45 00 22 14 50 02 21 45 00 7f 00 ff d9 11 48
     00000010: 18 14 5e 17 0c 06 04 04 00 00 00 00 00 00 60 00
     00000020: 00 00 00 00 00 00 00 1a ff ff 00 ff 96 62 44 f3
     00000030: c0 c4 fb 52 ee 35 ce b6 10 88 ed d4 b9 a3 50 11
     
     00000000: 14 50 02 21 45 00 22 14 50 07 ff 00 ff d9 12 48
     00000010: 16 12 53 0d 05 02 01 01 00 00 00 00 00 00 11 00
     00000020: 00 00 00 00 00 00 00 1a ff ff 00 ff 96 62 44 e3
     00000030: c3 73 4e 0d 5c c8 04 45 0c 4d 28 7a 00 44 78 7a
     
     00000000: 14 00 88 51 40 08 85 14 00 88 51 40 08 85 14 00
     00000010: 88 51 40 08 85 14 00 88 51 40 08 85 14 00 88 51
     00000020: 40 08 85 14 00 88 51 40 08 85 14 00 88 51 40 08
     00000030: 85 14 00 88 51 40 1f ff 00 00 ff d9 13 48 1e 1a
     00000040: 5c 14 09 05 03 03 00 00 00 00 00 00 01 00 00 00
     00000050: 00 00 00 00 00 1a ff ff 00 ff 96 62 44 e4 03 7e
     00000060: 03 d2 9d ba b9 95 ac 31 11 41 c5 28 6a 40 22 38
     
     00000000: 14 50 02 21 45 00 22 14 50 07 ff 00 ff d9 14 48
     00000010: 1e 18 5d 15 0a 05 03 03 00 00 00 00 00 00 00 00
     00000020: 00 00 00 00 00 00 00 1a ff ff 00 ff 96 62 44 e4
     00000030: 77 52 86 e2 b9 fa 0c 44 50 71 4f 06 95 82 e2 22
     */
    
    [self writeRegister:0x78 value:0x40];
    [self writeRegister:0x78 value:0x40];
    [self writeRegister:0x78 value:0x44];
    [self writeRegister:0xff value:0x04];
    [self writeRegister:0x27 value:0x80];
    [self writeRegister:0x28 value:0xca];
    [self writeRegister:0x29 value:0x53];
    [self writeRegister:0x2a value:0x0e];
    [self writeRegister:0xff value:0x01];
    [self writeRegister:0x3e value:0x20];
    
    // write interrupt?
    
    [self writeRegister:0x3e value:0x00];
    [self writeRegister:0xff value:0x04];
    [self writeRegister:0x27 value:0x00];
    [self writeRegister:0x28 value:0xca];
    [self writeRegister:0x29 value:0x10];
    [self writeRegister:0x2a value:0x06];
    
    /*
	[self setBrightness:0.5];
	[self setContrast:0.5];
	[self setGamma:0.5];
	[self setSaturation:0.5];
	[self setSharpness:0.5];
     */
    skipBytes = 0;
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

//
// Return the default resolution and rate
//
- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 5;
    
	return ResolutionCIF;
}


- (CameraError) startupGrabbingDoNotCall
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
/*    
	static UInt8 pac207_sensor_init[][8] = {
    {0x04,0x12,0x0d,0x00,0x6f,0x03,0x29,0x00},		// 0:0x0002
    {0x00,0x96,0x80,0xa0,0x04,0x10,0xF0,0x30},		// 1:0x000a reg_10 digital gain Red Green Blue Ggain
    {0x00,0x00,0x00,0x70,0xA0,0xF8,0x00,0x00},		// 2:0x0012
    {0x00,0x00,0x32,0x00,0x96,0x00,0xA2,0x02},		// 3:0x0040
    {0x32,0x00,0x96,0x00,0xA2,0x02,0xAF,0x00},		// 4:0x0042 reg_66 rate control
    {0x00,0x00,0x36,0x00,   0,   0,   0,   0},		// 5:0x0048 reg_72 rate control end BalSize_4a = 0x36
	};
*/    
    
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
/*    
	static UInt8 pac207_video_mode[][7]={ 
    {0x07,0x12,0x05,0x52,0x00,0x03,0x29},		// 0:Driver
    {0x04,0x12,0x05,0x0B,0x76,0x02,0x29},		// 1:ResolutionQCIF
    {0x04,0x12,0x05,0x22,0x80,0x00,0x29},		// 2:ResolutionCIF
	};
*/    
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
    return [self usbSetAltInterfaceTo:8 testPipe:[self getGrabbingPipe]];
}


//
// Scan the frame and return the results
//
IsocFrameResult  pac7311IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                        UInt32 * dataStart, UInt32 * dataLength, 
                                        UInt32 * tailStart, UInt32 * tailLength)
{
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
#if REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
#endif
    
    if (frameLength < 6) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
//        printf("Invalid frame!\n");
#endif
        return invalidFrame;
    }
    
    //  00 1a ff ff 00 ff 96 62 44 // perhaps even more zeroes in front

    for (position = 0; position < frameLength - 6; position++) 
    {
        if ((buffer[position+0] == 0xFF) && 
            (buffer[position+1] == 0xFF) && 
            (buffer[position+2] == 0x00) && 
            (buffer[position+3] == 0xFF) && 
            (buffer[position+4] == 0x96))
        {
#if REALLY_VERBOSE
//            printf("New chunk!\n");
#endif
            if (position > 0) 
            {
                *tailStart = 0;
                *tailLength = position;
            }
            
            *dataStart = position;
            *dataLength = frameLength - *dataStart;
            
            return newChunkFrame;
        }
    }
    
    return validFrame;
}

//
// return number of bytes copied
//
int  pac7311IsocDataCopier(void * destination, const void * source, size_t length, size_t available)
{
    UInt8 * src = (UInt8 *) source;
    int position, end, copied = 0, start = 0;
    
    end = length - 4;
    if (end < 0) 
        end  = 0;
    
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
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = pac7311IsocFrameScanner;
    grabContext.isocDataCopier = pac7311IsocDataCopier;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
- (BOOL) startupGrabStream 
{
    static BOOL firstTime = YES;
    
    // URB 189
    
    [self writeRegister:0x11 value:0x01];
    if (firstTime) 
    {
        [self writeRegister:0xff value:0x01];  // need this the first time
        [self writeRegister:0x78 value:0x44];
        [self writeRegister:0x78 value:0x45];
        
        firstTime = NO;
    }
//    (*intf)->ResetPipe(intf, 5);

/*
 // reset isoc (85)  // URB 193
// get current frame number 
// URB 195 strat of isoc transfer
    
    
    0c  1f  [0c]  // URB 208
    0a  03  [0a]
    60  04  [60]
    //iso
    00  15  [00]  // URB 212
    0e  80  [0e]
    04  ff  [04]
    ba  03  [ba]
    09  04  [09]
    0f  05  [0f]
    0b  10  [0b]
    01  11  [01]  // URB 219
                  // iso 220, 221, 222
    01  ff  [01]  // URB 223
                  // iso 224
    0a  03  [0a]  // URB 225
    40  04  [40]  // URB 226
    04  ff  [04]
    0b  04  [0b]
    05  05  [05]
    0f  10  [0f]  // URB 230
    01  11  [01]  // URB 231
                  // iso 232, 233, 234, 235, 236
    01  ff  [01]  // URB 237
    18  1f  [18]
    0a  03  [0a]
    00  04  [00]  // URB 240
                  // iso 241
*/
    /*
    [self writeRegister:0x80 value:0x12];
    [self writeRegister:0xff value:0x04];
    [self writeRegister:0x02 value:0x03];
    [self writeRegister:0x03 value:0x54];
    [self writeRegister:0x04 value:0x0c];
    [self writeRegister:0x05 value:0x15];
    [self writeRegister:0x10 value:0x04];
    [self writeRegister:0x32 value:0x05];
    [self writeRegister:0x11 value:0x01];
    
    [self writeRegister:0x10 value:0x0b];
    [self writeRegister:0x11 value:0x01];
    
    // probably enough with these two
    
    [self writeRegister:0x10 value:0x0f];
    [self writeRegister:0x11 value:0x01];
    */
    
    /*
    [self writeRegister:0xff value:0x01];
    [self writeRegister:0x78 value:0x44];  // 0x44 or 0x04
    [self writeRegister:0x78 value:0x45];  // 0x45 or 0x05
    */
    return YES;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    [self writeRegister:0xff value:0x01];
    /*
    [self writeRegister:0x78 value:0x04];
    [self writeRegister:0x78 value:0x44];
    [self writeRegister:0x78 value:0x44];
    */
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]];
}

- (BOOL) canSetSaturation 
{ 
    return YES;
}

- (void) setSaturation: (float) v 
{
    skipBytes = 16 * v;
    skipBytes *= 2;
    skipBytes += 0;
    printf("skipBytes = %u\n", (unsigned int) skipBytes);
}


- (void) analyze: (GenericChunkBuffer *) buffer
{
    int position, i, last = 0;
    
    for (position = 0; position < buffer->numBytes - 3; position++) 
    {
        if (buffer->buffer[position + 0] == 0xFF &&
            buffer->buffer[position + 1] == 0xFF &&
            buffer->buffer[position + 2] == 0xFF) 
        {
            printf("FF FF FF marker at %5.5d (+%4.4d):", position, position - last);
            for (i = -5; i < 11; i++) 
                printf(" 0x%2.2X", buffer->buffer[position + i]);
            printf("\n");
            last = position;
        }
    }
    
    printf("length (%ld) - last (%d) = %ld bytes remaining\n", buffer->numBytes, last, buffer->numBytes - last);
    printf("\n");
    
    last = 0;
    
    for (position = 4; position < buffer->numBytes - 4; position++) 
        if (buffer->buffer[position] == 0xFF) 
        {
            printf("0x%2.2X  0xFF 0x%2.2X  0x%2.2X 0x%2.2X 0x%2.2X 0x%2.2X marker at %5.5d (%d since last)\n", 
                   buffer->buffer[position - 1], 
                   buffer->buffer[position + 1], 
                   buffer->buffer[position + 2], 
                   buffer->buffer[position + 3], 
                   buffer->buffer[position + 4], 
                   buffer->buffer[position + 5], 
                   position, position - last);
            last = position;
        }
    
    printf("length (%ld) - last (%d) = %ld bytes remaining\n", buffer->numBytes, last, buffer->numBytes - last);
    printf("\n");
    
    // save file?
}


//
// This is the method that takes the raw chunk data and turns it into an image
//
- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
    static GenericChunkBuffer cleanBuffer = { NULL, 0 };
    static int counter = 0;
//    int i, skip = 16;
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
#ifdef REALLY_VERBOSE
//    printf("Need to decode a JPEG buffer with %ld bytes.\n", buffer->numBytes);
#endif
    
    if (cleanBuffer.buffer == NULL) 
        cleanBuffer.buffer = malloc(grabContext.chunkBufferLength);
    cleanBuffer.numBytes = pac7311IsocDataCopier(cleanBuffer.buffer, buffer->buffer, buffer->numBytes, grabContext.chunkBufferLength);
    
#ifdef REALLY_VERBOSE
//    printf("Need to decode a buffer with %ld bytes.\n", cleanBuffer.numBytes);
#endif
    
    if (counter++ % 100 == 0) 
        [self analyze:&cleanBuffer];
    
    [bayerConverter setSourceFormat:7]; // This is probably different
    [bayerConverter setSourceWidth:rawWidth height:rawHeight];
    [bayerConverter setDestinationWidth:rawWidth height:rawHeight];
    [bayerConverter convertFromSrc:cleanBuffer.buffer
                            toDest:nextImageBuffer
                       srcRowBytes:rawWidth
                       dstRowBytes:nextImageBufferRowBytes
                            dstBPP:nextImageBufferBPP
                              flip:hFlip
                         rotate180:NO]; // This might be different too
    
//	nextImageBufferBPP = 3;
//	nextImageBufferRowBytes = 640 * 3;
///	JpgDecompress(cleanBuffer.buffer + skipBytes, nextImageBuffer, cleanBuffer.numBytes - skipBytes, [self width], [self height]);
    
    // when jpeg_decode422() is called:
    //   frame.data - points to output buffer
    //   frame.tmpbuffer - points to input buffer
    //   frame.scanlength -length of data (tmpbuffer on input, data on output)
/*    
    spca50x->frame->width = rawWidth;
    spca50x->frame->height = rawHeight;
    spca50x->frame->hdrwidth = rawWidth;
    spca50x->frame->hdrheight = rawHeight;
    
    spca50x->frame->data = nextImageBuffer;
    spca50x->frame->tmpbuffer = buffer->buffer + skip;
    spca50x->frame->scanlength = buffer->numBytes - skip;
    
    spca50x->frame->decoder = &spca50x->maindecode;
    
    for (i = 0; i < 256; i++) 
    {
        spca50x->frame->decoder->Red[i] = [LUT red:i green:i];
        spca50x->frame->decoder->Green[i] = [LUT green:i];
        spca50x->frame->decoder->Blue[i] = [LUT blue:i green:i];
    }
    
    spca50x->frame->cameratype = spca50x->cameratype;
    
    spca50x->frame->format = VIDEO_PALETTE_RGB24;
    
    spca50x->frame->cropx1 = 0;
    spca50x->frame->cropx2 = 0;
    spca50x->frame->cropy1 = 0;
    spca50x->frame->cropy2 = 0;
    
    // reset info.dri
    
    spca50x->frame->decoder->info.dri = 0;
    
    // do jpeg decoding
    
    jpeg_decode422(spca50x->frame, 1);  // bgr = 1 (works better for SPCA508A...)
*/
}


@end
