//
//  SPCA525Driver.m
//  macam
//
//  Created by hxr on 7/13/06.
//  Copyright 2006 hxr. All rights reserved.
//


#import "SPCA525Driver.h"

#include "USB_VendorProductIDs.h"


@implementation SPCA525Driver
//
// Specify which Vendor and Product IDs this driver will work for
// Add these to the USB_VendorProductIDs.h file
//
+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKAM_PRO_5000], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Pro 5000", @"name", NULL], 
                
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKAM_FUSION], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Fusion", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKAM_ORBIT_MP], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Orbit MP", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKAM_PRO_NOTEBOOKS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Pro Notebooks", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKAM_OEM_DELL_NTBK], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam OEM Dell Notebook", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKAM_OEM_CISCO_VT_II], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam OEM Cisco VT Camera II", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKAM_UPDATEME], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam UpdateMe", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKAM_NEW0], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam (new, 0x08c0)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKAM_NEW4], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam (new 0x08c4)", @"name", NULL], 
        
        // More entries can easily be added for more cameras
        
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
    
    // interface #1, not 0
    
    /* this might be useful
        bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    or
    */
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    compressionType = jpegCompression;
    jpegVersion = 8;
//    compressionType = quicktimeImage;
//    quicktimeCodec = JpegACodec;
    
    // Allocate memory
    // Initialize variable and other structures
    
	return self;
}


- (BOOL) separateControlAndStreamingInterfaces
{
    return YES;
}


- (void) startupCamera
{
    [super startupCamera];
    
    probe.bmHint = 1;	// dwFrameInterval
	probe.bFormatIndex = 8; // format->index;
	probe.bFrameIndex = 0; // frame->bFrameIndex;
	probe.dwFrameInterval = 0; // uvc_try_frame_interval(frame, interval);
    
    [self getVideoControl:&probe probe:YES request:GET_DEF];
    [self printVideoControl:&probe title:"probe - GET-DEF"]  ;
    
    if ([self setVideoControl:&probe probe:YES]) 
        [self printVideoControl:&probe title:"probe - SET"]  ;
    
    if ([self getVideoControl:&min probe:YES request:GET_MIN]) 
        [self printVideoControl:&min title:"min"];
    
    if ([self getVideoControl:&max probe:YES request:GET_MAX]) 
        [self printVideoControl:&max title:"max"];
    
    if ([self getVideoControl:&control probe:YES request:GET_DEF]) 
        [self printVideoControl:&control title:"default"];
    
    [self setVideoControl:&control probe:NO];
    [self printVideoControl:&control title:"default - SET"];
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionQSIF:
            if (rate > 30) 
                return NO;
            return YES;
            break;
            
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
        *rate = 5;
    
	return ResolutionQSIF;
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
//    return [self usbSetAltInterfaceTo:11 testPipe:[self getGrabbingPipe]];

    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:11];
}


// Values for bmHeaderInfo (Video and Still Image Payload Headers, 2.4.3.3)

#define UVC_STREAM_EOH	(1 << 7)
#define UVC_STREAM_ERR	(1 << 6)
#define UVC_STREAM_STI	(1 << 5)
#define UVC_STREAM_RES	(1 << 4)
#define UVC_STREAM_SCR	(1 << 3)
#define UVC_STREAM_PTS	(1 << 2)
#define UVC_STREAM_EOF	(1 << 1)
#define UVC_STREAM_FID	(1 << 0)

