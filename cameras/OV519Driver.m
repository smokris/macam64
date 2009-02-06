//
//  OV519Driver.m
//
//  macam - webcam app and QuickTime driver component
//  OV519Driver - an experimental OV519 driver based on GenericDriver class
//
//  Created by Vincenzo Mantova on 5/11/06.
//  Copyright (C) 2006 Vincenzo Mantova (xworld21@gmail.com) & HXR (hxr@users.sourceforge.net). 
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

/*
	TODO:
		- add support for more OV519 cams
		- add sensor detection (AKA1 -> OV7648? I don't know - xworld21)
		- discover the meaning of undocumented registers
		- optimize settings for quality
		- correct fps settings for low resolution
		- try to use divider to get QSIF resolution
		- understand the X_OFFSETL meaning for SIF resolution
		- correct the flickering for progressive scan at SIF res (which would be better than interlaced)
		- snapshot button handling
		- led (if possible)
		- see if it's possible to use uncompressed mode at low resolution/fps

 http://www.rastageeks.org/ov51x-jpeg/index.php/Main_Page
*/

// QTNewGWorldFromPtr()

#import "OV519Driver.h"

#include "USB_VendorProductIDs.h"
#include "MiscTools.h"
//#include "JpgDecompress.h"
#include <unistd.h>


@interface OV519Driver (Private)

- (void) dumpRegisters;

@end


@implementation OV519Driver

//
// Specify which Vendor and Product IDs this driver will work for
//
+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_OV519_AKA1], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_OVT], @"idVendor",
            @"OV519-based camera (2)", @"name", NULL], 
        
        // Maxell Maxcam Plus -- still does not work though (actually seems to be a 10.3.x issue)
        
        // More entries can easily be added for more cameras
		
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_OV519], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_OVT], @"idVendor",
            @"OV519-based camera (1)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_OV519_AKA2], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_OVT], @"idVendor",
            @"OV519-based camera (3)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_EYE_TOY], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONY], @"idVendor",
            @"Sony Eye Toy (1)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_EYE_TOY_AKA1], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONY], @"idVendor",
            @"Sony Eye Toy (2)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_EYE_TOY_AKA2], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONY], @"idVendor",
            @"Sony Eye Toy (3)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_EYE_TOY_AKA3], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONY], @"idVendor",
            @"Sony Eye Toy (4)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_XBOX_VIDEO_CHAT], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MICROSOFT], @"idVendor",
            @"Microsoft Xbox Video Chat", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x4052], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Live! Cam Vista IM", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x405f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative WebCam Vista (D)/ Live! Cam Chat (VF0330)", @"name", NULL], 
        
		[NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x4061], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Live! Cam Notebook Pro (VF0400)", @"name", NULL], 
        
		[NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x4064], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Live! Cam Vista IM (VF0420)", @"name", NULL], 
        
		[NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x4068], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Live! Cam Notebook (VF0470)", @"name", NULL], 
        
		[NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x4069], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Live! Cam Video IM/Video Chat (VF0540)", @"name", NULL], 
        
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
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
//  compressionType = jpegCompression;  // No error checking on image, get flickering sometimes
    jpegVersion = 1;
    
    compressionType = quicktimeImage;  // Does some error checking on image
    quicktimeCodec = kJPEGCodecType;
    
    runningAverageMin = 0.61803399;  // Golden Ration is always a good constant! (seems to work well)
    runningAverageNext = 0;
    runningAverageCount = 4;
    
    // Allocate memory
    // Initialize variables and other structures
    
//  hardwareBrightness = YES;  // Should depend on the sensor
//  hardwareSaturation = YES;  // Should depend on the sensor
//  hardwareGain = NO;         // Should depend on the sensor
    
	return self;
}

