/*
    macam - webcam app and QuickTime driver component
    Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)
    Copyright (C) 2002 Hiroki Mori

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

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#import "MyCameraCentral.h"
#import "MyOV511Driver.h"
#import "Resolvers.h"
#import "yuv2rgb.h"
#import "MiscTools.h"

//#define OV511_DEBUG
//#define USE_COMPRESS

#ifdef USE_COMPRESS
//int Decompress420(unsigned char *pIn, unsigned char *pOut,int w,int h,int inSize);
int Decompress420(unsigned char *pIn, unsigned char *pOut, unsigned char *pTmp, int w, int h, int inSize);
#endif

#define OV511_QUANTABLESIZE	64
#define OV518_QUANTABLESIZE	32

#define OV511_YQUANTABLE { \
	0, 1, 1, 2, 2, 3, 3, 4, \
	1, 1, 1, 2, 2, 3, 4, 4, \
	1, 1, 2, 2, 3, 4, 4, 4, \
	2, 2, 2, 3, 4, 4, 4, 4, \
	2, 2, 3, 4, 4, 5, 5, 5, \
	3, 3, 4, 4, 5, 5, 5, 5, \
	3, 4, 4, 4, 5, 5, 5, 5, \
	4, 4, 4, 4, 5, 5, 5, 5  \
}

#define OV511_UVQUANTABLE { \
	0, 2, 2, 3, 4, 4, 4, 4, \
	2, 2, 2, 4, 4, 4, 4, 4, \
	2, 2, 3, 4, 4, 4, 4, 4, \
	3, 4, 4, 4, 4, 4, 4, 4, \
	4, 4, 4, 4, 4, 4, 4, 4, \
	4, 4, 4, 4, 4, 4, 4, 4, \
	4, 4, 4, 4, 4, 4, 4, 4, \
	4, 4, 4, 4, 4, 4, 4, 4  \
}

#define ENABLE_Y_QUANTABLE 1
#define ENABLE_UV_QUANTABLE 1

@implementation MyOV511PlusDriver

//Class methods needed
+ (unsigned short) cameraUsbProductID { return PRODUCT_OV511PLUS; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_OVT; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"OV511Plus-based camera"]; }

- (short) defaultAltInterface {
    return 7;
}

- (short) packetSize:(short)altInterface {
    short size;
    switch(altInterface) {
        case 7:
            size = 961;
            break;
        case 6:
            size = 769;
            break;
        case 5:
            size = 513;
            break;
        case 4:
            size = 385;
            break;
        case 3:
            size = 257;
            break;
        case 2:
            size = 129;
            break;
        case 1:
            size = 22;
            break;
    }
    return size;
}

@end

//camera modes and the necessary data for them

@interface MyOV511Driver (Private)

- (BOOL) setupGrabContext;				//Sets up the grabContext structure for the usb async callbacks
- (BOOL) cleanupGrabContext;				//Cleans it up
- (void) grabbingThread:(id)data;			//Entry method for the usb data grabbing thread

@end

@implementation MyOV511Driver

//Class methods needed
+ (unsigned short) cameraUsbProductID { return PRODUCT_OV511; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_OVT; }
+ (NSString*) cameraName {return [MyCameraCentral localizedStringFor:@"OV511-based camera"];}

void blockCopy(int buffsize, int *cursize, char *srcbuf, char *distbuf, int width, int height);
void tmpcopy32(u_char *buffer, int offset, int size, u_char *tmpbuf, long *tmpsize);

static unsigned char yQuanTable511[] = OV511_YQUANTABLE;
static unsigned char uvQuanTable511[] = OV511_UVQUANTABLE;

- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    UInt8 buf[16];
    long i;
    CameraError err=[self usbConnectToCam:usbDeviceRef];
//setup connection to camera
     if (err!=CameraErrorOK) return err;

    /* reset the OV511 */
    buf[0] = 0x7f;
    if (![self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_RST buf:buf len:1]) {
#ifdef VERBOSE
        NSLog(@"OV511:startupGrabbing: error : OV511_REG_RST");
#endif
        return CameraErrorUSBProblem;
    }

    buf[0] = 0x00;
    if (![self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_RST buf:buf len:1]) {
#ifdef VERBOSE
        NSLog(@"OV511:startupGrabbing: error : OV511_REG_RST");
#endif
        return CameraErrorUSBProblem;
    }

    /* initialize system */
    buf[0] = 0x01;
    if (![self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_EN_SYS buf:buf len:1]) {
#ifdef VERBOSE
        NSLog(@"OV511:startupGrabbing: error : OV511_REG_EN_SYS");
#endif
        return CameraErrorUSBProblem;
    }

    if (![self usbReadCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_CID buf:buf len:1]) {
#ifdef VERBOSE
        NSLog(@"OV511:startupGrabbing: error : OV511_REG_CID");
#endif
        return CameraErrorUSBProblem;
    }

    switch(buf[0]) {
        case 6:
            sensorType = SENS_SAA7111A_WITH_FI1236MK2;
            sensorWrite = SAA7111A_I2C_WRITE_ID;
            sensorRead = SAA7111A_I2C_READ_ID;
            [self seti2cid];
#ifdef OV511_DEBUG
            NSLog(@"macam: Lifeview USB Life TV (NTSC)");
#endif
            break;
        case 102:
            sensorType = SENS_SAA7111A;
            sensorWrite = SAA7111A_I2C_WRITE_ID;
            sensorRead = SAA7111A_I2C_READ_ID;
            [self seti2cid];
#ifdef OV511_DEBUG
            NSLog(@"macam: Lifeview USB CapView");
#endif
            break;
        case 0:
        default:
            // ditect i2c id
            for(i = 0; i <= 7; ++i) {
                buf[0] = OV7610_I2C_WRITE_ID + i * 4;
                [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_SID buf:buf len:1];
                if([self i2cRead2] != 0xff)
                    break;
            }
            if(i <= 7) {
                sensorWrite = OV7610_I2C_WRITE_ID + i * 4;
                sensorRead = OV7610_I2C_READ_ID + i * 4;
                [self seti2cid];

                // check Common I version ID
                if(([self i2cRead:0x29] & 0x03) == 0x03) {
                    sensorType = SENS_OV7610;
#ifdef OV511_DEBUG
                    NSLog(@"macam: OV511 Custom ID %d with OV7610", buf[0]);
#endif
                } else {
                    sensorType = SENS_OV7620;
#ifdef OV511_DEBUG
                    NSLog(@"macam: OV511 Custom ID %d with OV7620", buf[0]);
#endif
                }
            } else {
                return CameraErrorInternal;
            }
            break;
    }

