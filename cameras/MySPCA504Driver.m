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
#include "unistd.h"	//usleep

#define VENDOR_SUNPLUS 0x4fc
#define PRODUCT_SPCA504 0x504a


@interface MySPCA504Driver (Private)

//High level DSC access
- (CameraError) openDSCInterface;
- (void) closeDSCInterface;

//Medium level DSC access

- (BOOL) dscInit;
- (void) dscShutdown;
- (BOOL) dscRefreshToc;
- (long) dscTocLengthOfImage:(int)img;
- (NSData*) dscGetImage:(int)idx;



//Low level DSC access

- (BOOL) dscReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;
- (BOOL) dscWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;
- (BOOL) dscReadBulkTo:(unsigned char*)buf from:(int)offset length:(int)len;
@end 

@implementation MySPCA504Driver

+ (unsigned short) cameraUsbProductID { return PRODUCT_SPCA504; }
+ (unsigned short) cameraUsbVendorID { return VENDOR_SUNPLUS; }
+ (NSString*) cameraName { 
    return [MyCameraCentral localizedStringFor:@"Dual Mode Camera (SPCA504)"]; 
}


- (CameraError) startupWithUsbDeviceRef:(io_service_t)usbDeviceRef {
    CameraError err = [self usbConnectToCam:usbDeviceRef];
    fps=5;
    resolution=ResolutionVGA;
    if (err==CameraErrorOK) [self openDSCInterface];
    return err;
}

- (void) shutdown {
    [self closeDSCInterface];
    [super shutdown];
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
    if (![self dscRefreshToc]) return 0;
    return storedMediaCount/2;
}

- (id) getStoredMediaObject:(long)idx {
    NSBitmapImageRep* rep=[NSBitmapImageRep imageRepWithData:[self dscGetImage:idx]];
    return rep;	//Currently, macam only accepts NSBitmapImageRep - we should change that...
}

- (void) eraseStoredMedia {
#ifdef VERBOSE
    NSLog(@"MySPCA504Driver: eraseStoredMedia not implemented");
#endif
}

- (CameraError) openDSCInterface {
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
    if (err) return CameraErrorUSBProblem;
    if (![self dscInit]) return CameraErrorUSBProblem;
    return CameraErrorOK;
}

- (void) closeDSCInterface {
    IOReturn err;
    if (dscIntf) {						//close our interface interface
        [self dscShutdown];
        if (isUSBOK) {
            err = (*dscIntf)->USBInterfaceClose(dscIntf);
        }
        err = (*dscIntf)->Release(dscIntf);
        CheckError(err,"closeDSCInterface-Release Interface");
        dscIntf=NULL;
    }
}


