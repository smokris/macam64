//
//  OV519Driver.m
//
//  macam - webcam app and QuickTime driver component
//  OV519Driver - an experimental OV519 driver based on GenericDriver class
//
//  Created by Vincenzo Mantova on 5/11/06.
//  Copyright (C) 2006 Vincenzo Mantova (xworld21@gmail.com). 
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

	This driver is mostly a transcription of the ov51x linux driver by Mark W. McClelland
	and Joerg Heckenbach.
	For now it ONLY WORKS WITH TRUST SPACECAM 320 and other ov519 cameras with OV7648
	sensor. There is NO sensor detection.

*/

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

*/

// QTNewGWorldFromPtr()

#import "OV519Driver.h"

#include "USB_VendorProductIDs.h"
#include "MiscTools.h"
#include "JpgDecompress.h"
#include <unistd.h>


@interface OV519Driver (Private)

- (void) dumpRegs;

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
            [NSNumber numberWithUnsignedShort:0x4802], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x17ef], @"idVendor",
            @"Lenovo USB Webcam (40Y8519)", @"name", NULL], 
        
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
    
    compressionType = jpegCompression;
    jpegVersion = 1;
    
    // Allocate memory
    // Initialize variables and other structures
    
    hardwareBrightness = YES;
    hardwareSaturation = YES;
//  hardwareGain = YES;
    
    sensorSID = OV7648_I2C_WSID; // Assume this for now
    
	return self;
}


- (int) i2cSetSID;
{
    int result;
    
    result = [self regWrite:R51x_I2C_W_SID val:sensorSID];
    if (result < 0)
        return result;
    
    result = [self regWrite:R51x_I2C_R_SID val:sensorSID + 1];
    if (result < 0)
        return result;
    
    return result;
}


- (int) initSensor
{
    int i, result;
    BOOL success = NO;
    static int i2c_detection_attempts = 10;
    
    // Reset the sensor
    
    result = [self i2cWrite:0x12 val:0x80];
    if (result < 0) 
        return result;
    
    // Wait for it to initialize
    
    usleep(150 * 1000);
    
    // Now try to detect it a few times
    
	for (i = 0; i < i2c_detection_attempts && !success; i++) 
    {
        if ([self i2cRead:OV7610_REG_ID_HIGH] == 0x7F && 
            [self i2cRead:OV7610_REG_ID_LOW] == 0xA2) 
        {
			success = YES;
			break;
		}
        
        // Reset the sensor
        
        result = [self i2cWrite:0x12 val:0x80];
        if (result < 0) 
            return result;
        
        // Wait for it to initialize
        
        usleep(150 * 1000);
        
		// Dummy read to sync I2C
        
        result = [self i2cRead:0x00];
        if (result < 0) 
            return result;
	}
    
	if (!success)
		return -1;
    
    if (i > 0) 
        printf("I2C synced in %d attempts\n", i+1);
    else 
        printf("I2C synced in %d attempt\n", i+1);
    
	return 0;
}


- (int) configureOV6xx0
{
    return 0;
}


- (int) configureOV7xx0
{
    int result = 0;
    
    result = [self i2cWrite:0x12 val:0x80]; // reset
    if (result < 0) 
        return result;
    
    result = [self i2cWrite:0x12 val:0x14]; // setup
    if (result < 0) 
        return result;
    
    return result;
}


- (int) configureOV8xx0
{
    return 0;
}


