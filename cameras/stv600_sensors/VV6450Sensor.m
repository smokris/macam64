//
//  VV6450Sensor.m
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

#define VV6450_IDENT		0xe00a
#define VV6450_STATUS		0x02
#define VV6450_IMASK		0x04
#define VV6450_REG06 		0x06
#define VV6450_REG08 		0x08
#define VV6450_REG0A 		0x0a
#define VV6450_REG0C 		0x0c
#define VV6450_REG0E 		0x0e
#define VV6450_SETUP_0 		0x10	//Bits: 0:Low power 2:Soft reset 
#define VV6450_SETUP_1 		0x11
#define VV6450_ADC_BITS		0x12
#define VV6450_FG_MODES		0x14
#define VV6450_PIN_MAPPING	0x15	//Bits: 5:RESETB low-active
#define VV6450_DATA_FORMAT	0x16
#define VV6450_OP_FORMAT	0x17
#define VV6450_MODE_SELECT	0x18
#define VV6450_INTEGRATE	0x1c

#define VV6450_FEXP_H		0x20	//fine exposure (pixel time) value
#define VV6450_FEXP_L		0x21
#define VV6450_CEXP_H		0x22	//coarse exposure (line time) value
#define VV6450_CEXP_L		0x23
#define VV6450_GAIN  		0x24	//gain is 0..12. Add 0xf0.
#define VV6450_CLK_DIV 		0x25
#define VV6450_SHUTTERL 	0x26
#define VV6450_SHUTTERH 	0x28
#define VV6450_REG2A  		0x2a
#define VV6450_REG2C  		0x2c
#define VV6450_CONFIG  		0x2e
#define VV6450_REG32  		0x32
#define VV6450_REG34  		0x34
#define VV6450_REG36  		0x36
#define VV6450_REG38  		0x38

#define VV6450_WIDTH_H 		0x52	//Line length in pixel clocks
#define VV6450_WIDTH_L 		0x53
#define VV6450_STARTX_H		0x57
#define VV6450_STARTX_L		0x58
#define VV6450_STARTY_H	 	0x59
#define VV6450_STARTY_L	 	0x5a
#define VV6450_HEIGHT_H		0x61
#define VV6450_HEIGHT_L		0x62

#define VV6450_BLACKOFFSET_H	0x70
#define VV6450_BLACKOFFSET_L	0x71
#define VV6450_BLACKOFFSET_SETUP	0x72
#define VV6450_CR0		0x75
#define VV6450_CR1		0x76
#define VV6450_AS0		0x77
#define VV6450_AT0		0x78
#define VV6450_AT1		0x79

#import "VV6450Sensor.h"

#import "MyQCExpressADriver.h"
#import "MyQCWebDriver.h"


@interface VV6450Sensor (Private)
- (BOOL) writeGain:(short)value;
- (BOOL) writeExposure:(short)value;
@end

@implementation VV6450Sensor

- (id) initWithCamera:(MyQCExpressADriver*)cam {
    self = [super initWithCamera:cam];
    if (!self) return NULL;
    bytePerRegister = 1;
    i2cSensorAddress = -1; // not used
    reg23Value = -1; // not used
    i2cIdentityRegister = VV6450_IDENT;
    i2cIdentityValue = 0x08;
    gain = 10;
    exposure = 192;
	rawGainValue = 0x38;
	rawExposureValue = 0xf9;
    return self;
}

- (BOOL) checkSensor {
#if 0 // We don't use reg23Value & I2C
    BOOL ok = YES;
    short sensorID;
    [camera writeSTVRegister:0x0423 value:reg23Value];

    ok = [self readI2CRegister:i2cIdentityRegister to:&sensorID];
    if (!ok) return NO;
    if (sensorID != i2cIdentityValue) return NO;	//It's not our sensor...
#endif

    //Remote debugging: Give out the sensor and camera class to the console
    NSLog(@"Found image sensor of class:%@, camera of class:%@",
          NSStringFromClass([self class]),
          NSStringFromClass([camera class]));
    return YES;
}

- (BOOL) resetSensor {
    BOOL ok = YES;

    ok = [self stopStream];
	if (ok) ok = [self writeGain:0x003f];
	if (ok) ok = [self writeExposure:0x00fe];

	//exposure and gain
	[self adjustExposure];

    if (ok) ok = [camera writeSTVRegister:0x143f value:0x01]; //commit settings

    return ok;
}

- (BOOL) startStream {
    BOOL ok = YES;
	DEBUGLOG(@"startStream:");
    ok = [camera writeSTVRegister:0x1440 value:0x01];
    return ok;
}

- (BOOL) stopStream {
    BOOL ok = YES;
	DEBUGLOG(@"stopStream:");
    ok = [camera writeSTVRegister:0x1440 value:0x00];
    return ok;
}

