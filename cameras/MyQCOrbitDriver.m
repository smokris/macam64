/*
 MyQCOrbitDriver.m
 macam

 Created by Charles Le Seac'h on 15/08/04.
 Copyright 2004 Charles Le Seac'h (charles@torda.net). GPL applies.

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
 */

#import "MyQCOrbitDriver.h"

#include "USB_VendorProductIDs.h"


@implementation MyQCOrbitDriver

+ (NSArray*) cameraUsbDescriptions 
{
	NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_ORBIT],@"idProduct",
        @"Logitech QuickCam Orbit",@"name",NULL];
    
    return [NSArray arrayWithObjects:dict1,NULL];
}
	
	
- (BOOL) supportsCameraFeature:(CameraFeature)feature
{
    if (feature == CameraFeatureInspectorClassName)
        return TRUE;

    return FALSE;
}

- (id) valueOfCameraFeature:(CameraFeature)feature 
{
    if (feature == CameraFeatureInspectorClassName)
    	return @"MyQCOrbitCameraInspector";

    return NULL;
}

- (void) rotate:(int)deltapan :(int)deltatilt
{
	unsigned char buf[4];
	int pan, tilt;
	pan  =  64 * deltapan  / 100;
	tilt = -64 * deltatilt / 100; /* positive tilt is down, which is not what the user would expect */
	buf[0] = pan & 0xFF;
	buf[1] = (pan >> 8) & 0xFF;
	buf[2] = tilt & 0xFF;
	buf[3] = (tilt >> 8) & 0xFF;
	[self usbWriteCmdWithBRequest:SET_MPT_CTL wValue:PT_RELATIVE_CONTROL_FORMATTER wIndex:INTF_CONTROL buf:buf len:4];
}

- (void) center
{
	unsigned char buf;	
	int flags=3;
	buf = flags & 0x03; // only lower two bits are currently used
	[self usbWriteCmdWithBRequest:SET_MPT_CTL wValue: PT_RESET_CONTROL_FORMATTER wIndex:INTF_CONTROL buf:&buf len:1];
}

@end
