/*
 MyVV6410Sensor.m - Sensor driver for QuickCams
 
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

#define VV6410_IDENT		0x00
#define VV6410_STATUS		0x02
#define VV6410_IMASK		0x04
#define VV6410_REG06 		0x06
#define VV6410_REG08 		0x08
#define VV6410_REG0A 		0x0a
#define VV6410_REG0C 		0x0c
#define VV6410_REG0E 		0x0e
#define VV6410_SETUP_0 		0x10	//Bits: 0:Low power 2:Soft reset 
#define VV6410_SETUP_1 		0x11
#define VV6410_ADC_BITS		0x12
#define VV6410_FG_MODES		0x14
#define VV6410_PIN_MAPPING	0x15	//Bits: 5:RESETB low-active
#define VV6410_DATA_FORMAT	0x16
#define VV6410_OP_FORMAT	0x17
#define VV6410_MODE_SELECT	0x18
#define VV6410_INTEGRATE	0x1c
#define VV6410_FEXP_H		0x20	//fine exposure (pixel time) value
#define VV6410_FEXP_L		0x21
#define VV6410_CEXP_H		0x22	//coarse exposure (line time) value
#define VV6410_CEXP_L		0x23
#define VV6410_GAIN  		0x24	//gain is 0..12. Add 0xf0.
#define VV6410_CLK_DIV 		0x25
#define VV6410_SHUTTERL 	0x26
#define VV6410_SHUTTERH 	0x28
#define VV6410_REG2A  		0x2a
#define VV6410_REG2C  		0x2c
#define VV6410_CONFIG  		0x2e
#define VV6410_REG32  		0x32
#define VV6410_REG34  		0x34
#define VV6410_REG36  		0x36
#define VV6410_REG38  		0x38
#define VV6410_STARTX_H		0x57
#define VV6410_STARTX_L		0x58
#define VV6410_STARTY_H	 	0x59
#define VV6410_STARTY_L	 	0x5a
#define VV6410_WIDTH_H 		0x52	//Line length in pixel clocks
#define VV6410_WIDTH_L 		0x53
#define VV6410_HEIGHT_H		0x61
#define VV6410_HEIGHT_L		0x62
#define VV6410_AS0		0x77
#define VV6410_AT0		0x78
#define VV6410_AT1		0x79

#import "MyVV6410Sensor.h"
#import "MyQCExpressADriver.h"

@implementation MyVV6410Sensor

- (id) initWithCamera:(MyQCExpressADriver*)cam {
    self=[super initWithCamera:cam];
    if (!self) return NULL;
    bytePerRegister=1;
    i2cSensorAddress=0x20;
    reg23Value=5;
    i2cIdentityRegister=0;
    i2cIdentityValue=0x19;
    gain=10;
    exposure=192;
    return self;
}

- (BOOL) resetSensor {
    BOOL ok=YES;
    if (ok) ok=[camera writeSTVRegister:0x0423 value:0x05];

    if (ok) ok=[camera writeSTVRegister:0x1423 value:0x04];
    if (ok) ok=[camera writeSTVRegister:0x1500 value:0x1b];

    if (ok) {
        [self resetI2CSequence];
        [self addI2CRegister:VV6410_SETUP_0 	value:0x04];	//Soft reset trigger
        ok=[self writeI2CSequence];
    }

    if (ok) {
        [self resetI2CSequence];
        [self addI2CRegister:VV6410_SETUP_0	value:0x00];	//Set to CIF / 25 fps (QCIF:0xc0)
        ok=[self writeI2CSequence];
    }

    //What's this good for ??? ***
    if (ok) ok=[camera writeSTVRegister:0x1504 value:0x07];
    if (ok) ok=[camera writeSTVRegister:0x1503 value:0x45];

/* Setup sensor rect - not necessary, already set by setup0
 if (ok) {
        int x=1;
        int y=1;
        int width=415;
        int height=319;
        [self resetI2CSequence];
        [self addI2CRegister:VV6410_STARTX_H	value:(x>>8)&0xff];
        [self addI2CRegister:VV6410_STARTX_L	value:x%0xff];
        [self addI2CRegister:VV6410_STARTY_H	value:(y>>8)&0xff];
        [self addI2CRegister:VV6410_STARTY_L	value:y%0xff];
        [self addI2CRegister:VV6410_WIDTH_H	value:(width>>8)&0xff];
        [self addI2CRegister:VV6410_WIDTH_L	value:width%0xff];
        [self addI2CRegister:VV6410_HEIGHT_H	value:(height>>8)&0xff];
        [self addI2CRegister:VV6410_HEIGHT_L	value:height%0xff];
        ok=[self writeI2CSequence];
    }
*/
    if (ok) {
        //Gain, exposure and timing
        [self resetI2CSequence];
        [self addI2CRegister:VV6410_FEXP_H	value:0x01];
        [self addI2CRegister:VV6410_FEXP_L	value:0x80];
        [self addI2CRegister:VV6410_CEXP_H	value:(exposure>>8)&0xff];
        [self addI2CRegister:VV6410_CEXP_L	value:(exposure)&0xff];
        [self addI2CRegister:VV6410_GAIN	value:0xf0+gain];
        [self addI2CRegister:VV6410_CLK_DIV	value:0x00];
        ok=[self writeI2CSequence];
    }

    if (ok) ok=[camera writeSTVRegister:0x1501 value:0xb7];	//???
    if (ok) ok=[camera writeSTVRegister:0x1502 value:0xa7];	//???

    if (ok) {
        //Various settings
        [self resetI2CSequence];
        [self addI2CRegister:VV6410_SETUP_1	value:0x58];	//Immediate gain & clock rate updates
        [self addI2CRegister:VV6410_FG_MODES	value:0x55];
        [self addI2CRegister:VV6410_PIN_MAPPING	value:0x10];
        [self addI2CRegister:VV6410_DATA_FORMAT	value:0x81];
        [self addI2CRegister:VV6410_OP_FORMAT	value:0x18];
        [self addI2CRegister:VV6410_MODE_SELECT	value:0x00];
        [self addI2CRegister:VV6410_AS0		value:0x5e];
        [self addI2CRegister:VV6410_AT0		value:0x04];
        [self addI2CRegister:VV6410_AT1		value:0x11];	//Audio! Only for QC web!
        ok=[self writeI2CSequence];
    }

    return ok;
}

