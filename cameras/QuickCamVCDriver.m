//
//  QuickCamVCDriver.m
//  macam
//
//  Created by hxr on 5/17/06.
//  Copyright 2006 hxr. All rights reserved.
//


#import "QuickCamVCDriver.h"

#include <unistd.h>

#include "MiscTools.h"
#include "Resolvers.h"
#include "USB_VendorProductIDs.h"


#define BIGBUFFER_SIZE 0x20000


@interface QuickCamVCDriver (Private)

- (BOOL) resetUSS720;
- (BOOL) getUSS720Register: (UInt8) reg  returning: (UInt8 *) val;
- (BOOL) setUSS720Register: (UInt8) reg  value: (UInt8) val;
- (CameraError) setCameraRegister: (UInt8) reg  data: (UInt8) value;
- (CameraError) setCameraRegisters: (UInt8) reg  data: (void *) buffer  size: (UInt32) length;
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
    
    bpc = 8;
    frameCount = 0;
    multiplier = 0;
    
    // Allocate memory
    // Initialize variable and other structures
    
	return self;
}


- (void) startupCamera
{
    UInt8 registers[1];
    
    [self usbSetAltInterfaceTo:2 testPipe:[self getGrabbingPipe]];
    
    [self getUSS720Register:0 returning:registers];
    [self getUSS720Register:1 returning:registers];
    [self getUSS720Register:2 returning:registers];
    [self getUSS720Register:3 returning:registers];

    [self getCameraRegister:0x00 data:registers size:1];
    model = registers[0];
    [self getCameraRegister:0x01 data:registers size:1];
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
    
	long i;
	UInt8 bitmask;
	UInt8 * bigbuffer;
    
	
	bigbuffer = malloc(BIGBUFFER_SIZE);
	if (bigbuffer == NULL) 
	{
		printf("QuickCam VC: Init bigbuffer malloc error.\n");
	}
		
	// setup a 128KB bit mask for 6bit/8bit per component
	bitmask = 0xFF << bpc;
	for(i = 0; i < BIGBUFFER_SIZE; i += 2)
	{
		*(bigbuffer + i) = (unsigned char ) (i >> 11);
		*(bigbuffer + i + 1) = bitmask;
	}
	
//	get_camera_model(qcamvc);
	
    [self setCameraRegister:QCAM_VC_SET_BRIGHTNESS data:0x38];
    [self setCameraRegister:QCAM_VC_SET_BRIGHTNESS data:0x78];
	
	// clear config bit & disable video streaming
    [self setCameraRegister:QCAM_VC_SET_MISC data:0x00];
	
	// clear 0x0e address (whatever this address actually does?)
    [self setCameraRegister:0x0E data:0x00];
	
	// write 128KB of 6bit/8bit mask
    [self setCameraRegisters:QCAM_VC_GET_FRAME data:bigbuffer size:BIGBUFFER_SIZE];
	
	// set address 0x0e to 0x01
    [self setCameraRegister:0x0E data:0x01];
	
	// this might have somthing to do with setting the amount of compression - don't know how though.
    [self setCameraRegister:QCAM_VC_SET_BRIGHTNESS data:0x78];
    [self setCameraRegister:QCAM_VC_SET_BRIGHTNESS data:0x78];
    [self setCameraRegister:QCAM_VC_SET_BRIGHTNESS data:0x58];
    
	// set brightness & exposure - probably not needed here
	//qcamvc_set_brightness(qcamvc, qcamvc->brightness);
    [self setBrightness:brightness];
    [self setShutter:shutter];
	//qcamvc_set_exposure(qcamvc, qcamvc->exposure);
    
	// set config bit. (whatever this bit actually does?)
    [self setCameraRegister:QCAM_VC_SET_MISC data:0x01];
	
	// set CCD columns & rows
//	qcamvc_set_ccd_area(qcamvc);
    [self setCCDArea];
    
	// set brightness & exposure
//	qcamvc_set_brightness(qcamvc, qcamvc->brightness);
//	qcamvc_set_exposure(qcamvc, qcamvc->exposure);
    [self setBrightness:brightness];
    [self setShutter:shutter];
	
	// set the Light Sensitivity (no gain/no attenuation = 128 )
//	qcamvc_set_light_sensitivity(qcamvc, qcamvc->light_sens);
//    [self setLightSensitivity:lightSensitivity];
    
	// set Misc options & re-enable video streaming now
    UInt8 misc = 0;
    misc |= QCAM_VC_BIT_CONFIG_MODE;
    if (!multiplier) // odd
        misc |= QCAM_VC_BIT_MULT_FACTOR;
    if (compression) 
        misc |= QCAM_VC_BIT_COMPRESSION;
    misc |= QCAM_VC_BIT_ENABLE_VIDEO;
    [self setCameraRegister:QCAM_VC_SET_MISC data:misc];
	
	// send a get frame to clear the previous resolution
    [self setCameraRegister:QCAM_VC_GET_FRAME data:0xFF];
}


