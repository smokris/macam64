//
//  PAC207Driver.m
//
//  macam - webcam app and QuickTime driver component
//  PAC207Driver - driver for the Pixart PAC207 chip
//
//  Created by HXR on 3/24/06.
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


#import "PAC207Driver.h"
#import "MyController.h"
#import "AGC.h"

#include "USB_VendorProductIDs.h"
#include "gspcadecoder.h"


@interface PAC207Driver (Private)

- (BOOL) pixartDecompress:(UInt8 *)inp to:(UInt8 *)outp width:(short)width height:(short)height;

@end


void initializePixartDecoder(struct code_table * table);
inline unsigned short getShort(unsigned char * pt);
int pixartDecompressRow(struct code_table * table, unsigned char * input, unsigned char * output, int width);


@implementation PAC207Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VISTA_PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Vista Plus", @"name", NULL], 
        
        // Add more entries here if somehow these are not enough ;)
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x00], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Q-TEC Webcam 100 USB (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x01], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 01)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x02], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 02)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x03], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Philips SPC 220NC (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x04], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 04)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x05], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 05)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x06], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 06)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x07], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 07)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x08], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Common PixArt PAC207 based webcam (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x09], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 09)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0a)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0b)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0d)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0f)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x10], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Genius VideoCAM GE112 (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x11], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Genius KYE VideoCAM GE111 (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x12], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Genius GE110 (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x13], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 13)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x14], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 14)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x15], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 15)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x16], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 16)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x17], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 17)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x18], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 18)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x19], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 19)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1a)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1b)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1d)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1f)", @"name", NULL], 
        
        NULL];
}


- (int) getRegister:(UInt16)reg
{
    UInt8 buffer[8];
    
    BOOL ok = [self usbReadVICmdWithBRequest:0x00 wValue:0x00 wIndex:reg buf:buffer len:1];
    
    return (ok) ? buffer[0] : -1;
}


- (int) setRegister:(UInt16)reg toValue:(UInt16)val
{
    BOOL ok = [self usbWriteVICmdWithBRequest:0x00 wValue:val wIndex:reg buf:NULL len:0];
    
    return (ok) ? val : -1;
}


- (int) setRegisterList:(UInt16)reg number:(int)length withValues:(UInt8 *)buffer
{
    BOOL ok = [self usbWriteVICmdWithBRequest:0x01 wValue:0x00 wIndex:reg buf:buffer len:length];
    
    return (ok) ? length : -1;
}


- (int) getSensorRegister:(UInt16)reg
{
    return [self getRegister:reg];
}


- (int) setSensorRegister:(UInt16)reg toValue:(UInt16)val
{
    BOOL ok = YES;
    
    if (ok) 
        if ([self setRegister:reg toValue:val] < 0) 
            ok = NO;
    
    if (ok) 
        if ([self setRegister:0x13 toValue:0x01] < 0) 
            ok = NO;
    
    if (ok) 
        if ([self setRegister:0x1c toValue:0x01] < 0) 
            ok = NO;
    
    return (ok) ? val : -1;
}


- (int) dumpRegisters
{
	UInt8 regLN, regHN;
    
	printf("Camera Registers: ");
	for (regHN = 0; regHN < 0x50; regHN += 0x10) {
		printf("\n    ");
		for (regLN = 0; regLN < 0x10; ++regLN)
			printf(" %02X=%02X", regHN + regLN, [self getRegister:regHN + regLN]);
	}
	printf("\n\n");
    
    return 0;
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    [agc setEffects:[NSArray arrayWithObjects:[NSNumber numberWithInt:agcAffectGain], [NSNumber numberWithInt:agcAffectOffset], nil]];
    [agc setMode:agcProvidedAverage];  // use agcHistogram when histogram "breadth" matters
    
    bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    hardwareBrightness = YES;
    hardwareContrast = NO;
    
    compressionType = proprietaryCompression;  // Use own decompression routines
    
    MALLOC(decodingBuffer, UInt8 *, 356 * 292 + 1000, "decodingBuffer");
    initializePixartDecoder(codeTable);
    
    [self setCompression:0];
    
    buttonInterrupt = YES;
    buttonMessageLength = 2;
    
	return self;
}