//
// This is not used, just here for possible future use
//
- (void) scanI2C
{
    int i, result;
    
    // The OV519 must be more aggressive about sensor detection since
    // I2C write will never fail if the sensor is not present. We have
    // to try to initialize the sensor to detect its presence 
    
    for (i = 0; i < 0xFF; i +=2) 
    {
        [self setupSensorCommunication:i and:i+1];
        
        result = [self setSensorRegister:0x12 toValue:0x80];
        usleep(150*1000);
        
        if ((result = [self getSensorRegister:0x0A]) != 0xFF) 
            printf("found something at 0x%2.2X -- [0x%2.2X] = 0x%2.2X\n", i, 0x0A, result);
        
        if ((result = [self getSensorRegister:0x0B]) != 0xFF) 
            printf("found something at 0x%2.2X -- [0x%2.2X] = 0x%2.2X\n", i, 0x0B, result);
        
        if ((result = [self getSensorRegister:OV7610_REG_ID_HIGH]) != 0xFF) 
            printf("found something at 0x%2.2X -- [0x%2.2X] = 0x%2.2X\n", i, OV7610_REG_ID_HIGH, result);
        
        if ((result = [self getSensorRegister:OV7610_REG_ID_LOW]) != 0xFF) 
            printf("found something at 0x%2.2X -- [0x%2.2X] = 0x%2.2X\n", i, OV7610_REG_ID_LOW, result);
    }
}



- (void) startupCamera
{   // This init part is taken from ov51x driver for linux
	// I copied the comments, but some registers are not documented
    
#if 0
    // [hxr] read sensor ID here? suggested code:
    {
        if ([self setRegister:OV519_REG_RESET1 val:0x0f] < 0) return; // Reset
        
        UInt8 pid = [self i2cRead:OV7648_REG_PID];
        UInt8 ver = [self i2cRead:OV7648_REG_VER];
        
        printf("The sensor is %2x%2x\n", pid, ver);
        
        if (pid == 0x76 && ver == 0x48) 
            printf("The sensor is OV7648 as expected, thing should work.\n");
        else 
            printf("The sensor is unknown things may or may not work! Please report!\n");
    }
#endif
/*
    { OV511_REG_BUS, 0x5a,	0x6d }, // EnableSystem 
    // windows reads 0x53 at this point
    { OV511_REG_BUS, 0x53,	0x9b },
    { OV511_REG_BUS, 0x54,	0x0f }, // set bit2 to enable jpeg
    { OV511_REG_BUS, 0x5d,	0x03 },
    { OV511_REG_BUS, 0x49,	0x01 },
    { OV511_REG_BUS, 0x48,	0x00 },
    
    // Set LED pin to output mode. Bit 4 must be cleared or sensor
    // detection will fail. This deserves further investigation.
    { OV511_REG_BUS, OV519_GPIO_IO_CTRL0,	0xee },
    
    { OV511_REG_BUS, 0x51,	0x0f },	// SetUsbInit 
    { OV511_REG_BUS, 0x51,	0x00 },
    { OV511_REG_BUS, 0x22,	0x00 },
    // windows reads 0x55 at this point
 
    reg_setbit(ov, OV519_SYS_EN_CLK1, 1, 2 ) // enable compression
 
    reg_w_mask(ov, OV519_GPIO_DATA_OUT0, on ? 0x01 : 0x00, 0x01)  // led 
 
 
*/    
	if ([self setRegister:OV519_REG_RESET1 toValue:0x0f] < 0) return; // Reset
	if ([self setRegister:OV519_REG_YS_CTRL toValue:0x6d] < 0) return; // Enables various things (adds "System Reset Mask" to defaults)
	if ([self setRegister:OV519_REG_EN_CLK0 toValue:0x9b] < 0) return; // adds SCCB (I2C) and audio, unset microcontroller
	if ([self setRegister:OV519_REG_En_CLK1 toValue:0xff] < 0) return; // enables video fifo/jpeg/sfifo/cif // AG change
	if ([self setRegister:OV519_REG_PWDN toValue:0x03] < 0) return; // sets Normal mode (not suspend) and Power Down Reset Mask
	if ([self setRegister:0x49 toValue:0x01] < 0) return; // undocumented and unnecessary
	if ([self setRegister:0x48 toValue:0x00] < 0) return; // same as above
	if ([self setRegister:OV519_REG_GPIO_IO_CTRL0 toValue:0xee] < 0) return; // something about leds - not necessary for now
																		// in ov51x has something to do with sensor detection

	//if ([self setRegister:0xa2 val:0x20] < 0) return; // a2-a5 undocumented
	//if ([self setRegister:0xa3 val:0x18] < 0) return;
	//if ([self setRegister:0xa4 val:0x04] < 0) return;
	//if ([self setRegister:0xa5 val:0x28] < 0) return;
	//if ([self setRegister:0x37 val:0x00] < 0) return; // undocumented
	// These last registers (a2-a5 and 37) are not necessary - they were in ov51x
	if ([self setRegister:OV519_REG_AUDIO_CLK toValue:0x02] < 0) return; // 4.096 Hz audio clock
	
	// do we need to set resolution here? or macam does it after startup?
    // no need to [hxr]
	
	//if ([self setRegister:0x17 val:0x50] < 0) return; // From ov51x, not necessary and undocumendet
	if ([self setRegister:0x37 toValue:0x00] < 0) return; // undocumented, but ov51x reports it as 'SetUsbInit' - this IS necessary
	//if ([self setRegister:0x40 val:0xff] < 0) return; // I2C timeout counter - documented on ov511/8 specs
	//if ([self setRegister:0x46 val:0x00] < 0) return; // I2C clock prescaler - ^^^
	// ^^^ unnecessary (and undocumented on OV519 specs)
	if ([self setRegister:OV519_REG_CAMERA_CLOCK toValue:0x04] < 0) return; // from windrv 090403
	
    // reset i2c, reset sensor here?
    
	if ([self setRegister:OV519_REG_DFR toValue:0x10 withMask:0x50] < 0) return;	// 8-bit mode (color) (bridge->host)
																			// it's also possible to choose CCIR with 6th bit
																			// 0 - CCIR601, 1 - CCIR656
																			// which is better?
	if ([self setRegister:OV519_REG_Format toValue:0x9b] < 0) return;	// YUV422 + defect comp (7th bit)
																// also keep even/odd field (no differences seen)
																// "Maximum Frame Counter Number" ([2:0]) = 3 works
	//if ([self setRegister:0x26 val:0x00] < 0) return;	// Undocumented	and apparently unnecessary (always from ov51x)
	
	//if ([self i2cWriteMask:OV7648_REG_COME val:0x10 mask:0x10] < 0) return; // enables Edge Enhancement

	// Uncompressed frames aren't supported (but maybe at low resolution...)
	//compression = 1; // this is for selecting different levels of compression [hxr]
    
//  if ([self setRegister:OV519_REG_IO_N val:0x6f] < 0) return;
    
    sensor = [Sensor findSensor:self];
    if (sensor == NULL) 
        NSLog(@"Sensor could not be found, this is a big problem!\n");
    
    // Reset the sensor to basic settings, set reisters to default values
    [sensor reset];
    
    if ([sensor isKindOfClass:[OV7670 class]]) 
    {
        [self setRegister:OV519_REG_DFR toValue:0x0c];
        [self setRegister:OV519_REG_SR toValue:0x38];
    }
    
    [sensor configure];
    
#if REALLY_VERBOSE
	[self dumpRegisters];
#endif
    
	[self setBrightness:0.5];
	[self setContrast:0.5];
	[self setSaturation:0.5];
	[self setGamma:0.5];
	[self setSharpness:0.5];
}