//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionQSIF:
            if (rate > 30) 
                return NO;
            return YES;
            break;
            
        case ResolutionQCIF:
            if (rate > 30) 
                return NO;
            return YES;
            break;
            
        case ResolutionSIF:
            if (rate > 25) 
                return NO;
            return YES;
            break;
            
        case ResolutionCIF:
            if (rate > 20) 
                return NO;
            return YES;
            break;
            
        case ResolutionVGA:
            if (rate > 10) 
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
    
    frameCount++;
	
    [self setCameraRegister:QCAM_VC_GET_FRAME data:frameCount];
    
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


- (void) setBrightness: (float) v 
{
    UInt8 val = 255 * v;
	short i,j;
	unsigned char buffer[21] =
    {
		0x58, 0xd8, 0x58, 0xd8, 0x58,
		0xd8, 0x58, 0xd8, 0x58, 0xd8,
		0x58, 0xd8, 0x58, 0xd8, 0x58,
		0xd8, 0x58, 0xd8, 0x58, 0xd8, 
        0x5c
    };
	
	for (i = 0x01, j = 18 ; i <= 0x80 ; i *= 2 , j -= 2) 
	{
		if (val & i) 
		{
			buffer[j] = buffer[j] | 1;
			buffer[j+1] = buffer[j+1] | 1;
		}
	}
    
    [self setCameraRegisters:QCAM_VC_SET_BRIGHTNESS data:buffer size:sizeof(buffer)];
}


- (void) setShutter: (float) v 
{
    UInt8 val = 255 * v;
	unsigned char buffer[2];
	int ival;
    
	/* No idea why exposure range is 294 -> 1, 295 -> 16383, but that's what it is. */
	/* Exposure zero and one, appear to be the same thing. */
    
	ival = val + 1;
	ival = (ival < 4) ? ival : ((ival * ival) >> 2); /* linear below 4 */
	
	if(ival < 295)
	{
		ival = 295 - ival;
	}
	else if(ival > 16383)
	{
		ival = 16383;
	}
    
	buffer[0] = ival;
	buffer[1] = ival >> 8;
    
    [self setCameraRegisters:QCAM_VC_SET_EXPOSURE data:buffer size:2];
}


- (void) setCCDArea
{
    int w = [self width];
    int h = [self height];
    
    multiplier = 0;
    
    if (w > 176 || h > 144) // has to fit inside a byte?
    {
        multiplier = 1;
        w /= 2;
        h /=2;
    }
    	
    UInt8 ccd[4];
    /*
	unsigned char first_col;
	unsigned char last_col;
	unsigned char first_row;
	unsigned char last_row;
	unsigned char multiplier;
    */
    
    ccd[0] = 92 - w / 2;
    ccd[1] = ccd[0] + w;
    ccd[2] = (73 - h / 2) << multiplier;
    ccd[3] = ccd[2] + h;
        
    [self setCameraRegisters:QCAM_VC_SET_CCD_AREA data:ccd size:4];
}