- (void) startupCamera
{
    [self setRegister:0x41 toValue:0x00];
    [self setRegister:0x0f toValue:0x00];
    [self setRegister:0x11 toValue:0x30];
    
    [super startupCamera];
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionCIF:
            if (rate > 24) 
                return NO;
            return YES;
            break;
            
#if defined(DEBUG)
        case ResolutionQCIF:
            if (rate > 30) 
                return NO;
            return YES; // Not working yet for some unknown reason •••
            break;
#endif
            
        default: 
            return NO;
    }
}


- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 5;
    
	return ResolutionCIF;
}


- (void) setBrightness:(float)v 
{
    if ([self isAutoGain]) 
        [super setBrightness:v];
    else 
        [self setOffset:v];
}


- (BOOL) canSetOffset
{
    return YES;
}


- (float) offset
{
    int value = [self getRegister:0x08];
    
    if (value < 0) 
        return 0.5;
    
    return value / 255.0;
}


- (void) setOffset:(float) v
{
    UInt8 value = 255 * v;
    
    [self setRegister:0x08 toValue:value];
    
    [self setRegister:0x13 toValue:0x01];
    [self setRegister:0x1c toValue:0x01];
}


- (BOOL) canSetGain
{
    return [self isAutoGain] == NO;
}


- (void) setGain:(float) v 
{
    //    if ([self isAutoGain]) 
    [super setGain:v];
    //    else 
    {
        UInt8 value = 31 * v;
        [self setRegister:0x0e toValue:value];
        [self setRegister:0x13 toValue:0x01];
        [self setRegister:0x1c toValue:0x01];
    }
}

- (float) gainStep
{
    return 8 / 255.0;
}


- (BOOL) canSetShutter
{
    return YES;
}


- (void) setShutter:(float) v 
{
    UInt8 value = 0x04 + v * (0x7f - 0x04);  // min and max values
    
    if (value > 0x0f) 
        grabContext.maxFramesBetweenChunks = 1000 * 10;
    
    [super setShutter:v];
    
#if REALLY_VERBOSE
    printf("Setting shutter value to %f (0x%02x).\n", v, value);
#endif
    
    [self setRegister:0x02 toValue:value];
    [self setRegister:0x13 toValue:0x01];
    [self setRegister:0x1c toValue:0x01];
}


- (BOOL) agcDisablesShutter
{
    return NO;
}


- (short) maxCompression 
{
    return 1;
}


- (void) setCompression: (short) v 
{
    float limit = (0x0a - 0x04) / (float) (0x7f - 0x04);
    
    [super setCompression:v];
    
    if (v == 0) 
        if ([self shutter] < limit) 
            [self setShutter:limit];
}


- (BOOL) canSetLed
{
    return YES;
}


- (void) setLed:(BOOL)v
{
    if ([self canSetLed]) 
        [self setRegister:0x41 toValue:(v ? 0x02 : 0x00) withMask:0x02];
    
    [super setLed:v];
}


- (UInt8) getButtonPipe
{
    return 3;
}


- (BOOL) buttonDataHandler:(UInt8 *)data length:(UInt32)length
{
    BOOL result = NO;
    
    if (length == 2) 
    {
        if (data[0] == 0x5a && data[1] == 0x5a) 
            result = YES;
        
        data[0] = 194;  // 0xc2
        data[1] = 75;   // 0x4b
        (*streamIntf)->WritePipe(streamIntf, 4, data, length);  // Some kind of reset?
    }
    
    return result;
}

//
// Returns the pipe used for grabbing
//
- (UInt8) getGrabbingPipe
{
    return 5;
}

//
// Put in the alt-interface with the highest bandwidth (instead of 8)
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:8];
}