//
// This is an example that will have to be tailored to the specific camera or chip
// Scan the frame and return the results
//
IsocFrameResult  spca525IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength, 
                                         GenericFrameInfo * frameInfo)
{
//    static UInt8 lastFID = -1;
//    UInt8 FIDbit;
    int frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = 0;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
#if REALLY_VERBOSE
    if (frameLength > 12000) 
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
            buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5], buffer[6], buffer[7], 
            buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (frameLength < 2 || buffer[0] < 2 || buffer[0] > frameLength) 
        return invalidFrame;
    
	if (buffer[1] & UVC_STREAM_ERR) 
        return invalidFrame;  // Skip error frames
    
    // OK we have some good data
    
    if (buffer[1] & UVC_STREAM_EOF) 
    {
        *tailStart = buffer[0];
        *tailLength = frameLength - *tailStart;
        
#if REALLY_VERBOSE
        if (0) 
        printf("New image start!\n");
#endif
        
        return newChunkFrame;
    }
    
    *dataStart = buffer[0];
    *dataLength = frameLength - *dataStart;
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = spca525IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError error = CameraErrorOK;
    
    //  Probably will have a lot of statements kind of like this:
    //	[self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x0041 buf:NULL len:0];
    
    return error == CameraErrorOK;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    //  More of the same
    //  [self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x40 buf:NULL len:0];
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]]; // Must set alt interface to normal
}

- (BOOL) setVideoControl: (VideoControl *) ctrl  probe: (BOOL) probeVal
{
	int   size;
	UInt8 buffer[34];
    
    size = 34;
    
	*(UInt16*)  &buffer[0] = CFSwapInt16HostToLittle(ctrl->bmHint);
                 buffer[2] =                         ctrl->bFormatIndex;
                 buffer[3] =                         ctrl->bFrameIndex;
	*(UInt32*)  &buffer[4] = CFSwapInt32HostToLittle(ctrl->dwFrameInterval);
	*(UInt16*)  &buffer[8] = CFSwapInt16HostToLittle(ctrl->wKeyFrameRate);
	*(UInt16*) &buffer[10] = CFSwapInt16HostToLittle(ctrl->wPFrameRate);
	*(UInt16*) &buffer[12] = CFSwapInt16HostToLittle(ctrl->wCompQuality);
	*(UInt16*) &buffer[14] = CFSwapInt16HostToLittle(ctrl->wCompWindowSize);
	*(UInt16*) &buffer[16] = CFSwapInt16HostToLittle(ctrl->wDelay);
	*(UInt32*) &buffer[18] = CFSwapInt32HostToLittle(ctrl->dwMaxVideoFrameSize);
	*(UInt32*) &buffer[22] = CFSwapInt32HostToLittle(ctrl->dwMaxPayloadTransferSize);
    
	if (size == 34) 
    {
		*(UInt32*) &buffer[26] = CFSwapInt32HostToLittle(ctrl->dwClockFrequency);
		buffer[30] = ctrl->bmFramingInfo;
		buffer[31] = ctrl->bPreferedVersion;
		buffer[32] = ctrl->bMinVersion;
		buffer[33] = ctrl->bMaxVersion;
	}
    
    if (![self queryUVC:SET_CUR probe:probeVal buffer:buffer length:size])
    {
#ifdef VERBOSE
        NSLog(@"SPCA525Driver:setVideoControl:usbWriteCmdWithBRequest error");
#endif
        return NO;
    }
    
    return YES;
}


