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

#import "MySPCA504Driver.h"
#import "MyCameraCentral.h"
#include "Resolvers.h"
#include "MiscTools.h"

#define VENDOR_SUNPLUS 0x4fc
#define PRODUCT_SPCA504 0x504a

static unsigned char spcaJpegHeader[]={0x04,0x04,0x04,0x05,0x05,0x05,0x06,0x07,0x0c,0x08,0x07,0x07,0x07,0x07,0x0f,0x0b,
    0x0b,0x09,0x0c,0x11,0x0f,0x12,0x12,0x11,0x0f,0x11,0x11,0x13,0x16,0x1c,0x17,0x13,
    0x14,0x1a,0x15,0x11,0x11,0x18,0x21,0x18,0x1a,0x1d,0x1d,0x1f,0x1f,0x1f,0x13,0x17,
    0x22,0x24,0x22,0x1e,0x24,0x1c,0x1e,0x1f,0x1e,0xff,0xdb,0x00,0x43,0x01,0x05,0x05,
    0x05,0x07,0x06,0x07,0x0e,0x08,0x08,0x0e,0x1e,0x14,0x11,0x14,0x1e,0x1e,0x1e,0x1e,
    0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,
    0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,
    0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0xff,0xc0,
    0x00,0x11,0x08,0x03,0xc0,0x04,0xe0,0x03,0x01,0x21,0x00,0x02,0x11,0x01,0x03,0x11,
    0x01,0xff,0xc4,0x00,0x1f,0x00,0x00,0x01,0x05,0x01,0x01,0x01,0x01,0x01,0x01,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,
    0x0a,0x0b,0xff,0xc4,0x00,0xb5,0x10,0x00,0x02,0x01,0x03,0x03,0x02,0x04,0x03,0x05,
    0x05,0x04,0x04,0x00,0x00,0x01,0x7d,0x01,0x02,0x03,0x00,0x04,0x11,0x05,0x12,0x21,
    0x31,0x41,0x06,0x13,0x51,0x61,0x07,0x22,0x71,0x14,0x32,0x81,0x91,0xa1,0x08,0x23,
    0x42,0xb1,0xc1,0x15,0x52,0xd1,0xf0,0x24,0x33,0x62,0x72,0x82,0x09,0x0a,0x16,0x17,
    0x18,0x19,0x1a,0x25,0x26,0x27,0x28,0x29,0x2a,0x34,0x35,0x36,0x37,0x38,0x39,0x3a,
    0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4a,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,
    0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6a,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,
    0x83,0x84,0x85,0x86,0x87,0x88,0x89,0x8a,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,
    0x9a,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,
    0xb8,0xb9,0xba,0xc2,0xc3,0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0xd2,0xd3,0xd4,0xd5,
    0xd6,0xd7,0xd8,0xd9,0xda,0xe1,0xe2,0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xf1,
    0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,0xf9,0xfa,0xff,0xc4,0x00,0x1f,0x01,0x00,0x03,
    0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x01,
    0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0xff,0xc4,0x00,0xb5,0x11,0x00,
    0x02,0x01,0x02,0x04,0x04,0x03,0x04,0x07,0x05,0x04,0x04,0x00,0x01,0x02,0x77,0x00,
    0x01,0x02,0x03,0x11,0x04,0x05,0x21,0x31,0x06,0x12,0x41,0x51,0x07,0x61,0x71,0x13,
    0x22,0x32,0x81,0x08,0x14,0x42,0x91,0xa1,0xb1,0xc1,0x09,0x23,0x33,0x52,0xf0,0x15,
    0x62,0x72,0xd1,0x0a,0x16,0x24,0x34,0xe1,0x25,0xf1,0x17,0x18,0x19,0x1a,0x26,0x27,
    0x28,0x29,0x2a,0x35,0x36,0x37,0x38,0x39,0x3a,0x43,0x44,0x45,0x46,0x47,0x48,0x49,
    0x4a,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x63,0x64,0x65,0x66,0x67,0x68,0x69,
    0x6a,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x82,0x83,0x84,0x85,0x86,0x87,0x88,
    0x89,0x8a,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0xa2,0xa3,0xa4,0xa5,0xa6,
    0xa7,0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xc2,0xc3,0xc4,
    0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd9,0xda,0xe2,
    0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,0xf9,
    0xfa,0xff,0xda,0x00,0x0c,0x03,0x01,0x00,0x02,0x11,0x03,0x11,0x00,0x3f,0x00};

