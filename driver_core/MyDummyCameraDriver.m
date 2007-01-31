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

#import "MyDummyCameraDriver.h"
#import "Resolvers.h"

@implementation MyDummyCameraDriver

+ (unsigned short) cameraUsbProductID { return 0; }
+ (unsigned short) cameraUsbVendorID { return 0; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"Dummy camera"]; }


- (id) initWithError:(CameraError)err central:(MyCameraCentral*)c {
    short rate;
    CameraResolution res;
    self=[super initWithCentral:c];	//init superclass
    if (self==NULL) return NULL;
    self->errMsg=err;				//Copy our params
    res=[self defaultResolutionAndRate:&rate];
    [self setResolution:res fps:rate];
    return self;    
}

- (id) initWithCentral:(MyCameraCentral*)c {
    return [self initWithError:CameraErrorOK central:c];
}

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId {
    return [super startupWithUsbLocationId:usbLocationId];
}

- (BOOL) canSetDisabled
{
    return NO;  // Dummy cameras can not be disabled
}

- (BOOL) realCamera {	//Returns if the camera is a real image grabber or a dummy
    return (errMsg==CameraErrorOK);		//We're a dummy - if error is ok, we display a test image and act like a real one
}


- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    if ((fr<20)&&(r>=ResolutionQSIF)) return YES;
    else return NO;
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {
    if (dFps) *dFps=5;
    return ResolutionSIF;
}

//Grabbing


/*

Why CFRunLoops? Somehow, I didn't manage to get the NSRunLoop stopped after invalidating the timer - the most likely reason is the connection to the main thread. This is not beautiful, but it works. It affects only the two lines CFRunLoopRun(); (which could be [[NSRunLoop currentRunLoop] run]) and CFRunLoopStop(CFRunLoopGetCurrent()); (which could be omitted as far as I understand it because [timer invalidate] should remove the timer from the run loop).

*/

- (CameraError) decodingThread {
    [NSTimer scheduledTimerWithTimeInterval:(1.0f)/((float)fps)
                                     target:self
                                   selector:@selector(imageTime:)
                                   userInfo:NULL
                                    repeats:YES];
    CFRunLoopRun();
    return CameraErrorOK;
}

- (void) imageTime:(NSTimer*)timer {
    if (shouldBeGrabbing) {
        [self makeErrorImage:errMsg];
    } else {
        [timer invalidate];
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
}

@end
