//
//  WinbondDriver.h
//  macam
//
//  Created by Harald on 2/12/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import <GenericDriver.h>


@interface WinbondDriver : GenericDriver 
{
    // Add any data structure that you need to keep around
    // i.e. decoding buffers, decoding structures etc
}

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral: (id) c;

- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate;
- (CameraResolution) defaultResolutionAndRate: (short *) rate;

- (UInt8) getGrabbingPipe;
- (BOOL) setGrabInterfacePipe;
- (void) setIsocFrameFunctions;

- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;

- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer;

@end
