/*
 MyQCExpressBDriver.m - macam camera driver class for QuickCam Express (STV602)

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

#import "MyQCExpressBDriver.h"
#import "MyCameraCentral.h"
#include "MiscTools.h"
#include "unistd.h"

@implementation MyQCExpressBDriver

+ (unsigned short) cameraUsbProductID { return 0x870; }
+ (unsigned short) cameraUsbVendorID { return 0x46d; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"QuickCam Express"]; }

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err;

    err=[super startupWithUsbDeviceRef:usbDeviceRef];
    if (err==CameraErrorOK) {
/*Start stv600 emulation (or whatever it is). Without it, image data is shifted by one byte which is 0x01 for the first image and 0x00 for the following ones */
        if (![self writeSTVRegister:0x1446 value:1]) {
            err=CameraErrorUSBProblem;
        }
    }

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
    while (buttonThreadRunning) { usleep(10000); }
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
                    [self mergeCameraEventHappened:CameraEventSnapshotButtonDown];
                    break;
                case 17:	//Button up
                    [self mergeCameraEventHappened:CameraEventSnapshotButtonUp];
                    break;
				case   0:
					// with CIF happening on grab start/stopon my QCE w/o button [added by mark.asbach]
                case 194:	//sometimes sent on grab start / stop
                    break;
                default:
#ifdef VERBOSE
                    NSLog(@"MyQCExpressBDriver: unknown data on interrupt pipe:%i",camData);
#endif
                    break;
            }
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


@end