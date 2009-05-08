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


// look at http://gkall.hobby.nl/sq930x.html
// enough info there to get going

// SQ930B - CCD and CMOS
// SQ930C - CMOS only

// 0x041e:0x4038  Creative Live! Pro
// 0x041e:0x403c  Creative Live! Ultra
// 0x041e:0x403d  Creative Live! Ultra for Notebooks
// 0x041e:0x????  Creative Live! Cam for Notebooks Pro
// 0x041e:0x4038  Joy-IT 318S Live! Pro
// 0x????:0x????  Trust WB-3500T
// 0x????:0x????  Intertec Components GmbH ITM-PCS 20-
// 0x2770:0x930c  TECOM	318S-H (NHJ); NGS Robbie 2.0


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
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x403c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Webcam Live! Ultra (VF0060)", @"name", NULL], 
        
        NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    driverType = bulkDriver;
    
    compressionType = quicktimeImage;  // Does some error checking on image
    quicktimeCodec = kJPEGCodecType;

	return self;
}


- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionVGA:
            if (rate > 30) 
                return NO;
            return YES;
            break;
            
        case ResolutionSIF:
            if (rate > 30) 
                return NO;
            return YES;
            break;
            
        default: 
            return NO;
    }
}


- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 30;
    
	return ResolutionVGA;
}


@end
