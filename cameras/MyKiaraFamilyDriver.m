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

#import "MyKiaraFamilyDriver.h"

typedef struct _ToUCamFormatEntry {
    CameraResolution res;
    short frameRate;
    short usbFrameBytes;
    short altInterface;
    unsigned char camInit[12];
} ToUCamFormatEntry;

static ToUCamFormatEntry formats[]={
    {ResolutionQSIF , 5,146,1,{0x1D, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x92, 0x00, 0x80}},
    {ResolutionQSIF ,10,291,2,{0x1C, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x23, 0x01, 0x80}},
    {ResolutionQSIF ,15,437,3,{0x1B, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0xB5, 0x01, 0x80}},
    {ResolutionQSIF ,20,589,4,{0x1A, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x4D, 0x02, 0x80}},
    {ResolutionQSIF ,25,703,5,{0x19, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0xBF, 0x02, 0x80}},
    {ResolutionQSIF ,30,874,6,{0x18, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x6A, 0x03, 0x80}},
    {ResolutionSIF  , 5,582,4,{0x0D, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x46, 0x02, 0x80}}
};

static long numFormats=7;

@implementation MyKiaraFamilyDriver

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err=[super startupWithUsbDeviceRef:usbDeviceRef];
    if (!err) {
        chunkHeader=8;
        chunkFooter=4;
    }
    return err;
}

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {	//Returns if this combination is supported
    short i=0;
    BOOL found=NO;
    while ((i<numFormats)&&(!found)) {
        if ((formats[i].res==r)&&(formats[i].frameRate==fr)) found=YES;
        else i++;
    }
    return found;
}

- (void) setResolution:(CameraResolution)r fps:(short)fr {	//Set a resolution and frame rate.
    short i=0;
    BOOL found=NO;
    [super setResolution:r fps:fr];	//Update resolution and fps if state and format is ok
    while ((i<numFormats)&&(!found)) {
        if ((formats[i].res==resolution)&&(formats[i].frameRate==fps)) found=YES;
        else i++;
    }
    if (!found) {
#ifdef VERBOSE
        NSLog(@"MyKiaraFamilyDriver:setResolution: format not found");
#endif
    }
    [stateLock lock];
    if (!isGrabbing) {
        [self usbWriteCmdWithBRequest:GRP_SET_STREAM wValue:SEL_FORMAT wIndex:INTF_VIDEO buf:formats[i].camInit len:12];
        usbFrameBytes=formats[i].usbFrameBytes;
        usbAltInterface=formats[i].altInterface;
    }
    [stateLock unlock];
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {
    if (dFps) *dFps=5;
    return ResolutionSIF;
}
@end
