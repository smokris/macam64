//
//  QuickCamVCDriver.m
//  macam
//
//  Created by hxr on 5/17/06.
//  Copyright 2006 hxr. All rights reserved.
//


#import "QuickCamVCDriver.h"

#include "Resolvers.h"
#include "USB_VendorProductIDs.h"


@interface QuickCamVCDriver (Private)

- (BOOL) resetUSS720;
- (BOOL) getUSS720Register: (UInt8) reg  returning: (UInt8 *) val;
- (BOOL) setUSS720Register: (UInt8) reg  value: (UInt8) val;
- (CameraError) setCameraRegister: (UInt8) reg  data: (void *) buffer  size: (UInt32) length;
- (CameraError) getCameraRegister: (UInt8) reg  data: (void *) buffer  size: (UInt32) length;
- (BOOL) readStream: (void *) buffer  size: (UInt32) length;

@end


@implementation QuickCamVCDriver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_VC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CONNECTIX], @"idVendor",
            @"Logitech QuickCam VC (USB) [new]", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCLIP], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CONNECTIX], @"idVendor",
            @"Logitech QuickClip (USB)", @"name", NULL], 
        
        NULL];
}


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    // Allocate memory
    // Initialize variable and other structures
    
	return self;
}


- (void) startupCamera
{
    UInt8 registers[64];
    
    [self usbSetAltInterfaceTo:2 testPipe:[self getGrabbingPipe]];
    
    [self getUSS720Register:0 returning:registers];
    [self getUSS720Register:1 returning:registers];
    [self getUSS720Register:2 returning:registers];
    [self getUSS720Register:3 returning:registers];

    [self getCameraRegister:0x00 data:registers size:64];
    model = registers[0];
    [self getCameraRegister:0x01 data:registers size:64];
    type = registers[0];
	
	/* 
        for quickcam vc...
     address 0x00 always 0x02 (2)
     address 0x01 always 0x0A (16) // huh, should be 0x10 ...
     */
	
	printf("Camera: %d / %d\n", model, type); // 2 / 16 for me...
    
	[self setBrightness:0.5];
	[self setContrast:0.5];
	[self setGamma:0.5];
	[self setSaturation:0.5];
	[self setSharpness:0.5];
}


//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionCIF:
            if (rate > 20) 
                return NO;
            return YES;
            break;
            
        default: 
            return NO;
    }
}

//
// Return the default resolution and rate
//
- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 5;
    
	return ResolutionCIF;
}

//
// Returns the pipe used for grabbing
//
- (UInt8) getGrabbingPipe
{
    return 2;
}

//
// Put in the alt-interface with the highest bandwidth (instead of 8)
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbSetAltInterfaceTo:2 testPipe:[self getGrabbingPipe]];
}

//
// This is an example that will have to be tailored to the specific camera or chip
// Scan the frame and return the results
//
/*
IsocFrameResult  exampleIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength)
{
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 1) 
        return invalidFrame;
    
    if (something or other) 
    {
        *dataStart = 10; // Skip a 10 byte header for example
        *dataLength = frameLength - 10;
        
        return newChunkFrame;
    }
    
    return validFrame;
}
*/

//
// These are the C functions to be used for scanning the frames
//
/*
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = exampleIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}
*/

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError error = CameraErrorOK;
    
    //  Probably will have a lot of statements kind of like this:
    //	[self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x0041 buf:NULL len:0];
    
    return error == CameraErrorOK;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    //  More of the same
    //  [self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x40 buf:NULL len:0];
    
    [self usbSetAltInterfaceTo:2 testPipe:[self getGrabbingPipe]];
}

//
// This is the method that takes the raw chunk data and turns it into an image
//
- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
	// Decode the bytes
    
    //  Much decoding to be done here
    
    // Turn the Bayer data into an RGB image
    
    [bayerConverter setSourceFormat:3]; // This is probably different
    [bayerConverter setSourceWidth:rawWidth height:rawHeight];
    [bayerConverter setDestinationWidth:rawWidth height:rawHeight];
    [bayerConverter convertFromSrc:decodingBuffer
                            toDest:nextImageBuffer
                       srcRowBytes:rawWidth
                       dstRowBytes:nextImageBufferRowBytes
                            dstBPP:nextImageBufferBPP
                              flip:hFlip
                         rotate180:YES]; // This might be different too
}


