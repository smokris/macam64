//
//  AGC.m
//  macam
//
//  Created by Harald on 3/16/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import "AGC.h"
#import "Histogram.h"


@implementation AGC


- (id) init
{
	self = [super init];
	if (self == NULL) 
        return NULL;
    
    softwareAGCon = NO;
    
    return self;
}


- (BOOL) update:(Histogram *) histogram
{
    if (!softwareAGCon) 
        return NO;
    
    // check the time
    
    // update histogram?
    
    
    return NO;
}


@end
