//
//  OV7640.m
//  macam
//
//  Created by Harald on 11/2/07.
//  Copyright 2007 HXR. All rights reserved.
//

#import "OV7640.h"


@implementation OV7640


- (void) setResolution1:(CameraResolution)r fps:(short)fr
{
    switch (r) 
    {
        case ResolutionSIF:
            [self setRegister:OV7648_REG_COMC toValue:0x20 withMask:0x20];	// Quarter VGA
            [self setRegister:OV7648_REG_COMH toValue:0x20 withMask:0x20];	// Interlaced scan (ov51x set this to progressive - but interlaced seems more stable)
            break;
            
        case ResolutionVGA:
            [self setRegister:OV7648_REG_COMC toValue:0x00 withMask:0x20];	// Not Quarter VGA
            [self setRegister:OV7648_REG_COMH toValue:0x20 withMask:0x20];	// Interlaced scan
            break;
            
        default:
            break;
    }
}


- (void) setResolution3:(CameraResolution)r fps:(short)fr
{
    switch (fr) 
    {
        // FIXME (from ov51x): these are only valid at the max resolution.
        // It's possible that at SIF resolution you can go up to 60fps (OV7648 can do it)
        
        // this is a clockdiv setting in ov51x
         // it's a polarity setting - it works for some reason
        
        case 30:
        case 25:
        case 20:
            if ([self setRegister:0x11 toValue:0x00] < 0) return;
            break;
            
        case 15:
        case 10:
        case 5:
            if ([self setRegister:0x11 toValue:0x01] < 0) return;
            break;
            
        default:
            break;
    }
}


- (BOOL) canSetBrightness
{
    return YES;
}


- (void) setBrightness:(float)v
{
    UInt8 value = (UInt8) (v*255);
//    NSLog(@"Setting brightness to %02x.\n", value);
	[self setRegister:OV7648_REG_BRT toValue:value];
//    value = [self getRegister:OV7648_REG_BRT];
//    NSLog(@"Returned brightness is %02x.\n", value);
}


- (BOOL) canSetSaturation
{
    return YES;
}


- (void) setSaturation:(float)v
{
    UInt8 value = ((UInt8) (v*255)) & 0xf0;
//    NSLog(@"Setting saturation to %02x.\n", value);
	[self setRegister:OV7648_REG_SAT toValue:value];	// some bit are reserved
//    value = [self getRegister:OV7648_REG_SAT];
//    NSLog(@"Returned saturation is %02x.\n", value);
}


- (BOOL) canSetGain
{
    return YES;
}


- (void) setGain:(float)v
{
    UInt8 value = (UInt8) (v*255);
//    NSLog(@"Setting gain to %02x.\n", value);
	[self setRegister:OV7648_REG_GAIN toValue:value];
//    value = [self getRegister:OV7648_REG_GAIN];
//    NSLog(@"Returned gain is %02x.\n", value);
}


@end