- (BOOL) startStream {
    BOOL ok=YES;


    [self resetI2CSequence];
    [self addI2CRegister:VV6410_SETUP_0	value:0x00];	//0xc0 for QCIF
    if (ok) ok=[self writeI2CSequence];
    return ok;
}

- (BOOL) stopStream {
    BOOL ok=YES;
    
    [self resetI2CSequence];
    [self addI2CRegister:VV6410_SETUP_0	value:0x02];	//0xc2 for QCIF
    if (ok) ok=[self writeI2CSequence];
    return ok;
}

- (void) adjustExposure {
    BOOL ok=YES;
    short newExposure,newGain;
    short maxExposure=288;
    short maxGain=12;
    
    if ([camera isAutoGain]) {	//Do AEC

            /*The AEC plot: Try gain as low as possible:

Situation:	Dark			Medium			Bright
Exposure:	long			long			short
Gain:		high			low			low

            */

        short expCorr=(lastMeanBrightness-0.45f)*-50.0f;
        
        newExposure=exposure;		//Start from current situation
        newGain=gain;			//Start from current situation

        if (expCorr>0) expCorr=MAX(0,expCorr-3);
        else if (expCorr<0) expCorr=MIN(0,expCorr+3);

        if (expCorr>0) {	//too dark - need to lighten up
            if (newExposure<maxExposure) {
                newExposure=MIN(maxExposure,newExposure+expCorr);
            } else {
                newGain=MIN(maxGain,newGain+(expCorr)/4+1);
            }
        } else if (expCorr<0) {	//too bright - need to darken
            if (newGain>0) {
                newGain=MAX(0,newGain+(expCorr/4)-1);
            } else {
                newExposure=MAX(0,newExposure+expCorr);
            }
        }
    } else {
        newExposure=[camera shutter]*286.0f+1.0f;
        newGain=[camera gain]*12.0f;	//Real max is 14, but 12 is recommended as max
    }
    
    if ((newExposure!=exposure)||(newGain!=gain)) {
        exposure=newExposure;
        gain=newGain;
        [self resetI2CSequence];
        [self addI2CRegister:VV6410_GAIN value:0xf0+gain];
        [self addI2CRegister:VV6410_CEXP_H value:(exposure>>8)&0xff];
        [self addI2CRegister:VV6410_CEXP_L value:exposure&0xff];
        ok=ok&&[self writeI2CSequence];
    }
}

@end