//  returns OK if no error
- (BOOL) resetUSS720 
{
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBOut, kUSBClass, kUSBOther)
                               bRequest:BREQ_SOFT_RESET
                                 wValue:0x0000
                                 wIndex:0x0000
                                    buf:NULL
                                    len:0];
}


// val points to buffer of 7 bytes
- (BOOL) getUSS720Register: (UInt8) reg  returning: (UInt8 *) val
{
    UInt16 shiftedRegister = reg;
    
    shiftedRegister <<= 8;
    
    return [self usbReadCmdWithBRequest:BREQ_GET_1284_REG
                                 wValue:shiftedRegister
                                 wIndex:0x0000
                                    buf:val
                                    len:7];
}


- (BOOL) setUSS720Register: (UInt8) reg  value: (UInt8) val
{
    UInt16 shiftedRegister = reg;
    
    shiftedRegister <<= 8;
    shiftedRegister |= val;
    
    return [self usbWriteCmdWithBRequest:BREQ_SET_1284_REG
                                 wValue:shiftedRegister
                                 wIndex:0x0000
                                    buf:NULL
                                    len:0];
}


- (CameraError) setCameraRegister: (UInt8) reg  data: (void *) buffer  size: (UInt32) length
{
    BOOL ok = YES;
    
    [self resetUSS720];
    [self setUSS720Register:SET_USS720_USSCTRL value:ALL_INT_MASK];
    [self setUSS720Register:SET_USS720_CONTROL value:NINIT | SELECT_IN];
    [self setUSS720Register:SET_USS720_DATA    value:0x10];
    [self setUSS720Register:SET_USS720_CONTROL value:NINIT | AUTO_FD];
    [self setUSS720Register:SET_USS720_CONTROL value:NINIT | AUTO_FD | STROBE];
    [self setUSS720Register:SET_USS720_CONTROL value:NINIT];
    [self setUSS720Register:SET_USS720_CONTROL value:NINIT | AUTO_FD];
    [self setUSS720Register:SET_USS720_DATA    value:reg];
    [self setUSS720Register:SET_USS720_CONTROL value:NINIT | AUTO_FD | STROBE];
    [self setUSS720Register:SET_USS720_CONTROL value:NINIT | AUTO_FD];
    [self resetUSS720];
    
    if (ok && length > 0 && buffer != NULL) 
    {
        IOReturn result = (*intf)->WritePipe(intf, 1, buffer, length);
        CheckError(result, "QuickCamVCDriver:setCameraRegister");
        ok = (result) ? NO : YES;
    }
    
    return (ok) ? CameraErrorOK : CameraErrorUSBProblem;
}


- (CameraError) getCameraRegister: (UInt8) reg  data: (void *) buffer  size: (UInt32) length
{
    BOOL ok = YES;
    UInt8 registers[7];
    
    [self resetUSS720];
    [self getUSS720Register:GET_USS720_CONTROL returning:registers];
    [self setUSS720Register:SET_USS720_USSCTRL value:ALL_INT_MASK];
    [self getUSS720Register:GET_USS720_CONTROL returning:registers];
    [self setUSS720Register:SET_USS720_USSCTRL value:ALL_INT_MASK];
    [self setUSS720Register:SET_USS720_CONTROL value:EPP_MASK | NINIT | HLH | SELECT_IN];
    [self setUSS720Register:SET_USS720_DATA    value:0x10];
    [self setUSS720Register:SET_USS720_CONTROL value:EPP_MASK | NINIT | HLH | AUTO_FD];
    [self getUSS720Register:GET_USS720_CONTROL returning:registers];
    [self setUSS720Register:SET_USS720_CONTROL value:EPP_MASK | NINIT | HLH | AUTO_FD | STROBE];
    [self setUSS720Register:SET_USS720_CONTROL value:EPP_MASK | NINIT | HLH];
    [self getUSS720Register:GET_USS720_CONTROL returning:registers];
    [self setUSS720Register:SET_USS720_CONTROL value:EPP_MASK | NINIT | HLH | AUTO_FD];
    [self getUSS720Register:GET_USS720_CONTROL returning:registers];
    [self getUSS720Register:GET_USS720_STATUS  returning:registers];
    [self setUSS720Register:SET_USS720_EXTCTRL value:ECR_ECP | BULK_IN_EMPTY| BULK_OUT_EMPTY];
    [self setUSS720Register:SET_USS720_CONTROL value:EPP_MASK | NINIT | HLH];
    [self setUSS720Register:SET_USS720_ECPCMD  value:reg];
    [self resetUSS720];
    
    if (ok && length > 0 && buffer != NULL) 
    {
        IOReturn result = (*intf)->ReadPipe(intf, 2, buffer, &length);
        CheckError(result, "QuickCamVCDriver:getCameraRegister");
        ok = (result) ? NO : YES;
        [self resetUSS720];
    }
    
    return (ok) ? CameraErrorOK : CameraErrorUSBProblem;
}

