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

#import <Cocoa/Cocoa.h>
#import <MySTV600Sensor.h>


@interface MyPB0100Sensor : MySTV600Sensor {
    short shutter;
    short highVoltage;	//Note that this is double the value of the sensor setting (for slower auto exposure)
}

- (id) initWithCamera:(MyQCExpressADriver*)cam;
- (BOOL) resetSensor;	//Sets the sensor to defaults for grabbing - to be called before grabbing starts
- (BOOL) startStream;	//Starts up data delivery from the sensor
- (BOOL) stopStream;	//Stops data delivery from the sensor
- (void) adjustExposure;//Sets the camera exposure according to gain, shutter, autoGain etc.

@end