//set internals
    camHFlip=NO;			//Some defaults that can be changed during startup
    chunkHeader=0;
    chunkFooter=0;
//set camera video defaults
    if(sensorType == SENS_SAA7111A_WITH_FI1236MK2 || sensorType == SENS_SAA7111A)
        [self setBrightness:0.584f];
    else if(sensorType == SENS_OV7610 || sensorType == SENS_OV7620)
        [self setBrightness:0.0f];
//    [self setContrast:0.567f];
//    [self setGamma:0.5f];
//    [self setSaturation:0.630f];
//    [self setGain:0.5f];
//    [self setShutter:0.5f];
    [self setAutoGain:YES];

    return [super startupWithUsbDeviceRef:usbDeviceRef];
}

- (void) dealloc {
    [self usbCloseConnection];
    [super dealloc];
}

- (BOOL) canSetBrightness { return YES; }
- (void) setBrightness:(float)v{
    UInt8 b;
    if (![self canSetBrightness]) return;
    if(sensorType == SENS_SAA7111A_WITH_FI1236MK2 || sensorType == SENS_SAA7111A) {
        b=SAA7111A_BRIGHTNESS(CLAMP_UNIT(v));
        if ((b!=SAA7111A_BRIGHTNESS(brightness)))
            [self i2cWrite:OV7610_REG_BRT val:b];
    } else if(sensorType == SENS_OV7610 || sensorType == SENS_OV7620) {
        b=OV7610_BRIGHTNESS(CLAMP_UNIT(v));
        if ((b!=OV7610_BRIGHTNESS(brightness)))
            [self i2cWrite:0 val:b];
    }
    [super setBrightness:v];
}

- (BOOL) canSetContrast { return NO; }
- (void) setContrast:(float)v {
    UInt8 b;
    if (![self canSetContrast]) return;
    b=SAA7111A_CONTRAST(CLAMP_UNIT(v));
    if (b!=SAA7111A_CONTRAST(contrast))
        [self i2cWrite:0x0b val:b];
    [super setContrast:v];
}

- (BOOL) canSetSaturation { return NO; }
- (void) setSaturation:(float)v {
    UInt8 b;
    if (![self canSetSaturation]) return;
    b=SAA7111A_SATURATION(CLAMP_UNIT(v));
    if (b!=SAA7111A_SATURATION(saturation))
        [self i2cWrite:OV7610_REG_SAT val:b];
    [super setSaturation:v];
}

- (BOOL) canSetGamma { return NO; }
- (void) setGamma:(float)v {
    UInt8 b;
    if (![self canSetGamma]) return;
    b=SAA7111A_GAMMA(CLAMP_UNIT(v));
//    if (b!=SAA7111A_GAMMA(gamma))
//        [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_GAMMA wIndex:INTF_CONTROL buf:&b len:1];
    [super setGamma:v];
}

- (BOOL) canSetShutter { return NO; }
- (void) setShutter:(float)v {
    UInt8 b[2];
    if (![self canSetShutter]) return;
    b[0]=SAA7111A_SHUTTER(CLAMP_UNIT(v));
//    if (b[0]!=SAA7111A_SHUTTER(shutter))
//        [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_SHUTTER wIndex:INTF_CONTROL buf:b len:2];
    [super setShutter:v];
}

- (BOOL) canSetGain { return NO; }
- (void) setGain:(float)v {
    UInt8 b;
    if (![self canSetGain]) return;
    b=SAA7111A_GAIN(CLAMP_UNIT(v));
//    if (b!=SAA7111A_GAIN(gain))
//        [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_GAIN wIndex:INTF_CONTROL buf:&b len:1];
    [super setGain:v];
}

- (BOOL) canSetAutoGain { return NO; }
- (void) setAutoGain:(BOOL)v {
    UInt8 b;
    UInt8 gb;
    UInt8 sb[2];
    if (![self canSetAutoGain]) return;
    b=SAA7111A_AUTOGAIN(v);
    gb=SAA7111A_GAIN(gain);
    sb[0]=SAA7111A_SHUTTER(shutter);
    if (b!=SAA7111A_AUTOGAIN(autoGain)) {
//        [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_AUTOGAIN wIndex:INTF_CONTROL buf:&b len:1];
//        if (!v) {
//            [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_GAIN wIndex:INTF_CONTROL buf:&gb len:1];
//            [self usbWriteCmdWithBRequest:GRP_SET_LUMA wValue:SEL_SHUTTER wIndex:INTF_CONTROL buf:sb len:2];
//        }
    }
    [super setAutoGain:v];
}    

- (BOOL)canSetHFlip { return NO; }

- (WhiteBalanceMode) defaultWhiteBalanceMode { return WhiteBalanceAutomatic; }

- (void) setImageBuffer:(unsigned char*)buffer bpp:(short)bpp rowBytes:(long)rb{
    if (buffer==NULL) return;
    if ((bpp!=3)&&(bpp!=4)) return;
    if (rb<0) return;
    [super setImageBuffer:buffer bpp:bpp rowBytes:rb];
}

- (short) maxCompression {
#ifdef USE_COMPRESS
    return 1;
#else
    return 0;
#endif
}

- (BOOL) supportsResolution:(CameraResolution)res fps:(short)rate {
    switch (res) {
        case ResolutionSIF:
            if (rate>10) return NO;
            return YES;
            break;
        default: return NO;
    }
}

- (CameraResolution) defaultResolutionAndRate:(short*)rate {
    *rate=5;
    return ResolutionSIF;
}

- (short) defaultAltInterface {
    return 1;
}

- (short) packetSize:(short)altInterface {
    short size;
    switch(altInterface) {
        case 6:
            size = 257;
            break;
        case 5:
            size = 513;
            break;
        case 4:
            size = 512;
            break;
        case 3:
            size = 769;
            break;
        case 2:
            size = 768;
            break;
        case 1:
            size = 993;
            break;
        case 0:
            size = 992;
            break;
    }
    return size;
}