- (BOOL) dscInit {
    unsigned char buf[256];
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2000 buf:buf len:0]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0013 wIndex:0x2301 buf:buf len:0]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x2883 buf:buf len:0]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0005 wIndex:0x2800 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2800 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0005 wIndex:0x2840 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2840 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0003 wIndex:0x2801 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2801 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0005 wIndex:0x2841 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2841 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0003 wIndex:0x2802 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2802 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0007 wIndex:0x2842 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2842 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0005 wIndex:0x2803 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2803 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x000e wIndex:0x2843 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2843 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0007 wIndex:0x2804 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2804 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2844 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2844 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x000c wIndex:0x2805 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2805 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2845 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2845 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x000f wIndex:0x2806 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2806 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2846 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2846 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0012 wIndex:0x2807 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2807 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2847 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2847 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0004 wIndex:0x2808 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2808 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0005 wIndex:0x2848 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2848 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0004 wIndex:0x2809 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2809 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0006 wIndex:0x2849 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2849 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0004 wIndex:0x280a buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x280a buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0008 wIndex:0x284a buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x284a buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0006 wIndex:0x280b buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x280b buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0014 wIndex:0x284b buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x284b buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0008 wIndex:0x280c buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x280c buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x284c buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x284c buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0011 wIndex:0x280d buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x280d buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x284d buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x284d buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0012 wIndex:0x280e buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x280e buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x284e buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x284e buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0011 wIndex:0x280f buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x280f buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x284f buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x284f buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0004 wIndex:0x2810 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2810 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0007 wIndex:0x2850 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2850 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0004 wIndex:0x2811 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2811 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0008 wIndex:0x2851 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2851 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0005 wIndex:0x2812 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2812 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0011 wIndex:0x2852 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2852 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0007 wIndex:0x2813 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2813 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2853 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2853 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x000c wIndex:0x2814 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2814 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2854 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2854 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0011 wIndex:0x2815 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2815 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2855 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2855 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0015 wIndex:0x2816 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2816 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2856 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2856 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0011 wIndex:0x2817 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2817 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2857 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2857 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0004 wIndex:0x2818 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2818 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x000e wIndex:0x2858 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2858 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0005 wIndex:0x2819 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2819 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0014 wIndex:0x2859 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2859 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0007 wIndex:0x281a buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x281a buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x285a buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x285a buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0009 wIndex:0x281b buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x281b buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x285b buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x285b buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x000f wIndex:0x281c buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x281c buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x285c buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x285c buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001a wIndex:0x281d buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x281d buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x285d buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x285d buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0018 wIndex:0x281e buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x281e buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x285e buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x285e buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0013 wIndex:0x281f buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x281f buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x285f buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x285f buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0005 wIndex:0x2820 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2820 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2860 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2860 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0007 wIndex:0x2821 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2821 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2861 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2861 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x000b wIndex:0x2822 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2822 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2862 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2862 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0011 wIndex:0x2823 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2823 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2863 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2863 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0014 wIndex:0x2824 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2824 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2864 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2864 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0021 wIndex:0x2825 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2825 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2865 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2865 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001f wIndex:0x2826 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2826 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2866 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2866 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0017 wIndex:0x2827 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2827 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2867 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2867 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0007 wIndex:0x2828 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2828 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2868 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2868 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x000b wIndex:0x2829 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2829 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2869 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2869 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0011 wIndex:0x282a buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x282a buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x286a buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x286a buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0013 wIndex:0x282b buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x282b buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x286b buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x286b buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0018 wIndex:0x282c buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x282c buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x286c buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x286c buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001f wIndex:0x282d buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x282d buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x286d buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x286d buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0022 wIndex:0x282e buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x282e buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x286e buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x286e buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001c wIndex:0x282f buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x282f buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x286f buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x286f buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x000f wIndex:0x2830 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2830 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2870 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2870 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0013 wIndex:0x2831 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2831 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2871 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2871 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0017 wIndex:0x2832 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2832 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2872 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2872 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001a wIndex:0x2833 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2833 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2873 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2873 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001f wIndex:0x2834 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2834 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2874 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2874 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0024 wIndex:0x2835 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2835 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2875 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2875 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0024 wIndex:0x2836 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2836 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2876 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2876 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2837 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2837 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2877 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2877 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0016 wIndex:0x2838 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2838 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2878 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2878 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001c wIndex:0x2839 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2839 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x2879 buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2879 buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001d wIndex:0x283a buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x283a buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x287a buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x287a buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001d wIndex:0x283b buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x283b buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x287b buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x287b buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0022 wIndex:0x283c buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x283c buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x287c buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x287c buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x283d buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x283d buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x287d buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x287d buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001f wIndex:0x283e buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x283e buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x287e buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x287e buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x283f buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x283f buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x001e wIndex:0x287f buf:buf len:0]) return NO;
    if (![self dscReadCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x287f buf:buf len:1]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x2501 buf:buf len:0]) return NO;
    if (![self dscWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x2306 buf:buf len:0]) return NO;

    if (![self dscWriteCmdWithBRequest:0x08 wValue:0x0000 wIndex:0x0006 buf:buf len:0]) return NO;
    {
        BOOL done=NO;
        int tries=30;
        while (!done) {
            if (![self dscReadCmdWithBRequest:0x01 wValue:0x0000 wIndex:0x0001 buf:buf len:1]) return NO;
            if (buf[0]==0x86) {
                done=YES;
            } else {
                usleep(500000);
                tries--;
                if (tries<=0) done=YES; 
            }
            NSAssert(tries>=0,@"initial check timed out"); 
        }
        //it's read additional 2 times (why?)
        if (![self dscReadCmdWithBRequest:0x01 wValue:0x0000 wIndex:0x0001 buf:buf len:1]) return NO;
        if (![self dscReadCmdWithBRequest:0x01 wValue:0x0000 wIndex:0x0001 buf:buf len:1]) return NO;
    }
    if (![self dscWriteCmdWithBRequest:0x01 wValue:0x0000 wIndex:0x000f buf:buf len:0]) return NO;

