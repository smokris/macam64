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


#import "MyPB0100Sensor.h"
#import "MyQCExpressADriver.h"

#define BEST_LOW_VOLTAGE 0x01
#define BEST_HIGH_VOLTAGE 0x10

@implementation MyPB0100Sensor

- (id) initWithCamera:(MyQCExpressADriver*)cam {
    self=[super initWithCamera:cam];
    if (!self) return NULL;
    bytePerRegister=2;
    i2cSensorAddress=0xba;
    reg23Value=1;
    i2cIdentityRegister=0;
    i2cIdentityValue=0x64;
    return self;
}

- (BOOL) resetSensor {
    BOOL ok=YES;

    // PB0100 reset to default (see sensor docs)
    [self resetI2CSequence];
    [self addI2CRegister:13 value:1];
    ok=[self writeI2CSequence];

    [self addI2CRegister:13 value:0];
    ok=[self writeI2CSequence];

    //Set chip enable to NO to stop streaming
    [self addI2CRegister:7 value:0x28];
    ok=[self writeI2CSequence];


    /* stuff we would do if we wanted the sensor to do automatic exposure control
    [self addI2CRegister:51 value:0xff];	//Max gain [1..255] steps: 0.125
    [self addI2CRegister:52 value:0x01];	//Min gain [1..255]
    [self addI2CRegister:23 value:0x01];	//auto gain speed in frames [1..63] - doesn't matter because we do it ourselves
    ok=[self writeI2CSequence];
    */


// Setup sensor window
    [self addI2CRegister: 1 value:0x000c];
    [self addI2CRegister: 2 value:0x0004];
    [self addI2CRegister: 3 value:0x011f];	
    [self addI2CRegister: 4 value:0x015f];
    ok=[self writeI2CSequence];

//timing for the sensor
    [self addI2CRegister: 5 value:0x0001];	//Almost no horizontal blanking (was 0x2f - why?)
    [self addI2CRegister: 6 value:0x0004];	//No vertical blanking
    [self addI2CRegister: 8 value:0x0000];	//No integration frame time multiplication
    [self addI2CRegister:10 value:0x001a];	//2/3 transfer speed (4 MHz), normal gain processing speed, normal
    ok=[self writeI2CSequence];

//configure gain and lighting specific stuff
    [self addI2CRegister:57 value:0x00];	//adc voltage offset
    [self addI2CRegister:60 value:0x01];	//low adc voltage (constant)
    [self addI2CRegister:14 value:0x00];	//Disable auto gain on the chip - we'll do it ourselves
    [self addI2CRegister:43 value:0x10];	//Green 1 gain (white balance will be done by the bayer converter)
    [self addI2CRegister:44 value:0x10];	//Blue gain
    [self addI2CRegister:45 value:0x10];	//Red gain
    [self addI2CRegister:46 value:0x10];	//Green 2 gain
    ok=[self writeI2CSequence];
    
//initial values for stuff that will be adjusted by white balance, gain, exposure
    shutter=287;
    highVoltage=BEST_HIGH_VOLTAGE*2;
    [self addI2CRegister:59 value:highVoltage/2];	//high adc voltage (will be controlled by our gain function)
    [self addI2CRegister:9 value:shutter];		//Exposure time (will be controlled by our exposure function)
    ok=[self writeI2CSequence];
    return ok;

}

- (BOOL) startStream {
    BOOL ok=YES;
    [self resetI2CSequence];
    [self addI2CRegister:7 value:0x2b];	//switch streaming on
    ok=[self writeI2CSequence];
    return ok;
}

- (BOOL) stopStream {
    BOOL ok=YES;
    [self resetI2CSequence];
    [self addI2CRegister:11 value:0x11];	//switch streaming off
    [self addI2CRegister:7 value:0x28];		//switch streaming off
    ok=[self writeI2CSequence];
    return ok;
}

/* Our auto exposure strategy:

                   very dark		dark		medium		bright		very bright

low voltage		0		0		0		0		0
high voltage		low		medium		medium		medium		high
shutter			full		full		medium		low		low

In short: Try to keep the high voltage (gain) to medium and do everything with the shutter. Only in very bright or dark situations, change the high voltage. Keep the low voltage to zero (people can do that with brightness/contrast)
*/


- (void) adjustExposure {
    short newShutter;
    short newHighVoltage;
    short expCorr;
    if ([camera isAutoGain]) {
        newShutter=shutter;		//We start with the old settings and manipulate them if needed
        newHighVoltage=highVoltage;
        expCorr=(lastMeanBrightness-0.45f)*-15.0f;
        if (expCorr>0) { //We have to make the image brighter
            if (newHighVoltage>BEST_HIGH_VOLTAGE*2) {	//We can lower highVoltage
                newHighVoltage--;
            } else if (newShutter<287) {	//We can extend the shutter time
                newShutter=MIN(287,newShutter+expCorr);
            } else if (newHighVoltage>2*2) {
                newHighVoltage--;
            }
        } else if (expCorr<0) { //We have to make the image darker
            if (newHighVoltage<BEST_HIGH_VOLTAGE*2) {	//We can higher highVoltage
                newHighVoltage++;
            } else if (newShutter>1) {	//We can shorten the shutter time
                newShutter=MAX(1,newShutter+expCorr);
            } else if (newHighVoltage<0x1f*2) {
                newHighVoltage++;
            }
        }
//        NSLog(@"brightness:%f corr:%i shutter:%i voltage:%i",lastMeanBrightness,expCorr,newShutter,newHighVoltage);
    } else {
        newShutter=286.0f*[camera shutter]+1.0f;
        newHighVoltage=30.0f*(1.0f-[camera gain])+1.0f;
        newHighVoltage*=2;
    }
    [self resetI2CSequence];
    if (shutter!=newShutter) [self addI2CRegister:9 value:newShutter];
    if (highVoltage!=newHighVoltage) [self addI2CRegister:59 value:newHighVoltage/2];
    [self writeI2CSequence];
    shutter=newShutter;
    highVoltage=newHighVoltage;
}






@end
