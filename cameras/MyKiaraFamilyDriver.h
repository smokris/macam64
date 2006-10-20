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


#import "MyPhilipsCameraDriver.h"


#define WB_MODE_FORMATTER			0x1000


@interface MyKiaraFamilyDriver : MyPhilipsCameraDriver 
{
}

+ (NSArray*) cameraUsbDescriptions;

- (void) dealloc;

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId;

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr;	//Returns if this combination is supported
- (void) setResolution:(CameraResolution)r fps:(short)fr;	//Set a resolution and frame rate.
- (CameraResolution) defaultResolutionAndRate:(short*)fps;
- (void) setLed:(BOOL)v;		// switch LED on/off

- (short) maxCompression;

// White Balance
- (BOOL) canSetWhiteBalanceMode;
- (BOOL) canSetWhiteBalanceModeTo: (WhiteBalanceMode) newMode;
- (void) setWhiteBalanceMode: (WhiteBalanceMode) newMode;

@end


@interface MyKiaraFamilyPowerSaveDriver : MyKiaraFamilyDriver 
{
}

+ (NSArray*) cameraUsbDescriptions;

- (id) initWithCentral: (id) c;

@end