- (BOOL) setupGrabContext {
    long i,j;
    AbsoluteTime at;
    IOReturn err;

    BOOL ok=YES;
    [self cleanupGrabContext];					//cleanup in case there's something left in here

    usbAltInterface = [self defaultAltInterface];
    usbFrameBytes = [self packetSize:usbAltInterface];

    grabContext.bytesPerFrame=usbFrameBytes;
#ifdef USE_COMPRESS
    if(compression)
        grabContext.framesPerTransfer=256;
    else
        grabContext.framesPerTransfer=192;
#else
    grabContext.framesPerTransfer=192;
#endif
    grabContext.framesInRing=grabContext.framesPerTransfer*16;
    grabContext.concurrentTransfers=3;
    grabContext.finishedTransfers=0;
    grabContext.bytesPerChunk=[self height]*[self width]*6/4+chunkHeader+chunkFooter;	//4 yuv pixels fit into 4 bytes  + header + footer
    grabContext.nextReadOffset=0;
    grabContext.bufferLength=grabContext.bytesPerFrame*grabContext.framesInRing+grabContext.bytesPerChunk;
    grabContext.droppedFrames=0;
    grabContext.currentChunkStart=-1;
    grabContext.bytesInChunkSoFar=0;
    grabContext.maxCompleteChunks=3;
    grabContext.currCompleteChunks=0;
    grabContext.intf=intf;
    grabContext.shouldBeGrabbing=&shouldBeGrabbing;
    grabContext.err=CameraErrorOK;
//preliminary set more complicated parameters to NULL, so there are no stale pointers if setup fails
    grabContext.initiatedUntil=0;
    grabContext.chunkListLock=NULL;
    grabContext.chunkReadyLock=NULL;
    grabContext.buffer=NULL;
    grabContext.transferContexts=NULL;
    grabContext.chunkList=NULL;
//Setup locks
    if (ok) {
        grabContext.chunkListLock=[[NSLock alloc] init];
        if ((grabContext.chunkListLock)==NULL) ok=NO;
    }
    if (ok) {
        grabContext.chunkReadyLock=[[NSLock alloc] init];
        if ((grabContext.chunkReadyLock)==NULL) ok=NO;
        else {					//locked by standard, will be unlocked by isocComplete
            [grabContext.chunkReadyLock tryLock];
        }
    }
//Setup ring buffer
    if (ok) {
        MALLOC(grabContext.buffer,void*,grabContext.bufferLength,"setupGrabContext-buffer");
        if ((grabContext.buffer)==NULL) ok=NO;
    }
//Setup ring buffer
    if (ok) {
        MALLOC(grabContext.chunkBuffer,void*,[self height]*[self width]*12/8,"setupGrabContext-fbuffer");
        if ((grabContext.chunkBuffer)==NULL) ok=NO;
    }
//Setup compress buffer
    if (ok) {
        MALLOC(grabContext.tmpBuffer,void*,[self height]*[self width]*12/8,"setupGrabContext-tbuffer");
        if ((grabContext.tmpBuffer)==NULL) ok=NO;
    }
//Setup transfer contexts
    if (ok) {
        MALLOC(grabContext.transferContexts,OV511TransferContext*,sizeof(OV511TransferContext)*grabContext.concurrentTransfers,"setupGrabContext-OV511TransferContext");
        if ((grabContext.transferContexts)==NULL) ok=NO;
    }
    if (ok) {
        for (i=0;i<grabContext.concurrentTransfers;i++) {
            grabContext.transferContexts[i].frameList=NULL;
            grabContext.transferContexts[i].bufferOffset=0;
        }
        for (i=0;(i<grabContext.concurrentTransfers)&&ok;i++) {
            MALLOC(grabContext.transferContexts[i].frameList,IOUSBIsocFrame*,sizeof(IOUSBIsocFrame)*grabContext.framesPerTransfer,"setupGrabContext-frameList");
            if ((grabContext.transferContexts[i].frameList)==NULL) ok=NO;
            else {
                for (j=0;j<grabContext.framesPerTransfer;j++) {
                    grabContext.transferContexts[i].frameList[j].frReqCount=grabContext.bytesPerFrame;
                    grabContext.transferContexts[i].frameList[j].frActCount=0;
                    grabContext.transferContexts[i].frameList[j].frStatus=0;
                }
            }
        }
    }
//The list of ready-to-decode chunks
    if (ok) {
        MALLOC(grabContext.chunkList,OV511CompleteChunk*,sizeof(OV511CompleteChunk)*grabContext.maxCompleteChunks,"setupGrabContext-chunkList");
        if ((grabContext.chunkList)==NULL) ok=NO;
    }
//Get usb timing info
    if (ok) {
        err=(*intf)->GetBusFrameNumber(intf, &(grabContext.initiatedUntil), &at);
        CheckError(err,"GetBusFrameNumber");
        if (err) ok=NO;
        grabContext.initiatedUntil+=50;	//give it a little time to start
   }
    if (!ok) [self cleanupGrabContext];				//We failed. Throw away the garbage

    if(ok) {
        UInt8 buf[16];
 //       CameraError ret=CameraErrorOK;

        buf[0] = 0x01;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_PKSZ buf:buf len:1];

        buf[0] = 0x00;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_PKFMT buf:buf len:1];

        buf[0] = 0x3d;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_RST buf:buf len:1];

        buf[0] = 0x00;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_RST buf:buf len:1];

        /* set YUV 4:2:0 format, Y channel LPF */
        buf[0] = 0x01;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_M400 buf:buf len:1];

        buf[0] = 0x03;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_M420_YFIR buf:buf len:1];

        /* disable snapshot */
        buf[0] = 0x00;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_SNAP buf:buf len:1];

        /* disable compression */
        buf[0] = 0x00;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_CE_EN buf:buf len:1];

        if(sensorType == SENS_OV7610 || sensorType == SENS_OV7620) {
            [self i2cWrite:OV7610_REG_RWB val:0x05];
            [self i2cWrite:OV7610_REG_EC val:0xff];
            [self i2cWrite:OV7610_REG_COMB val:0x01];
            [self i2cWrite:OV7610_REG_FD val:0x06];
            [self i2cWrite:OV7610_REG_COME val:0x1c];
            [self i2cWrite:OV7610_REG_COMF val:0x90];
            [self i2cWrite:OV7610_REG_ECW val:0x2e];
            [self i2cWrite:OV7610_REG_ECB val:0x7c];
            [self i2cWrite:OV7610_REG_COMH val:0x24];
            [self i2cWrite:OV7610_REG_EHSH val:0x04|0x80];
            [self i2cWrite:OV7610_REG_EHSL val:0xac];
            [self i2cWrite:OV7610_REG_EXBK val:0xfe];
            // Auto brightness enabled
            [self i2cWrite:OV7610_REG_COMJ val:0x91];
            [self i2cWrite:OV7610_REG_BADJ val:0x48];
            [self i2cWrite:OV7610_REG_COMK val:0x81];
            [self i2cWrite:OV7610_REG_GAM val:0x04];

            // himori add
            [self i2cWrite:OV7610_REG_GC val:0x00];
            [self i2cWrite:OV7610_REG_BLU val:0x80];
            [self i2cWrite:OV7610_REG_RED val:0x80];
            [self i2cWrite:OV7610_REG_SAT val:0xc0];
            [self i2cWrite:OV7610_REG_BRT val:0x60];
            [self i2cWrite:OV7610_REG_AS val:0x00];
            [self i2cWrite:OV7610_REG_BBS val:0x24];
            [self i2cWrite:OV7610_REG_RBS val:0x24];
            [self i2cWrite:OV7610_REG_RBS val:0x24];

            // SIF
            [self i2cWrite:OV7610_REG_SYN_CLK val:0x01];
            [self i2cWrite:OV7610_REG_COMA val:0x04];
            [self i2cWrite:OV7610_REG_COMC val:0x24];
            [self i2cWrite:OV7610_REG_COML val:0x9e];

        } else {	// SAA7111A

            [self i2cWrite:0x06 val:0xce];
            [self i2cWrite:0x07 val:0x00];
            [self i2cWrite:0x10 val:0x44];
            [self i2cWrite:0x0e val:0x01];
            [self i2cWrite:0x00 val:0x00];
            [self i2cWrite:0x01 val:0x00];
            [self i2cWrite:0x03 val:0x23];
            [self i2cWrite:0x04 val:0x00];
            [self i2cWrite:0x05 val:0x00];
//            [self i2cWrite:0x08 val:0xc8];
            [self i2cWrite:0x08 val:0x88];
            [self i2cWrite:0x09 val:0x01];
            [self i2cWrite:0x0a val:0x95];
            [self i2cWrite:0x0b val:0x48];
            [self i2cWrite:0x0c val:0x50];
            [self i2cWrite:0x0d val:0x00];
            [self i2cWrite:0x0f val:0x00];
            [self i2cWrite:0x11 val:0x0c];
            [self i2cWrite:0x12 val:0x00];
            [self i2cWrite:0x13 val:0x00];
            [self i2cWrite:0x14 val:0x00];
            [self i2cWrite:0x15 val:0x00];
            [self i2cWrite:0x16 val:0x00];
            [self i2cWrite:0x17 val:0x00];

            [self i2cWrite:0x02 val:0xc0];

#ifdef OV511_DEBUG
            NSLog(@"SAA7111A status = %02x\n",  [self i2cRead:0x1f]);
#endif
        }

