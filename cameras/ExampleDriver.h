//
//  ExampleDriver.h
//
//  macam - webcam app and QuickTime driver component
//  ExampleDriver - an example to show how to implement a macam driver
//
//  Created by hxr on 3/21/06.
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

/*
 Here is the simplest way of adding a driver to macam:
 - Copy the ExampleDriver.[h|m] files 
 - Rename them to something that makes sense for your camera or chip
 - Fill in the methods with the information specific to your camera
 - Add your driver to MyCameraCentral
 That's it!
 
 OK, so some of the information you need to write the methods can be hard 
 to come by, but at least this example shows you exactly what you need.
 */

#import <GenericDriver.h>

@interface ExampleDriver : GenericDriver 
{
    // Add any data structure that you need to keep around
    // i.e. decoding buffers, decoding structures etc
}

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral: (id) c;

- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate;
- (CameraResolution) defaultResolutionAndRate: (short *) rate;

- (UInt8) getGrabbingPipe;
- (BOOL) setGrabInterfacePipe;
- (void) setIsocFrameFunctions;

- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;

- (void) decodeBuffer: (GenericChunkBuffer *) buffer;

@end