//
// Scan the frame and return the results
//
IsocFrameResult  pac207IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                        UInt32 * dataStart, UInt32 * dataLength, 
                                        UInt32 * tailStart, UInt32 * tailLength, 
                                        GenericFrameInfo * frameInfo)
{
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 6) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
//        printf("Invalid chunk!\n");
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
#endif
    
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
            
            if (frameInfo != NULL) 
            {
                frameInfo->averageLuminance = buffer[position + 9];
                frameInfo->averageLuminanceSet = 1;
                frameInfo->averageSurroundLuminance = buffer[position + 10];
                frameInfo->averageSurroundLuminanceSet = 1;
#if REALLY_VERBOSE
//              printf("The central luminance is %d (surround is %d)\n", frameInfo->averageLuminance, frameInfo->averageSurroundLuminance);
#endif
            }
            
            *dataStart = position;
            *dataLength = frameLength - position;
            
            return newChunkFrame;
        }
    }
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = pac207IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError error = CameraErrorOK;
    
    UInt8 init[][8] = 
    {
    { 0x04, 0x12, 0x0d, 0x00, 0x6f, 0x03, 0x29, 0x00 }, 
    { 0x00, 0x96, 0x80, 0xa0, 0x04, 0x10, 0xf0, 0x30 }, 
    { 0x00, 0x00, 0x00, 0x70, 0xa0, 0xf8, 0x00, 0x00 }, 
    { 0x00, 0x00, 0x32, 0x00, 0x96, 0x00, 0xa2, 0x02 }, 
    { 0x00, 0x00, 0x36, 0x00 }, 
    { 0x04, 0x12, 0x05, 0x22, 0x00, 0x01, 0x29 },
    { 0x32, 0x00, 0x96, 0x00, 0xa2, 0x02, 0xaf, 0x00 },
    };
    
    [self setRegisterList:0x02 number:8 withValues:init[0]];
    [self setRegisterList:0x0a number:8 withValues:init[1]];
    [self setRegisterList:0x12 number:8 withValues:init[2]];
    [self setRegisterList:0x40 number:8 withValues:init[3]];
    [self setRegisterList:0x48 number:4 withValues:init[4]];
    
    [self setRegister:0x4a toValue:([self compression] ? 0x88 : 0xff)];
    [self setRegister:0x4b toValue:0x00];
    
    [self setRegister:0x13 toValue:0x01];
    [self setRegister:0x1c toValue:0x01];
    
    [self setRegister:0x41 toValue:([self resolution] == ResolutionCIF ? 0x00 : 0x01) withMask:0x01];
    [self setRegisterList:0x02 number:7 withValues:init[5]];
    [self setRegister:0x0e toValue:0x0a];
    [self setRegister:0x18 toValue:0x00];
    [self setRegisterList:0x42 number:8 withValues:init[6]];
    
    [self setShutter:[self shutter]];  // Also does the 0x13/0x1c
    
    [self setRegister:0x40 toValue:0x01];  // Start the stream
    
    return error == CameraErrorOK;
}

