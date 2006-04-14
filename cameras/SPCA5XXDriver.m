//
//  SPCA5XX.m
//
//  macam - webcam app and QuickTime driver component
//  SPCA5XX - driver for SPCA5XX-based cameras
//
//  Created by HXR on 9/19/05.
//  Copyright (C) 2005 HXR (hxr@users.sourceforge.net). 
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

#import "SPCA5XXDriver.h"

#include "MiscTools.h"

#include <unistd.h>



@implementation SPCA5XXDriver


void spca5xxRegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbReadCmdWithBRequest:reg 
                            wValue:value 
                            wIndex:index 
                               buf:buffer 
                               len:length];
}


void spca5xxRegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbWriteCmdWithBRequest:reg 
                             wValue:value 
                             wIndex:index 
                                buf:buffer 
                                len:length];
}


int spca50x_reg_write(struct usb_device * dev, __u16 reg, __u16 index, __u16 value)
{
    __u8 buf[16]; // not sure this is needed, but I'm hesitant to pass NULL
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    // No USB_DIR_OUT in original code!
    
    BOOL ok = [driver usbWriteCmdWithBRequest:reg 
                                       wValue:value 
                                       wIndex:index 
                                          buf:buf 
                                          len:0];
    
    return (ok) ? 0 : -1;
}


int spca50x_reg_read_with_value(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u16 length)
{
    __u8 buf[16]; // originally 4, should really check against length
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    BOOL ok = [driver usbReadCmdWithBRequest:reg 
                                       wValue:value 
                                       wIndex:index 
                                          buf:buf 
                                          len:0];
    
    return (ok) ? buf[0] + 256 * buf[1] + 256 * 256 * buf[2] + 256 * 256 * 256 * buf[3] : -1;
//    return *(int *)&buffer[0]; //  original code, non-portable because ofbyte ordering assumptions
}


/* 
 *   returns: negative is error, pos or zero is data
 */
int spca50x_reg_read(struct usb_device * dev, __u16 reg, __u16 index, __u16 length)
{
	return spca50x_reg_read_with_value(dev, reg, 0, index, length);
}


/*
 * Simple function to wait for a given 8-bit value to be returned from
 * a spca50x_reg_read call.
 * Returns: negative is error or timeout, zero is success.
 */
int spca50x_reg_readwait(struct usb_device * dev, __u16 reg, __u16 index, __u16 value)
{
	int count = 0;
	int result = 0;
    
	while (count < 20)
	{
		result = spca50x_reg_read(dev, reg, index, 1);
		if (result == value) 
            return 0;
        
//		wait_ms(50);
        usleep(50);
        
		count++;
	}
    
	return -1;
}


int spca50x_write_vector(struct usb_spca50x * spca50x, __u16 data[][3])
{
	struct usb_device * dev = spca50x->dev;
	int err_code;
    
	int I = 0;
	while ((data[I][0]) != (__u16) 0 || (data[I][1]) != (__u16) 0 || (data[I][2]) != (__u16) 0) 
	{
		err_code = spca50x_reg_write(dev, data[I][0], (__u16) (data[I][2]), (__u16) (data[I][1]));
		if (err_code < 0) 
		{ 
//			PDEBUG(1, "Register write failed for 0x%x,0x%x,0x%x", data[I][0], data[I][1], data[I][2]); 
			return -1; 
		}
		I++;
	}
    
	return 0;
}


// need meat here

//
// Initialize the driver
//
- (id) initWithCentral:(id) c 
{
    self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x = (struct usb_spca50x *) malloc(sizeof(struct usb_spca50x));
    spca50x->dev = (struct usb_device *) malloc(sizeof(struct usb_device));
    spca50x->dev->driver = self;
    
    return self;
}

//
// Subclass this for more functionality
//
- (void) startupCamera
{
    // 
    
    [self spca5xx_init];
    [self spca5xx_config];
    
    // Set some default parameters
    
    [super startupCamera];
}


- (void) dealloc 
{
    [self spca5xx_shutdown];
    
    free(spca50x->dev);
    free(spca50x);
    
    [super dealloc];
}

//
// spca5xx is confused about meaning of CIF and SIF, or we are, whatever...
//
short SPCA5xxResolution(CameraResolution res) 
{
    short ret;
    
    switch (res) 
    {
        case ResolutionSQSIF: ret = CUSTOM; break;
        case ResolutionQSIF:  ret = QCIF; break;
        case ResolutionQCIF:  ret = QSIF; break;
        case ResolutionSIF:   ret = CIF; break;
        case ResolutionCIF:   ret = SIF; break;
        case ResolutionVGA:   ret = VGA; break;
        case ResolutionSVGA:  ret = CUSTOM; break;
        default:              ret =  -1; break;
    }
    return ret;
}


