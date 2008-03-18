//
//  OV534Driver.m
//  macam
//
//  Created by Harald on 1/10/08.
//  Copyright 2008 hxr. All rights reserved.
//

//
// Many thanks to Jim Paris at PS2 developer forums
//


#import "OV534Driver.h"


//  SCCB/sensorinterface

#define EYEREG_SCCB_ADDRESS   0xf1   /* ? */
#define EYEREG_SCCB_SUBADDR   0xf2
#define EYEREG_SCCB_WRITE     0xf3
#define EYEREG_SCCB_READ      0xf4
#define EYEREG_SCCB_OPERATION 0xf5
#define EYEREG_SCCB_STATUS    0xf6

#define EYE_SCCB_OP_WRITE_3 0x37
#define EYE_SCCB_OP_WRITE_2 0x33
#define EYE_SCCB_OP_READ_2  0xf9


@interface OV534Driver (Private)

- (void) initCamera;

@end


@implementation OV534Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x3002], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06f8], @"idVendor",
            @"Hercules Blog Webcam", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x3003], @"idProduct", 
            [NSNumber numberWithUnsignedShort:0x06f8], @"idVendor", 
            @"Hercules Dualpix HD Webcam", @"name", NULL],
        
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
    
    [LUT setDefaultOrientation:NormalOrientation];
    
    driverType = bulkDriver;
    
    decodingSkipBytes = 0;
    
    compressionType = proprietaryCompression;
    
	return self;
}


- (void) startupCamera
{
    [self initCamera];
    
    [super startupCamera];
}



- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionVGA:
            if (rate > 30) 
                return NO;
            return YES;
            break;
            
        case ResolutionSIF:
            if (rate > 120) 
                return NO;
            return NO; // Not working yet 
            break;
            
        default: 
            return NO;
    }
}


- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 30;
    
	return ResolutionVGA;
}

- (BOOL) canSetLed
{
    return YES;
}

- (void) setLed:(BOOL) v
{
    [self setRegister:0x21 toValue:0x80 withMask:0x80];
    [self setRegister:0x23 toValue:(v ? 0x80 : 0x00) withMask:0x80];
    
    [super setLed:v];
}


//
// Set up some unusual defaults
//
- (void) setIsocFrameFunctions
{
    grabContext.chunkBufferLength = 2 * [self width] * [self height];
    grabContext.numberOfChunkBuffers = 2;  // Must be at least 2
    grabContext.numberOfTransfers = 3;  // Must be at least 3 for the PS3 Eye!
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    videoBulkReadsPending = 0;
    
    [self setRegister:0xe0 toValue:0x00];
    
    return YES;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    [self setRegister:0xe0 toValue:0x09];
}


int clip(int x)
{
	if (x < 0) x = 0;
	if (x > 255) x = 255;
	return x;
}


void yuv_to_rgb(UInt8 y, UInt8 u, UInt8 v, UInt8 * r, UInt8 * g, UInt8 * b)
{
	int c = y - 16;
	int d = u - 128;
	int e = v - 128;
    
	*r = clip((298 * c           + 409 * e + 128) >> 8);
	*g = clip((298 * c - 100 * d - 208 * e + 128) >> 8);
	*b = clip((298 * c + 516 * d           + 128) >> 8);
}


//
// Return YES if everything is OK
//
- (BOOL) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
	// Decode the bytes
    
    UInt8 * ptr = buffer->buffer;
    
    int R = 0;
    int G = 1;
    int B = 2;
    
    int row, column;
    
    if (buffer->numBytes < (grabContext.chunkBufferLength - 4)) 
        return NO;  // Skip this chunk
    
    for (row = 0; row < rawHeight; row++) 
    {
        UInt8 * out = nextImageBuffer + row * nextImageBufferRowBytes;
        
        for (column = 0; column < rawWidth; column += 2) 
        {
            int y1 = *ptr++;
            int u  = *ptr++;
            int y2 = *ptr++;
            int v  = *ptr++;
            
            yuv_to_rgb(y1, u, v, out + R, out + G, out + B);
            out += nextImageBufferBPP;
            
            yuv_to_rgb(y2, u, v, out + R, out + G, out + B);
            out += nextImageBufferBPP;
        }
    }
    
    [LUT processImage:nextImageBuffer numRows:rawHeight rowBytes:nextImageBufferRowBytes bpp:nextImageBufferBPP];
    
    return YES;
}