/*
 //Do a stupid toc read - just because the win driver also daes that
    if (![self dscReadCmdWithBRequest:0x0b wValue:0x0000 wIndex:0x0000 buf:buf len:2]) return NO;
    numEntries=buf[0]+(buf[1]<<8);
    if (numEntries>0) {
        if (![self dscWriteCmdWithBRequest:0x0a wValue:numEntries wIndex:0x000c buf:buf len:0]) return NO;
        if (![self dscReadBulkTo:buf from:0 length:32]) return NO;	//Read all, but take only first
    }
    NSLog(@"stupid toc read done");
*/
    if (![self dscReadCmdWithBRequest:0x01 wValue:0x0000 wIndex:0x0005 buf:buf len:1]) return NO;
    if (![self dscReadCmdWithBRequest:0x01 wValue:0x0001 wIndex:0x0005 buf:buf len:1]) return NO;
    if (![self dscReadCmdWithBRequest:0x01 wValue:0x0002 wIndex:0x0005 buf:buf len:1]) return NO;
    if (![self dscReadCmdWithBRequest:0x01 wValue:0x0003 wIndex:0x0005 buf:buf len:1]) return NO;
    if (![self dscReadCmdWithBRequest:0x01 wValue:0x0000 wIndex:0x0005 buf:buf len:1]) return NO;
    if (![self dscReadCmdWithBRequest:0x01 wValue:0x0001 wIndex:0x0005 buf:buf len:1]) return NO;
    return YES;
}

- (void) dscShutdown {
    unsigned char buf[2];
    [self dscWriteCmdWithBRequest:0x00 wValue:0x0001 wIndex:0x2306 buf:buf len:0];
    [self dscWriteCmdWithBRequest:0x00 wValue:0x0000 wIndex:0x0d04 buf:buf len:0];
}

- (BOOL) dscRefreshToc {					//Returns number of objects on cam or -1 if err
    unsigned char buf[2];
    long tmpStoredMediaCount;
    NSMutableData* tmpToc;
    //Cleanup everything
    storedMediaCount=0;
    if (toc) [toc release]; toc=NULL;

    //Count objects
    if (![self dscReadCmdWithBRequest:0x0b wValue:0x0000 wIndex:0x0000 buf:buf len:2]) return NO;
    tmpStoredMediaCount=buf[0]+(buf[1]<<8);
    if (tmpStoredMediaCount==0) return YES;	//No images
    //request toc
    tmpToc=[[[NSMutableData alloc] initWithLength:32*tmpStoredMediaCount] autorelease];
    if (!tmpToc) return NO;
    if (![self dscWriteCmdWithBRequest:0x0a wValue:tmpStoredMediaCount wIndex:0x000c buf:buf len:0]) return NO;
    if (![self dscReadBulkTo:[tmpToc mutableBytes] from:0 length:32*tmpStoredMediaCount]) return NO;
    [tmpToc retain];
    toc=tmpToc;
    storedMediaCount=tmpStoredMediaCount;
    return YES;
}