// use mode array from "config"
- (BOOL) supportsResolution:(CameraResolution) res fps:(short) rate 
{
    int mode = SPCA5xxResolution(res);
    
    if (mode < 0) 
        return NO;
    
    /*
     spca50x->mode_cam[CIF].width = 320;
     spca50x->mode_cam[CIF].height = 240;
     spca50x->mode_cam[CIF].t_palette = P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
     spca50x->mode_cam[CIF].pipe = 1023;
     spca50x->mode_cam[CIF].method = 1;
     spca50x->mode_cam[CIF].mode = 0;
     */         
    
    if (rate > 30 || rate < 1) 
        return NO;
    
    if (spca50x->mode_cam[mode].width == WidthOfResolution(res) && 
        spca50x->mode_cam[mode].height == HeightOfResolution(res) && 
        spca50x->mode_cam[mode].pipe > 0) 
        return YES;
    
    return NO;
}


- (CameraResolution) defaultResolutionAndRate:(short *) dFps 
{
    if (dFps) 
        *dFps = 5;
    
    if ([self supportsResolution:ResolutionVGA fps:*dFps]) 
        return ResolutionVGA;
    
    if ([self supportsResolution:ResolutionCIF fps:*dFps]) 
        return ResolutionCIF;
    
    if ([self supportsResolution:ResolutionSIF fps:*dFps]) 
        return ResolutionSIF;
    
    if ([self supportsResolution:ResolutionQCIF fps:*dFps]) 
        return ResolutionQCIF;
    
    if ([self supportsResolution:ResolutionQSIF fps:*dFps]) 
        return ResolutionQSIF;
    
    return ResolutionInvalid;
}

- (void) spcaSetResolution: (int) spcaRes
{
    spca50x->mode = spca50x->mode_cam[spcaRes].mode;
}

//
// Set a resolution and frame rate.
//
- (void) setResolution: (CameraResolution) r fps: (short) fr 
{
    if (![self supportsResolution:r fps:fr]) 
        return;
    
    [stateLock lock];
    if (!isGrabbing) 
    {
        resolution = r;
        fps = fr;
        
        [self spcaSetResolution:SPCA5xxResolution(r)];
    }
    [stateLock unlock];
}


- (BOOL) canSetBrightness 
{
    return YES;
}


- (void) setBrightness:(float) v 
{
    spca50x->brightness = v * 65535;
    [self spca5xx_setbrightness];
    [super setBrightness:v];
}


- (BOOL) canSetContrast 
{
    return YES;
}


- (void) setContrast:(float) v
{
    spca50x->contrast = v * 65535;
    [self spca5xx_setcontrast];
    [super setContrast:v];
}


//
// Put in the alt-interface with the highest bandwidth (instead of 8)
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbSetAltInterfaceTo:7 testPipe:[self getGrabbingPipe]];
}


//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError error = CameraErrorOK;
    
    [self spca5xx_start];
    
    return error == CameraErrorOK;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    [self spca5xx_stop];
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]];
}


#pragma mark ----- SPCA5XX Specific -----
#pragma mark -> Subclass Must Implement! <-

// The follwing must be implemented by subclasses of the SPCA5XX driver
// And hopefully it is simple, a simple call to a routine for each


// return int?
// turn off LED
// verify sensor
- (CameraError) spca5xx_init
{
    return CameraErrorUnimplemented;
}


// return int?
// get sensor and set up sensor mode array
// turn off power
// set bias
- (CameraError) spca5xx_config
{
    return CameraErrorUnimplemented;
}


// turn on power
// turn on LED
// initialize sensor
// setup image formats and compression

- (CameraError) spca5xx_start
{
    return CameraErrorUnimplemented;
}


// stop sending
// turn off LED
// turn off power
- (CameraError) spca5xx_stop
{
    return CameraErrorUnimplemented;
}


// turn off LED
// turn off power
- (CameraError) spca5xx_shutdown
{
    return CameraErrorUnimplemented;
}


// return brightness
- (CameraError) spca5xx_getbrightness
{
    return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_setbrightness
{
    return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_setAutobright
{
    return CameraErrorUnimplemented;
}


// return contrast??
- (CameraError) spca5xx_getcontrast
{
    return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_setcontrast
{
    return CameraErrorUnimplemented;
}



@end




@implementation SPCA5XX_SONIXDriver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        /*
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VISTA_PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Vista Plus", @"name", NULL], 
        */
        // Add more entries here
        
        NULL];
}

/*

static void sonixRegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{   
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbReadVICmdWithBRequest:reg 
                              wValue:value 
                              wIndex:index 
                                 buf:buffer 
                                 len:length];
}


static void sonixRegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 *buffer, __u16 length)
{
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbWriteVICmdWithBRequest:reg 
                               wValue:value 
                               wIndex:index 
                                  buf:buffer 
                                  len:length];
}


#include "sonix.h"

*/


// stuff


@end


// how about PDEBUG???

// define
void udelay(int delay_time_probably_micro_seconds)
{
    usleep(delay_time_probably_micro_seconds);
}


void wait_ms(int delay_time_in_milli_seconds)
{
    usleep(delay_time_in_milli_seconds * 1000);
}




