/*
 MyQCWebDriver.m - macam camera driver class for Logitech QuickCam Web
 
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

#import "MyQCWebDriver.h"
#import "MyCameraCentral.h"
#include "MiscTools.h"

@implementation MyQCWebDriver

+ (unsigned short) cameraUsbProductID { return 0x850; }
+ (unsigned short) cameraUsbVendorID { return 0x46d; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"QuickCam Web"]; }

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    return ((r==ResolutionCIF)&&(fr==5));
}

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err;

    err=[super startupWithUsbDeviceRef:usbDeviceRef];

    extraBytesInLine=4;
    mainToButtonThreadConnection=NULL;
    buttonToMainThreadConnection=NULL;

    if (err==CameraErrorOK) {
        id threadData=NULL;
        if (doNotificationsOnMainThread) {
            NSPort* port1=[NSPort port];
            NSPort* port2=[NSPort port];
            mainToButtonThreadConnection=[[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
            [mainToButtonThreadConnection setRootObject:self];
            threadData=[NSArray arrayWithObjects:port2,port1,NULL];
        }
        buttonThreadShouldBeRunning=YES;
        buttonThreadRunning=YES;
        [NSThread detachNewThreadSelector:@selector(buttonThread:) toTarget:self withObject:threadData];
    }
    return err;
}

- (void) shutdown {
    buttonThreadShouldBeRunning=NO;
    if ((intf)&&(isUSBOK)) (*intf)->AbortPipe(intf,2);
    while (buttonThreadRunning) {}
    if (buttonToMainThreadConnection) [buttonToMainThreadConnection release];
    if (mainToButtonThreadConnection) [mainToButtonThreadConnection release];
    buttonToMainThreadConnection=NULL;
    mainToButtonThreadConnection=NULL;
    [super shutdown];
}

- (void) buttonThread:(id)data {
    unsigned char camData;
    UInt32 length;
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    buttonThreadRunning=NO;
    if (data) {
        buttonToMainThreadConnection=[[NSConnection alloc] initWithReceivePort:[data objectAtIndex:0] sendPort:[data objectAtIndex:1]];
    }
    while ((buttonThreadShouldBeRunning)&&(isUSBOK)) {
        length=1;
        (*intf)->ReadPipe(intf,2,&camData,&length);
        if (length==1) {
            switch (camData) {
                case 16:	//Button down
                    if (lastButtonData==17) [self mergeCameraEventHappened:CameraEventSnapshotButtonDown];
                    break;
                case 17:	//Button up
                    if (lastButtonData==16) [self mergeCameraEventHappened:CameraEventSnapshotButtonUp];
                    break;
                case 194:	//sometimes sent on grab start / stop
                    break;
                default:
#ifdef VERBOSE
                    NSLog(@"MyQCExpressBDriver: unknown data on interrupt pipe:%i",camData);
#endif
                    break;
            }
            lastButtonData=camData;
        }
    }
    [pool release];
    [NSThread exit];
}

- (void) mergeCameraEventHappened:(CameraEvent)evt {
    if (doNotificationsOnMainThread) {
        if ([NSRunLoop currentRunLoop]!=mainThreadRunLoop) {
            if (buttonToMainThreadConnection) {
                [(id)[buttonToMainThreadConnection rootProxy] mergeCameraEventHappened:evt];
                return;
            }
        }
    }
    [self cameraEventHappened:self event:evt];
}

- (BOOL) camInit {
    BOOL ok;
    UInt8 direction;
    UInt8 number;
    UInt8 transferType;
    UInt16 maxPacketSize;
    UInt8 interval;
    IOReturn err;

    ok=[self writeSTVRegister:0x1500 value:1];
    if (ok) ok=[self writeSTVRegister:0x1443 value:0];

    if (ok) ok=[sensor resetSensor];

    if (ok) {
        if (intf&&isUSBOK) {
            err=(*intf)->GetPipeProperties(intf,1,&direction,&number,&transferType,&maxPacketSize,&interval);
            if (err) ok=NO;
        } else ok=NO;
    }
    if (ok) ok=[self writeSTVRegister:0x15c1 value:(maxPacketSize&0xff)];		//isoch frame size lo
    if (ok) ok=[self writeSTVRegister:0x15c2 value:((maxPacketSize>>8)&0xff)];		//isoch frame size hi

    if (ok) ok=[self writeSTVRegister:0x1443 value:0x20];				//timing
    if (ok) ok=[self writeSTVRegister:0x15c3 value:1];					//y subsampling
    return ok;
}

- (CameraError) decodingThread {
    CameraError err;
    [self writeSTVRegister:0x1445 value:0x01];	//LED
    err=[super decodingThread];
    [self writeSTVRegister:0x1445 value:0x00];	//LED
    return err;
}





@end