- (BOOL) getVideoControl: (VideoControl *) ctrl  probe: (BOOL) probeVal  request: (UInt8) request
{
	int   size;
	UInt8 buffer[34];
    
    size = 26;
    
    if (![self queryUVC:request probe:probeVal buffer:buffer length:size])
    {
#ifdef VERBOSE
        NSLog(@"SPCA525Driver:setVideoControl:usbWriteCmdWithBRequest error");
#endif
        return NO;
    }
    
	ctrl->bmHint                   = CFSwapInt16LittleToHost(*(UInt16 *) &buffer[0]);
	ctrl->bFormatIndex             = buffer[2];
	ctrl->bFrameIndex              = buffer[3];
	ctrl->dwFrameInterval          = CFSwapInt32LittleToHost(*(UInt32 *) &buffer[4]);
	ctrl->wKeyFrameRate            = CFSwapInt16LittleToHost(*(UInt16 *) &buffer[8]);
	ctrl->wPFrameRate              = CFSwapInt16LittleToHost(*(UInt16 *) &buffer[10]);
	ctrl->wCompQuality             = CFSwapInt16LittleToHost(*(UInt16 *) &buffer[12]);
	ctrl->wCompWindowSize          = CFSwapInt16LittleToHost(*(UInt16 *) &buffer[14]);
	ctrl->wDelay                   = CFSwapInt16LittleToHost(*(UInt16 *) &buffer[16]);
	ctrl->dwMaxVideoFrameSize      = CFSwapInt32LittleToHost(*(UInt32 *) &buffer[18]);
	ctrl->dwMaxPayloadTransferSize = CFSwapInt32LittleToHost(*(UInt32 *) &buffer[22]);
    
	if (size == 34) 
    {
		ctrl->dwClockFrequency = CFSwapInt32LittleToHost(*(UInt32 *) &buffer[26]);
		ctrl->bmFramingInfo    = buffer[30];
		ctrl->bPreferedVersion = buffer[31];
		ctrl->bMinVersion      = buffer[32];
		ctrl->bMaxVersion      = buffer[33];
	}
	else 
    {
		ctrl->dwClockFrequency = 0; // video->dev->clock_frequency;
		ctrl->bmFramingInfo = 0;
		ctrl->bPreferedVersion = 0;
		ctrl->bMinVersion = 0;
		ctrl->bMaxVersion = 0;
	}
    
    return YES;
}


- (void) printVideoControl: (VideoControl *) ctrl  title: (char *) text
{
    printf("===== Video Control: %s =====\n", text);
	printf("bmHint:                      0x%04x\n", ctrl->bmHint);
	printf("bFormatIndex:                   %3u\n", ctrl->bFormatIndex);
	printf("bFrameIndex:                    %3u\n", ctrl->bFrameIndex);
	printf("dwFrameInterval:          %9u\n", (unsigned int) ctrl->dwFrameInterval);
	printf("wKeyFrameRate:                %5u\n", ctrl->wKeyFrameRate);
	printf("wPFrameRate:                  %5u\n", ctrl->wPFrameRate);
	printf("wCompQuality:                 %5u\n", ctrl->wCompQuality);
	printf("wCompWindowSize:              %5u\n", ctrl->wCompWindowSize);
	printf("wDelay:                       %5u\n", ctrl->wDelay);
	printf("dwMaxVideoFrameSize:      %9u\n", (unsigned int) ctrl->dwMaxVideoFrameSize);
	printf("dwMaxPayloadTransferSize: %9u\n", (unsigned int) ctrl->dwMaxPayloadTransferSize);
	printf("dwClockFrequency:         %9u\n", (unsigned int) ctrl->dwClockFrequency);
	printf("bmFramingInfo:                 0x%02x\n", ctrl->bmFramingInfo);
	printf("bPreferedVersion:               %3u\n", ctrl->bPreferedVersion);
	printf("bMinVersion:                    %3u\n", ctrl->bMinVersion);
	printf("bMaxVersion:                    %3u\n", ctrl->bMaxVersion);
    printf("\n");
}


- (BOOL) queryUVC: (UInt8) request  probe: (BOOL) probeVal  buffer: (UInt8 *) buffer  length: (short) length
{
    UInt8  direction = (request & 0x80) ? kUSBIn : kUSBOut;
    UInt16 probeValue = (probeVal ? VS_PROBE_CONTROL : VS_COMMIT_CONTROL) << 8;
    UInt16 probeIndex = 0 << 8 | 1; // unit << 8 | interface-number
    
    return [self usbControlCmdWithBRequestType:USBmakebmRequestType(direction, kUSBClass, kUSBInterface)
                               bRequest:request
                                 wValue:probeValue
                                 wIndex:probeIndex
                                    buf:buffer
                                    len:length];
}


@end
