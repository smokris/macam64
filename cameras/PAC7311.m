//
//  PAC7311.m
//  macam
//
//  Created by Harald Ruda on 1/15/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
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
    
	if(![self usbSetAltInterfaceTo:8 testPipe:5]) return CameraErrorNoBandwidth;
    
    if (YES) // for debugging
    {
//    	Pipe information
//    	int i, cnt = CountPipes(intf);
        
//    	for (i = 0; i < cnt; i++) 
//          ShowPipeInfo(intf, i);
    }
    
	UInt8 buff[8];
	[self usbReadCmdWithBRequest: 0x01 wValue:0x00 wIndex:0x0000 buf:buff len:2];
	if(buff[0] != 0x04 || buff[1] != 0x63){
#ifdef VERBOSE
		NSLog(@"Invalid Sensor or chip");
#endif
		return CameraErrorUSBProblem;
	}
    
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
    
    //	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x10 wIndex:0x000f buf:NULL len:0]; // Power Control
    
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac207_sensor_init[0] len:8]; // 0x0002
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x000a buf:pac207_sensor_init[1] len:8]; // 0x000a
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0012 buf:pac207_sensor_init[2] len:8]; // 0x0012
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0040 buf:pac207_sensor_init[3] len:8]; // 0x0040
                                                                                                                 //	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0042 buf:pac207_sensor_init[4] len:8]; // 0x0042
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0048 buf:pac207_sensor_init[5] len:4]; // 0x0048
    
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
    
	switch(resolution){
        case ResolutionQCIF: // 176 x 144
                             //	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x03 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)
            [self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac207_video_mode[1] len:7];	// ?????
            break;
        case ResolutionCIF: // 352 x 288
                            //	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x02 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)
            [self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac207_video_mode[2] len:7];	// ?????
                                                                                                                        //	if(compression){
                                                                                                                        //		[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x04 wIndex:0x0002 buf:NULL len:0]; // PXCK = 12MHz /n
                                                                                                                        //	} else {
                                                                                                                        //		[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x0a wIndex:0x0002 buf:NULL len:0]; // PXCK = 12MHz /n
                                                                                                                        //	}
            break;
        default:
#ifdef VERBOSE
            NSLog(@"startupGrabbing: Invalid resolution!");
#endif
            return CameraErrorUSBProblem;
	}
    
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x0a wIndex:0x000e buf:NULL len:0]; // PGA global gain (Bit 4-0)
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x0018 buf:NULL len:0]; // ???
    
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0042 buf:pac207_sensor_init[4] len:8]; // 0x0042
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x7e wIndex:0x004a buf:NULL len:0]; // ???
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x0040 buf:NULL len:0]; // Start ISO pipe
    
    return err;
}


@end
