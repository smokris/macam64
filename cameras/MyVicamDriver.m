/*
 MyVicamDriver.m - Vista Imaging Vicam driver

 Copyright (C) 2002 Dave Camp (dave@thinbits.com)
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

/*

Observations from the Mac OS 9 Vicam driver

VGA = Full Size
SIF = Half Size
QSIF = Quarter Size
SQSIF = Sub Quarter

GG == gain
SS == shutter speed

Control Packet						
 0  1  2  3  4  5  6  7  8  9       wValue  Mac display size				Notes
high quality:                       ------  ----------------                -----
                                            
GG 00 90 07 SS SS SS SS 00 08		0080/0000	-- Full size (640 x 480),	wValue seems to alternate along with index
GG 00 90 07 SS SS SS SS 00 08		0081	-- Half size (320 x 240)		same as full size
GG 21 DC 02 SS SS SS SS 00 04		0081	-- Quarter size (160 x 120)
GG 00 90 07 SS SS SS SS 00 08		0081	-- CIF (352 x 288)				same as full size
GG 21 DC 02 SS SS SS SS 00 04		0081	-- QCIF (176 x 144)				same as quarter size
GG 21 4C 02 SS SS SS SS 18 04		0081	-- Sub Quarter (128 x 96)		
	
medium quality:

GG 00 90 07 SS SS SS SS 00 08		0081	-- Full size (640 x 480)		same as full size (high)
GG 01 C8 03 SS SS SS SS 00 04		0081	-- Half size (320 x 240)
GG 11 E8 01 SS SS SS SS 00 04		0081	-- Quarter size (160 x 120)
GG 01 C8 03 SS SS SS SS 00 04		0081	-- CIF (352 x 288)				same as half size (medium)
GG 11 E8 01 SS SS SS SS 00 04		0081	-- QCIF (176 x 144)				same as quarter size (medium)
GG 11 88 01 SS SS SS SS 18 04		0081	-- Sub Quarter (128 x 96)


low quality:

GG 01 C8 03 SS SS SS SS 00 04		0081	-- Full size (640 x 480)		same as half size (medium)
GG 21 DC 02 SS SS SS SS 00 04		0081	-- Half size (320 x 240)		same as quarter size (high)
GG 12 F4 00 SS SS SS SS 00 02		0081	-- Quarter size (160 x 120)
GG 21 DC 02 SS SS SS SS 00 04		0081	-- CIF (352 x 288)				same as quarter size (high)
GG 12 F4 00 SS SS SS SS 00 02		0081	-- QCIF (176 x 144)				same as quarter size (low)
GG 12 C4 00 SS SS SS SS 18 02		0081	-- Sub Quarter (128 x 96)

So, this gives us:
                                    Raw frame dimensions
									--------------------
GG 00 90 07 SS SS SS SS 00 08		512 x 242 -- good color
GG 21 DC 02 SS SS SS SS 00 04		256 x 183 -- bad color (square pixels?)
GG 21 4C 02 SS SS SS SS 18 04		256 x 183 -- bad color
GG 01 C8 03 SS SS SS SS 00 04		256 x 242 -- good color
GG 11 E8 01 SS SS SS SS 00 04		256 x 122 -- good color
GG 11 88 01 SS SS SS SS 18 04		256 x  98 -- good color
GG 12 F4 00 SS SS SS SS 00 02		128 x 122 -- good color
GG 12 C4 00 SS SS SS SS 18 02		128 x  98 -- good color

-------
What I think the fields mean:

upper 4 bits of [1]: vertical decimation
0 - 242
1 - 122
2 - 183, bad color encoding  (The Mac OS 9 drivers seem to be able
		to use this mode and decode color, but I don't see how.)

lower 4 bits of [1]: horizontal decimation & color/mono select

0 - 512 wide, color
1 - 256 wide, color
2 - 128 wide, color
3 - 256 wide, mono
4 - 128 wide, mono
5 - 512 wide, mono

[2] - ???
[3] - ???
[8] - ??? Set to 0x18 on some dimensions to lower height more than [1] specifies. 122 - 98 = 24 = 0x18?
[9] - ??? Maybe a width value? Observed values are 8 = 512, 4 = 256, 2 = 128

-------------

Other notes:

	Does not appear that a control request is needed before every frame. They only need to be sent
	when a settings change is desired. They only appear to be sent frequently on Mac OS 9 because
	automatic gain and shutter adjustments are on by default. Sending requests on every frame may
	lower the framerate of the camera.
	
	Larger frame sizes appeared to use interlacing on OS 9. At slower shutter speeds, the interlacing
	was obvious on fast moving objects, and could also be ovserved by watching the shutter LED.
	(blink-blink-pause).
	
	Control requests on OS 9 seemed to alternate with index values of 0 and 1 (but not always).
	Might be related to interlacing. Might also be related to a comment in the Linux code indicating
	that two requests were sometimes needed to change the shutter speed. More research is needed.
	
	It might be possible to construct control requests using values other than the complete requests 
	observed on OS 9. For example you might be able to mix and match the horiz and vert decimation
	settings for interesting results.
	
	Each frame is preceeded by 64 bytes, and followed by an additional 64 bytes of data. The first 12 
	bytes of this data appears to be some sort of camera information. The 12 bytes of data may vary 
	between the start of the frame and the end, especially on longer exposures.
	
	Byte [0] sees to be an average luminance for the frame, useful for automatic gain/shutter calculations. 
	Byte [1] & 0x40 yields the current state of the button on the camera. 1 = on, 0 = off.
	
	Found this by accident. If you issue a read for a number of bytes equal to several frames (e.g. 2x normal)
	the read completes with a buffer that starts with a normal frame, and also subsequent frames in the buffer.
	However, the subsequent frames in the buffer are substantially brighter than the initial frame.

-------------


Shutter speeds:

00 00 3B 0F		1/4
00 00 2F 0C		1/5
00 00 27 0A		1/6
00 00 B3 08		1/7
00 00 9D 07		1/8
00 00 C4 06		1/9
00 00 17 06		1/10
00 00 89 05		1/11
00 00 13 05		1/12
00 00 AF 04		1/13
00 00 59 04		1/14
00 00 0F 04		1/15
00 00 CE 03		1/16
00 00 94 03		1/17
00 00 61 03		1/18
00 00 34 03		1/19
00 00 0B 03		1/20
00 00 E5 02		1/21
00 00 C4 02		1/22
00 00 A5 02		1/23
00 00 89 02		1/24
00 00 6F 02		1/25
00 00 57 02		1/26
00 00 40 02		1/27
00 00 2C 02		1/28
00 00 18 02		1/29
00 00 07 02		1/30
00 00 F6 01		1/31
00 00 E6 01		1/32
00 00 D7 01		1/33
00 00 C9 01		1/34
00 00 BC 01		1/35
00 00 B0 01		1/36
00 00 A4 01		1/37
00 00 99 01		1/38
00 00 8F 01		1/39
00 00 85 01		1/40
00 00 7B 01		1/41
00 00 72 01		1/42
00 00 69 01		1/43
00 00 61 01		1/44
00 00 59 01		1/45
00 00 52 01		1/46
00 00 4A 01		1/47
00 00 44 01		1/48
00 00 3D 01		1/49
00 00 37 01		1/50
00 00 30 01		1/51
00 00 2B 01		1/52
00 00 25 01		1/53
00 00 1F 01		1/54
00 00 1A 01		1/55
00 00 15 01		1/56
00 00 10 01		1/57
00 00 0B 01		1/58
00 00 07 01		1/59
00 00 03 01		1/60
05 00 03 01		1/61
09 00 03 01		1/62
0D 00 03 01		1/63
11 00 03 01		1/64
14 00 03 01		1/65
18 00 03 01		1/66
1C 00 03 01		1/67
1F 00 03 01		1/68
22 00 03 01		1/69
26 00 03 01		1/70
...
65 00 03 01		1/98
7F 00 03 01		1/117
9C 00 03 01		1/150
B9 00 03 01		1/208
D7 00 03 01		1/346
...
E6 00 03 01		1/516
E7 00 03 01		1/533
E8 00 03 01		1/552
E9 00 03 01		1/572
EA 00 03 01		1/594
EB 00 03 01		1/617
...
F3 00 03 01		1/900
F4 00 03 01		1/954
F5 00 03 01		1/1016
F6 00 03 01		1/1086
F7 00 03 01		1/1166
F8 00 03 01		1/1260
F9 00 03 01		1/1369
FA 00 03 01		1/1500
FB 00 03 01		1/1657
FC 00 03 01		1/1852
FD 00 03 01		1/2100
FE 00 03 01		1/2423
FF 00 03 01		1/2863
00 01 03 01		1/3500
01 01 03 01		1/4500
02 01 03 01		1/6300
03 01 03 01		1/10500
04 01 03 01		1/315000



Turn off LED:

bRequest: 0x55
wValue: 0x0000
no data

Turn on LED:

bRequest: 0x55
wValue: 0x0003
no data

*/

