//
//  DivioCriver.h
//  macam
//
//  Created by Harald on 1/28/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import <GenericDriver.h>


typedef enum 
{
    NW_NotInitialized = 0,
    NW800_BRIDGE, 
    NW801_BRIDGE, 
    NW802_BRIDGE, 
    NW_Unknown
} DivioBridgeType;


@interface DivioDriver : GenericDriver 
{
    DivioBridgeType bridgeType;
}

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral: (id) c;

- (DivioBridgeType) autodetectBridge;

- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate;
- (CameraResolution) defaultResolutionAndRate: (short *) rate;

- (UInt8) getGrabbingPipe;
- (BOOL) setGrabInterfacePipe;
- (void) setIsocFrameFunctions;

- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;

@end


/*
@interface DivioCriver : DivioCriver 

@end



@interface DivioCriver : DivioCriver 

@end


@interface DivioCriver : DivioCriver 

@end


@interface DivioCriver : DivioCriver 

@end
*/