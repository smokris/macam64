//
//  SQ930C.h
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


#import "GenericDriver.h"



@interface SQ930C : GenericDriver 
{
}

// Choose which USB Vendor and Product IDs to activate for
+ (NSArray *) cameraUsbDescriptions;


@end
