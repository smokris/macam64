//
//  SQ930C.m
//
//  macam - webcam app and QuickTime driver component
//  SQ930C - driver for SQ930C-based cameras
//
//  Created by HXR on 1/15/06.
//
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net). 
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA
//

#import <Cocoa/Cocoa.h>

#import "SQ930C.h"

#include "USB_VendorProductIDs.h"


@implementation SQ930C


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SQ930C], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SQ], @"idVendor",
            @"SQ930C based camera", @"name", NULL], 
        
        NULL];
}


- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId 
{
    CameraError error;
    
    // Setup the connection to the camera
    
    error = [self usbConnectToCam:usbLocationId configIdx:0];
    
    if (error != CameraErrorOK) 
    {
        printf("Trying to connect with configuration = 1");
        error = [self usbConnectToCam:usbLocationId configIdx:1];
    }
    
    if (error != CameraErrorOK) 
    {
        printf("Trying to connect with configuration = -1");
        error = [self usbConnectToCam:usbLocationId configIdx:-1];
    }
    
    if (error != CameraErrorOK) 
        return error;
    
    // Get the ID from the camera
    // This will allow more precise idetification of abilities
/*    
    [self reset];
    [self accessRegister:REGISTER_GET_ID];
    
    [self readData:modelID len:4];
    [self reset];
    
    sqModel = [self decodeModelID];
    sqModelName = [self getModelName];
*/    
    // Set some default parameters
    
    [self setBrightness:0.5];
    [self setContrast:0.5];
    [self setSaturation:0.5];
    [self setSharpness:0.5];
    [self setGamma: 0.5];
    
    // Do the remaining, usual connection stuff
    
    error = [super startupWithUsbLocationId:usbLocationId];
    
    return error;
}


/////////////////////////////////////////////
//
//  Digital Still Camera (DSC) functionality
//
/////////////////////////////////////////////


- (BOOL) canStoreMedia 
{
    return NO;
}


@end