- (int) findSensor;
{
    int result;
    
    // The OV519 must be more aggressive about sensor detection since
    // I2C write will never fail if the sensor is not present. We have
    // to try to initialize the sensor to detect its presence 
    
#if 0 // in cvs-build-2006-07-16
    int i;
    
    for (i = 0; i < 0xFF; i +=2) 
    {
        sensorSID = i;
        result = [self i2cSetSID];
        result = [self i2cWrite:0x12 val:0x80];
        usleep(150*1000);
        
        if ((result = [self i2cRead:0x0A]) != 0xFF) 
            printf("found something at 0x%2.2X -- [0x%2.2X] = 0x%2.2X\n", i, 0x0A, result);
        
        if ((result = [self i2cRead:0x0B]) != 0xFF) 
            printf("found something at 0x%2.2X -- [0x%2.2X] = 0x%2.2X\n", i, 0x0B, result);
        
        if ((result = [self i2cRead:OV7610_REG_ID_HIGH]) != 0xFF) 
            printf("found something at 0x%2.2X -- [0x%2.2X] = 0x%2.2X\n", i, OV7610_REG_ID_HIGH, result);
        
        if ((result = [self i2cRead:OV7610_REG_ID_LOW]) != 0xFF) 
            printf("found something at 0x%2.2X -- [0x%2.2X] = 0x%2.2X\n", i, OV7610_REG_ID_LOW, result);
    }
#endif
    
    // First we try OV7xx0
    
    sensorSID = OV7xx0_SID;
    result = [self i2cSetSID];
    if (result < 0) 
        return -1;
    
    result = [self initSensor];
    if (result >= 0) 
    {
        printf("Found OV7xx0 sensor.\n");
        result = [self configureOV7xx0];
        if (result < 0) 
            printf("Could not configure the OV7xx0 sensor.\n");
        return result;
    }
    
    // Second we try OV6xx0
    
    sensorSID = OV6xx0_SID;
    result = [self i2cSetSID];
    if (result < 0) 
        return -1;
    
    result = [self initSensor];
    if (result >= 0) 
    {
        printf("Found OV6xx0 sensor.\n");
        result = [self configureOV6xx0];
        if (result < 0) 
            printf("Could not configure the OV6xx0 sensor.\n");
        return result;
    }
    
    // Third we try OV8xx0
    
    sensorSID = OV8xx0_SID;
    result = [self i2cSetSID];
    if (result < 0) 
        return -1;
    
    result = [self initSensor];
    if (result >= 0) 
    {
        printf("Found OV8xx0 sensor.\n");
        result = [self configureOV8xx0];
        if (result < 0) 
            printf("Could not configure the OV8xx0 sensor.\n");
        return result;
    }
    
    // 4th we try OV9xx0
    
    sensorSID = OV9xx0_SID;
    result = [self i2cSetSID];
    if (result < 0) 
        return -1;
    
    result = [self initSensor];
    if (result >= 0) 
    {
        printf("Found OV9xx0 sensor.\n");
        return result;
    }
    
    // 5th we try OV8xx0
    
    sensorSID = 0xD8;
    result = [self i2cSetSID];
    if (result < 0) 
        return -1;
    
    result = [self initSensor];
    if (result >= 0) 
    {
        printf("Found sensor with SID = 0x%2.2X.\n", sensorSID);
        return result;
    }
    
    // 6th we try OV8xx0
    
    sensorSID = 0x48;
    result = [self i2cSetSID];
    if (result < 0) 
        return -1;
    
    result = [self initSensor];
    if (result >= 0) 
    {
        printf("Found sensor with SID = 0x%2.2X.\n", sensorSID);
        return result;
    }
    
    printf("Could not find a sensor SID. Big problem.\n");
    
    sensorSID = OV7xx0_SID;
    result = [self i2cSetSID];
    
    return result;
}