//
// Provide feedback about which resolutions and rates are supported
//
// Should check with the sensor
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
	if (rate > 30) 
        return NO;
    
    switch (res) 
    {
		case ResolutionSIF:
		case ResolutionVGA:
            return YES;
            
		case ResolutionCIF:
			return [sensor isKindOfClass:[OV7670 class]];
			
		case ResolutionQCIF:					
		case ResolutionQSIF:		
		case ResolutionSQSIF:			
		case ResolutionSVGA:
        default: 
            return NO;
    }
}

//
// Return the default resolution and rate
//
- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 25;   // 30 rate blinks when connected with usb hub
    
	return ResolutionVGA;
}

- (void) setResolution:(CameraResolution)r fps:(short)fr
{
	int width = WidthOfResolution(r);
    int height = HeightOfResolution(r);
    
	[super setResolution:r fps:fr];
    
    if (![self supportsResolution:r fps:fr]) 
        return;
    
	if (isGrabbing) 
        return;
    
    [sensor setResolution1:r fps:fr];
    
    switch (r) 
    {
        case ResolutionCIF:
			[self setRegister:OV519_REG_X_OFFSETL toValue:0x1];	
            break;
            
		case ResolutionSIF:
            [self setRegister:OV519_REG_X_OFFSETL toValue:[sensor isKindOfClass:[OV7670 class]] ? 0x00 : 0x01];	// Don't ask why but this make VGA/SIF works correctly (blue image!) // AG change
            break;
            
        case ResolutionVGA:
            [self setRegister:OV519_REG_X_OFFSETL toValue:0x00];	// Don't ask why but this make VGA/SIF works correctly
            break;
            
        default:
            break;
    }
    
    [sensor setResolution2:r fps:fr];
   
    switch (fr) 
    {
        // FIXME (from ov51x): these are only valid at the max resolution.
        // It's possible that at SIF resolution you can go up to 60fps (OV7648 can do it)
        case 30:
            if ([self setRegister:0xa4 toValue:0x0c] < 0) return;	// These are undocumented register
            if ([self setRegister:0x23 toValue:0xff] < 0) return;	// but they work
            break;
            
        case 25:
            if ([self setRegister:0xa4 toValue:0x0c] < 0) return;
            if ([self setRegister:0x23 toValue:0x1f] < 0) return;
            break;
            
        case 20:
            if ([self setRegister:0xa4 toValue:0x0c] < 0) return;
            if ([self setRegister:0x23 toValue:0x1b] < 0) return;
            break;
            
        case 15:
            if ([self setRegister:0xa4 toValue:0x04] < 0) return;
            if ([self setRegister:0x23 toValue:0xff] < 0) return;
            break;
            
        case 10:
            if ([self setRegister:0xa4 toValue:0x04] < 0) return;
            if ([self setRegister:0x23 toValue:0x1f] < 0) return;
            break;
            
        case 5:
            if ([self setRegister:0xa4 toValue:0x04] < 0) return;
            if ([self setRegister:0x23 toValue:0x1b] < 0) return;
            break;
            
        default:
            break;
    }
    
    [sensor setResolution3:r fps:fr];
    
    if ([self setRegister:OV519_REG_H_SIZE toValue:width/16] < 0) 
        return;
    
    if ([self setRegister:OV519_REG_V_SIZE toValue:height/8] < 0) 
        return;
    
    [sensor setResolution:r fps:fr];
}


