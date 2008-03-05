//
//  R5U870Driver.m
//  macam
//
//  Created by Harald  on 3/5/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import "R5U870Driver.h"

#include "USB_VendorProductIDs.h"


@implementation R5U870Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1830], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"Sony VCC VGP-VCC2 for VAIO SZ", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1832], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"Sony VCC VGP-VCC3 for VAIO UX", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1833], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"Sony VCC VGP-VCC2 for VAIO AR1", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1834], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"Sony VCC VGP-VCC2 for VAIO AR2", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1835], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"Sony VCC VGP-VCC5 for VAIO SZ", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1836], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"Sony VCC VGP-VCC4 for VAIO FE", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1837], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"Sony VCC VGP-VCC4 for VAIO FZ", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1839], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"Sony VCC VGP-VCC6 for VAIO CR", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x183a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"Sony VCC VGP-VCC7 for VAIO SZ", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x183b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"Sony VCC VGP-VCC8 for VAIO FZ", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1810], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"HP Pavillion Webcam - UVC", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1870], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_RICOH], @"idVendor",
            @"HP Pavillion Webcam / HP Webcam 1000", @"name", NULL], 
        
        NULL];
}




@end