//
// For comparison
//
- (BOOL) startupGrabStreamOriginal
{
    CameraError error = CameraErrorOK;
    
    UInt8 init[][8] = 
    {
    { 0x04, 0x12, 0x0d, 0x00, 0x6f, 0x03, 0x29, 0x00 }, 
    { 0x00, 0x96, 0x80, 0xa0, 0x04, 0x10, 0xf0, 0x30 }, 
    { 0x00, 0x00, 0x00, 0x70, 0xa0, 0xf8, 0x00, 0x00 }, 
    { 0x00, 0x00, 0x32, 0x00, 0x96, 0x00, 0xa2, 0x02 }, 
    { 0x00, 0x00, 0x36, 0x00 }, 
    { 0x04, 0x12, 0x05, 0x22, 0x00, 0x01, 0x29 },
    { 0x32, 0x00, 0x96, 0x00, 0xa2, 0x02, 0xaf, 0x00 },
    };
    
    [self setRegisterList:0x02 number:8 withValues:init[0]];
    [self setRegisterList:0x0a number:8 withValues:init[1]];
    [self setRegisterList:0x12 number:8 withValues:init[2]];
    [self setRegisterList:0x40 number:8 withValues:init[3]];
    [self setRegisterList:0x48 number:4 withValues:init[4]];
    [self setRegister:0x13 toValue:0x01];
    [self setRegister:0x1c toValue:0x01];
    
    [self setRegisterList:0x02 number:7 withValues:init[5]];
    [self setRegister:0x0e toValue:0x0a];
    [self setRegister:0x18 toValue:0x00];
    [self setRegisterList:0x42 number:8 withValues:init[6]];
    [self setRegister:0x4a toValue:0x48];
    [self setRegister:0x13 toValue:0x01];
    [self setRegister:0x1c toValue:0x01];
    
    [self setRegister:0x40 toValue:0x01];
    
    return error == CameraErrorOK;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    [self setRegister:0x40 toValue:0x00];  // Stop the stream
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]]; // Must set alt interface to normal
}

//
// This is the method that takes the raw chunk data and turns it into an image
//
- (BOOL) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
    BOOL problem;
    
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
#if defined(DEBUG)
    if (YES) 
    {
        UInt8 * buf = buffer->buffer;
        NSTextField * message = [self getDebugMessageField];
        if (message) 
            [message setStringValue:[NSString stringWithFormat:@"%02X %02X %02X %02X  %02X %02X %02X %02X  %02X %02X %02X %02X  %02X %02X %02X %02X ", 
                buf[0], buf[1], buf[2], buf[3], buf[4], buf[5], buf[6], buf[7], buf[8], buf[9], buf[10], buf[11], buf[12], buf[13], buf[14], buf[15]]];
    }
#endif
    
	// Decode the bytes
    
    problem = [self pixartDecompress:buffer->buffer to:decodingBuffer width:rawWidth height:rawHeight];
    
    // Turn the Bayer data into an RGB image
    
    [bayerConverter setSourceFormat:4];
    [bayerConverter setSourceWidth:rawWidth height:rawHeight];
    [bayerConverter setDestinationWidth:rawWidth height:rawHeight];
    [bayerConverter convertFromSrc:decodingBuffer
                            toDest:nextImageBuffer
                       srcRowBytes:rawWidth
                       dstRowBytes:nextImageBufferRowBytes
                            dstBPP:nextImageBufferBPP
                              flip:hFlip
                         rotate180:NO];
    
    return problem == NO;
}

//
// Decompress the byte stream
//
- (BOOL) pixartDecompress:(UInt8 *)input to:(UInt8 *)output width:(short)width height:(short)height
{
	// We should received a whole frame with header and EOL marker in *input
	// and return a BGGR pattern in *output
	// remove the header then 
    // - copy line by line EOL is set with 0x0ff0 marker or 
	// - 0x1ee1 marker for compressed line
    // - 0x2dd2 is still unknown
    
	unsigned short word;
	int row;
    
#if REALLY_VERBOSE
    int bad = 0;
    int comp = 0;
    int uncomp = 0;
#endif
    
	input += 16;  // Skip the header
    
	// Go through row by row
    
	for (row = 0; row < height; row++) 
    {
		word = getShort(input);
		switch (word) 
        {
            case 0x0FF0:
#if REALLY_VERBOSE
                uncomp++;
                bad = 0;
                //              NSLog(@"0x0FF0");
#endif
                memcpy(output, input + 2, width);
                input += (2 + width);
                break;
                
            case 0x1EE1:
#if REALLY_VERBOSE
                comp++;
                bad = 0;
                //              NSLog(@"0x1EE1");
#endif
                input += pixartDecompressRow(codeTable, input, output, width);
                break;
                
            case 0x2DD2:  // Don't know what this means yet
#if REALLY_VERBOSE
                bad++;
                NSLog(@"0x2DD2");
#endif
                return NO;
                break;
                
            default:
#if REALLY_VERBOSE
                if (bad == 0) 
                    NSLog(@"other EOL 0x%04x", word);
                else 
                    NSLog(@"-- EOL 0x%04x", word);
                bad++;
                row--; // try again!
                input += 1;
                if (bad > 4) 
#endif
                    return YES;
		}
		output += width;
	}
    
#if 0
#if REALLY_VERBOSE
    if (comp == 0) 
        printf("Image is uncompressed!\n");
    else if (uncomp == 0) 
        printf("Every line is compressed!\n");
    else 
        printf("Image has %d uncompressed and %d compressed lines.\n", uncomp, comp);
#endif
#endif
    
	return NO;
}

