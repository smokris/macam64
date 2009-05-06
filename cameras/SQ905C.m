//
//  SQ905C.m
//  macam
//
//  Created by hxr on 4/29/09.
//  Copyright 2009 HXR. All rights reserved.
//


#import "SQ905C.h"

#include "USB_VendorProductIDs.h"


@implementation SQ905CDriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x905C], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SQ], @"idVendor",
            @"SQ905C based camera", @"name", NULL], 
        
        NULL];
}


@end


@implementation SQ905Cvariant1

@end


