//
//  AGC.h
//  macam
//
//  Created by Harald on 3/16/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import <Histogram.h>


//
// Algorithm for Automatic Gain Control
//
// Some cameras do not have AGC built-in, but require driver-level support. 
//

//
// connect with Histogram, or use other data?
// 
// update often, but not necessarily every frame
// 
// keep track of recent changes, to understand effects
//


@interface AGC : NSObject 
{
    BOOL softwareAGCon;
    
}


- (BOOL) update:(Histogram *) histogram;


@end
