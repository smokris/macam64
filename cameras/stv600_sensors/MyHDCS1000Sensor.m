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


#import "MyHDCS1000Sensor.h"
#import "MyQCExpressADriver.h"

#define HDCS_STATUS		0x01*2
#define HDCS_IMASK		0x02*2
#define HDCS_PCTRL		0x03*2
#define HDCS_PDRV		0x04*2
#define HDCS_ICTRL		0x05*2
#define HDCS_ITMG		0x06*2
#define HDCS_BFRAC		0x07*2	//Semantic difference between 1000 and 1020
#define HDCS_BRATE		0x08*2	
#define HDCS_ADCCTRL		0x09*2
#define HDCS_FWROW		0x0a*2
#define HDCS_FWCOL		0x0b*2
#define HDCS_LWROW		0x0c*2
#define HDCS_LWCOL		0x0d*2
#define HDCS_TCTRL		0x0e*2
#define HDCS_ERECPGA		0x0f*2
#define HDCS_EROCPGA		0x10*2
#define HDCS_ORECPGA		0x11*2
#define HDCS_OROCPGA		0x12*2
#define HDCS_ROWEXPL		0x13*2
#define HDCS_ROWEXPH		0x14*2
#define HDCS1000_SROWEXPL	0x15*2
#define HDCS1000_SROWEXPH	0x16*2
#define HDCS1020_SROWEXP	0x15*2
#define HDCS1020_ERROR		0x16*2

@implementation MyHDCS1000Sensor

- (id) initWithCamera:(MyQCExpressADriver*)cam {
    self=[super initWithCamera:cam];
    if (!self) return NULL;
    bytePerRegister=1;
    i2cSensorAddress=0xaa;
    reg23Value=0;
    i2cIdentityRegister=1;
    i2cIdentityValue=0x08;
    configCmd=0x2e;
    controlCmd=0x30;
    xStart=4;
    exposure=250;
    gain=1;
    return self;
}

- (BOOL) resetSensor {
    BOOL ok=YES;

    [camera writeSTVRegister:0x0423 value:1];
    [camera writeSTVRegister:0x0423 value:0];

    [self resetI2CSequence];
    [self addI2CRegister:controlCmd value:1];
    ok=ok&&[self writeI2CSequence];
    [self addI2CRegister:controlCmd value:0];
    ok=ok&&[self writeI2CSequence];

    [self addI2CRegister:HDCS_IMASK value:0];
    ok=ok&&[self writeI2CSequence];

    //gain (start value)
    [self addI2CRegister:HDCS_ERECPGA value:gain];
    [self addI2CRegister:HDCS_EROCPGA value:gain];
    [self addI2CRegister:HDCS_ORECPGA value:gain];
    [self addI2CRegister:HDCS_OROCPGA value:gain];
    ok=ok&&[self writeI2CSequence];

    [camera writeSTVRegister:0x1500 value:0x1d];
    [camera writeSTVRegister:0x1504 value:0x07];
    [camera writeSTVRegister:0x1503 value:0x95];

    [camera writeSTVRegister:0x0423 value:0x00];

    //window
    [self addI2CRegister:HDCS_FWROW value:0x02];
    [self addI2CRegister:HDCS_FWCOL value:xStart];	
    [self addI2CRegister:HDCS_LWROW value:0x4c];	
    [self addI2CRegister:HDCS_LWCOL value:xStart+0x57];
    ok=ok&&[self writeI2CSequence];

    [self addI2CRegister:HDCS_TCTRL value:0x14];	//down to 0x06??
    ok=ok&&[self writeI2CSequence];

    //exposure (start value)
    [self addI2CRegister:HDCS_ROWEXPL value:exposure&0xff];
    [self addI2CRegister:HDCS_ROWEXPH value:exposure>>8];
    ok=ok&&[self writeI2CSequence];

    [camera writeSTVRegister:0x1501 value:0xb5];	//???
    [camera writeSTVRegister:0x1502 value:0xa8];	//???

    [self addI2CRegister:HDCS_PCTRL value:0x63];
    [self addI2CRegister:HDCS_PDRV value:0xff];
    [self addI2CRegister:HDCS_ICTRL value:0x20];
    [self addI2CRegister:HDCS_ITMG value:0x11];
    [self addI2CRegister:configCmd value:0x08];
    ok=ok&&[self writeI2CSequence];

    //adc fidelity
    [self addI2CRegister:HDCS_ADCCTRL value:0x0a];
    ok=ok&&[self writeI2CSequence];

    return ok;

}

- (BOOL) startStream {
    BOOL ok=YES;
    [self resetI2CSequence];
    [self addI2CRegister:controlCmd value:0x04];	//switch streaming on
    ok=[self writeI2CSequence];
    return ok;
}

- (BOOL) stopStream {
    BOOL ok=YES;
    [self resetI2CSequence];
    [self addI2CRegister:controlCmd value:0x00];	//switch streaming off
    ok=[self writeI2CSequence];
    return ok;
}

- (void) adjustExposure {
    BOOL ok=YES;
    short newExposure,newGain,expCorr,maxExposure,maxGain;
    if ([camera isAutoGain]) {	//Do AEC

/*The AEC plot: Try gain as low as possible:

Situation:	Dark			Medium			Bright
Exposure:	long			long			short
Gain:		high			low			low

*/
        maxExposure=288;
        maxGain=127;
        newExposure=exposure;		//Start from current situation        
        newGain=gain;			//Start from current situation        

        expCorr=(lastMeanBrightness-0.45f)*-50.0f;
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
        newGain=[camera gain]*127.0f;
    }

    if (newExposure!=exposure) {
        exposure=newExposure;
        [self resetI2CSequence];
        [self addI2CRegister:HDCS_ROWEXPH value:exposure>>8];
        [self addI2CRegister:HDCS_ROWEXPL value:exposure&0xff];
        ok=ok&&[self writeI2CSequence];
    }
    if (newGain!=gain) {
        gain=newGain;
        [self resetI2CSequence];
        [self addI2CRegister:HDCS_ERECPGA value:gain];
        [self addI2CRegister:HDCS_EROCPGA value:gain];
        [self addI2CRegister:HDCS_ORECPGA value:gain];
        [self addI2CRegister:HDCS_OROCPGA value:gain];
        ok=ok&&[self writeI2CSequence];
    }
}






@end
