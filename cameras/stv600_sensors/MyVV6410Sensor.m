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

#define VV6410_IDENT		0x00
#define VV6410_STATUS		0x02
#define VV6410_IMASK		0x04
#define VV6410_REG06 		0x06
#define VV6410_REG08 		0x08
#define VV6410_REG0A 		0x0a
#define VV6410_REG0C 		0x0c
#define VV6410_REG0E 		0x0e
#define VV6410_CONTROL 		0x10
#define VV6410_ADC_BITS		0x12
#define VV6410_INTEGRATE	0x1c
#define VV6410_GAIN  		0x24
#define VV6410_SHUTTERL 	0x26
#define VV6410_SHUTTERH 	0x28
#define VV6410_REG2A  		0x2a
#define VV6410_REG2C  		0x2c
#define VV6410_CONFIG  		0x2e
#define VV6410_REG32  		0x32
#define VV6410_REG34  		0x34
#define VV6410_REG36  		0x36
#define VV6410_REG38  		0x38
#define VV6410_STARTX		0x57
#define VV6410_STARTY	 	0x59
#define VV6410_WIDTH  		0x52
#define VV6410_HEIGHT 		0x61


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
    return self;
}

- (BOOL) resetSensor {
    BOOL ok=YES;
    if (ok) ok=[camera writeSTVRegister:0x0423 value:0x05];

/*
    if (!isaweb(dev)) {
        if (usb_quickcam_set1(dev, 0x1446, 1) < 0) goto error;
    }	
*/

    if (ok) ok=[camera writeSTVRegister:0x1423 value:0x04];
    if (ok) ok=[camera writeSTVRegister:0x1500 value:0x1b];

    if (ok) {
        [self resetI2CSequence];
        [self addI2CRegister:VV6410_CONTROL value:0x04];
        ok=[self writeI2CSequence];
    }
    //Control: Web CIF: 0x02, Web QCIF: 0xa2, Express CIF:0x02, Express QCIF 0xc2
    if (ok) {
        [self resetI2CSequence];
        [self addI2CRegister:VV6410_CONTROL value:0x02];
        ok=[self writeI2CSequence];
    }

    if (ok) {
        [self resetI2CSequence];
        [self addI2CRegister:VV6410_GAIN value:0xfb];
        ok=[self writeI2CSequence];
    }

    if (ok) ok=[camera writeSTVRegister:0x1504 value:0x07];

    if (ok) ok=[camera writeSTVRegister:0x1503 value:0x45];

    /* set window size
    if (vv6410_set_window(dev,0,0,48,64,sensor_ctrl) < 0) {
        printk(KERN_ERR "vv6410_set_window failed");
        goto error;
    }
 */

    if (ok) {
        [self resetI2CSequence];
        [self addI2CRegister:0x20 value:0x01];	//0x00 for QCIF
        [self addI2CRegister:0x21 value:0x89];	//0xe3 for QCIF
        [self addI2CRegister:0x22 value:0x01];	//0x00 for QCIF
        [self addI2CRegister:0x23 value:0x3e];	//0x9e for QCIF
        [self addI2CRegister:0x24 value:0xfa];
        [self addI2CRegister:0x25 value:0x01];
        ok=[self writeI2CSequence];
    }

    if (ok) ok=[camera writeSTVRegister:0x1501 value:0xb7];	//???
    if (ok) ok=[camera writeSTVRegister:0x1502 value:0xa7];	//???

    if (ok) {
        [self resetI2CSequence];
        [self addI2CRegister:0x11 value:0x18];
        [self addI2CRegister:0x14 value:0x55];
        [self addI2CRegister:0x15 value:0x10];
        [self addI2CRegister:0x16 value:0x81];
        [self addI2CRegister:0x17 value:0x18];
        [self addI2CRegister:0x18 value:0x00];
        [self addI2CRegister:0x77 value:0x5e];
        [self addI2CRegister:0x78 value:0x04];
        [self addI2CRegister:0x79 value:0x11];	//Audio! Only for QC web!
        ok=[self writeI2CSequence];
    }

    return ok;
}

- (BOOL) startStream {
    BOOL ok=YES;

    //        if (usb_quickcam_set1(dev, 0x1445, 1) < 0) //led
    [self resetI2CSequence];
    [self addI2CRegister:VV6410_CONTROL value:0x00];	//0xc0 for QCIF
    if (ok) ok=[self writeI2CSequence];
    return ok;
}

- (BOOL) stopStream {
    BOOL ok=YES;
    
    [self resetI2CSequence];
    [self addI2CRegister:VV6410_CONTROL value:0x02];	//0xc2 for QCIF
    if (ok) ok=[self writeI2CSequence];
    return ok;
}

- (void) adjustExposure {
}

@end
