//
//  TP68xx.m
//  macam
//
//  Created by hxr on 3/24/09.
//  Copyright 2009 hxr. All rights reserved.
//


#import "TP68xxDriver.h"


@implementation TP6801Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0001], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06a2], @"idVendor",
            @"TP6801 based camera", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0003], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06a2], @"idVendor",
            @"TP6801F based camera", @"name", NULL], 
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    compressionType = quicktimeImage;  // Does some error checking on image
    quicktimeCodec = kJPEGCodecType;
    
	return self;
}


- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    if (rate > 30) 
        return NO;
    
    switch (res) 
    {
        case ResolutionVGA:
        case ResolutionSIF:
            return YES;
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


- (UInt8) getGrabbingPipe
{
    return 1;
}


- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:5];
}


- (BOOL) canSetUSBReducedBandwidth
{
    return YES;
}


IsocFrameResult  tp68xxIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                        UInt32 * dataStart, UInt32 * dataLength, 
                                        UInt32 * tailStart, UInt32 * tailLength, 
                                        GenericFrameInfo * frameInfo)
{
    int position, frameLength = frame->frActCount;
    
    printf("packet received!\n");
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 1) 
    {
        *dataLength = 0;
        
#if VERBOSE
        printf("Invalid chunk!\n");
#endif
        return invalidFrame;
    }
    
#if VERBOSE
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
#endif
    
    for (position = 0; position < frameLength - 6; position++) 
    {
        if ((buffer[position+0] == 0xFF) && 
            (buffer[position+1] == 0xFF) && 
            (buffer[position+2] == 0x00) && 
            (buffer[position+3] == 0xFF) && 
            (buffer[position+4] == 0x96))
        {
#if VERBOSE
            printf("New chunk!\n");
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


- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = tp68xxIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


- (BOOL) startupGrabStream 
{
    CameraError error = CameraErrorOK;
    
//    [self setRegister:0x40 toValue:0x01];  // Start the stream
    
    return error == CameraErrorOK;
}


- (void) shutdownGrabStream 
{
//    [self setRegister:0x40 toValue:0x00];  // Stop the stream
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]]; // Must set alt interface to normal
}


@end


@implementation TP6811Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6810], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06a2], @"idVendor",
            @"TP6811 based camera", @"name", NULL], 
        
        NULL];
}

@end


@implementation TP6813Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0168], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06a2], @"idVendor",
            @"TP6813 based camera", @"name", NULL], 
        
        NULL];
}


@end