- (void) setBrightness: (float) v
{
	[super setBrightness:v];
    [sensor setBrightness:v];
}


- (void) setSaturation: (float) v
{
	[super setSaturation:v];
    [sensor setSaturation:v];
}


- (void) setGain: (float) v
{
	[super setBrightness:v];
    [sensor setGain:v];
}


- (BOOL) canSetLed 
{
    return YES;
}


- (void) setLed:(BOOL)v 
{
    [super setLed:v];
    
    // Switches red LED on Eye Toy
    // Don't know how to control blue LED yet
    
    [self setRegister:OV519_REG_GPIO_DATA_OUT0 toValue:(v ? 0x01 : 0x00) withMask:0x01];
    
//  [self regWriteMask:OV519_REG_GPIO_DATA_OUT1 val:(v ? 0x02 : 0x00)  mask:0x02];
//  [self regWriteMask:OV519_REG_IO_Y val:(v ? 0x10 : 0x00)  mask:0x10];
}


//
// Returns the pipe used for grabbing
//
- (UInt8) getGrabbingPipe
{
    return 1;
}

//
// Put in the alt-interface with the highest bandwidth (instead of 8)
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
	if ([self setRegister:OV519_REG_RESET1 toValue:0x0f] < 0) // safe reset
        return FALSE;
    
    if (![self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:4]) 
        return FALSE;
    
	if ([self setRegister:OV519_REG_RESET1 toValue:0x00] < 0) 
        return FALSE;
    
	return TRUE;
}

- (BOOL) canSetUSBReducedBandwidth
{
    return YES;
}

//
// Scan the frame and return the results
//
IsocFrameResult  OV519IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                       UInt32 * dataStart, UInt32 * dataLength, 
                                       UInt32 * tailStart, UInt32 * tailLength, 
                                       GenericFrameInfo * frameInfo)
{
#define WAIT_NEW 0
#define WAIT_NEXT 1

/*
	Frame format (taken from ov51x):
	The header is 16 bytes long when it's present. The rest is jpeg data.
	
	Header:
	Byte	Value		Desc
	 0		0xff		magic
	 1		0xff		magic
	 2		0xff		magic (in jpeg we can't have three 0xff subsequently)
	 3		0xXX		0x50 = SOF, 0x51 = EOF
	 9		0xXX		0x01 initial frame without data, 0x00 standard frame with image
	 14		Lo			in EOF = length of image data / 8
	 15		Hi

*/

    int frameLength = frame->frActCount;
    static int currState = WAIT_NEW; 
    // it's good to use a static var? Can I expect that this function is not called by more than one thread?
    // This should be fine, that is what the grabbingThread is for, no other thread should call this function [hxr]
	static int currLen;
    
    *dataStart = 0;
    *dataLength = 0;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
#if 0
    if (frameLength == 0) 
        printf("zero-length buffer\n");
    else 
        printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", 
                buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5], buffer[6], buffer[7], buffer[8], buffer[9]);
