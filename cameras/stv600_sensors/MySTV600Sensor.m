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



#import "MySTV600Sensor.h"
#import "MyQCExpressADriver.h"
#import "MyQCWebDriver.h"


@implementation MySTV600Sensor

- (id) initWithCamera:(MyQCExpressADriver*)cam {
    self=[super init];
    if (!self) return NULL;
    self->camera=cam;
    bytePerRegister=-1;
    i2cSensorAddress=-1;
    reg23Value=-1;
    i2cIdentityRegister=-1;
    i2cIdentityValue=-1;
    return self;
}

- (BOOL) checkSensor {
    BOOL ok=YES;
    unsigned short sensorID;
    NSAssert(bytePerRegister>0,@"Your subclass of MySTV600Sensor must set bytePerRegister on init");
    NSAssert(i2cSensorAddress>=0,@"Your subclass of MySTV600Sensor must set i2cSensorAddress on init");
    NSAssert(reg23Value>=0,@"Your subclass of MySTV600Sensor must set reg23Value on init");
    NSAssert(i2cIdentityRegister>=0,@"Your subclass of MySTV600Sensor must set i2cIdentityRegister on init");
    NSAssert(i2cIdentityValue>=0,@"Your subclass of MySTV600Sensor must set i2cIdentityValue on init");

    [camera writeSTVRegister:0x0423 value:reg23Value];
    ok=[self readI2CRegister:i2cIdentityRegister to:&sensorID];
    if (!ok) return NO;
    if (sensorID!=i2cIdentityValue) return NO;	//It's not our sensor...
    //Remote debugging: Give out the sensor and camera class to the console
    NSLog(@"Found image sensor of class:%@, camera of class:%@",
        NSStringFromClass([self class]),
        NSStringFromClass([camera class]));
    return YES;
}

- (BOOL) resetSensor {
    NSAssert(0,@"Your subclass of MySTV600Sensor must override resetSensor");
    return NO;
}

- (BOOL) startStream {
    NSAssert(0,@"Your subclass of MySTV600Sensor must override startStream");
    return NO;
}

- (BOOL) stopStream {
    NSAssert(0,@"Your subclass of MySTV600Sensor must override stopStream");
    return NO;
}
- (void) adjustExposure {
    NSAssert(0,@"Your subclass of MySTV600Sensor must override adjustExposure");
}

- (void) setLastMeanBrightness:(float)brightness {
    lastMeanBrightness=brightness;
}

- (void) resetI2CSequence {
    i2cBuf[0x21]=0;
}

- (void) addI2CRegister:(unsigned char)reg value:(unsigned short)val {
    BOOL twoByte=(bytePerRegister==2);
    i2cBuf[i2cBuf[0x21]]=reg;
    if (twoByte) {
        i2cBuf[2*i2cBuf[0x21]+0x10]=val&0xff;
        i2cBuf[2*i2cBuf[0x21]+0x11]=(val>>8)&0xff;
    } else {
        i2cBuf[i2cBuf[0x21]+0x10]=val;
    }
    i2cBuf[0x21]++;
}

- (BOOL) writeI2CSequence {
    BOOL ok=YES;
    i2cBuf[0x20]=i2cSensorAddress;
    if (i2cBuf[0x21]>0) {
        i2cBuf[0x21]--;
        i2cBuf[0x22]=1;
        ok=[camera usbWriteCmdWithBRequest:4 wValue:0x0400 wIndex:0 buf:i2cBuf len:35];
    }
    i2cBuf[0x21]=0;
    //The QuickCam Web needs to send a message to propagate the i2c registers
    if ([camera isKindOfClass:[MyQCWebDriver class]]) {
        ok=ok&&[camera writeSTVRegister:0x1704 value:1];
    }
    return ok;
}

- (BOOL) readI2CRegister:(unsigned char)reg to:(unsigned short*)val {
    BOOL ok=YES;
    BOOL twoByte=(bytePerRegister==2);
    i2cBuf[0x00]=reg;
    i2cBuf[0x20]=i2cSensorAddress;
    i2cBuf[0x21]=0;
    i2cBuf[0x22]=3;
    ok=[camera usbWriteCmdWithBRequest:4 wValue:0x0400 wIndex:0 buf:i2cBuf len:35];
    if (!ok) return NO;
    if (!val) return NO;
    *val=0;
    if (twoByte) {
        ok=[camera usbReadCmdWithBRequest:4 wValue:0x1410 wIndex:0 buf:val len:2];
    } else {
        ok=[camera usbReadCmdWithBRequest:4 wValue:0x1410 wIndex:0 buf:val len:2];
        *val/=256;
    }
    *val=*val&0xff;
    return ok;
}


@end