- (void) startupCamera
{   // This init part is taken from ov51x driver for linux
	// I copied the comments, but some registers are not documented
    
#if 0
    // [hxr] read sensor ID here? suggested code:
    {
        if ([self regWrite:OV519_REG_RESET1 val:0x0f] < 0) return; // Reset
        
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
	if ([self regWrite:OV519_REG_RESET1 val:0x0f] < 0) return; // Reset
	if ([self regWrite:OV519_REG_YS_CTRL val:0x6d] < 0) return; // Enables various things (adds "System Reset Mask" to defaults)
	if ([self regWrite:OV519_REG_EN_CLK0 val:0x9b] < 0) return; // adds SCCB (I2C) and audio, unset microcontroller
	if ([self regWrite:OV519_REG_En_CLK1 val:0x0f] < 0) return; // enables video fifo/jpeg/sfifo/cif
	if ([self regWrite:OV519_REG_PWDN val:0x03] < 0) return; // sets Normal mode (not suspend) and Power Down Reset Mask
	if ([self regWrite:0x49 val:0x01] < 0) return; // undocumented and unnecessary
	if ([self regWrite:0x48 val:0x00] < 0) return; // same as above
	if ([self regWrite:OV519_REG_GPIO_IO_CTRL0 val:0xee] < 0) return; // something about leds - not necessary for now
																		// in ov51x has something to do with sensor detection

	//if ([self regWrite:0xa2 val:0x20] < 0) return; // a2-a5 undocumented
	//if ([self regWrite:0xa3 val:0x18] < 0) return;
	//if ([self regWrite:0xa4 val:0x04] < 0) return;
	//if ([self regWrite:0xa5 val:0x28] < 0) return;
	//if ([self regWrite:0x37 val:0x00] < 0) return; // undocumented
	// These last registers (a2-a5 and 37) are not necessary - they were in ov51x
	if ([self regWrite:OV519_REG_AUDIO_CLK val:0x02] < 0) return; // 4.096 Hz audio clock
	
	// do we need to set resolution here? or macam does it after startup?
    // no need to [hxr]
	
	//if ([self regWrite:0x17 val:0x50] < 0) return; // From ov51x, not necessary and undocumendet
	if ([self regWrite:0x37 val:0x00] < 0) return; // undocumented, but ov51x reports it as 'SetUsbInit' - this IS necessary
	//if ([self regWrite:0x40 val:0xff] < 0) return; // I2C timeout counter - documented on ov511/8 specs
	//if ([self regWrite:0x46 val:0x00] < 0) return; // I2C clock prescaler - ^^^
	// ^^^ unnecessary (and undocumented on OV519 specs)
	if ([self regWrite:OV519_REG_CAMERA_CLOCK val:0x04] < 0) return; // from windrv 090403
	
	// Reset the I2C - useful when experimenting with sensor's settings
	if ([self i2cWrite:OV7648_REG_COMA val:0x80] < 0) return;

	if ([self regWriteMask:OV519_REG_DFR val:0x10 mask:0x50] < 0) return;	// 8-bit mode (color) (bridge->host)
																			// it's also possible to choose CCIR with 6th bit
																			// 0 - CCIR601, 1 - CCIR656
																			// which is better?
	if ([self regWrite:OV519_REG_Format val:0x9b] < 0) return;	// YUV422 + defect comp (7th bit)
																// also keep even/odd field (no differences seen)
																// "Maximum Frame Counter Number" ([2:0]) = 3 works
	//if ([self regWrite:0x26 val:0x00] < 0) return;	// Undocumented	and apparently unnecessary (always from ov51x)
	
	//if ([self i2cWriteMask:OV7648_REG_COME val:0x10 mask:0x10] < 0) return; // enables Edge Enhancement

	// Uncompressed frames aren't supported (but maybe at low resolution...)
	//compression = 1; // this is for selecting different levels of compression [hxr]
    
//  if ([self regWrite:OV519_REG_IO_N val:0x6f] < 0) return;
    
    if ([self findSensor] < 0) ;
    
#if REALLY_VERBOSE
	[self dumpRegs];
#endif
	[self setBrightness:0.5];
	[self setGamma:0.5];
	[self setSaturation:0.5];
	[self setSharpness:0.5];
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
	// OV519 + OV7648 case
	if (rate > 30) return NO;
    
    switch (res) 
    {
		case ResolutionSIF:
		case ResolutionVGA:
			return YES;
            
		case ResolutionSQSIF:
		case ResolutionQSIF:
		case ResolutionQCIF:
		case ResolutionCIF:
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
        *rate = 30;
    
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
    
    switch (r) 
    {
        case ResolutionSQSIF:
            break;
            
        case ResolutionQSIF:
            break;
            
        case ResolutionQCIF:
            break;
            
        case ResolutionSIF:
            [self i2cWriteMask:OV7648_REG_COMC val:0x20 mask:0x20];	// Quarter VGA
            [self i2cWriteMask:OV7648_REG_COMH val:0x20 mask:0x20];	// Interlaced scan (ov51x set this to progressive - but interlaced seems more stable)
            [self regWrite:OV519_REG_X_OFFSETL val:0x01];	// Don't ask why but this make VGA/SIF works correctly (blue image!)
            break;
            
        case ResolutionCIF:
            break;
            
        case ResolutionVGA:
            [self i2cWriteMask:OV7648_REG_COMC val:0x00 mask:0x20];	// Not Quarter VGA
            [self i2cWriteMask:OV7648_REG_COMH val:0x20 mask:0x20];	// Interlaced scan
            [self regWrite:OV519_REG_X_OFFSETL val:0x00];	// Don't ask why but this make VGA/SIF works correctly
            break;
            
        case ResolutionSVGA:
            break;
            
        default:
            fprintf(stderr, "Invalid resolution\n");
            return;
    }
    
    switch (fr) 
    {
        // FIXME (from ov51x): these are only valid at the max resolution.
        // It's possible that at SIF resolution you can go up to 60fps (OV7648 can do it)
        case 30:
            if ([self regWrite:0xa4 val:0x0c] < 0) return;	// These are undocumented register
            if ([self regWrite:0x23 val:0xff] < 0) return;	// but they works
            if ([self i2cWrite:0x11 val:0x00] < 0) return;	// this is a clockdiv setting in ov51x
                                                            // it's a polarity setting - it works for some reason
            break;
            
        case 25:
            if ([self regWrite:0xa4 val:0x0c] < 0) return;
            if ([self regWrite:0x23 val:0x1f] < 0) return;
            if ([self i2cWrite:0x11 val:0x00] < 0) return;
            break;
            
        case 20:
            if ([self regWrite:0xa4 val:0x0c] < 0) return;
            if ([self regWrite:0x23 val:0x1b] < 0) return;
            if ([self i2cWrite:0x11 val:0x00] < 0) return;
            break;
            
        case 15:
            if ([self regWrite:0xa4 val:0x04] < 0) return;
            if ([self regWrite:0x23 val:0xff] < 0) return;
            if ([self i2cWrite:0x11 val:0x01] < 0) return;
            break;
            
        case 10:
            if ([self regWrite:0xa4 val:0x04] < 0) return;
            if ([self regWrite:0x23 val:0x1f] < 0) return;
            if ([self i2cWrite:0x11 val:0x01] < 0) return;
            break;
            
        case 5:
            if ([self regWrite:0xa4 val:0x04] < 0) return;
            if ([self regWrite:0x23 val:0x1b] < 0) return;
            if ([self i2cWrite:0x11 val:0x01] < 0) return;
            break;
            
        default:
            return;
    }
    
    if ([self regWrite:OV519_REG_H_SIZE val:width/16] < 0) 
        return;
    
    if ([self regWrite:OV519_REG_V_SIZE val:height/8] < 0) 
        return;
}

- (void) setBrightness: (float) v
{
	[super setBrightness:v];
	[self i2cWrite:OV7648_REG_BRT val:(UInt8)(v*255)];
}

- (void) setSaturation: (float) v
{
	[super setSaturation:v];
	[self i2cWrite:OV7648_REG_SAT val:((UInt8)(v*255)) & 0xf0];	// some bit are reserved
}

- (BOOL) canSetGain
{
    return YES;
}

- (void) setGain: (float) v
{
	[super setBrightness:v];
	[self i2cWrite:OV7648_REG_GAIN val:(UInt8)(v*255)];
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
    
    [self regWriteMask:OV519_REG_GPIO_DATA_OUT0 val:(v ? 0x01 : 0x00)  mask:0x01];
    
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
	if ([self regWrite:OV519_REG_RESET1 val:0x0f] < 0) // safe reset
        return FALSE;
    
    if (![self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:4]) 
        return FALSE;
    
//    if (![self usbSetAltInterfaceTo:4 testPipe:[self getGrabbingPipe]]) // 4 should be the best, but 1,2,3 are possible
//        return FALSE;                                                   // and give smaller packets
    
	if ([self regWrite:OV519_REG_RESET1 val:0x00] < 0) 
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
                                         UInt32 * tailStart, UInt32 * tailLength)
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
    
#if REALLY_VERBOSE
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
#if REALLY_VERBOSE
        printf("HEADER!\n");
#endif
		if (buffer[3] == 0x50) // Start of frame
        {
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
			if (currState == WAIT_NEW) // It's common to have EOF without SOF at beginning of the stream
                return invalidFrame;
            
			if (buffer[9] == 0x01) 
				return invalidFrame;
			
			currState = WAIT_NEW;
#if REALLY_VERBOSE
			if (currLen != 8 * (buffer[15]*256 + buffer[14])) // this check could be useful for debugging
            {
                printf("End of frame length value (%d) does not correspond to total length (%d)\n", 
                       8 * (buffer[15]*256 + buffer[14]), currLen);
//                return invalidFrame;
            }
#endif
			*dataStart = 16;
			*dataLength = 0;
            
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
//  if ([self regWrite:0x2f val:0x80] < 0) // no comment in ov51x, undocumented and not necessary
//      return FALSE;
	
    if ([self regWrite:OV519_REG_RESET1 val:0x0f] < 0)  // resets jpeg and other stuffs
        return FALSE;
    
	if ([self regWrite:OV519_REG_RESET1 val:0x00] < 0) 
        return FALSE;
    
	return TRUE;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
	if ([self regWrite:OV519_REG_RESET1 val:0x0f] < 0) 
        return;
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]];
    
	return;
}