//
// try a couple of ways:
// - keep readin until register says empty
// - precompute size
- (void) readData
{
    //set up
    
    // loop while data is available
    
    // read in more data
    
    [self setCameraRegister:QCAM_VC_GET_FRAME data:frameCount];

    int ready = 0;
    int readyCount = 0;
    
    do 
    {
        UInt8 misc = 0;
        
        [self getCameraRegister:QCAM_VC_SET_MISC data:&misc size:1];
        ready = misc & QCAM_VC_BIT_FRAME_READY;
        
        if (!ready) 
        {
            printf("QuickCam VC image is not ready! [%2x]\n", misc);
            usleep(20000);
            
            if (++readyCount > 10) 
                ready = 1;
        }
    } 
    while (!ready);
    
    UInt32 totalLength = ([self width] * [self height] * bpc / 8) + 64;
    UInt32 expectedLength = totalLength;
    
    void * buf = malloc(totalLength + 1);
    
    IOReturn ret = (*streamIntf)->ReadPipe(streamIntf, [self getGrabbingPipe], buf, &totalLength);

    if (ret != kIOReturnSuccess) 
    {
        printf("There was a problem reading the chunk\n");
    }
    
    printf("A chunk of length %ld was just read (expected %ld).\n", totalLength, expectedLength);
        
#if 0
	unsigned long oldjif, rate, diff;
	int err;
	size_t size;
    
	if ( (err=allocate_raw_frame(qcamvc)) )
		return err;
    
	oldjif = jiffies;
	
	/* wait for it to become ready */
	if (!frame_is_ready(qcamvc))
	{ /* about 2 secounds has elapsed without the camera telling us a frame is ready... */
		printk("Camera timed-out while grabbing frame #%d.\n", qcamvc->frame_count);
		return -ENODEV;
	}

	/* now suck the image data from the camera */
	if (set_register(qcamvc, QCAM_VC_GET_FRAME, qcamvc->frame_count))
    return -ENODEV;

	size = qcamvc->ops->qcamvc_stream_read(qcamvc->lowlevel_data, qcamvc->raw_frame, qcamvc->packet_len);

	if (size == 0)
{
		printk("Failed to read frame #%d from the camera.\n", qcamvc->frame_count);
		return -1;
}

/* calc frame rate */
rate = qcamvc->packet_len * HZ / 1024;
diff = jiffies-oldjif;
qcamvc->transfer_rate = diff==0 ? rate : rate/diff;

return size;
#endif
}

// 
// Bulk read version???
//
- (void) grabbingThread: (id) data 
{
    NSAutoreleasePool * pool=[[NSAutoreleasePool alloc] init];
//    IOReturn error;
    bool ok = true;
//    long i;
    
    ChangeMyThreadPriority(10);	// We need to update the isoch read in time, so timing is important for us
    
    // Try to get as much bandwidth as possible somehow?
    
    if (![self setGrabInterfacePipe]) 
    {
        if (grabContext.contextError == CameraErrorOK) 
            grabContext.contextError = CameraErrorNoBandwidth; // Probably means not enough bandwidth
        ok = NO;
    }
    
    // Start the stream
    
    if (ok) 
        ok = [self startupGrabStream];
    
    // keep going until we stop ()
    
    while (shouldBeGrabbing) 
    {
        // ask for frame
        
        // read data
        
        [self readData];
        
        // put it where it goes
        
        // prepare to get next frame
    }
    
    // Stop the stream, reset the USB, close down 
    
    [self shutdownGrabStream];
    
    shouldBeGrabbing = NO; // Error in grabbingThread or abort? initiate shutdown of everything else
    [grabContext.chunkReadyLock unlock]; // Give the decodingThread a chance to abort
    
    // Exit the thread cleanly
    
    [pool release];
    grabbingThreadRunning = NO;
    [NSThread exit];
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
    [bayerConverter convertFromSrc:buffer->buffer
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


- (CameraError) setCameraRegister: (UInt8) reg  data: (UInt8) value
{
    return [self setCameraRegisters:reg data:&value size:1];
}


- (CameraError) setCameraRegisters: (UInt8) reg  data: (void *) buffer  size: (UInt32) length
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
        IOReturn result = (*streamIntf)->WritePipe(streamIntf, 1, buffer, length);
        CheckError(result, "QuickCamVCDriver:setCameraRegister");
        ok = (result) ? NO : YES;
    }
    
    return (ok) ? CameraErrorOK : CameraErrorUSBProblem;
}


- (CameraError) getCameraRegister: (UInt8) reg  data: (void *) buffer  size: (UInt32) length
{
    BOOL ok = YES;
    UInt8 registers[7];
    UInt8 readBuffer[64];
    UInt32 actualLength = 64;
    
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
//      IOReturn result = (*intf)->ReadPipe(intf, 2, buffer, &length);
        IOReturn result = (*streamIntf)->ReadPipe(streamIntf, 2, readBuffer, &actualLength);
        CheckError(result, "QuickCamVCDriver:getCameraRegister");
        ok = (result) ? NO : YES;
        [self resetUSS720];
    }
    
    int i;
    for (i = 0; i < length; i++) 
        ((UInt8 *) buffer)[i] = readBuffer[i];
    
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
        IOReturn result = (*streamIntf)->ReadPipe(streamIntf, 2, buffer, &length);
        CheckError(result, "QuickCamVCDriver:readStream");
        ok = (result) ? NO : YES;
    }
    
    return (ok) ? CameraErrorOK : CameraErrorUSBProblem;
}


@end
