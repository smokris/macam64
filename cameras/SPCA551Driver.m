//
//  SPCA551Driver.m
//  macam
//
//  Created by Harald on 11/14/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "SPCA551Driver.h"


@implementation SPCA551ADriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        /*
         [NSDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithUnsignedShort:PRODUCT_DSC_13M_SMART], @"idProduct",
             [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
             @"Genius DSC 1.3M Smart", @"name", NULL], 
         */
        NULL];
}

@end
