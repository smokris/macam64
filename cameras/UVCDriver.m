//
//  UVCDriver.m
//  macam
//
//  Created by HXR on 5/8/09.
//  Copyright 2009 HXR. All rights reserved.
//


#import "UVCDriver.h"


@implementation UVCDriver


+ (NSArray *) cameraUsbDescriptions 
{
	return nil;
        /*
    return [NSArray arrayWithObjects:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC + 0x00], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0x00)", @"name", NULL], 
        NULL];
        */
}


- (BOOL) isUVC
{
	return YES;
}










@end

// The SPCA525 is a good subclass for this to include here