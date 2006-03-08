//
//  VV6450Sensor.h
//  macam
//
//  Created by masakazu on Sun May 08 2005.
//  Copyright (c) 2005 masakazu (masa0038@users.sourceforge.net)
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
#import "MyVV6410Sensor.h"

@interface VV6450Sensor : MyVV6410Sensor {
    UInt8 rawGainValue;
    UInt8 rawExposureValue;
}

- (id) initWithCamera:(MyQCExpressADriver*)cam;
- (BOOL) writeI2CSequence;
- (BOOL) readI2CRegister:(unsigned char)reg to:(unsigned short*)val;
- (BOOL) resetSensor;	//Sets the sensor to defaults for grabbing - to be called before grabbing starts
- (BOOL) startStream;	//Starts up data delivery from the sensor
- (BOOL) stopStream;	//Stops data delivery from the sensor
- (void) adjustExposure;//Sets the camera exposure according to gain, shutter, autoGain etc.

@end