#ifdef USE_COMPRESS
        if(compression) {
            /* enable compression */
            [self ov511_upload_quan_tables];
            buf[0] = 0x07;
            [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_CE_EN buf:buf len:1];
            buf[0] = 0x03;
            [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_LT_EN buf:buf len:1];
        }
#endif

        if(sensorType == SENS_SAA7111A) {
            buf[0] = 0x00;
            [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_DLYM buf:buf len:1];

            buf[0] = 0x00;
            [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_PEM buf:buf len:1];
        }

        buf[0] = ([self width] >> 3) - 1;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_PXCNT buf:buf len:1];

        buf[0] = ([self height] >> 3) - 1;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_LNCNT buf:buf len:1];


        buf[0] = 0x00;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_PXDV buf:buf len:1];

        buf[0] = 0x00;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_LNDV buf:buf len:1];

        buf[0] = 0x01;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_ENFC buf:buf len:1];

        /* set FIFO format */
        buf[0] = (usbFrameBytes - 1) / 32;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_PKSZ buf:buf len:1];

        buf[0] = 0x03;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_PKFMT buf:buf len:1];

        /* select the fifosize alternative */
//        if (![self usbSetAltInterfaceTo:7 testPipe:1]) return CameraErrorNoBandwidth;

        /* reset the device again */
        buf[0] = 0x3f;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_RST buf:buf len:1];

        buf[0] = 0x00;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_RST buf:buf len:1];
    }

    return ok;
}

- (BOOL) cleanupGrabContext {
    long l;
    if (grabContext.buffer) {				//dispose the buffer
        FREE(grabContext.buffer,"cleanupGrabContext-buffer");
        grabContext.buffer=NULL;
    }
    if (grabContext.transferContexts) {			//if we have transfer contexts
        for (l=0;l<grabContext.concurrentTransfers;l++) {	//iterate through the contexts and throw them away
            if (grabContext.transferContexts[l].frameList) {
                FREE(grabContext.transferContexts[l].frameList,"cleanupGrabContext-frameList");
                grabContext.transferContexts[l].frameList=NULL;
            }
        }
        FREE(grabContext.transferContexts,"cleanupgrabContext.transferContexts");
        grabContext.transferContexts=NULL;
    }
    if (grabContext.chunkList) {				//throw away the list of ready-to-decode chunks
        FREE(grabContext.chunkList,"cleanupGrabContext-chunkList");
        grabContext.chunkList=NULL;
    }
    if (grabContext.chunkListLock) {			//throw away the chunk list access lock
        [grabContext.chunkListLock release];
        grabContext.chunkListLock=NULL;
    }
    if (grabContext.chunkReadyLock) {			//throw away the chunk ready gate lock
        [grabContext.chunkReadyLock release];
        grabContext.chunkReadyLock=NULL;
    }
    return YES;
}

//StartNextIsochRead and isocComplete refer to each other, so here we need a declaration
static bool StartNextIsochRead(OV511GrabContext* grabContext, int transferIdx);

