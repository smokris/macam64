//
//  SPCA561ADriver.m
//  macam
//
//  Created by hxr on 1/19/06.
//  Copyright 2006 hxr@users.sourceforge.net. All rights reserved.
//


#import "SPCA561ADriver.h"

#include "USB_VendorProductIDs.h"


@implementation SPCA561ADriver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_CHAT_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Chat (B)", @"name", NULL], 
        
        NULL];
}


#include "spca561.h"


- (CameraError) spca5xx_init
{
    spca561_init(spca5xx_struct);
    return CameraErrorOK;
}



- (CameraError) spca5xx_config
{
    spca561_config(spca5xx_struct);
    return CameraErrorOK;
}


- (CameraError) spca5xx_start
{
    spca561_start(spca5xx_struct);
    return CameraErrorOK;
}


- (CameraError) spca5xx_stop
{
    spca561_stop(spca5xx_struct);
    return CameraErrorOK;
}


- (CameraError) spca5xx_shutdown
{
    spca561_shutdown(spca5xx_struct);
    return CameraErrorOK;
}


// brightness also returned in spca5xx_struct

- (CameraError) spca5xx_getbrightness
{
    spca561_getbrightness(spca5xx_struct);
    return CameraErrorOK;
}


// takes brightness from spca5xx_struct

- (CameraError) spca5xx_setbrightness
{
    spca561_setbrightness(spca5xx_struct);
    return CameraErrorOK;
}


- (CameraError) spca5xx_setAutobright
{
    spca561_setAutobright(spca5xx_struct);
    return CameraErrorOK;
}


// contrast also return in spca5xx_struct

- (CameraError) spca5xx_getcontrast
{
    spca561_getcontrast(spca5xx_struct);
    return CameraErrorOK;
}


// takes contrast from spca5xx_struct

- (CameraError) spca5xx_setcontrast
{
    spca561_setcontrast(spca5xx_struct);
    return CameraErrorOK;
}




// other stuff, including decompression



@end
