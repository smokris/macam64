/*
 macam - webcam app and QuickTime driver component
 
 Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)
 Copyright (C) 2002 Dirk-Willem van Gulik (dirkx@webweaving.org)

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

#import "MyQX3Driver.h"
#import "MyCameraCentral.h"
#include "MiscTools.h"

/*
o Intel Play QX3 Microscope@2100000  <class IOUSBDevice>
  {
   "bDeviceSubClass" = 0
   "bcdDevice" = 352
   "idVendor" = 2067
   "IOUserClientClass" = "IOUSBDeviceUserClient"
   "USB Vendor Name" = "Mattel Inc."
   "IOGeneralInterest" = ("_IOServiceInterestNotifier is not s$
   "iManufacturer" = 2
   "Device Speed" = 1
   "locationID" = 34603008
   "iProduct" = 1
   "bDeviceProtocol" = 0
   "bDeviceClass" = 0
   "PortNum" = 1
   "idProduct" = 1
   "Bus Power Available" = 250
   "bMaxPacketSize0" = 8
   "USB Address" = 2
   "USB Product Name" = "Intel Play QX3 Microscope"
   "IOCFPlugInTypes" = {"9dc7b780-9ec0-11d4-a54f-000a27052861"$
   "bNumConfigurations" = 1
   "iSerialNumber" = 0
  }
*/

#define VENDOR_MATTEL (2067)
#define PRODUCT_QX3_INTEL (1)

@implementation MyQX3Driver

+ (unsigned short) cameraUsbProductID { 
    return PRODUCT_QX3_INTEL;  // XXX  subclass for QX3+ microscope too.
}

+ (unsigned short) cameraUsbVendorID { 
    return VENDOR_MATTEL; 
}

+ (NSString*) cameraName {
    return [MyCameraCentral localizedStringFor:@"Intel Play QX3 Microscope"];
}

// Port 2 - bit3 Top light
- (void) setTopLight:(BOOL)v {
    topLight = v;
    gpioChanged = TRUE;
}

// Port 2 - bit1 Bottom light
- (void) setBottomLight:(BOOL)v {
    bottomLight = v;
    gpioChanged = TRUE;
}

// Need to wrap this into a stage engine to avoid
// needless setGPIOs.
//
- (void) doLights {
    unsigned char ov = (topLight ? 0 : 8) + (bottomLight ? 0 : 2);
    [super setGPIO:2 and:(0xFF - 2 - 8) or:ov];
    gpioChanged = FALSE;
}

- (BOOL) getCradle {
    return (lastCradle == 0);
}

- (BOOL) getTopLight {
    return topLight;
}

- (BOOL) getBottomLight {
    return bottomLight;
}

- (CameraError) doChunkReadyThings {

    unsigned int v = [ super getGPIO ];

    // port 1 bit 2 - snapshot button
    //
    if ((v & 0x200) == 0) {

        // reset the latch - see QX3 docs
        //
        [super setGPIO:3 and:0xDF or:0xDF ];
        [super setGPIO:3 and:0xFF or:0xFF ];

        if (lastButt == 0) {
            [self cameraEventHappened:self event:CameraEventSnapshotButtonDown];
            NSLog(@"Snapshot button pressed.");
        }
        if (lastButt == 3)
            NSLog(@"Movie recording.");

        lastButt++;
    } else {
        if (lastButt != 0)  {
            [self cameraEventHappened:self event:CameraEventSnapshotButtonUp];
        } 

        if (lastButt > 3)
            NSLog(@"Movie recording ends.");
        lastButt = 0;
    }

    // port 2 bit 6 - cradle
    //
    if ((v & 0x400000) == 0) {
        if (lastCradle != 0) {	
            NSLog(@"Placed in the cradle (top light off; bottom light on).");
            // XXX need a stage engine here.
            [self setTopLight:FALSE ];
            [self setBottomLight:TRUE ];
            [self setWhiteBalanceMode:[self whiteBalanceMode]];
            }               
        lastCradle = 0;
    } else {
        if (lastCradle != 1) {
            NSLog(@"Out of the cradle (bottom light off; top light on).");
            [self setTopLight:TRUE ];
            [self setBottomLight:FALSE ];
            [self setWhiteBalanceMode:[self whiteBalanceMode]];              
            }
        lastCradle = 1;
    }
    
    if (gpioChanged) {
            [ self doLights ];
            [ self changedSomething ];
    }
    
    return [ super doChunkReadyThings ];
}