- (int) getRegister:(UInt16)reg
{
    UInt8 buffer[8];
    
    BOOL ok = [self usbReadCmdWithBRequest:0x01 wValue:0x0000 wIndex:reg buf:buffer len:1];
    
    return (ok) ? buffer[0] : -1;
}


- (int) setRegister:(UInt16)reg toValue:(UInt8)val
{
    UInt8 buffer[8];
    
    buffer[0] = val;
    
    BOOL ok = [self usbWriteCmdWithBRequest:0x01 wValue:0x0000 wIndex:reg buf:buffer len:1];
    
    return (ok) ? val : -1;
}


- (int) verifySetRegister:(UInt16)reg toValue:(UInt8)val
{
    int verify;
    
    if ([self setRegister:reg toValue:val] < 0) 
    {
        printf("OV534Driver:verifySetRegister:setRegister failed\n");
        return -1;
    }
    
    verify = [self getRegister:reg];
    
    if (val != verify) 
    {
        printf("OV534Driver:verifySetRegister:getRegister returns something unexpected! (0x%04x != 0x%04x)\n", val, verify);
    }
    
    return verify;
}


- (void) initSCCB
{
    [self verifySetRegister:0xe7 toValue:0x3a];
    
    [self setRegister:EYEREG_SCCB_ADDRESS toValue:0x60];
    [self setRegister:EYEREG_SCCB_ADDRESS toValue:0x60];
    [self setRegister:EYEREG_SCCB_ADDRESS toValue:0x60];
    [self setRegister:EYEREG_SCCB_ADDRESS toValue:0x42];
}

//
// Is SCCB OK? Return YES if OK
//
- (BOOL) sccbStatusOK
{
#define SCCB_RETRY 5
    
    int try = 0;
    UInt8 ret;
    
    for (try = 0; try < SCCB_RETRY; try++) 
    {
        ret = [self getRegister:EYEREG_SCCB_STATUS];
        
        if (ret == 0x00) 
            return YES;
        
        if (ret == 0x04) 
            return NO;
        
        if (ret != 0x03) 
            printf("OV534Driver:sccbStatus is 0x%02x, attempt %d (of %d)\n", ret, try + 1, SCCB_RETRY);
    }
    
    return NO;
}


- (int) getSensorRegister:(UInt8)reg
{
    if ([self setRegister:EYEREG_SCCB_SUBADDR toValue:reg] < 0) 
        return -1;
    
    if ([self setRegister:EYEREG_SCCB_OPERATION toValue:EYE_SCCB_OP_WRITE_2] < 0) 
        return -1;
    
    if (![self sccbStatusOK]) 
    {
        printf("OV534Driver:getSensorRegister:SCCB not OK (1)\n");
        return -1;
    }
    
    if ([self setRegister:EYEREG_SCCB_OPERATION toValue:EYE_SCCB_OP_READ_2] < 0) 
        return -1;
    
    if (![self sccbStatusOK]) 
    {
        printf("OV534Driver:getSensorRegister:SCCB not OK (2)\n");
        return -1;
    }
    
    return [self getRegister:EYEREG_SCCB_READ];
}


- (int) setSensorRegister:(UInt8)reg toValue:(UInt8)val
{
    if ([self setRegister:EYEREG_SCCB_SUBADDR toValue:reg] < 0) 
        return -1;
    
    if ([self setRegister:EYEREG_SCCB_WRITE toValue:val] < 0) 
        return -1;
    
    if ([self setRegister:EYEREG_SCCB_OPERATION toValue:EYE_SCCB_OP_WRITE_3] < 0) 
        return -1;
    
    return ([self sccbStatusOK]) ? val : -1;
}