//
// Read and write a register value
// taken from MyOV511Driver
// Read and write also sensor's I2C registers
//

- (int) regRead:(UInt8) reg
{
    UInt8 buf[16]; // Why do we need 16 UInt8?
    
    if (![self usbReadCmdWithBRequest:1 wValue:0 wIndex:reg buf:buf len:1]) 
    {
#ifdef VERBOSE
        NSLog(@"OV519:regRead:usbReadCmdWithBRequest error");
#endif
        return -1;
    }
    
    return buf[0];
}

- (int) regWrite:(UInt8) reg val:(UInt8) val
{
    UInt8 buf[16]; // Same comment as above
    
    buf[0] = val;
    
    if (![self usbWriteCmdWithBRequest:1 wValue:0 wIndex:reg buf:buf len:1]) 
    {
#ifdef VERBOSE
        NSLog(@"OV519:regWrite:usbWriteCmdWithBRequest error");
#endif
        return -1;
    }
    
    return 0;
}

- (int) regWriteMask:(UInt8) reg val:(UInt8) val mask:(UInt8) mask
{
	UInt8 realVal;
	realVal = [self regRead:reg];
	realVal &= ~mask;
	val &= mask;
	realVal |= val;
	return [self regWrite:reg val:realVal];
}


- (int) i2cRead:(UInt8) reg 
{
    int result = 0;
    int val;
    
/*
	rc = reg_w(ov, R51x_I2C_SADDR_2, reg); // 0x43
	if (rc < 0) return rc;
    
	// Initiate 2-byte write cycle 
	rc = reg_w(ov, R518_I2C_CTL, 0x03); // 0x47
	if (rc < 0) return rc;
    
	// Initiate 2-byte read cycle 
	rc = reg_w(ov, R518_I2C_CTL, 0x05); // 0x47
	if (rc < 0) return rc;
    
	value = reg_r(ov, R51x_I2C_DATA); // 0x45
*/    
    
//	[self regWrite:OV519_I2C_SSA val:OV7648_I2C_RSID];
	result = [self regWrite:OV519_I2C_SSA val:sensorSID]; // 0x41
    if (result < 0) 
        return result;
	
    // perform a dummy write cycle to set the register
    result = [self regWrite:OV519_I2C_SMA val:reg]; // 0x43
    if (result < 0) 
        return result;
    
    // initiate the dummy write
    result = [self regWrite:OV519_I2C_CONTROL val:0x03]; // 0x47
    if (result < 0) 
        return result;
    
	result = [self regWrite:0x44 val:sensorSID + 1]; // 0x41
    if (result < 0) 
        return result;
    
    // initiate read
    result = [self regWrite:OV519_I2C_CONTROL val:0x05]; // 0x47
    if (result < 0) 
        return result;
    
    // retrieve data
    val = [self regRead:OV519_I2C_SDA]; // 0x45
    
    return val;
}