- (void) adjustExposure {
    BOOL ok = YES;
    short newExposure, newGain;
    short maxExposure = 14 << 4;
    short maxGain = 15;
    
    if ([camera isAutoGain]) {	//Do AEC

            /*The AEC plot: Try gain as low as possible:

Situation:	Dark			Medium			Bright
Exposure:	long			long			short
Gain:		high			low			low

            */

        short expCorr = (lastMeanBrightness - 0.45f) * -50.0f;
        
        newExposure = exposure;		//Start from current situation
        newGain = gain;			//Start from current situation

        if (expCorr > 0) expCorr = MAX(0, expCorr - 3);
        else if (expCorr < 0) expCorr = MIN(0, expCorr + 3);

        if (expCorr > 0) {	//too dark - need to lighten up
            if (newExposure < maxExposure) {
                newExposure = MIN(maxExposure, newExposure + expCorr);
            } else {
                newGain = MIN(maxGain, newGain + (expCorr) / 4 + 1);
            }
        } else if (expCorr < 0) {	//too bright - need to darken
            if (newGain > 0) {
                newGain = MAX(0, newGain + (expCorr / 4) - 1);
            } else {
                newExposure = MAX(0, newExposure + expCorr);
            }
        }
    } else {
        newExposure = [camera shutter] * 210.0f + 14.0f;
        newGain = [camera gain] * 14.0f + 1.0f;
    }
    
    if (newExposure != exposure || newGain != gain) {
        exposure = newExposure;
        gain = newGain;
		ok = [self writeGain:gain];
		if (!ok) NSLog(@"setGain failed: %d", gain);
		ok = [self writeExposure:(exposure >> 4)];
		if (!ok) NSLog(@"setExposure failed: %d", (exposure >> 4));
    }
}

- (BOOL) writeGain:(short)value {
	BOOL ok = YES;
	unsigned char g;

    g = value | 0x30;

	if (g == rawGainValue) return YES;

	rawGainValue = g;
	DEBUGLOG(@"writeGain: 0x%02x", g & 0x00ff);
    if (ok) ok = [camera writeSTVRegister:0x0509 value:g];
    if (ok) ok = [camera writeSTVRegister:0x050A value:g];
    if (ok) ok = [camera writeSTVRegister:0x050B value:g];
    if (ok) ok = [camera writeSTVRegister:0x050D value:0x01];
    if (ok) ok = [camera writeSTVRegister:0x143f value:0x01]; //commit settings
	return ok;
}

- (BOOL) writeExposure:(short)value {
	BOOL ok = YES;
	unsigned char a = value;

	a = MIN(a, 14) | 0x00f0;

	if (a == rawExposureValue) return YES;

	rawExposureValue = a;
	DEBUGLOG(@"writeExposure: 0x%02x", a & 0x00ff);
    if (ok) ok = [camera writeSTVRegister:0x143a value:a];
    if (ok) ok = [camera writeSTVRegister:0x143f value:0x01]; //commit settings
	return ok;
}

- (BOOL) writeI2CSequence {
    BOOL ok = YES;

    NSAssert(i2cSensorAddress >= 0, @"MyVV6450Sensor doesn't support i2cSensorAddress");

    i2cBuf[0x20] = i2cSensorAddress;
    if (i2cBuf[0x21] > 0) {
        i2cBuf[0x21]--;
        i2cBuf[0x22] = 1;
        ok=[camera usbWriteCmdWithBRequest:4 wValue:0x0400 wIndex:0 buf:i2cBuf len:35];
    }
    i2cBuf[0x21] = 0;
    //The QuickCam Web needs to send a message to propagate the i2c registers
    if ([camera isKindOfClass:[MyQCWebDriver class]]) {
        ok = ok && [camera writeSTVRegister:0x1704 value:1];
    }
    return ok;
}

- (BOOL) readI2CRegister:(unsigned char)reg to:(unsigned short*)val {
    BOOL ok = YES;

    NSAssert(i2cSensorAddress >= 0, @"MyVV6450Sensor doesn't support i2cSensorAddress");

    BOOL twoByte = (bytePerRegister == 2);
    i2cBuf[0x00] = reg;
    i2cBuf[0x20] = i2cSensorAddress;
    i2cBuf[0x21] = 0;
    i2cBuf[0x22] = 3;
    ok = [camera usbWriteCmdWithBRequest:4 wValue:0x0400 wIndex:0 buf:i2cBuf len:35];
    if (!ok) return NO;
    if (!val) return NO;
    *val = 0;
    if (twoByte) {
        ok = [camera usbReadCmdWithBRequest:4 wValue:0x1410 wIndex:0 buf:val len:2];
    } else {
        ok = [camera usbReadCmdWithBRequest:4 wValue:0x1410 wIndex:0 buf:val len:2];
        *val /= 256;
    }
    *val = *val & 0xff;
    return ok;
}

@end
