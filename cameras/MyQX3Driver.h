/*
 macam - webcam app and QuickTime driver component
 
 Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)
 Copyright (C) 2002 Dirk-Willem van Gulik (dirkx@webweaving.org)

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

#import <Cocoa/Cocoa.h>
#import "MyCPIACameraDriver.h"

@interface MyQX3Driver : MyCPIACameraDriver {
    // Functions specific to the Mattel Intel Play Microscope
    //
    BOOL topLight;
    BOOL bottomLight;
    BOOL gpioChanged;
    int lastButt;
    int lastCradle;    
    id changeHandlers; // XX turn into array
}

+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;

// Early init.

// Camera Custom features
// - We have our own inspector
- (BOOL) supportsCameraFeature:(CameraFeature)feature;
- (id) valueOfCameraFeature:(CameraFeature)feature;

// Functions specific to the microscope:
// 	http://webcam.sourceforge.net/docs/qx3_cmd.pdf
//
- (void) setTopLight:(BOOL)v;
- (BOOL) getTopLight;

- (void) setBottomLight:(BOOL)v;
- (BOOL) getBottomLight;

- (BOOL) getCradle;					// True if cradled - False if unseated.

- (void) changedSomething;				// send out GP notify

- (void) doLights;					// Update lights

- (BOOL) startupGrabStream;				// starts camera streaming (turn on the lights)
- (BOOL) shutdownGrabStream;				// Stops camera streaming (turn off the lights)

// Private define of our event channel to the
#define EVENT_QX3_ACHANGE (@"CAMERADRIVER_QX3_aChange")	
@end
