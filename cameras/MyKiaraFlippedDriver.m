/*
 macam - webcam app and QuickTime driver component
 Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 $Id$
 */

#import "MyKiaraFlippedDriver.h"
#import "MyCameraCentral.h"

#define PRODUCT_TOUCAM_FUN 0x0310
#define PRODUCT_QUICKCAM_PRO_3000 0x08b0

@implementation MyKiaraFlippedDriver

+ (NSArray*) cameraUsbDescriptions {
    NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_TOUCAM_FUN],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS],@"idVendor",
        @"Philips ToUCam Fun",@"name",NULL];
    NSDictionary* dict2=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_PRO_3000],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH],@"idVendor",
        @"Logitech QuickCam Pro 3000",@"name",NULL];
    return [NSArray arrayWithObjects:dict1,dict2,NULL];
}



- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err=[super startupWithUsbDeviceRef:usbDeviceRef];
    camHFlip=YES;
    return err;
}

@end