static void isocComplete(void *refcon, IOReturn result, void *arg0) {
    int i,j;
    OV511GrabContext* grabContext=(OV511GrabContext*)refcon;
    IOUSBIsocFrame* myFrameList=(IOUSBIsocFrame*)arg0;
    short transferIdx=0;
    bool frameListFound=false;
    int currStart;

    if (result) {						//USB error handling
        *(grabContext->shouldBeGrabbing)=NO;			//We'll stop no matter what happened
        if (!grabContext->err) {
            if (result==kIOReturnOverrun) grabContext->err=CameraErrorTimeout;	//We didn't setup the transfer in time
            else grabContext->err=CameraErrorUSBProblem;			//Probably some communication error
        }
        if (result!=kIOReturnOverrun) CheckError(result,"isocComplete");		//Other error: log to console
    }
    
    if (*(grabContext->shouldBeGrabbing)) {						//look up which transfer we are
        while ((!frameListFound)&&(transferIdx<grabContext->concurrentTransfers)) {	
            if ((grabContext->transferContexts[transferIdx].frameList)==myFrameList) frameListFound=true;
            else transferIdx++;
        }
        if (!frameListFound) {
#ifdef VERBOSE
            NSLog(@"isocComplete: Didn't find my frameList");
#endif
            *(grabContext->shouldBeGrabbing)=NO;
        }
    }

    /* find start packet */
/*    grabContext->currentChunkStart = -1;*/
    currStart = -1;
    for(i = 0; i < grabContext->framesPerTransfer; ++i) {
        if(*(grabContext->buffer + grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i + 0) == 00 &&
            *(grabContext->buffer + grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i + 1) == 00 &&
            *(grabContext->buffer + grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i + 2) == 00 &&
            *(grabContext->buffer + grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i + 3) == 00 &&
            *(grabContext->buffer + grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i + 4) == 00 &&
            *(grabContext->buffer + grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i + 5) == 00 &&
            *(grabContext->buffer + grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i + 6) == 00 &&
            *(grabContext->buffer + grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i + 7) == 00 &&
            (*(grabContext->buffer + grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i + 8) & 0x08)) {
            if(*(grabContext->buffer + grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i + (grabContext->bytesPerFrame-1)) == 00) {
                grabContext->currentChunkStart = grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame * i;
                currStart = i;
            } else {
                [grabContext->chunkListLock lock];		//Enter critical section
                if(currStart >= 0) {
/*                    NSLog(@"isocComplete: ReadIsochPipeAsync have complete freame in buffer [%d] %d - %d : %02x %02x", transferIdx, currStart, i,
                        *(grabContext->buffer+grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame*i+8),
                        *(grabContext->buffer+grabContext->transferContexts[transferIdx].bufferOffset + 											grabContext->bytesPerFrame*i+(grabContext->bytesPerFrame-1)));
*/
                        if (grabContext->currCompleteChunks>=grabContext->maxCompleteChunks) {	//overflow: throw away oldest chunk
                            for (j=1;j<grabContext->maxCompleteChunks;j++) {
                                grabContext->chunkList[j-1]=grabContext->chunkList[j];
                            }
                            grabContext->currCompleteChunks--;
                        }

                        grabContext->chunkList[grabContext->currCompleteChunks].start=grabContext->currentChunkStart;	//insert new chunk
                        grabContext->chunkList[grabContext->currCompleteChunks].end=
                            grabContext->transferContexts[transferIdx].bufferOffset+i*grabContext->bytesPerFrame+grabContext->bytesPerFrame;
                        grabContext->chunkList[grabContext->currCompleteChunks].isSeparate=false;
                        grabContext->currCompleteChunks++;

                } else {
/*                    NSLog(@"isocComplete: ReadIsochPipeAsync have incomplete freame in buffer [%d] - %d : %02x %02x", transferIdx, i,
                        *(grabContext->buffer+grabContext->transferContexts[transferIdx].bufferOffset + grabContext->bytesPerFrame*i+8),
                        *(grabContext->buffer+grabContext->transferContexts[transferIdx].bufferOffset + 											grabContext->bytesPerFrame*i+(grabContext->bytesPerFrame-1)));
*/
                        if (grabContext->currCompleteChunks>=grabContext->maxCompleteChunks) {	//overflow: throw away oldest chunk
                            for (j=1;j<grabContext->maxCompleteChunks;j++) {
                                grabContext->chunkList[j-1]=grabContext->chunkList[j];
                            }
                            grabContext->currCompleteChunks--;
                        }

                        grabContext->chunkList[grabContext->currCompleteChunks].start=grabContext->currentChunkStart;	//insert new chunk
                        grabContext->chunkList[grabContext->currCompleteChunks].end=
                            grabContext->currentChunkEnd;
                        grabContext->chunkList[grabContext->currCompleteChunks].start2=grabContext->transferContexts[transferIdx].bufferOffset;	//insert new chunk
                        grabContext->chunkList[grabContext->currCompleteChunks].end2=
                            grabContext->transferContexts[transferIdx].bufferOffset+i*grabContext->bytesPerFrame+grabContext->bytesPerFrame;
                        grabContext->chunkList[grabContext->currCompleteChunks].isSeparate=true;
                         grabContext->currCompleteChunks++;
                }
                [grabContext->chunkListLock unlock];		//exit critical section
                [grabContext->chunkReadyLock tryLock];		//try to wake up the decoder
                [grabContext->chunkReadyLock unlock];
                grabContext->currentChunkStart = -1;
                currStart = -1;
            }
        }
    }
    if(grabContext->currentChunkStart >= 0) {
        grabContext->currentChunkEnd = grabContext->transferContexts[transferIdx].bufferOffset + grabContext->framesPerTransfer * grabContext->bytesPerFrame;
    }

    if (*(grabContext->shouldBeGrabbing)) {	//initiate next transfer
        if (!StartNextIsochRead(grabContext,transferIdx)) *(grabContext->shouldBeGrabbing)=NO;
    }
    if (!(*(grabContext->shouldBeGrabbing))) {	//on error: collect finished transfers and exit if all transfers have ended
        grabContext->finishedTransfers++;
        if ((grabContext->finishedTransfers)>=(grabContext->concurrentTransfers)) {
            CFRunLoopStop(CFRunLoopGetCurrent());
        }
    }
}