#import "MyVicamDriver.h"
#import "Resolvers.h"
#import "MiscTools.h"
#import "vicamurbs.h"
#import "RGBScaler.h"
#include "unistd.h"


// --------------------------------------------------------------------------------

#define	_gg_	0x00	// Gain placeholder
#define	_ss_	0x00	// Shutter speed placeholder

#define	kVicamRequestSize	16
#define DATA_HEADER_SIZE 	64

typedef UInt8	VicamRequest[kVicamRequestSize];
typedef	struct
{
    VicamRequest	request;		// Request packet to send
    UInt16		pad1;			// Bytes preceeding the frame
    UInt16		cameraWidth;		// Width of raw Y-Cr-Cb image from camera (1 byte/pixel)
    UInt16		cameraHeight;		// Height of raw Y-Cr-Cb image from camera
    UInt16		pad2;			// Bytes trailing the frame
} VicamInfo;

VicamInfo	gVicamInfo[] = 
{
//	  Request bytes
//    [0]    [1]   [2]   [3]   [4]                     [8]  [9] 
//    gain   h/w   ???   ???   shutter speed values    ???  ???											 p1  w    h    p2
	{{ _gg_, 0x00, 0x90, 0x07, _ss_, _ss_, _ss_, _ss_, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, 64, 512, 242,  64}, // 0
	{{ _gg_, 0x21, 0xDC, 0x02, _ss_, _ss_, _ss_, _ss_, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, 64, 256, 183,  64}, // 1
	{{ _gg_, 0x21, 0x42, 0x02, _ss_, _ss_, _ss_, _ss_, 0x18, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, 64, 256, 144, 192}, // 2
	{{ _gg_, 0x01, 0xC8, 0x03, _ss_, _ss_, _ss_, _ss_, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, 64, 256, 242,  64}, // 3
	{{ _gg_, 0x11, 0xE8, 0x01, _ss_, _ss_, _ss_, _ss_, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, 64, 256, 122,  64}, // 4
	{{ _gg_, 0x11, 0x88, 0x01, _ss_, _ss_, _ss_, _ss_, 0x18, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, 64, 256,  98,  64}, // 5
	{{ _gg_, 0x12, 0xF4, 0x00, _ss_, _ss_, _ss_, _ss_, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, 64, 128, 122,  64}, // 6
	{{ _gg_, 0x12, 0xC4, 0x00, _ss_, _ss_, _ss_, _ss_, 0x18, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, 64, 128,  98,  64}	 // 7
};

// --------------------------------------------------------------------------------

@interface MyVicamDriver (Private)

- (CameraError) startupGrabbing;
- (void) shutdownGrabbing;
- (void) grabbingThread:(id)data;
- (void) handleFullChunkWithReadBytes:(UInt32)readSize error:(IOReturn)err;
- (void) fillNextChunk;
- (void) syncCameraSettings;
- (void) decodeOneFrame:(unsigned char*) src;
- (void) mergeCameraEventHappened:(CameraEvent)evt;

@end

// --------------------------------------------------------------------------------

@implementation MyVicamDriver

+ (unsigned short) cameraUsbProductID { return 0x009d; }
+ (unsigned short) cameraUsbVendorID { return 0x04c1; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"Vicam"]; }

// --------------------------------------------------------------------------------

- (id) initWithCentral:(MyCameraCentral*)c {
    short rate;
    CameraResolution res;

    self = [super initWithCentral:c];	//init superclass
    if (!self) return NULL;

    rgbScaler=[[RGBScaler alloc] init];	//create a scaler/blitter instance

    if (!rgbScaler) {
        [self dealloc];
        return NULL;
    }

    res=[self defaultResolutionAndRate:&rate];
    [self setResolution:res fps:rate];
    [self setGain: 1.0f];
    [self setShutter: 0.98f];
    [self setContrast: 0.5f];
    [self setBrightness: 0.5f];
    [self setSaturation: 0.5f];
    [self setWhiteBalanceMode:[self defaultWhiteBalanceMode]];

    cameraBuffer = NULL;
    cameraBufferSize = 0;
    decodeRGBBuffer = NULL;
    decodeRGBBufferSize = 0;
    return self;    
}

// --------------------------------------------------------------------------------

- (void) dealloc {
    if (rgbScaler) [rgbScaler release]; rgbScaler=NULL;
    [super dealloc];
}

// --------------------------------------------------------------------------------
//	usbIntfWriteCmdWithBRequest
//
//	This is like usbWriteCmdWithBRequest, but it sends to the interface, not the device
// --------------------------------------------------------------------------------

- (BOOL) usbIntfWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    IOReturn err;
    IOUSBDevRequest req;
    req.bmRequestType=USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBInterface);
    req.bRequest=bReq;
    req.wValue=wVal;
    req.wIndex=wIdx;
    req.wLength=len;
    req.pData=buf;
    if ((!isUSBOK)||(!streamIntf)) return NO;
    err=(*streamIntf)->ControlRequest(streamIntf,0,&req);
#ifdef LOG_USB_CALLS
    NSLog(@"usb write req:%i val:%i idx:%i len:%i ret:%i",bReq,wVal,wIdx,len,err);
    if (len>0) DumpMem(buf,len);
#endif
    CheckError(err,"usbWriteCmdWithBRequest");
    if ((err==kIOUSBPipeStalled)&&(streamIntf)) (*streamIntf)->ClearPipeStall(streamIntf,0);
    return (!err);
}

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId
{
	CameraError	err;

	err = [self usbConnectToCam:usbLocationId configIdx:0];
	controlChange = YES;
	
	//setup connection to camera
	if (err != CameraErrorOK)
		return err;

	// Download firmware
	[self usbIntfWriteCmdWithBRequest:0xFF wValue:0 wIndex:0 buf:firmware1 len:sizeof(firmware1)];
	[self usbIntfWriteCmdWithBRequest:0xFF wValue:0 wIndex:0 buf:findex1 len:sizeof(findex1)];
	[self usbIntfWriteCmdWithBRequest:0xFF wValue:0 wIndex:0 buf:fsetup len:sizeof(fsetup)];
	[self usbIntfWriteCmdWithBRequest:0xFF wValue:0 wIndex:0 buf:firmware2 len:sizeof(firmware2)];
	[self usbIntfWriteCmdWithBRequest:0xFF wValue:0 wIndex:0 buf:findex2 len:sizeof(findex2)];
	[self usbIntfWriteCmdWithBRequest:0xFF wValue:0 wIndex:0 buf:fsetup len:sizeof(fsetup)];
	
	// Power
	[self usbIntfWriteCmdWithBRequest:0x50 wValue:1 wIndex:0 buf:0 len:0];
	
	// LED - Need to pause before sending this, otherwise it does not seem to work...
	[self usbIntfWriteCmdWithBRequest:0x55 wValue:3 wIndex:0 buf:0 len:0];
	
	return [super startupWithUsbLocationId:usbLocationId];
}

// --------------------------------------------------------------------------------

- (BOOL) realCamera
{
    return (YES);
}

// --------------------------------------------------------------------------------

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr
{
	BOOL	result = YES;

	switch(r)
	{
		case ResolutionCIF:
		case ResolutionQCIF:
		case ResolutionSIF:
		case ResolutionQSIF:
		case ResolutionSQSIF:
		case ResolutionVGA:
                    result = YES;
		break;
                default:
                    result = NO;
                    break;
        }
	
	return (result);
}

// --------------------------------------------------------------------------------

- (CameraResolution) defaultResolutionAndRate:(short*)dFps
{
    if (dFps)
		*dFps = 30;
    return ResolutionSIF;
}

// --------------------------------------------------------------------------------

- (void) setResolution:(CameraResolution)r fps:(short)fr
{
	[super setResolution:r fps:fr];
	controlChange = YES;
}

// --------------------------------------------------------------------------------

- (short) preferredBPP
{
	return 4;
}

// --------------------------------------------------------------------------------

- (BOOL) canSetBrightness
{
    return YES;
}

// --------------------------------------------------------------------------------

- (BOOL) canSetContrast
{
    return YES;
}

// --------------------------------------------------------------------------------

- (BOOL) canSetSaturation
{
    return YES;
}

// --------------------------------------------------------------------------------

- (BOOL) canSetWhiteBalanceMode
{
    return YES;
}

// --------------------------------------------------------------------------------

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)wb
{
    switch (wb) {
        case WhiteBalanceLinear:
        case WhiteBalanceIndoor:
        case WhiteBalanceOutdoor:
        case WhiteBalanceAutomatic:
            return YES;
            break;
        default:
            return NO;
            break;
    }
}

// --------------------------------------------------------------------------------
- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode {
    [super setWhiteBalanceMode:newMode];
    switch (whiteBalanceMode) {
        case WhiteBalanceLinear:
            redGain	=1.0f;
            blueGain	=1.0f;
            break;
        case WhiteBalanceIndoor:
            redGain	=0.87f;
            blueGain	=1.13f;
            break;
        case WhiteBalanceOutdoor:
            redGain	=1.13f;
            blueGain	=0.87f;
            break;
        case WhiteBalanceAutomatic:
        default:
            redGain	=1.0f;
            blueGain	=1.0f;
        break;
    }
}

// --------------------------------------------------------------------------------

- (BOOL) canSetGain
{
    return YES;
}

// --------------------------------------------------------------------------------

- (BOOL) canSetAutoGain
{
    return YES;
}

// --------------------------------------------------------------------------------

- (void) setAutoGain:(BOOL)ag {
    [super setAutoGain:ag];
    if (ag) {
        corrSum=0.0f;	//Reset the integrated correction (see below for details)
        [self setGain:0.0f];
        [self setShutter:0.9f];
    }
}

// --------------------------------------------------------------------------------

- (float) gain {
    return gain;
}

// --------------------------------------------------------------------------------

- (void) setGain:(float)v
{
    gain=v;
    controlChange = YES;
}

// --------------------------------------------------------------------------------

- (BOOL) canSetShutter
{
    return YES;
}

// --------------------------------------------------------------------------------

- (float) shutter
{
    return shutter;
}

// --------------------------------------------------------------------------------

- (void) setShutter:(float)v
{
    shutter=v;
	controlChange = YES;
}

#pragma mark -

//Grabbing


/*

Why CFRunLoops? Somehow, I didn't manage to get the NSRunLoop stopped after invalidating the timer - the most likely reason is the connection to the main thread. This is not beautiful, but it works. It affects only the two lines CFRunLoopRun(); (which could be [[NSRunLoop currentRunLoop] run]) and CFRunLoopStop(CFRunLoopGetCurrent()); (which could be omitted as far as I understand it because [timer invalidate] should remove the timer from the run loop).

*/


// --------------------------------------------------------------------------------

//init grabbing stuff

- (CameraError) startupGrabbing {

    //Set natural camera resolution - FIX ME: Could be smarter...
    requestIndex = 0;

    switch ([self resolution])
    {
        case ResolutionSQSIF:	// 128x96
            requestIndex = 7;
            break;

        case ResolutionQSIF:	// 160x120
            requestIndex = 6;
            break;

        case ResolutionQCIF:	// 176x144
            requestIndex = 3;
            break;

        case ResolutionSIF:		// 320x240
            requestIndex = 2;
            break;

        case ResolutionCIF:		// 352x288
            requestIndex = 1;
            break;

        case ResolutionVGA:		// 640x480
            requestIndex = 0;
            break;

        default:
            requestIndex = 0;
            break;
    }
	
    videoBulkReadsPending=0;
    emptyChunks=NULL;
    fullChunks=NULL;
    emptyChunkLock=NULL;
    fullChunkLock=NULL;
    chunkReadyLock=NULL;
    decodeRGBBuffer=NULL;
    decodeRGBBufferSize=4*gVicamInfo[requestIndex].cameraWidth*gVicamInfo[requestIndex].cameraHeight;
    MALLOC(decodeRGBBuffer,UInt8*,decodeRGBBufferSize,decodeRGBBuffer);
    if (!decodeRGBBuffer) return CameraErrorNoMem;
    emptyChunks=[[NSMutableArray alloc] initWithCapacity:HOMECONNECT_NUM_CHUNKS];
    if (!emptyChunks) return CameraErrorNoMem;
    fullChunks=[[NSMutableArray alloc] initWithCapacity:HOMECONNECT_NUM_CHUNKS];
    if (!fullChunks) return CameraErrorNoMem;
    emptyChunkLock=[[NSLock alloc] init];
    if (!emptyChunkLock) return CameraErrorNoMem;
    fullChunkLock=[[NSLock alloc] init];
    if (!fullChunkLock) return CameraErrorNoMem;
    chunkReadyLock=[[NSLock alloc] init];
    if (!chunkReadyLock) return CameraErrorNoMem;
    [chunkReadyLock tryLock];					//Should be locked by default
    controlChange=YES;						//We should set the camera settings before we start
    return CameraErrorOK;
    
}

// --------------------------------------------------------------------------------

//Cleanup grabbing stuff

- (void) shutdownGrabbing {
    if (emptyChunks) {
        [emptyChunks release];
        emptyChunks=NULL;
    }
    if (fullChunks) {
        [fullChunks release];
        fullChunks=NULL;
    }
    if (emptyChunkLock) {
        [emptyChunkLock release];
        emptyChunkLock=NULL;
    }
    if (fullChunkLock) {
        [fullChunkLock release];
        fullChunkLock=NULL;
    }
    if (chunkReadyLock) {
        [chunkReadyLock release];
        chunkReadyLock=NULL;
    }
    if (decodeRGBBuffer) {
        FREE(decodeRGBBuffer,"decodeRGBBuffer");
        decodeRGBBuffer=NULL;
    }

}

// --------------------------------------------------------------------------------

//The "inner" grabbing thread that does the actual USB reading

- (void) grabbingThread:(id)data {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    IOReturn err;
    CFRunLoopSourceRef cfSource;
    grabbingError=CameraErrorOK;

    //Run the grabbing loop
    if (shouldBeGrabbing) {
        err = (*streamIntf)->CreateInterfaceAsyncEventSource(streamIntf, &cfSource);	//Create an event source
        CheckError(err,"CreateInterfaceAsyncEventSource");
        if (err) {
            if (!grabbingError) grabbingError=CameraErrorNoMem;
            shouldBeGrabbing=NO;
        }
    }

    if (shouldBeGrabbing) {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//Add it to our run loop
        [self fillNextChunk];
    CFRunLoopRun();
    }

    shouldBeGrabbing=NO;			//error in grabbingThread or abort? initiate shutdown of everything else
    [chunkReadyLock unlock];			//give the decodingThread a chance to abort
    [pool release];
    grabbingThreadRunning=NO;
    [NSThread exit];
}

// --------------------------------------------------------------------------------

//A c wrapper that is called on USB bulk read completion. Just calls the appropriate object method - Called in grabbingThread

static void handleFullChunk(void *refcon, IOReturn result, void *arg0) {
    MyVicamDriver* driver=(MyVicamDriver*)refcon;
    long size=((long)arg0);
    [driver handleFullChunkWithReadBytes:size error:result];
}

// --------------------------------------------------------------------------------

//This is called on USB bulk read completion. Handles error, notifies decoder, initiates next read - runs in grabbingThread 

- (void) handleFullChunkWithReadBytes:(UInt32)readSize error:(IOReturn)err  {
    NSMutableData* tmpChunk;
    videoBulkReadsPending--;
    
    if (err) {
        ShowError(err,"ReadPipe");
        if ((err==kIOUSBPipeStalled)&&(streamIntf)) {
            (*streamIntf)->ClearPipeStall(streamIntf, 1);
        } else {
            if (!grabbingError) grabbingError=CameraErrorUSBProblem;
            shouldBeGrabbing=NO;				//Inside decodingThread, always set shouldBeGrabbing to NO on error
        }
    }
    if (shouldBeGrabbing) {					//no usb error.
        if ([fullChunks count]>HOMECONNECT_NUM_CHUNKS) {	//the full chunk list is already full - discard the oldest
            [fullChunkLock lock];
            tmpChunk=[fullChunks objectAtIndex:0];
            [tmpChunk retain];
            [fullChunks removeObjectAtIndex:0];
            [fullChunkLock unlock];
            /*Note that the locking here is a bit stupid since we lock fullChunkLock twice when we have a buffer overflow. But this hopefully happens not too often and I don't want a sequence to require two locks at the same time since this could be likely to introduce deadlocks */
            [emptyChunkLock lock];
            [emptyChunks addObject:tmpChunk];
            [tmpChunk release];
            tmpChunk=NULL;		//to be sure...
            [emptyChunkLock unlock];
        }
        [fullChunkLock lock];		//Append our full chunk to the list
        [fullChunks addObject:fillingChunk];
        [fillingChunk release];
        fillingChunk=NULL;		//to be sure...
        [fullChunkLock unlock];
        [chunkReadyLock tryLock];	//New chunk is there. Try to wake up the decoder
        [chunkReadyLock unlock];
    } else {				//Incorrect chunk -> ignore (but back to empty chunks)
        [emptyChunkLock lock];
        [emptyChunks addObject:fillingChunk];
        [fillingChunk release];
        fillingChunk=NULL;			//to be sure...
        [emptyChunkLock unlock];
    }
    if (shouldBeGrabbing) [self fillNextChunk];

    //We can only stop if there's no read request left. If there is an error, no new one was issued
    if (videoBulkReadsPending<=0) CFRunLoopStop(CFRunLoopGetCurrent());
}

// --------------------------------------------------------------------------------

//starts an asynchronous bulk read - runs in grabbingThread



- (void) fillNextChunk {
    IOReturn err;
    
    if (!shouldBeGrabbing) return;	//No new reads when stopped or error
    [self syncCameraSettings];		//Make sure the camera is up to date
    if (!shouldBeGrabbing) return;	//No new reads when stopped
    //Get an empty chunk
    if (shouldBeGrabbing) {
        if ([emptyChunks count]>0) {	//We have a recyclable buffer
            [emptyChunkLock lock];
            fillingChunk=[emptyChunks lastObject];
            [fillingChunk retain];
            [emptyChunks removeLastObject];
            [emptyChunkLock unlock];
        } else {			//We need to allocate a new one
            fillingChunk=[[NSMutableData alloc] initWithCapacity:CHUNK_SIZE];
            if (!fillingChunk) {
                if (!grabbingError) grabbingError=CameraErrorNoMem;
                shouldBeGrabbing=NO;
            }
        }
    }
    //start the bulk read
    if (shouldBeGrabbing) {
        err=(*streamIntf)->ReadPipeAsync(streamIntf,1,
                                   [fillingChunk mutableBytes],
                                   CHUNK_SIZE,
                                   (IOAsyncCallback1)(handleFullChunk),self);	//Read one chunk
        CheckError(err,"grabbingThread:ReadPipeAsync");
        if (err) {
            grabbingError=CameraErrorUSBProblem;
            shouldBeGrabbing=NO;
        } else videoBulkReadsPending++;
    }    
}

// --------------------------------------------------------------------------------

//Updates the camera configuration if needed - runs in grabbingThread

- (void) syncCameraSettings {
    if ((controlChange)&&(shouldBeGrabbing)) {
        UInt32		realShutter;
        UInt8		request[kVicamRequestSize];
        int		shutterFraction;

        controlChange = NO;

        // Fill in the request
        BlockMoveData(gVicamInfo[requestIndex].request, request, kVicamRequestSize);

        // Set the gain
        request[0] = [self gain] * 255; // 0 = 0% gain, FF = 100% gain

        // Shutter range is from 1/4 second to 1/100 second.
        shutterFraction = 4 + ((1.0f-[self shutter]) * 2000);

        if (shutterFraction > 60)
        {
            // Short exposure
            realShutter = ((-15631900 / shutterFraction)+260533)/1000;

            request[4] = realShutter & 0xFF;
            request[5] = (realShutter >> 8) & 0xFF;
            request[6] = 0x03;
            request[7] = 0x01;
        }
        else
        {
            // Long exposure
            realShutter = 15600/shutterFraction - 1;
            request[4] = 0;
            request[5] = 0;
            request[6] = realShutter & 0xFF;
            request[7] = realShutter >> 8;
        }

        
        // Send the camera configuration
        if (![self usbIntfWriteCmdWithBRequest:0x51 wValue:0x81 wIndex:0 buf:request len:kVicamRequestSize]) {
            grabbingError=CameraErrorUSBProblem;
            shouldBeGrabbing=NO;
        }
    }
}

// --------------------------------------------------------------------------------

- (CameraError) decodingThread {
    CameraError err=CameraErrorOK;
    unsigned char* chunkData;
    NSMutableData* currChunk;
    //Initialize the camera, buffers and stuff
    grabbingThreadRunning=NO;
    err=[self startupGrabbing];
    if (err) shouldBeGrabbing=NO;
    //Detach grabbing thread
    if (shouldBeGrabbing) {
        grabbingError=CameraErrorOK;
        grabbingThreadRunning=YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];
    }
    //Do our decoding loop
    while (shouldBeGrabbing) {
        [chunkReadyLock lock];					//wait for new chunks to arrive
        while ((shouldBeGrabbing)&&([fullChunks count]>0)) {	//decode all full chunks we have until we lock again
            BOOL bufferSet;
            [fullChunkLock lock];				//Take the oldest chunk to decode
            currChunk=[fullChunks objectAtIndex:0];
            [currChunk retain];
            [fullChunks removeObjectAtIndex:0];
            [fullChunkLock unlock];
            [imageBufferLock lock];				//Get image destination data
            lastImageBuffer=nextImageBuffer;
            lastImageBufferBPP=nextImageBufferBPP;
            lastImageBufferRowBytes=nextImageBufferRowBytes;
            bufferSet=nextImageBufferSet;
            nextImageBufferSet=NO;
            if (bufferSet) {
                chunkData=[currChunk mutableBytes];
                [self decodeOneFrame:chunkData];
                [imageBufferLock unlock];
                [self mergeImageReady];
            } else {
                [imageBufferLock unlock];
            }
            [emptyChunkLock lock];				//recycle our chunk - it's empty again
            [emptyChunks addObject:currChunk];
            [currChunk release];
            currChunk=NULL;
            [emptyChunkLock unlock];

        }
    }
    //wait until grabbingThread has finished
    while (grabbingThreadRunning) { usleep(10000); }	//Wait for grabbingThread finish
    //We need to sleep here because otherwise the compiler would optimize the loop away

    //if the first error occurred on grabbingThread, take the result from there
    if (!err) err=grabbingError;
    //Cleanup everything
    [self shutdownGrabbing];
    return err;
}


/*
 - (void) decodeOneFrame:(unsigned char*) src {
    int srcWidth=gVicamInfo[requestIndex].cameraWidth;
    int srcHeight=gVicamInfo[requestIndex].cameraHeight;
    int dstWidth=[self width];
    int dstHeight=[self height];

    // Lame attempt at automatic gain control
    if ([self isAutoGain]) {
        SInt16	frameLuminance = (UInt8) src[gVicamInfo[requestIndex].cameraWidth + gVicamInfo[requestIndex].cameraHeight + gVicamInfo[requestIndex].pad1 + gVicamInfo[requestIndex].pad2 - 63];
        float	currentGain = [self gain];
        SInt16	threshold = 164;	// Arbitrary value...
        SInt16	tolerance = 16;		// Help keep gain from oscillating

        // Use the average of both values (they can be different)
        frameLuminance += (UInt8) src[0];
        frameLuminance /= 2;

        // Adjust the gain if the luminance varies from the threshold by more than
        // an arbitrary amount.
        if ((frameLuminance - threshold) > tolerance && currentGain > 0.01)
            [self setGain:currentGain - 0.01];

        if ((frameLuminance - threshold) < tolerance && currentGain < 0.99)
            [self setGain:currentGain + 0.01];
    }	
	
    //Step one: decode raw data to rgb
    vicam_decode_color(src,srcWidth,srcHeight,decodeRGBBuffer);

    //Step two: scale the rgb data to the desired output resolution
    [rgbScaler setSourceWidth:srcWidth
                       height:srcHeight
                bytesPerPixel:4
                     rowBytes:srcWidth*4];
    [rgbScaler setDestinationWidth:dstWidth
                            height:dstHeight
                     bytesPerPixel:lastImageBufferBPP
                          rowBytes:lastImageBufferRowBytes];
    [rgbScaler convert:decodeRGBBuffer to:lastImageBuffer];
}
*/


//This is the decoding core. Decodes and scales one chunk of raw camera data to the buffer pointed at lastImageBuffer, -BPP, -RowBytes


- (void) decodeOneFrame:(unsigned char*) data {

/*
The data from the camera is similar to a usual GRBG Bayer matrix, but some color components seem to be encoded differently in the data stream: The green components cannot be read directly - instead, calculating the difference between the row-neighbouring ged or blue components produces acceptable results (we need some investigations here...). Additionally, the pixels are usually not square. The source image has a widescreen format. So the scaling process will inflate the image more vertically than horizontally, resulting in a vertically blurred image. So we'll interpolate horizontally here to have the image blurred rather horizontally than vertically, hoping that these two processes will result in a close-to-uniform frequency distribution.

*/
    int width=gVicamInfo[requestIndex].cameraWidth;
    int height=gVicamInfo[requestIndex].cameraHeight;
    int x,y;
    UInt16* src1=(UInt16*)(data+DATA_HEADER_SIZE);
    UInt16* src2=(UInt16*)(data+width+DATA_HEADER_SIZE);
    UInt32* dst1=(UInt32*)(decodeRGBBuffer);
    UInt32* dst2=(UInt32*)(decodeRGBBuffer+4*width);
    UInt16 s11,s12,s21,s22;			//Raw source data
    long rc,bc;					//Component distances from luminance
    long r,g,b;
    long bri=(brightness-0.5f)*256.0f;
    long con=contrast*256.0f;
    long sat=saturation*contrast*1024.0f;
    long rgai=redGain*256.0f;
    long bgai=blueGain*256.0f;
    long rcSum=0;
    long bcSum=0;
    long gSum=0;
    for (y=(height/2);y>0;y--) {			// Iterate through rows (2 lines each iteration)
        s12 = CFSwapInt16HostToBig(*src1);  // Read first two source bytes in row
        src1++;
        s22 = CFSwapInt16HostToBig(*src2);  // Read first two source bytes in row
        src2++;
        for (x=(width/2)-1;x>0;x--) {			//Iterate through all but two columns (2 colums each iteration)
            s11=s12;					//shift source data
            s21=s22;					//shift source data
            s12 = CFSwapInt16HostToBig(*src1);  // Read next two source bytes in row
            src1++;
            s22 = CFSwapInt16HostToBig(*src2);  // Read next two source bytes in row
            src2++;
            
            //calculate chroma color components (for all four pixels)
            rc=((	((((s11&0xff)+(s12&0xff))*rgai)>>9)		-((s12>>8)&0xff))	*sat)/256;
            bc=((	(((((s21>>8)&0xff)+((s22>>8)&0xff))*bgai)>>9)	-(s21&0xff))		*sat)/256;
            rcSum+=rc;
            bcSum+=bc;
            
            //write rgb pixels
            g=(((((s11>>8)&0xff)+((s11)&0xff))*con)/256)+bri;
            r=g+rc;
            b=g+bc;
            *(dst1++) = CFSwapInt32BigToHost((CLAMP(r,0,255)<<24)+(CLAMP(g,0,255)<<16)+(CLAMP(b,0,255)<<8));

            g=(((((s11)&0xff)+((s12>>8)&0xff))*con)/256)+bri;
            r=g+rc;
            b=g+bc;
            *(dst1++) = CFSwapInt32BigToHost((CLAMP(r,0,255)<<24)+(CLAMP(g,0,255)<<16)+(CLAMP(b,0,255)<<8));

            g=(((((s21>>8)&0xff)+((s21)&0xff))*con)/256)+bri;
            r=g+rc;
            b=g+bc;
            *(dst2++) = CFSwapInt32BigToHost((CLAMP(r,0,255)<<24)+(CLAMP(g,0,255)<<16)+(CLAMP(b,0,255)<<8));

            g=(((((s21)&0xff)+((s22>>8)&0xff))*con)/256)+bri;
            r=g+rc;
            b=g+bc;
            *(dst2++) = CFSwapInt32BigToHost((CLAMP(r,0,255)<<24)+(CLAMP(g,0,255)<<16)+(CLAMP(b,0,255)<<8));
            gSum+=g;	//Sum up green component to get the average brightness
        }
        //write last two pixels in row

        //calculate chroma color components
        rc=((	(((s12&0xff)*rgai)>>8)				-((s12>>8)&0xff))	*sat)/256;
        bc=((	((((s22>>8)&0xff)*bgai)>>8)			-(s22&0xff))		*sat)/256;

        //write rgb pixels
        g=(((((s12>>8)&0xff)+((s12)&0xff))*con)/256)+bri;
        r=g+rc;
        b=g+bc;
        *(dst1++) = CFSwapInt32BigToHost((CLAMP(r,0,255)<<24)+(CLAMP(g,0,255)<<16)+(CLAMP(b,0,255)<<8));
        *(dst1++) = CFSwapInt32BigToHost((CLAMP(r,0,255)<<24)+(CLAMP(g,0,255)<<16)+(CLAMP(b,0,255)<<8));

        g=(((((s22>>8)&0xff)+((s22)&0xff))*con)/256)+bri;
        r=g+rc;
        b=g+bc;
        *(dst2++) = CFSwapInt32BigToHost((CLAMP(r,0,255)<<24)+(CLAMP(g,0,255)<<16)+(CLAMP(b,0,255)<<8));
        *(dst2++) = CFSwapInt32BigToHost((CLAMP(r,0,255)<<24)+(CLAMP(g,0,255)<<16)+(CLAMP(b,0,255)<<8));
        
        //Advance one row
        src1+=(width/2);
        src2+=(width/2);
        dst1+=width;
        dst2+=width;
    }
    
    //Decoding is done. Now scale into the receicing buffer
    [rgbScaler setSourceWidth:width
                       height:height
                bytesPerPixel:4
                     rowBytes:width*4];
    [rgbScaler setDestinationWidth:[self width]
                            height:[self height]
                     bytesPerPixel:lastImageBufferBPP
                          rowBytes:lastImageBufferRowBytes];
    [rgbScaler convert:decodeRGBBuffer to:lastImageBuffer];

    //If needed, update white balance
    if ((whiteBalanceMode==WhiteBalanceAutomatic)&&(saturation*contrast!=0.0f)) {
        float corrFactor=-0.03f;
        float maxCorr=0.02f;
        float red=((float)rcSum)/((float)((width-2)*height));	//Calculate the average component distance
        float blue=((float)bcSum)/((float)((width-2)*height));
        red*=corrFactor;					//Scale down to get correction term
        blue*=corrFactor;
        red=CLAMP(red,-maxCorr,maxCorr);			//Limit correction to avoid oscillation
        blue=CLAMP(blue,-maxCorr,maxCorr);
        redGain +=red;						//Apply correction to color gains
        blueGain+=blue;
    }
    //If needed, update auto gain
    if ([self isAutoGain]) {
/*
The approach is to keep gain as low as possible. This sometimes means low fps, but it's better than noise (other opinions?)

An additional problem is that the correction results may be delayed becuse of buffered frames in the decoding pipeline. Using a p-adjustment (just using the "badness" of the current frame) will likely result in slow correction and/or oscillatng brightness. So the approach here is to use pi-adjustment (using the brightness difference and the integrated/summed corrections of the previous frames). pd would probably even be nicer, but it's difficult to get a good derivation in this context.

 Another problem: The longest exposure setting differs quite much from the second longest, so adjusting here becones reather non-continuous. In order to reduce oscillation around this, there's a threshold to go to/from the highest  setting. There's an exception to the "keep the gain low" rule: When the image is too dark and the threshod is not reached, try to rise the gain.
 
*/

        double best=100.0;		//The "optimum brightness"
        double tolerance=18.0;		//tolerable average is best +- tolerance 
        double strength=0.0002;		//correction units per unit out of acceptable value
        double maxCorr=0.02;		//Maximum allowable correction units
        //Find out if and how we have to correct gain/exposure
        double avg=(((double)gSum*4.0/((float)((width-2)*height)))-((double)bri))/(((double)con)/128.0);
        double pCorr=0.0;		//The p-correction
        double piCorr=0.0;		//The correction taking the integrated foctor into account
        double corrSumBlend=10.0f;
        double fullShutterThreshold=0.024;
        if (avg<(best-tolerance)) pCorr=((best-tolerance)-avg)*strength;	//Too dark -> positive correction
        if (avg>(best+tolerance)) pCorr=((best+tolerance)-avg)*strength;	//Too bright -> negative correction
        pCorr=CLAMP(pCorr,-maxCorr,maxCorr);

        //Calculate the pi-part Adjust the integrated correction
        piCorr=pCorr+0.8*corrSum;					//Damp oscillation (need to asjust factor?)
        corrSum=(corrSumBlend*corrSum+pCorr)/(corrSumBlend+1.0f);	//Exponentially weigthed sum as integral
        
        //Now do the correction
        if (piCorr>0.0) {
            if ([self shutter]<1.0f) {
                if ([self shutter]+piCorr>=0.9f) {
                    if (piCorr>=fullShutterThreshold) {
                        [self setShutter:MIN([self shutter]+piCorr,1.0f)];
                    } else {
                        [self setGain:MIN([self gain]+piCorr,1.0f)];
                    }
                } else [self setShutter:MIN([self shutter]+piCorr,1.0f)];
            } else if ([self gain]<1.0f) {
                [self setGain:MIN([self gain]+piCorr,1.0f)];
            }
            
        } else if (piCorr<0.0) {
            if ([self gain]>0.0f) {
                [self setGain:MAX([self gain]+piCorr,0.0f)];
            } else if ([self shutter]>0.0f) {
                if ([self shutter]>=0.9) {
                    if (piCorr<=-fullShutterThreshold) [self setShutter:MAX([self shutter]+piCorr,0.0f)];
                } else {
                    [self setShutter:MAX([self shutter]+piCorr,0.0f)];
                }
            }
        }
    }
    //Check if the snapshot button state has changed.
    {
        BOOL buttonIsPressed=(data[1] & 0x40)?YES:NO;
        if (buttonIsPressed&&!buttonWasPressed) {
            [self mergeCameraEventHappened:CameraEventSnapshotButtonDown];
        } else if (!buttonIsPressed&&buttonWasPressed) {
            [self mergeCameraEventHappened:CameraEventSnapshotButtonUp];
        }
        buttonWasPressed=buttonIsPressed;
    }
}

- (void) mergeCameraEventHappened:(CameraEvent)evt {
    if (doNotificationsOnMainThread) {
        if ([NSRunLoop currentRunLoop]!=mainThreadRunLoop) {
            if (decodingThreadConnection) {
                [(id)[decodingThreadConnection rootProxy] mergeCameraEventHappened:evt];
                return;
            }
        }
    }
    [self cameraEventHappened:self event:evt];
}

@end
