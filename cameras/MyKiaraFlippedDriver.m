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

#include "USB_VendorProductIDs.h"


@implementation MyKiaraFlippedDriver

+ (NSArray*) cameraUsbDescriptions 
{
    NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_TOUCAM_FUN],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS],@"idVendor",
        @"Philips ToUCam Fun",@"name",NULL];
    
    NSDictionary* dict2=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_PRO_3000],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH],@"idVendor",
        @"Logitech QuickCam Pro 3000",@"name",NULL];
    
	NSDictionary* dict3=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedShort:PRODUCT_WEBCAM_5],@"idProduct",
		[NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS],@"idVendor",
		@"Creative Labs Webcam 5",@"name",NULL];
    
	NSDictionary* dict4=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedShort:PRODUCT_AFINA_EYE],@"idProduct",
		[NSNumber numberWithUnsignedShort:VENDOR_SOTEC],@"idVendor",
		@"Sotec Afina Eye",@"name",NULL];
    
	NSDictionary* dict5=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedShort:PRODUCT_AFINA_EYE],@"idProduct",
		[NSNumber numberWithUnsignedShort:VENDOR_AME_CO],@"idVendor",
		@"AME Co. Afina Eye",@"name",NULL];
    
	NSDictionary* dict6=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedShort:PRODUCT_VCS_UM100],@"idProduct",
		[NSNumber numberWithUnsignedShort:VENDOR_VISIONITE],@"idVendor",
		@"Visionite VCS-UM100",@"name",NULL];
    
	return [NSArray arrayWithObjects:dict1,dict2,dict3,dict4,dict5,dict6,NULL];
}

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId {
    CameraError err=[super startupWithUsbLocationId:usbLocationId];
    camHFlip=YES;
    return err;
}

@end