- (void) initCamera
{
    [self verifySetRegister:0xe7 toValue:0x3a];
    [self setRegister:0xf1 toValue:0x60];
    [self setRegister:0xf1 toValue:0x60];
    [self setRegister:0xf1 toValue:0x60];
    [self setRegister:0xf1 toValue:0x42];
    
    [self verifySetRegister:0xc2 toValue:0x0c];
    [self verifySetRegister:0x88 toValue:0xf8];
    [self verifySetRegister:0xc3 toValue:0x69];
    [self verifySetRegister:0x89 toValue:0xff];
    [self verifySetRegister:0x76 toValue:0x03];
    [self verifySetRegister:0x92 toValue:0x01];
    [self verifySetRegister:0x93 toValue:0x18];
    [self verifySetRegister:0x94 toValue:0x10];
    [self verifySetRegister:0x95 toValue:0x10];
    [self verifySetRegister:0xe2 toValue:0x00];
    [self verifySetRegister:0xe7 toValue:0x3e];
    
    [self setRegister:0x1c toValue:0x0a];
    [self setRegister:0x1d toValue:0x22];
    [self setRegister:0x1d toValue:0x06];
    [self verifySetRegister:0x96 toValue:0x00];
    
    [self setRegister:0x97 toValue:0x20];
    [self setRegister:0x97 toValue:0x20];
    [self setRegister:0x97 toValue:0x20];
    [self setRegister:0x97 toValue:0x0a];
    [self setRegister:0x97 toValue:0x3f];
    [self setRegister:0x97 toValue:0x4a];
    [self setRegister:0x97 toValue:0x20];
    [self setRegister:0x97 toValue:0x15];
    [self setRegister:0x97 toValue:0x0b];
    
    [self verifySetRegister:0x8e toValue:0x40];
    [self verifySetRegister:0x1f toValue:0x81];
    [self verifySetRegister:0x34 toValue:0x05];
    [self verifySetRegister:0xe3 toValue:0x04];
    [self verifySetRegister:0x88 toValue:0x00];
    [self verifySetRegister:0x89 toValue:0x00];
    [self verifySetRegister:0x76 toValue:0x00];
    [self verifySetRegister:0xe7 toValue:0x2e];
    [self verifySetRegister:0x31 toValue:0xf9];
    [self verifySetRegister:0x25 toValue:0x42];
    [self verifySetRegister:0x21 toValue:0xf0];
    
    [self setRegister:0x1c toValue:0x00];
    [self setRegister:0x1d toValue:0x40];
    [self setRegister:0x1d toValue:0x02];
    [self setRegister:0x1d toValue:0x00];
    [self setRegister:0x1d toValue:0x02];
    [self setRegister:0x1d toValue:0x57];
    [self setRegister:0x1d toValue:0xff];
    
    [self verifySetRegister:0x8d toValue:0x1c];
    [self verifySetRegister:0x8e toValue:0x80];
    [self verifySetRegister:0xe5 toValue:0x04];
    
    [self setSensorRegister:0x12 toValue:0x80];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    
    [self setSensorRegister:0x3d toValue:0x03];
    [self setSensorRegister:0x17 toValue:0x26];
    [self setSensorRegister:0x18 toValue:0xa0];
    [self setSensorRegister:0x19 toValue:0x07];
    [self setSensorRegister:0x1a toValue:0xf0];
    [self setSensorRegister:0x32 toValue:0x00];
    [self setSensorRegister:0x29 toValue:0xa0];
    [self setSensorRegister:0x2c toValue:0xf0];
    [self setSensorRegister:0x65 toValue:0x20];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x42 toValue:0x7f];
    [self setSensorRegister:0x63 toValue:0xe0];
    [self setSensorRegister:0x64 toValue:0xff];
    [self setSensorRegister:0x66 toValue:0x00];
    [self setSensorRegister:0x13 toValue:0xf0];
    [self setSensorRegister:0x0d toValue:0x41];
    [self setSensorRegister:0x0f toValue:0xc5];
    [self setSensorRegister:0x14 toValue:0x11];
    
    [self setSensorRegister:0x22 toValue:0x7f];
    [self setSensorRegister:0x23 toValue:0x03];
    [self setSensorRegister:0x24 toValue:0x40];
    [self setSensorRegister:0x25 toValue:0x30];
    [self setSensorRegister:0x26 toValue:0xa1];
    [self setSensorRegister:0x2a toValue:0x00];
    [self setSensorRegister:0x2b toValue:0x00];
    [self setSensorRegister:0x6b toValue:0xaa];
    [self setSensorRegister:0x13 toValue:0xff];
    
    [self setSensorRegister:0x90 toValue:0x05];
    [self setSensorRegister:0x91 toValue:0x01];
    [self setSensorRegister:0x92 toValue:0x03];
    [self setSensorRegister:0x93 toValue:0x00];
    [self setSensorRegister:0x94 toValue:0x60];
    [self setSensorRegister:0x95 toValue:0x3c];
    [self setSensorRegister:0x96 toValue:0x24];
    [self setSensorRegister:0x97 toValue:0x1e];
    [self setSensorRegister:0x98 toValue:0x62];
    [self setSensorRegister:0x99 toValue:0x80];
    [self setSensorRegister:0x9a toValue:0x1e];
    [self setSensorRegister:0x9b toValue:0x08];
    [self setSensorRegister:0x9c toValue:0x20];
    [self setSensorRegister:0x9e toValue:0x81];
    
    [self setSensorRegister:0xa6 toValue:0x04];
    [self setSensorRegister:0x7e toValue:0x0c];
    [self setSensorRegister:0x7f toValue:0x16];
    
    [self setSensorRegister:0x80 toValue:0x2a];
    [self setSensorRegister:0x81 toValue:0x4e];
    [self setSensorRegister:0x82 toValue:0x61];
    [self setSensorRegister:0x83 toValue:0x6f];
    [self setSensorRegister:0x84 toValue:0x7b];
    [self setSensorRegister:0x85 toValue:0x86];
    [self setSensorRegister:0x86 toValue:0x8e];
    [self setSensorRegister:0x87 toValue:0x97];
    [self setSensorRegister:0x88 toValue:0xa4];
    [self setSensorRegister:0x89 toValue:0xaf];
    [self setSensorRegister:0x8a toValue:0xc5];
    [self setSensorRegister:0x8b toValue:0xd7];
    [self setSensorRegister:0x8c toValue:0xe8];
    [self setSensorRegister:0x8d toValue:0x20];
    
    [self setSensorRegister:0x0c toValue:0x90];
    
    [self verifySetRegister:0xc0 toValue:0x50];
    [self verifySetRegister:0xc1 toValue:0x3c];
    [self verifySetRegister:0xc2 toValue:0x0c];
    
    [self setSensorRegister:0x2b toValue:0x00];
    [self setSensorRegister:0x22 toValue:0x7f];
    [self setSensorRegister:0x23 toValue:0x03];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x0c toValue:0xd0];
    [self setSensorRegister:0x64 toValue:0xff];
    [self setSensorRegister:0x0d toValue:0x41];
    
    [self setSensorRegister:0x14 toValue:0x41];
    [self setSensorRegister:0x0e toValue:0xcd];
    [self setSensorRegister:0xac toValue:0xbf];
    [self setSensorRegister:0x8e toValue:0x00];
    [self setSensorRegister:0x0c toValue:0xd0];
    
    [self setRegister:0xe0 toValue:0x09];
//  [self setRegister:0xe0 toValue:0x00];
}

@end


@implementation OV538Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2000], @"idProduct", 
            [NSNumber numberWithUnsignedShort:0x1415], @"idVendor", 
            @"Sony HD Eye for PS3 (SLEH 00201)", @"name", NULL],
        
        NULL];
}

@end