- (void) changedSomething
{
    NSNotificationCenter *nc = [ NSNotificationCenter defaultCenter ];
    [ nc postNotificationName:EVENT_QX3_ACHANGE object:nil ];
}   

// Subvert the linear white balance for our
// purposes.
//
- (void) setWhiteBalanceMode:(WhiteBalanceMode)wb {

    whiteBalanceMode = wb;
    if (whiteBalanceMode != WhiteBalanceLinear) {
        [ super setWhiteBalanceMode:wb ];
        return;
    }

    NSLog(@"Linear: Hijacked for ColourCorrection curve qx3_document.pdf file; v1.4; 01-02-2000; S. Gillies; page 1");
    if ((topLight) ||( bottomLight)) {
        // Mode 3 - Disable ACB
        [ self setColourBalance:3 red:0.0 green:0.0 blue:0.0 ];

        // Mode 1 - Lamp specific (yellowish) colour balance
        [ self setColourBalance:1 
            red:(51.0/CPIA_COLOR_GAIN_FACTOR) 
            green:(47.0/CPIA_COLOR_GAIN_FACTOR) 
            blue:(3.0/CPIA_COLOR_GAIN_FACTOR) ];

       // Colour correction matrix
 	[ self setSensorMatrix:0x61 a2:0xED a3:0xF1 a4:0xEA a5:0x5F a6:0xF6 a7:0xE0 a8:0xE0 a9:0x7F ];

        // Todo - flicker control, Base Compensation
    } else {
        // Mode 3 - Disable ACB
        [ self setColourBalance:3 red:0.0 green:0.0 blue:0.0 ];

        // Mode 1 - Sensor/lense curve.
        [ self setColourBalance:1 
            red:(20.0/CPIA_COLOR_GAIN_FACTOR) 
            green:(5.0/CPIA_COLOR_GAIN_FACTOR) 
            blue:(7.0/CPIA_COLOR_GAIN_FACTOR) ];

        // Colour correction matrix
        [ self setSensorMatrix:0x60 a2:0xE2 a3:0xFE a4:0xF7 a5:0x59 a6:0xF0 a7:0xFC a8:0xE4 a9:0x60 ];
        // Todo - flicker control, Base Compensation
    }    
}

- (BOOL) startupGrabStream {				// Lights On!

    topLight = FALSE;
    bottomLight = FALSE;
    gpioChanged = TRUE;
    lastButt = -1;
    lastCradle = -1;
    [ self doLights ];
    [ self changedSomething ];

    return [super startupGrabStream];
}

- (BOOL) supportsCameraFeature:(CameraFeature)feature
{
    if (feature == CameraFeatureInspectorClassName)
        return TRUE;

    return FALSE;
}

- (id) valueOfCameraFeature:(CameraFeature)feature 
{
    if (feature == CameraFeatureInspectorClassName)
    	return @"MyQX3CameraInspector";

    return NULL;
}


// XXX investigate how it is possible for this not to be
//     called on certain exits of macam.

- (BOOL) shutdownGrabStream {				//stops camera streaming
    BOOL r = [super shutdownGrabStream];
    NSLog(@"Switching off lights.");

    [self setTopLight:FALSE ];
    [self setBottomLight:FALSE  ];
    [self doLights ];
    [ self changedSomething ];

    return r;
}
@end

@implementation MyQX5Driver 

+ (unsigned short) cameraUsbProductID 
{ 
    return 0x0553;
}

+ (unsigned short) cameraUsbVendorID 
{ 
    return 0x0151; 
}

+ (NSString*) cameraName 
{
    return [MyCameraCentral localizedStringFor:@"Digital Blue QX5 Microscope"];
}

// user interface issues, can we have both lights on the QX5?

// is the light communication the same?
// - doLights

// same or different color balance values?

// same routines for collecting the data?

// methods to deal with new image encoding etc

// separate program to turn on/off lights? script or simple unix tool?

@end

