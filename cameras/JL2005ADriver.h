//
//  JL2005ADriver.h
//  macam
//
//  Created by Harald on 3/1/07.
//  Copyright 2007 hxr. All rights reserved.
//


#import <GenericDriver.h>


@interface JL2005ADriver : GenericDriver 
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
