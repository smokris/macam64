//
//  QCMessengerDriver.h
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

#include <Carbon/Carbon.h>
#include <QuickTime/QuickTime.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

#include "GlobalDefs.h"

#import "RGB888Scaler.h"
#import "MyQCExpressADriver.h"


@interface QCMessengerDriver : MyQCExpressADriver {
    BOOL f_debug;
    RGB888Scaler* scaler;
    long srcWidth, srcHeight;
//    unsigned char ImgBuf[324 * 248 * 3 + 100]; // Width * Height * BPP
    unsigned char* imgBuf;
    unsigned long imgBufLen;
}

+ (NSArray *) cameraUsbDescriptions;

- (BOOL) isDebugging;

- (id) initWithCentral:(id)c;
- (void) dealloc;

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId;

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr;
#if 1
- (CameraResolution) defaultResolutionAndRate:(short*)dFps;
#endif
- (void) setResolution:(CameraResolution)r fps:(short)fr;

- (void) grabbingThread:(id)data;
- (CameraError) decodingThread;				//Entry method for the chunk to image decoding thread

- (BOOL) canSetLed;
- (BOOL) isLedOn;
- (void) setLed:(BOOL)v;

@end