- (int) i2cWrite:(UInt8) reg val:(UInt8) val
{
    
//	[self regWrite:OV519_I2C_SSA val:OV7648_I2C_WSID];
	[self regWrite:OV519_I2C_SSA val:sensorSID];
    
    if ([self regWrite:OV519_I2C_SWA val:reg] < 0) 
        return -1;
    
    if ([self regWrite:OV519_I2C_SDA val:val] < 0) 
        return -1;
    
    if ([self regWrite:OV519_I2C_CONTROL val:0x01] < 0) 
        return -1;
    
    return 0;
}

- (int) i2cWriteMask:(UInt8) reg val:(UInt8) val mask:(UInt8) mask
{
	UInt8 realVal;
	realVal = [self i2cRead:reg];
	realVal &= ~mask;
	val &= mask;
	realVal |= val;
	return [self i2cWrite:reg val:realVal];
}

- (void) dumpRegs
{
	UInt8 regLN, regHN;
	printf("Camera Regs ");
	for (regHN = 0; regHN < 0xf0; regHN+=0x10) {
		printf("\n    ");
		for (regLN = 0; regLN < 0x10; ++regLN)
			printf(" %02X=%02X", regHN + regLN, [self regRead:regHN + regLN]);
	}
	printf("\n\n");
	printf("I2C Regs ");
	for (regHN = 0; regHN < 0x80; regHN+=0x10) {
		printf("\n    ");
		for (regLN = 0; regLN < 0x10; ++regLN)
			printf(" %02X=%02X", regHN + regLN, [self i2cRead:regHN + regLN]);
	}
	printf("\n\n");
}

@end



/*
 EyeToy -- different LED policy -- Only turn on if asked to, very bright -- no need for macam special treatment
 
 LED control - different for 511+, 518&+, 519
 
 clockdivision is different...
 
 
 
 */