static bool StartNextIsochRead(OV511GrabContext* grabContext, int transferIdx) {
    IOReturn err;
    long bytesInRing=grabContext->framesInRing*grabContext->bytesPerFrame;

    grabContext->transferContexts[transferIdx].bufferOffset = grabContext->nextReadOffset;
    *(grabContext->buffer+grabContext->transferContexts[transferIdx].bufferOffset) = 0xff;
    err=(*(grabContext->intf))->ReadIsochPipeAsync(grabContext->intf,
                                    1,
                                    grabContext->buffer+grabContext->transferContexts[transferIdx].bufferOffset,
                                    grabContext->initiatedUntil,
                                    grabContext->framesPerTransfer,
                                    grabContext->transferContexts[transferIdx].frameList,
                                    (IOAsyncCallback1)(isocComplete),
                                    grabContext);
    switch (err) {
        case 0:
            grabContext->initiatedUntil+=grabContext->framesPerTransfer;	//update frames
            grabContext->nextReadOffset+=grabContext->framesPerTransfer*grabContext->bytesPerFrame;	//update buffer offset
            if ((grabContext->nextReadOffset)>=bytesInRing) {			//wrap around ring (it's a ring buffer)
                grabContext->nextReadOffset-=bytesInRing;
                if (grabContext->nextReadOffset) {
#ifdef VERBOSE
                    NSLog(@"StartNextIsochRead: ring buffer is not properly wrapping");
#endif
                    err=1;
                }
            }
            break;
        case 0x1000003:
            if (!grabContext->err) grabContext->err=CameraErrorNoCam;
            break;
        default:
            CheckError(err,"StartNextIsochRead-ReadIsochPipeAsync");
            if (!grabContext->err) grabContext->err=CameraErrorUSBProblem;
                break;
    }
    return !err;
}

- (void) grabbingThread:(id)data {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    long i;
    IOReturn err;
    CFRunLoopSourceRef cfSource;
    bool ok=true;

    ChangeMyThreadPriority(10);	//We need to update the isoch read in time, so timing is important for us

    if (![self usbSetAltInterfaceTo:usbAltInterface testPipe:1]) {
        if (!grabContext.err) grabContext.err=CameraErrorNoBandwidth;	//probably no bandwidth
        ok=NO;
    }

    if (!isUSBOK) { grabContext.err=CameraErrorNoCam; ok=NO; }

    err = (*intf)->CreateInterfaceAsyncEventSource(intf, &cfSource);	//Create an event source
    CheckError(err,"CreateInterfaceAsyncEventSource");
    CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//Add it to our run loop
    
    if (!isUSBOK) { grabContext.err=CameraErrorNoCam; ok=NO; }
    
    for (i=0;(i<grabContext.concurrentTransfers)&&ok;i++) {	//Initiate transfers
        ok=StartNextIsochRead(&grabContext,i);
    }
    if (ok) CFRunLoopRun();					//Do our run loop

    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	//remove the event source

    if (![self usbSetAltInterfaceTo:0 testPipe:0]) {
        if (!grabContext.err) grabContext.err=CameraErrorNoBandwidth;	//probably no bandwidth
        ok=NO;
    }

    shouldBeGrabbing=NO;			//error in grabbingThread or abort? initiate shutdown of everything else
    [grabContext.chunkReadyLock unlock];	//give the decodingThread a chance to abort
    [pool release];
    grabbingThreadRunning=NO;
    [NSThread exit];
}

