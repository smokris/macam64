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

#import "MyToUCamFunDriver.h"
#import "MyCameraCentral.h"

#define PRODUCT_TOUCAM_FUN 784

@implementation MyToUCamFunDriver

+ (unsigned short) cameraUsbProductID { return PRODUCT_TOUCAM_FUN; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_PHILIPS; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"Philips ToUCam Fun"]; }

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err=[super startupWithUsbDeviceRef:usbDeviceRef];
    if (!err) {
        camHFlip=YES;
    }
    return err;
}

@end