#endif
    
    if (frameLength < 3) 
        return invalidFrame;
    
    if (buffer[0] == 0xff && buffer[1] == 0xff && buffer[2] == 0xff) 
    {
		if (buffer[3] == 0x50) // Start of frame
        {
#if REALLY_VERBOSE
//            printf("HEADER!\n");
#endif
			if (buffer[9] == 0x01) 
                return invalidFrame;
            
			*dataStart = 16;
			*dataLength = frameLength - 16;
			currState = WAIT_NEXT;
			currLen = frameLength - 16;
            
			return newChunkFrame;
		} 
        else if (buffer[3] == 0x51) // End of frame
        {
#if REALLY_VERBOSE
//            printf("footer!\n");
#endif
			if (currState == WAIT_NEW) // It's common to have EOF without SOF at beginning of the stream
                return invalidFrame;
            
			if (buffer[9] == 0x01) 
				return invalidFrame;
			
			currState = WAIT_NEW;
            
			*dataStart = 16;
			*dataLength = 0;
            
#if REALLY_VERBOSE
			if (currLen != 8 * (buffer[15]*256 + buffer[14])) // this check could be useful for debugging
            {
                printf("End of frame length value (%d) does not correspond to total length (%d)\n", 
                       8 * (buffer[15]*256 + buffer[14]), currLen);
//                return invalidChunk;
            }
#endif
			return validFrame;
		} 
	} 
    else if (currState == WAIT_NEXT) 
    {
        *dataLength = frameLength;
		currLen += frameLength;
        return validFrame;
    }
    
    return invalidFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = OV519IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    int i;
    
    for (i = 0; i < runningAverageCount; i++) 
        runningAverage[i] = 0;

//  if ([self setRegister:0x2f val:0x80] < 0) // no comment in ov51x, undocumented and not necessary
//      return FALSE;
	
    if ([self setRegister:OV519_REG_RESET1 toValue:0x0f] < 0)  // resets jpeg and other stuffs
        return FALSE;
    
	if ([self setRegister:OV519_REG_RESET1 toValue:0x00] < 0) 
        return FALSE;
    
	return TRUE;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
	if ([self setRegister:OV519_REG_RESET1 toValue:0x0f] < 0) 
        return;
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]];
    
	return;
}


- (BOOL) decodeBuffer:(GenericChunkBuffer *) buffer
{
    int i;
    long limit = 0;
    
    for (i = 0; i < runningAverageCount; i++) 
        limit += runningAverage[i];
    limit = runningAverageMin * limit / runningAverageCount;
    
    runningAverage[runningAverageNext] = buffer->numBytes;
    runningAverageNext = (runningAverageNext + 1) % runningAverageCount;
    
    if (buffer->numBytes < limit) 
    {
#if REALLY_VERBOSE
        printf("Frame dropped because it was too short, length=%ld, limit=%ld\n", buffer->numBytes, limit);
#endif
        return NO;
    }
    
    return [super decodeBuffer:buffer];
}

//
// Read and write a register value
// taken from MyOV511Driver
// Read and write also sensor's I2C registers
//

- (int) getRegister:(UInt8)reg
{
    UInt8 buf[16];  // Not sure we need this, but why not
	
	usleep(1000);  // Now it operates with usb hub
    
    if (![self usbReadCmdWithBRequest:1 wValue:0 wIndex:reg buf:buf len:1]) 
    {
        NSLog(@"OV519:getRegister:usbReadCmdWithBRequest error");
        return -1;
    }
    
    return buf[0];
}


- (int) setRegister:(UInt8)reg toValue:(UInt8)val
{
    UInt8 buf[16];  // Not sure we need this, but why not
    
    buf[0] = val;
    
    usleep(1000);  // Now it operates with usb hub 
    
	if(![self usbWriteCmdWithBRequest:1 wValue:0 wIndex:reg buf:buf len:1]) 
    {
		NSLog(@"OV519:setRegister:usbWriteCmdWithBRequest error");
		return -1;
	}
    
	return 0;
}


- (int) setRegister:(UInt8)reg toValue:(UInt8)val withMask:(UInt8)mask
{
    int result = [self getRegister:reg];
    UInt8 actualVal = result;
    
    if (result < 0) 
        return result;
    
    actualVal &= ~mask;  // clear out bits
    val &= mask;         // only set bits allowed by mask
    actualVal |= val;    // combine them
    
    return [self setRegister:reg toValue:actualVal];
}