static unsigned char spcaJpegFooter[]={0xff,0xd9};

@interface MySPCA504Driver (Private)

- (void) openDSCInterface;
- (void) closeDSCInterface;
- (BOOL) dscReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;
- (BOOL) dscWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;

@end 

@implementation MySPCA504Driver

+ (unsigned short) cameraUsbProductID { return PRODUCT_SPCA504; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_SUNPLUS; }
+ (NSString*) cameraName { return [MyCameraCentral localizedStringFor:@"Dual Mode Camera (SPCA504)"]; }


- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    fps=5;
    resolution=ResolutionVGA;
    return [self usbConnectToCam:usbDeviceRef];
}

- (void) dealloc {
    [self usbCloseConnection];
    [super dealloc];
}

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {
    if ((r==ResolutionVGA)&&(fr==5)) return YES;
    else return NO;
}

- (void) setResolution:(CameraResolution)r fps:(short)fr {
    [super setResolution:r fps:fr];	//Update instance variables if state is ok and format is supported
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {	//This is a start
    if (dFps) *dFps=5;
    return ResolutionVGA;
}

- (BOOL) canStoreMedia {
    return YES;
}

- (long) numberOfStoredMediaObjects {
    unsigned char num;
    [self usbReadCmdWithBRequest:0x01 wValue:0x0002 wIndex:0x0005 buf:&num len:1];
    return num;
}

- (id) getStoredMediaObject:(long)idx {
    unsigned char* toc=NULL;
    id result=NULL;
    NSData* data=NULL;
    BOOL ok=YES;
    unsigned char save2713;	//Save the toc location
    unsigned char save2714;
    unsigned char save2715;
    UInt32 bulkLen;
    IOReturn err;
    unsigned char* myTocEntry;
    unsigned char* imgData;
    UInt32 myOffset;
    UInt32 myLength;
    UInt32 arg;
    unsigned char readChar;
    int i;
    
    long totalImageCount=[self numberOfStoredMediaObjects];
    if (totalImageCount<=idx) return NULL;
    
    [self openDSCInterface];
    if (!dscIntf) ok=NO;
    if (ok) {
        MALLOC(toc,unsigned char*,256*totalImageCount,"MySPCA504Driver:getStoredMediaObject toc buffer");
        if (!toc) ok=NO;
    }
    if (ok) {

        [self dscWriteCmdWithBRequest:0x01 wValue:0x0001 wIndex:0x2000 buf:NULL len:0];	//change mode (???)

//Do what you gotta do...
        [self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2000 buf:&readChar len:1];
        NSLog(@"read 0x2000: %02x",readChar);

        [self dscWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x2306 buf:NULL len:0];		//Write something

//Set read length
        [self dscWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2710 buf:NULL len:0];		//Write read length
        [self dscWriteCmdWithBRequest:0x00 wValue:totalImageCount wIndex:0x2711 buf:NULL len:0];//Write read length
        [self dscWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2712 buf:NULL len:0];		//Write read length
//Save the TOC location
        [self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2713 buf:&save2713 len:1];	//Save the location of the toc
        [self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2714 buf:&save2714 len:1];
        [self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2715 buf:&save2715 len:1];
        NSLog(@"toc offset: %02x %02x %02x",save2713,save2714,save2715);
//Set read offset
        [self dscWriteCmdWithBRequest:0x00 wValue:save2713 wIndex:0x2713 buf:NULL len:0];	//Write read offset
        [self dscWriteCmdWithBRequest:0x00 wValue:save2714 wIndex:0x2714 buf:NULL len:0];	//Write read offset
        [self dscWriteCmdWithBRequest:0x00 wValue:save2715 wIndex:0x2715 buf:NULL len:0];	//Write read offset0

//Do what you gotta do...
        [self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2301 buf:&readChar len:1];
        NSLog(@"read 0x2301: %02x",readChar);

//Read TOC via bulk pipe
        [self dscWriteCmdWithBRequest:0x00 wValue:0x0002 wIndex:0x27a1 buf:NULL len:0];	//Initiate bulk read
        for (i=0;i<totalImageCount;i++) {
            bulkLen=256;
            NSLog(@"going to read toc %i: %i bytes expected",i,bulkLen);
            err=(*dscIntf)->ReadPipe(dscIntf, 1, toc+i*256,&bulkLen);
            ShowError(err,"MySPCA504Driver:getStoredMediaObject bulk 1");
            NSLog(@"toc read: %i bytes",bulkLen);
            DumpMem(toc+i*256,bulkLen);
        }
//Do what you gotta do...
        [self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x27b0 buf:&readChar len:1];
        NSLog(@"read 0x27b0: %02x",readChar);

        //Extract the needed info from our entry
        myTocEntry=toc+256*idx;
        myOffset=(((UInt32)myTocEntry[0x01])<<7)+(((UInt32)myTocEntry[0x02])<<15);
        myLength=((UInt32)myTocEntry[0x0b])+(((UInt32)myTocEntry[0x0c])<<8)+(((UInt32)myTocEntry[0x0d])<<16);
        NSLog(@"My Image: offset %i, length: %i",myOffset,myLength);
//Allocate a buffer to hold the JPEG image (623 bytes header + data + 2 bytes footer)
        MALLOC(imgData,unsigned char*,625+myLength,"MySPCA504Driver:getStoredMediaObject imgData");
        if (!imgData) ok=NO;
    }
    if (ok) {
//Configure the camera's Pseudo-DMA to transfer the image
        arg=myLength&0xff;
        [self dscWriteCmdWithBRequest:0x00 wValue:arg wIndex:0x2710 buf:NULL len:0];	//Write read length
        arg=(myLength&0xff00)>>8;
        [self dscWriteCmdWithBRequest:0x00 wValue:arg wIndex:0x2711 buf:NULL len:0];	//Write read length
        arg=(myLength&0xff0000)>>16;
        [self dscWriteCmdWithBRequest:0x00 wValue:arg wIndex:0x2712 buf:NULL len:0];	//Write read length
        arg=myOffset&0xff;
        [self dscWriteCmdWithBRequest:0x00 wValue:arg wIndex:0x2713 buf:NULL len:0];	//Write read offset
        arg=(myOffset&0xff00)>>8;
        [self dscWriteCmdWithBRequest:0x00 wValue:arg wIndex:0x2714 buf:NULL len:0];	//Write read offset
        arg=(myOffset&0xff0000)>>16;
        [self dscWriteCmdWithBRequest:0x00 wValue:arg wIndex:0x2715 buf:NULL len:0];	//Write read offset

        [self dscWriteCmdWithBRequest:0x00 wValue:0x0002 wIndex:0x27a1 buf:NULL len:0];	//Initiate bulk read
        bulkLen=myLength;
        NSLog(@"going to read %i bytes of image data",bulkLen);
        err=(*dscIntf)->ReadPipe(dscIntf, 1, imgData+623,&myLength);
        ShowError(err,"MySPCA504Driver:getStoredMediaObject bulk 2");
        NSLog(@"Read %i bytes of image data",bulkLen);
        memcpy(imgData,spcaJpegHeader,623);
        memcpy(imgData+623+myLength,spcaJpegFooter,2);	//I know, two bytes are ridiculous to memcpy...

        [self dscWriteCmdWithBRequest:0x00 wValue:save2713 wIndex:0x2713 buf:NULL len:0];	//restore read offset
        [self dscWriteCmdWithBRequest:0x00 wValue:save2714 wIndex:0x2714 buf:NULL len:0];	//restore read offset
        [self dscWriteCmdWithBRequest:0x00 wValue:save2715 wIndex:0x2715 buf:NULL len:0];	//restore read offset

        data=[[NSData alloc] initWithBytes:imgData length:myLength+625];
        if (!data) ok=NO;
    }
    if (ok) {
        result=[[[NSBitmapImageRep alloc] initWithData:data] autorelease];
        if (!result) ok=NO;
    }
    
    [self closeDSCInterface];
    if (data) [data release]; data=NULL;
    if (imgData) FREE(toc,"MySPCA504Driver:getStoredMediaObject img data"); toc=NULL;
    if (toc) FREE(toc,"MySPCA504Driver:getStoredMediaObject toc buffer"); toc=NULL;

    return result;
}

- (void) eraseStoredMedia {
#ifdef VERBOSE
    NSLog(@"MySPCA504Driver: eraseStoredMedia not implemented");
#endif
}

- (void) openDSCInterface {
    IOUSBFindInterfaceRequest		interfaceRequest;
    io_iterator_t			iterator;
    IOReturn 				err;
    io_service_t			usbInterfaceRef;
    IOCFPlugInInterface 		**iodev;		// requires <IOKit/IOCFPlugIn.h>
    SInt32 				score;

    interfaceRequest.bInterfaceClass = kIOUSBFindInterfaceDontCare;		// requested class
    interfaceRequest.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;		// requested subclass
    interfaceRequest.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;		// requested protocol
    interfaceRequest.bAlternateSetting = kIOUSBFindInterfaceDontCare;		// requested alt setting

    //take an iterator over the device interfaces...
    err = (*dev)->CreateInterfaceIterator(dev, &interfaceRequest, &iterator);
    CheckError(err,"openDSCInterface-CreateInterfaceIterator");

    //and take the second one
    IOIteratorNext(iterator);
    usbInterfaceRef = IOIteratorNext(iterator);
    assert (usbInterfaceRef);

    //we don't need the iterator any more
    IOObjectRelease(iterator);
    iterator = 0;

    //get a plugin interface for the interface interface
    err = IOCreatePlugInInterfaceForService(usbInterfaceRef, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
    CheckError(err,"openDSCInterface-IOCreatePlugInInterfaceForService");
    assert(iodev);
    IOObjectRelease(usbInterfaceRef);

    //get access to the interface interface
    err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID)&dscIntf);
    CheckError(err,"openDSCInterface-QueryInterface2");
    assert(dscIntf);
    (*iodev)->Release(iodev);					// done with this

    //open interface
    err = (*dscIntf)->USBInterfaceOpen(dscIntf);
    CheckError(err,"openDSCInterface-USBInterfaceOpen");

    //set alternate interface
    err = (*dscIntf)->SetAlternateInterface(dscIntf,0);
    CheckError(err,"openDSCInterface-SetAlternateInterface");
}

