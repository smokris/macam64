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

@class MyQCExpressADriver;

@interface MySTV600Sensor : NSObject {
    MyQCExpressADriver* camera;		//The reference to our camera
    unsigned char i2cBuf[35];		//The buffer for i2c-over-usb communicatiion
    short bytePerRegister;		//should be set to 1 or 2 depending on the size of transferred i2c registers
    short i2cSensorAddress;		//The i2c address of the sensor
//Values for matching the sensor
    short reg23Value;			//The setting for the STV600 register 23 for this sensor
    short i2cIdentityRegister;		//The i2c register to read for identity checking
    short i2cIdentityValue;		//The value the read should result if the sensor is there

    float lastMeanBrightness;		//The last brightness reported from outside. Is used for auto exposure.
}

- (id) initWithCamera:(MyQCExpressADriver*)cam;

- (BOOL) checkSensor;	//Tests if the sensor is there and inits internals if yes.

- (BOOL) resetSensor;	//Sets the sensor to defaults for grabbing - to be called before grabbing starts
- (BOOL) startStream;	//Starts up data delivery from the sensor
- (BOOL) stopStream;	//Stops data delivery from the sensor
- (void) adjustExposure;//Sets the camera exposure according to gain, shutter, autoGain etc.
- (void) setLastMeanBrightness:(float)brightness;	//Accept the last brightness value
//USB level communication - should not be called from outsidee
- (void) resetI2CSequence;
- (void) addI2CRegister:(unsigned char)reg value:(unsigned short)val;
- (BOOL) writeI2CSequence;
- (BOOL) readI2CRegister:(unsigned char)reg to:(unsigned short*)val;
@end
