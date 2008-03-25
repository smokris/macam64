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
    
    int width;
    int height;
    struct timeval tvCurrent;

    UInt8 * buffer;
    int rowBytes;
    int bytesPerPixel;
    BOOL  newBuffer;
    struct timeval tvNew;
}

- (id) init;

- (void) setWidth:(int)newWidth andHeight:(int)newHeight;
- (void) setupBuffer:(UInt8 *)buffer rowBytes:(int)rowBytes bytesPerPixel:(int)bpp;

- (void) processRGB;
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
- (void) setImage:(NSImageView *)view;
- (void) draw;

@end