/*
- (CameraError) writeCameraRegister:(UInt16)reg to:(UInt32)val len:(long)len 
{
    return [self writeCameraRegister:reg fromBuffer:((UInt8*)(&val))+(sizeof(UInt32)-len) len:len];
}

- (CameraError) writeCameraRegister:(UInt16)reg fromBuffer:(UInt8*)buf len:(long)len 
{
    BOOL ok=YES;
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x07f8 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x020c wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0010 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0206 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0207 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0204 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0206 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:reg    wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0207 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0206 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self resetUSS720];
    if ((ok)&&(len>0)) {
        IOReturn ret=(*intf)->WritePipe(intf, 1, buf, len);
        CheckError(ret,"MyQCProBeigeDriver:writeCameraRegister");
        ok=(ret)?NO:YES;
    }
    return (ok)?CameraErrorOK:CameraErrorUSBProblem;
}

- (CameraError) readCameraRegister:(UInt16)reg toBuffer:(UInt8*)retBuf len:(long)len 
{
    BOOL ok=YES;
    UInt8 buf[7];
    ok=ok&&[self resetUSS720];
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0100 wIndex:0x0000 buf:buf len:7]; //<-- 0a 4c a3 f9 00 00
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x07f8 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0100 wIndex:0x0000 buf:buf len:7]; //<-- 0a 4c 03 f8 00 00
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x07f8 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02cc wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0010 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02c6 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0100 wIndex:0x0000 buf:buf len:7]; //<-- ba c6 03 f8 10 00
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02c7 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02c4 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0100 wIndex:0x0000 buf:buf len:7]; //<-- da c4 03 f8 10 00
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02c6 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0100 wIndex:0x0000 buf:buf len:7]; //<-- fa c6 03 f8 10 00
    ok=ok&&[self usbReadCmdWithBRequest:0x03 wValue:0x0000 wIndex:0x0000 buf:buf len:7]; //<-- fa c6 03 f8 10 00
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x0663 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:0x02c4 wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self usbWriteCmdWithBRequest:0x04 wValue:reg wIndex:0x0000 buf:NULL len:0];
    ok=ok&&[self resetUSS720];
    if (ok) {
        UInt32 actLen=len;
        IOReturn ret=((IOUSBInterfaceInterface182*)(*intf))->ReadPipeTO(intf, 2, retBuf, &actLen, 2000, 3000);
        CheckError(ret,"MyQCProBeigeDriver:writeCameraRegister");
        ok=(ret)?NO:YES;
    }
    ok=ok&&[self resetUSS720];
    return (ok)?CameraErrorOK:CameraErrorUSBProblem;
}    
*/


- (BOOL) readStream: (void *) buffer  size: (UInt32) length
{
    BOOL ok = YES;
    
    [self resetUSS720];

    // bulk write one byte? (commented out)
    
    if (ok && length > 0 && buffer != NULL) 
    {
        IOReturn result = (*intf)->ReadPipe(intf, 2, buffer, &length);
        CheckError(result, "QuickCamVCDriver:readStream");
        ok = (result) ? NO : YES;
    }
    
    return (ok) ? CameraErrorOK : CameraErrorUSBProblem;
}


@end