- (long) dscTocLengthOfImage:(int)idx {
    unsigned char* tocData;
    if (!toc) return 0;
    tocData=[toc mutableBytes];
    tocData+=idx*64;
    if (tocData[31]!=0) {
        NSLog(@"invalid image size of image %i (1-based)",idx);
        return 0;
    }
    return tocData[28]+256*tocData[29]+65536*tocData[30];
}

- (NSData*) dscGetImage:(int)idx {
    unsigned char buf[2];
    unsigned long length;
    NSMutableData* imageData;
    unsigned char* imageBuf;

    if ((length=[self dscTocLengthOfImage:idx])<=0) return NULL;
    if (!(imageData=[NSMutableData dataWithLength:length])) return NULL;
    if (!(imageBuf=[imageData mutableBytes])) return NULL;
    if (![self dscReadCmdWithBRequest:0x0b wValue:0x0000 wIndex:0x0005 buf:buf len:1]) return NULL;
    if (![self dscReadCmdWithBRequest:0x01 wValue:0x0040 wIndex:0x0005 buf:buf len:1]) return NULL;
    if (![self dscWriteCmdWithBRequest:0x0a wValue:idx+1 wIndex:0x000d buf:buf len:0]) return NULL;
    if (![self dscReadBulkTo:imageBuf from:0 length:length]) return NULL;
    return imageData;
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
//    NSLog(@"in req:%02x val:%04x idx:%04x len:%i",bReq,wVal,wIdx,len);
//    if (len==1) NSLog(@"result:%02x",*((unsigned char*)buf));
//    else if (len==2) NSLog(@"result:%04x",*((unsigned short*)buf));
//    else NSLog(@"result:%08x",*((unsigned long*)buf));
    CheckError(err,"usbReadCmdWithBRequest");
    if (err==kIOUSBPipeStalled) (*dscIntf)->ClearPipeStall(dscIntf,0);
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
//    NSLog(@"out req:%02x val:%04x idx:%04x",bReq,wVal,wIdx);
    CheckError(err,"usbWriteCmdWithBRequest");
    if (err==kIOUSBPipeStalled) (*dscIntf)->ClearPipeStall(dscIntf,0);
    return (!err);
}


- (BOOL) dscReadBulkTo:(unsigned char*)dest from:(int)startOffset length:(int)length {
#define BULK_BLOCK_LENGTH 256
    unsigned char c;
    int retries=10;
    BOOL done=NO;
    unsigned char buf[BULK_BLOCK_LENGTH];
    unsigned long currBlockOffset=0;
    unsigned long endOffset=startOffset+length;
    unsigned long copied=0;
    UInt32 readLength=BULK_BLOCK_LENGTH;
    IOReturn err=0;
    //Step 1: Wait until bulk is ready
    while (!done) {	
        [self dscReadCmdWithBRequest:0x0b wValue:0x0000 wIndex:0x0004 buf:&c len:1];
        if (c) done=YES;
        else {
            usleep(500000);
            retries--;
            if (retries<=0) {
                NSLog(@"wait for bulk ready timed out");
                return NO;
            }
        }
    }
    //Step 2: Do the reading until pipe is empty and copy wanted portions
    while (!err) {
        err=((IOUSBInterfaceInterface182*)(*dscIntf))->ReadPipeTO(dscIntf,1,buf,&readLength,100,300);
        if (!err) {		//Read was ok
            long from=MAX(startOffset,currBlockOffset);
            long to=MIN(endOffset,currBlockOffset+BULK_BLOCK_LENGTH);
            long len=to-from;
            if (len>0) {	//Does the block have data we want?
                long copySrcOffset=(startOffset>currBlockOffset)?startOffset:0;
                memcpy(dest+copied,buf+copySrcOffset,len);
                copied+=len;
            }
            currBlockOffset+=BULK_BLOCK_LENGTH;
        }
    }
    return (copied==length);
}




@end