/*
 
 0x41 - i2c write address
 0x42 - 
 0x43 - write value (register index)
 0x44 - i2c read address
 0x45 - value read (register value)
 0x46 - 
 0x47 - i2c control
 
 */

- (int) setupSensorCommunication:(Class)sensorClass
{
    return [self setupSensorCommunication:[sensorClass i2cWriteAddress] and:[sensorClass i2cReadAddress]];
}

- (int) setupSensorCommunication:(UInt8)writeAddress and:(UInt8)readAddress
{
    int result;
    
    result = [self setRegister:R51x_I2C_W_SID toValue:writeAddress];  // OV519_I2C_SSA
    if (result < 0)
        return result;
    
    result = [self setRegister:R51x_I2C_R_SID toValue:readAddress];
    if (result < 0)
        return result;
    
    return result;
}

- (int) getSensorRegister:(UInt8)reg
{
    int result = 0;
    
    // Perform a dummy write cycle to set the sensor register we want
    
    result = [self setRegister:OV519_I2C_SMA toValue:reg]; // 0x43
    if (result < 0) 
        return result;
    
    // Initiate the dummy write
    
    result = [self setRegister:OV519_I2C_CONTROL toValue:0x03]; // 0x47
    if (result < 0) 
        return result;
    
    // Initiate the read
    
    result = [self setRegister:OV519_I2C_CONTROL toValue:0x05]; // 0x47
    if (result < 0) 
        return result;
    
    // Retrieve the data
    
    return [self getRegister:OV519_I2C_SDA]; // 0x45
}


- (int) setSensorRegister:(UInt8)reg toValue:(UInt8)val
{
    int result = 0;
    
    result = [self setRegister:OV519_I2C_SWA toValue:reg];
    if (result < 0) 
        return result;
    
    result = [self setRegister:OV519_I2C_SDA toValue:val];
    if (result < 0) 
        return result;
    
    result = [self setRegister:OV519_I2C_CONTROL toValue:0x01];
    if (result < 0) 
        return result;
    
    return 0;
}


- (void) dumpRegisters
{
	UInt8 regLN, regHN;
    
	printf("Camera Registers: ");
	for (regHN = 0; regHN < 0xf0; regHN+=0x10) {
		printf("\n    ");
		for (regLN = 0; regLN < 0x10; ++regLN)
			printf(" %02X=%02X", regHN + regLN, [self getRegister:regHN + regLN]);
	}
	printf("\n\n");
    
	printf("Sensor Registers: ");
	for (regHN = 0; regHN < 0x80; regHN+=0x10) {
		printf("\n    ");
		for (regLN = 0; regLN < 0x10; ++regLN)
			printf(" %02X=%02X", regHN + regLN, [self getSensorRegister:regHN + regLN]);
	}
	printf("\n\n");
}

@end


/*
 EyeToy -- different LED policy -- Only turn on if asked to, very bright -- no need for macam special treatment
 
 LED control - different for 511+, 518&+, 519
 
 clockdivision is different...
 
 
 
 */


@implementation OV518Driver

+ (NSArray *) cameraUsbDescriptions
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_OV518], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_OVT], @"idVendor",
            @"OV518 based webcam", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral:(id)c
{
    return self;
}

@end 


@implementation OV518PlusDriver

+ (NSArray *) cameraUsbDescriptions
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_OV518PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_OVT], @"idVendor",
            @"OV518+ based webcam", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral:(id)c
{
    return self;
}

@end 



@implementation OV511Driver

+ (NSArray *) cameraUsbDescriptions
{
    return [NSArray arrayWithObjects:
        /*
         [NSDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithUnsignedShort:PRODUCT_OV511], @"idProduct",
             [NSNumber numberWithUnsignedShort:VENDOR_OVT], @"idVendor",
             @"OV511 based webcam", @"name", NULL], 
         */
        NULL];
}

- (id) initWithCentral:(id)c
{
    return self;
}

@end 


@implementation OV511PlusDriver

+ (NSArray *) cameraUsbDescriptions
{
    return [NSArray arrayWithObjects:
        /*
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_OV511PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_OVT], @"idVendor",
            @"OV511+ based webcam", @"name", NULL], 
        */
        NULL];
}

- (id) initWithCentral:(id)c
{
    return self;
}

@end 
