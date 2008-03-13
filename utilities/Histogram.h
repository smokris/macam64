//
//  Histogram.h
//  macam
//
//  Created by Harald on 3/7/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import <Cocoa/Cocoa.h>


@interface Histogram : NSObject 
{
    int value[256];
    
    int max;
    int total;
    int median;
    int centroid;
    
    int threshold;
    int lowThreshold;
    int highThreshold;
    int lowPower;
    int highPower;
}

- (id) init;

- (void) processRGB:(UInt8 *)buffer width:(int)width height:(int)height rowBytes:(int)rowBytes bpp:(int)bpp;
- (void) processOne:(UInt8 *)buffer width:(int)width height:(int)height rowBytes:(int)rowBytes bpp:(int)bpp;
- (void) calculateStatistics;
- (void) reset;

- (int) getMedian;
- (int) getLowThreshold;
- (int) getHighThreshold;

- (int) getCentroid;
- (int) getLowPower;
- (int) getHighPower;

- (void) drawImage:(NSImageView *)view withMiddle:(int)middle low:(int)low high:(int)high;

@end
