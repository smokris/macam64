//
//  Histogram.m
//  macam
//
//  Created by Harald on 3/7/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import "Histogram.h"


@implementation Histogram

- (id) init
{
    self = [super init];
    
    [self reset];
    threshold = 10;
    
    return self;
}


- (void) processRGB:(UInt8 *)buffer width:(int)width height:(int)height rowBytes:(int)rowBytes bpp:(int)bpp
{
    int i, j;
    
    [self reset];
    
    for (j = 0; j < height; j++) 
    {
        UInt8 * p = buffer + j * rowBytes;
        
        for (i = 0; i < width; i++, p += bpp) 
        {
            value[p[0]]++;
            value[p[1]]++;
            value[p[2]]++;
        }
    }
}


- (void) processOne:(UInt8 *)buffer width:(int)width height:(int)height rowBytes:(int)rowBytes bpp:(int)bpp
{
    int i, j;
    
    [self reset];
    
    for (j = 0; j < height; j++) 
    {
        UInt8 * p = buffer + j * rowBytes;
        
        for (i = 0; i < width; i++, p += bpp) 
            value[*p]++;
    }
}


- (void) calculateStatistics
{
    int i;
    
    int sum = 0;
    int weighted = 0;
    
    for (i = 0; i < 256; i++) 
    {
        if (max < value[i]) 
            max = value[i];
        
        sum += value[i];
        weighted += i * value[i];
    }
    
    total = sum;
    centroid = weighted / total;
    
    sum = 0;
    for (i = 0; i < 256; i++) 
    {
        sum += value[i];
        if (sum > total / 2) 
        {
            median = i;
            break;
        }
    }
    
    int limit = total * threshold / 100;
    
    sum = 0;
    for (i = 0; i < 256; i++) 
    {
        sum += value[i];
        if (sum > limit) 
        {
            lowThreshold = i;
            break;
        }
    }
    
    sum = 0;
    for (i = 255; i >= 0; i--) 
    {
        sum += value[i];
        if (sum > limit) 
        {
            highThreshold = i;
            break;
        }
    }
    
    int power = total * threshold / 1000;
    
    for (i = 0; i < 256; i++) 
        if (value[i] >= power) 
        {
            lowPower = i;
            break;
        }
    
    for (i = 255; i >= 0; i--) 
        if (value[i] >= power) 
        {
            highPower = i;
            break;
        }
}


- (void) reset
{
    int i;
    
    for (i = 0; i < 256; i++) 
        value[i] = 0;
    
    max = 0;
    total = 0;
    median = -1;
    lowThreshold = -1;
    highThreshold = -1;
    centroid = -1;
    lowPower = -1;
    highPower = -1;
}


- (int) getMedian
{
    if (median < 0) 
        [self calculateStatistics];
    
    return median;
}


- (int) getLowThreshold
{
    if (lowThreshold < 0) 
        [self calculateStatistics];
    
    return lowThreshold;
}


- (int) getHighThreshold
{
    if (highThreshold < 0) 
        [self calculateStatistics];
    
    return highThreshold;
}


- (int) getCentroid
{
    if (centroid < 0) 
        [self calculateStatistics];
    
    return centroid;
}


- (int) getLowPower
{
    if (lowPower < 0) 
        [self calculateStatistics];
    
    return lowPower;
}


- (int) getHighPower
{
    if (highPower < 0) 
        [self calculateStatistics];
    
    return highPower;
}


- (void) drawImage:(NSImageView *)view withMiddle:(int)middle low:(int)low high:(int)high
{
    int i;
    NSPoint from, to;
    NSRect bounds = [view bounds];
    NSImage * image = [[NSImage alloc] initWithSize:bounds.size];
    
    [image lockFocus];
    
    // Clear image
    
    [[NSColor lightGrayColor] set];
    [NSBezierPath fillRect:bounds];
    
    // Draw each bar of the histogram
    
    [[NSColor blackColor] set];
    from.y = 0.0;
    
    for (i = 0; i < 256; i++) 
    {
        from.x = to.x = i + 0.5;
        to.y = value[i] * bounds.size.height / (float) max;
        
        [NSBezierPath strokeLineFromPoint:from toPoint:to];
    }
    
    to.y = bounds.size.height;
    
    // Draw the middle (green) line
    
    [[NSColor greenColor] set];
    from.x = to.x = middle + 0.5;
    [NSBezierPath strokeLineFromPoint:from toPoint:to];
    
    // Draw the low and high (red) bars
    
    [[NSColor redColor] set];
    from.x = to.x = low + 0.5;
    [NSBezierPath strokeLineFromPoint:from toPoint:to];
    from.x = to.x = high + 0.5;
    [NSBezierPath strokeLineFromPoint:from toPoint:to];
    
    [image unlockFocus];
    
    [view setImage:image];
}

@end
