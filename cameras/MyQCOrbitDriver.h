/*
 MyQCOrbitDriver.h
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

#import <Cocoa/Cocoa.h>
#import "MyKiaraFamilyDriver.h"

/*
 This source code is directly inspired by pwc driver
 */

#define SET_MPT_CTL                         0x0D
#define PT_RELATIVE_CONTROL_FORMATTER		0x01
#define PT_RESET_CONTROL_FORMATTER          0x02

/*
 QuickCam Orbit/Sphere is electronicaly the same as QuickCam Pro 4000.
 It has two engines it make it pan and tilt.
 */

@interface MyQCOrbitDriver : MyKiaraFamilyDriver {

}

+ (NSArray*) cameraUsbDescriptions;

- (BOOL) supportsCameraFeature:(CameraFeature)feature;
- (id) valueOfCameraFeature:(CameraFeature)feature;

- (void) rotate:(int)deltapan :(int)deltatilt;
- (void) center;

@end