- (CameraError) decodingThread {
    int lineExtra;
    OV511CompleteChunk currChunk;
    long i;
    int cursize;
    short width=[self width];	//Should remain constant during grab
    short height=[self height];	//Should remain constant during grab
    CameraError err=CameraErrorOK;
    grabbingThreadRunning=NO;

    if (![self setupGrabContext]) {
        err=CameraErrorNoMem;
        shouldBeGrabbing=NO;
    }

    if (shouldBeGrabbing) {
        grabbingThreadRunning=YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];    //start grabbingThread
    }

    while (shouldBeGrabbing) {
        [grabContext.chunkReadyLock lock];				//wait for ready-to-decode chunks
        while ((shouldBeGrabbing)&&(grabContext.currCompleteChunks>0)) {	//decode all chunks unless we should stop grabbing
            [grabContext.chunkListLock lock];			//lock for access to chunk list
            currChunk=grabContext.chunkList[0];			//take first (oldest) chunk
            for(i=1;i<grabContext.currCompleteChunks;i++) {		//all others go one down
                grabContext.chunkList[i-1]=grabContext.chunkList[i];
            }
            grabContext.currCompleteChunks--;			//we have taken one from the list
            [grabContext.chunkListLock unlock];			//we're done accessing the chunk list.
//            NSLog(@"decodingThread: %d", currChunk.isSeparate);

//            if(currChunk.end < currChunk.start)
//            NSLog(@"decodingThread: %d %d %d %d %d %d",
//                currChunk.start, currChunk.end, cursize, currChunk.isSeparate, currChunk.start2, currChunk.end2); 
if(currChunk.start >= 0) {
            if (nextImageBufferSet) {				//do we have a target to decode into?
                [imageBufferLock lock];				//lock image buffer access
                if (nextImageBuffer!=NULL) {
#if 0
                    if (currChunk.end<currChunk.start) {		//does the chunk wrap?
                        memcpy(grabContext.buffer+grabContext.framesInRing*grabContext.bytesPerFrame,
                               grabContext.buffer,
                               currChunk.end);		//Copy the second part at the end of the first part (into the Q-buffer appendix)
                    }
#endif
#ifdef USE_COMPRESS
                    if(compression) {
                        grabContext.tmpLength = 0;
                        // first block
                        tmpcopy32(grabContext.buffer+currChunk.start, 9, grabContext.bytesPerFrame, grabContext.tmpBuffer, &grabContext.tmpLength);
                        if(currChunk.isSeparate) {
                        for(i=1;currChunk.start + grabContext.bytesPerFrame*i < currChunk.end; ++i)
                            tmpcopy32(grabContext.buffer+currChunk.start+grabContext.bytesPerFrame*i, 0, grabContext.bytesPerFrame,
                                grabContext.tmpBuffer, &grabContext.tmpLength);
                        } else {
                        for(i=1;currChunk.start + grabContext.bytesPerFrame*i < currChunk.end-grabContext.bytesPerFrame; ++i)
                            tmpcopy32(grabContext.buffer+currChunk.start+grabContext.bytesPerFrame*i, 0, grabContext.bytesPerFrame,
                                grabContext.tmpBuffer, &grabContext.tmpLength);

NSLog(@"OV511:%d %d %x", (*(grabContext.buffer+currChunk.start+grabContext.bytesPerFrame*i+9)+1)<<3,
    (*(grabContext.buffer+currChunk.start+grabContext.bytesPerFrame*i+10)+1)<<3,
    *(grabContext.buffer+currChunk.start+grabContext.bytesPerFrame*i+11));
// EOF packet
//                        tmpcopy32(grabContext.buffer+currChunk.start+grabContext.bytesPerFrame*i, 0, grabContext.bytesPerFrame,
//                            grabContext.tmpBuffer, &grabContext.tmpLength);
                        }
                        // second block
                        if(currChunk.isSeparate) {
                           for(i=0;currChunk.start2 + grabContext.bytesPerFrame*i < currChunk.end2-grabContext.bytesPerFrame; ++i)
                                tmpcopy32(grabContext.buffer+currChunk.start2+grabContext.bytesPerFrame*i, 0, grabContext.bytesPerFrame,
                                    grabContext.tmpBuffer, &grabContext.tmpLength);

NSLog(@"OV511:%d %d %x", (*(grabContext.buffer+currChunk.start2+grabContext.bytesPerFrame*i+9)+1)<<3,
    (*(grabContext.buffer+currChunk.start2+grabContext.bytesPerFrame*i+10)+1)<<3,
    *(grabContext.buffer+currChunk.start2+grabContext.bytesPerFrame*i+11));

// EOF packet
//                            tmpcopy32(grabContext.buffer+currChunk.start2+grabContext.bytesPerFrame*i, 0, grabContext.bytesPerFrame,
//                                grabContext.tmpBuffer, &grabContext.tmpLength);
                        }
{
                        int size = Decompress420(grabContext.tmpBuffer, grabContext.chunkBuffer, NULL, width, height, grabContext.tmpLength);
//NSLog(@"OV511:org size %d decomp size = %d", grabContext.tmpLength,size);
}
                    } else {
#endif
//                    chunkBuffer=grabContext.buffer+currChunk.start+chunkHeader;	//Our chunk starts here
                        cursize = 0;
                        blockCopy(grabContext.bytesPerFrame-9-1, &cursize, grabContext.buffer+currChunk.start+9, grabContext.chunkBuffer,
                            width, height);
                        for(i=1;currChunk.start + grabContext.bytesPerFrame*i < currChunk.end; ++i)
                            blockCopy(grabContext.bytesPerFrame-1, &cursize, grabContext.buffer+currChunk.start+grabContext.bytesPerFrame*i,
                                grabContext.chunkBuffer, width, height);
                        if(currChunk.isSeparate)
                            for(i=0;currChunk.start2 + grabContext.bytesPerFrame*i < currChunk.end2; ++i)
                                blockCopy(grabContext.bytesPerFrame-1, &cursize, grabContext.buffer+currChunk.start2+grabContext.bytesPerFrame*i,
                                    grabContext.chunkBuffer, width, height);
//                    lineExtra=nextImageBufferRowBytes-width*nextImageBufferBPP;	//bytes to skip after each line in target buffer
                    }
                    lineExtra = 0;
                    yuv2rgb (width,height,YUVOV420Style,grabContext.chunkBuffer,nextImageBuffer,
                             nextImageBufferBPP,0,lineExtra,hFlip!=camHFlip);	//decode
#ifdef USE_COMPRESS
                }
#endif
                lastImageBuffer=nextImageBuffer;			//Copy nextBuffer info into lastBuffer
                lastImageBufferBPP=nextImageBufferBPP;
                lastImageBufferRowBytes=nextImageBufferRowBytes;
                nextImageBufferSet=NO;				//nextBuffer has been eaten up
                [imageBufferLock unlock];				//release lock
                [self mergeImageReady];				//notify delegate about the image. perhaps get a new buffer
            }
} else {
    NSLog(@"OV511:error chunk s = %d e =%d s2 = %d e2 = %d", currChunk.start,currChunk.end,currChunk.start2,currChunk.end2);
}
        }
    }
    while (grabbingThreadRunning) {}
    if (!err) err=grabContext.err;
    [self cleanupGrabContext];				//grabbingThread doesn't need the context any more since it's done
    return err;
}
    
/*
    2 bytes write to i2c on ov511 bus
*/

- (int) i2cWrite:(UInt8) reg val:(UInt8) val{
    UInt8 buf[16];

    buf[0] = reg;
    if(![self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_SWA buf:buf len:1]) {
#ifdef VERBOSE
        NSLog(@"OV511:i2cWrite:usbWriteCmdWithBRequest error");
#endif
        return -1;
    }

    buf[0] = val;
    if(![self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_SDA buf:buf len:1]) {
#ifdef VERBOSE
        NSLog(@"OV511:i2cWrite:usbWriteCmdWithBRequest error");
#endif
        return -1;
    }

    buf[0] = 0x01;
    if(![self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1]) {
#ifdef VERBOSE
        NSLog(@"OV511:i2cWrite:usbWriteCmdWithBRequest error");
#endif
        return -1;
    }

    /* wait until bus idle */
    do {
        if(![self usbReadCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1]) {
#ifdef VERBOSE
            NSLog(@"OV511:i2cWrite:usbReadCmdWithBRequest error");
#endif
            return -1;
        }
    } while((buf[0] & 0x01) == 0);

    /* no retries */
    if((buf[0] & 0x02) != 0)
      return -1;

    return 0;
}

/*
    byte read from i2c spesfic id on ov511 bus
*/

- (int) i2cRead:(UInt8) reg {
    UInt8 buf[16];
    UInt8 val;
    int retries = 3;

    while(--retries >= 0) {

        /* wait until bus idle */
        do {
            [self usbReadCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];
        } while((buf[0] & 0x01) == 0);

        /* perform a dummy write cycle to set the register */
        buf[0] = reg;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_SMA buf:buf len:1];

        /* initiate the dummy write */
        buf[0] = 0x03;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];

        /* wait until bus idle */
        do {
            [self usbReadCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];
        } while((buf[0] & 0x01) == 0);

        /* no retries */
        if((buf[0] & 0x02) == 0)
            break;
    }

    if(retries < 0)
        return -1;

    retries = 3;
    while(--retries >= 0) {
        /* initiate read */
        buf[0] = 0x05;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];

        /* wait until bus idle */
        do {
            [self usbReadCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];
        } while((buf[0] & 0x01) == 0);

        if((buf[0] & 0x02) == 0)
            break;

        /* abort I2C bus before retrying */
        buf[0] = 0x05;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];
    }
 
    if(retries < 0)
        return -1;

    /* retrieve data */
    [self usbReadCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_SDA buf:buf len:1];
    val = buf[0];

    buf[0] = 0x05;
    [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];

    return val;
}