@end


//
// Initialize the decoding table
//
void initializePixartDecoder(struct code_table * table)
{
	int i, is_abs, val, len;

	for (i = 0; i < 256; i++) 
    {
		is_abs = 0;
		val = 0;
		len = 0;
        
		if ((i & 0xC0) == 0) 				// code 00
        {
			val = 0;
			len = 2;
		} 
        else if ((i & 0xC0) == 0x40)        // code 01
        {
			val = -5;
			len = 2;
		} 
        else if ((i & 0xC0) == 0x80)        // code 10
        {
			val = +5;
			len = 2;
		} 
        else if ((i & 0xF0) == 0xC0)        // code 1100
        {
			val = -10;
			len = 4;
		} 
        else if ((i & 0xF0) == 0xD0)        // code 1101
        {
			val = +10;
			len = 4;
		} 
        else if ((i & 0xF8) == 0xE0)        // code 11100
        {
			val = -15;
			len = 5;
		} 
        else if ((i & 0xF8) == 0xE8)        // code 11101
        {
			val = +15;
			len = 5;
		} 
        else if ((i & 0xFC) == 0xF0)        // code 111100
        {
			val = -20;
			len = 6;
		} 
        else if ((i & 0xFC) == 0xF4)        // code 111101
        {
			val = +20;
			len = 6;
		} 
        else if ((i & 0xF8) == 0xF8)        // code 11111xxxxxx
        {
			is_abs = 1;
			val = 0;
			len = 5;
		}
        
		table[i].is_abs = is_abs;
		table[i].val = val;
		table[i].len = len;
	}
}

//
// Get the next byte, this works for both little and big endian systems
//
inline unsigned char getByte(unsigned char * input, unsigned int bitpos)
{
	unsigned char * address;
    
	address = input + (bitpos >> 3);
    
	return (address[0] << (bitpos & 7)) | (address[1] >> (8 - (bitpos & 7)));
}

//
// Get the next word, assumes big-endian input
//
inline unsigned short getShort(unsigned char * pt)
{
	return ((((unsigned short) pt[0]) << 8) | pt[1]);
}


#define CLIP(color) (unsigned char)(((color)>0xFF)?0xff:(((color)<0)?0:(color)))

//
// This function decompresses one row of the image
//
int pixartDecompressRow(struct code_table * table, unsigned char * input, unsigned char * output, int width)
{
	int col, val, bitpos;
	unsigned char code;

	// The first two pixels are stored as raw 8-bit numbers
    
	*output++ = input[2];
	*output++ = input[3];
    
	bitpos = 32; // This includes the 2-byte header and the first two bytes

    // Here is the decoding loop
    
	for (col = 2; col < width; col++) 
    {
		// Get the bitcode for the table
        
		code = getByte(input, bitpos);
		bitpos += table[code].len;
        
		// Calculate the actual pixel value
        
		if (table[code].is_abs) // This is an absolute value: get 6 more bits for the actual value
        {
			code = getByte(input, bitpos);
			bitpos += 6;
			*output++ = code & 0xFC; // Use only the high 6 bits
		} 
        else // The value will be relative to left pixel
        {
			val = output[-2] + table[code].val;
			*output++ = CLIP(val);
		}
	}
    
	return 2 * ((bitpos + 15) / 16); // return the number of bytes used for line, rounded up to whole words
}