- (void) closeDSCInterface {
    IOReturn err;
    if (dscIntf) {						//close our interface interface
        if (isUSBOK) {
            err = (*dscIntf)->USBInterfaceClose(dscIntf);
        }
        err = (*dscIntf)->Release(dscIntf);
        CheckError(err,"closeDSCInterface-Release Interface");
        dscIntf=NULL;
    }
}

- (BOOL) dscReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    IOReturn err;
    IOUSBDevRequest req;
    if (!isUSBOK) return NO;
    if (dscIntf==NULL) return NO;
    req.bmRequestType=USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBDevice);
    req.bRequest=bReq;
    req.wValue=wVal;
    req.wIndex=wIdx;
    req.wLength=len;
    req.pData=buf;
    err=(*dscIntf)->ControlRequest(dscIntf,0,&req);
    CheckError(err,"usbReadCmdWithBRequest");
    if (err=kIOUSBPipeStalled) (*dscIntf)->ClearPipeStall(dscIntf,0);
    return (!err);
}

- (BOOL) dscWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    IOReturn err;
    IOUSBDevRequest req;
    if (!isUSBOK) return NO;
    if (dscIntf==NULL) return NO;
    req.bmRequestType=USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice);
    req.bRequest=bReq;
    req.wValue=wVal;
    req.wIndex=wIdx;
    req.wLength=len;
    req.pData=buf;
    err=(*dscIntf)->ControlRequest(dscIntf,0,&req);
    CheckError(err,"usbWriteCmdWithBRequest");
    if (err=kIOUSBPipeStalled) (*dscIntf)->ClearPipeStall(dscIntf,0);
    return (!err);
}

@end