- (int) i2cRead2 {
    UInt8 buf[16];
    UInt8 val;
    int retries = 3;

    while(--retries >= 0) {
        /* initiate read */
        buf[0] = 0x05;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];

        /* wait until bus idle */
        do {
            [self usbReadCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];
        } while((buf[0] & 0x01) == 0);

        if((buf[0] & 0x02) == 0)
            break;

        /* abort I2C bus before retrying */
        buf[0] = 0x05;
        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];
    }
 
    if(retries < 0)
        return -1;

    /* retrieve data */
    [self usbReadCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_SDA buf:buf len:1];
    val = buf[0];

    buf[0] = 0x05;
    [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_I2C_CONTROL buf:buf len:1];

    return val;
}

- (void) seti2cid {
    UInt8 buf[16];
    /* set I2C write slave ID */
    buf[0] = sensorWrite;
    [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_SID buf:buf len:1];

    /* set I2C read slave ID */
    buf[0] = sensorRead;
    [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:OV511_REG_SRA buf:buf len:1];
}

- (int) ov511_upload_quan_tables{
	unsigned char *pYTable = yQuanTable511;
	unsigned char *pUVTable = uvQuanTable511;
	unsigned char val0, val1;
        UInt8 buf[16];
	int i, reg = OV511_REG_LT_V;

	for (i = 0; i < OV511_QUANTABLESIZE / 2; i++)
	{
		if (ENABLE_Y_QUANTABLE)
		{
			val0 = *pYTable++;
			val1 = *pYTable++;
			val0 &= 0x0f;
			val1 &= 0x0f;
			val0 |= val1 << 4;
                        buf[0] = val0;
                        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:reg buf:buf len:1];
		}

		if (ENABLE_UV_QUANTABLE)
		{
			val0 = *pUVTable++;
			val1 = *pUVTable++;
			val0 &= 0x0f;
			val1 &= 0x0f;
			val0 |= val1 << 4;
                        buf[0] = val0;
                        [self usbWriteCmdWithBRequest:2 wValue:0 wIndex:reg+OV511_QUANTABLESIZE/2 buf:buf len:1];
		}

		reg++;
	}

	return 0;
}

void blockCopy(int buffsize, int *cursize, char *srcbuf, char *distbuf, int width, int height)
{
char *ubase, *vbase, *ybase;
long numblocks, nextsize, numbytes, blockoffset, nextoffset, copysize, rawblocks;
long i;

	ybase = distbuf;
	ubase = distbuf + width * height;
	vbase = distbuf + width * height * 5 / 4;

        rawblocks = width / 8;

	while(buffsize > 0 && *cursize < width * height * 12 / 8) {
		switch((*cursize / 64) % 6) {
		case 0:		/* U */
			numblocks = (*cursize / 384);
			nextsize = 64 - (*cursize % 64);
			do {
				numbytes = (*cursize % 64);
				blockoffset = (numblocks / (rawblocks / 2)) * (64 * (rawblocks / 2)) +
				(numblocks % (rawblocks / 2)) * 8;
				nextoffset = (numbytes / 8) * 8 * (rawblocks / 2) +
					numbytes % 8 + blockoffset;
				copysize = buffsize < (8 - numbytes % 8) ?
					buffsize : (8 - numbytes % 8);
                                for(i = 0; i < copysize; ++i)
                                    *(ubase + nextoffset + i) = *srcbuf++;
				*cursize += copysize;
				buffsize -= copysize;
				nextsize -= copysize;
			} while(nextsize > 0 && buffsize > 0);
			break;
		case 1:		/* V */
			numblocks = (*cursize / 384);
			nextsize = 64 - (*cursize % 64);
			do {
				numbytes = (*cursize % 64);
				blockoffset = (numblocks / (rawblocks / 2)) * (64 * (rawblocks / 2)) +
				(numblocks % (rawblocks / 2)) * 8;
				nextoffset = (numbytes / 8) * 8 * (rawblocks / 2) +
					numbytes % 8 + blockoffset;
				copysize = buffsize < (8 - numbytes % 8) ?
					buffsize : (8 - numbytes % 8);
                                for(i = 0; i < copysize; ++i)
                                    *(vbase + nextoffset + i) = *srcbuf++;
				*cursize += copysize;
				buffsize -= copysize;
				nextsize -= copysize;
			} while(nextsize > 0 && buffsize > 0);
			break;
		default:	/* Y */
			numblocks = (*cursize / 384) * 4 +
				((*cursize / 64) % 6 - 2);
			nextsize = 64 - (*cursize % 64);
			do {
				numbytes = (*cursize % 64);
				blockoffset = (numblocks / rawblocks) * (64 * rawblocks) +
				(numblocks % rawblocks) * 8;
				nextoffset = (numbytes / 8) * 8 * rawblocks +
					numbytes % 8 + blockoffset;
				copysize = buffsize < (8 - numbytes % 8) ?
					buffsize : (8 - numbytes % 8);
                                for(i = 0; i < copysize; ++i)
                                    *(ybase + nextoffset + i) = *srcbuf++;
				*cursize += copysize;
				buffsize -= copysize;
				nextsize -= copysize;
			} while(nextsize > 0 && buffsize > 0);
			break;
		}
	}
}

void tmpcopy32(u_char *buffer, int offset, int size, u_char *tmpbuf, long *tmpsize)
{
int b, in = 0, allzero;

	if (offset) {
		memmove(tmpbuf + *tmpsize,
			buffer + offset, 32 - offset);
		*tmpsize += 32 - offset;	// Bytes out
		in = 32;
	}

	while (in < size - 1) {
		allzero = 1;
		for (b = 0; b < 32; b++) {
			if (buffer[in + b]) {
				allzero = 0;
				break;
			}
		}

		if (allzero) {
			/* Don't copy it */
		} else {
			memmove(tmpbuf + *tmpsize,
				&buffer[in], 32);
			*tmpsize += 32;
		}

		in += 32;
	}
}

@end
