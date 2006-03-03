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

#import "SPCA5XX.h"

#include <unistd.h>

#include "USB_VendorProductIDs.h"


@interface SPCA5XX (Private)

- (CameraError) startupGrabbing;
- (CameraError) shutdownGrabbing;

@end


@implementation SPCA5XX


void spca5xxRegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbReadCmdWithBRequest:reg 
                            wValue:value 
                            wIndex:index 
                               buf:buffer 
                               len:length];
}


void spca5xxRegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbWriteCmdWithBRequest:reg 
                             wValue:value 
                             wIndex:index 
                                buf:buffer 
                                len:length];
}


int spca50x_reg_write(struct usb_device * dev, __u16 reg, __u16 index, __u16 value)
{
    __u8 buf[16]; // not sure this is needed, but I'm hesitant to pass NULL
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
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
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
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


- (id) initWithCentral:(id) c 
{
    self = [super initWithCentral:c];
    
    if (!self) 
        return NULL;
    
    bayerConverter = [[BayerConverter alloc] init];
    if (!bayerConverter) 
        return NULL;
        
    return self;
}


- (void) dealloc 
{
    if (bayerConverter) 
    {
        [bayerConverter release]; 
        bayerConverter = NULL;
    }
    
    [super dealloc];
}


- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId 
{
    CameraError error;
    
    // Setup the connection to the camera
    
    error = [self usbConnectToCam:usbLocationId configIdx:0];
    
    if (error != CameraErrorOK) 
        return error;
    
    // Set some default parameters
    
    [self setBrightness:0.5];
    [self setContrast:0.5];
    [self setSaturation:0.5];
    [self setSharpness:0.5];
    [self setGamma: 0.5];
    
    // Do the remaining, usual connection stuff
    
    error = [super startupWithUsbLocationId:usbLocationId];
    
    return error;
}


//////////////////////////////////////
//
//  Image / camera properties can/set
//
//////////////////////////////////////


- (BOOL) canSetSharpness 
{
    return YES; // Perhaps ill-advised
}


- (void) setSharpness:(float) v 
{
    [super setSharpness:v];
    [bayerConverter setSharpness:sharpness];
}


- (BOOL) canSetBrightness 
{
     return YES;
}


- (void) setBrightness:(float) v 
{
    [self spca5xx_setbrightness];
    [super setBrightness:v];
    [bayerConverter setBrightness:brightness - 0.5f];
}


- (BOOL) canSetContrast 
{
    return YES;
}


- (void) setContrast:(float) v
{
    [self spca5xx_setcontrast];
    [super setContrast:v];
    [bayerConverter setContrast:contrast + 0.5f];
}


- (BOOL) canSetSaturation
{
    return YES;
}


- (void) setSaturation:(float) v
{
    [super setSaturation:v];
    [bayerConverter setSaturation:saturation * 2.0f];
}


- (BOOL) canSetGamma 
{
    return YES; // Perhaps ill-advised
}


- (void) setGamma:(float) v
{
    [super setGamma:v];
    [bayerConverter setGamma:gamma + 0.5f];
}


- (BOOL) canSetGain 
{
    return NO;
}


- (BOOL) canSetShutter 
{
    return NO;
}


// Gain and shutter combined
- (BOOL) canSetAutoGain 
{
    return NO;
}


- (void) setAutoGain:(BOOL) v
{
    if (v == autoGain) 
        return;
    
    [super setAutoGain:v];
    [bayerConverter setMakeImageStats:v];
}


- (BOOL) canSetHFlip 
{
    return YES;
}


- (short) maxCompression 
{
    return 0;
}


- (BOOL) canSetWhiteBalanceMode 
{
    return NO;
}


- (WhiteBalanceMode) defaultWhiteBalanceMode 
{
    return WhiteBalanceLinear;
}


- (BOOL) canBlackWhiteMode 
{
    return NO;
}


- (BOOL) canSetLed 
{
    return NO;
}


// use mode array from "config"
- (BOOL) supportsResolution:(CameraResolution) res fps:(short) rate 
{
//    spca5xx_struct;
    int mode;
    
    for (mode = QCIF; mode < TOTMODE; mode++) 
    {
        /*
         spca50x->mode_cam[CIF].width = 320;
         spca50x->mode_cam[CIF].height = 240;
         spca50x->mode_cam[CIF].t_palette = P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
         spca50x->mode_cam[CIF].pipe = 1023;
         spca50x->mode_cam[CIF].method = 1;
         spca50x->mode_cam[CIF].mode = 0;
*/         
    }
    
    if (rate > 30 || rate < 1) 
        return NO;
    
    if (res == ResolutionQSIF) 
        return YES;
    
    if (res == ResolutionSIF) 
        return YES;
    
    if (res == ResolutionVGA) 
        return YES;
    
    return NO;
}


- (CameraResolution) defaultResolutionAndRate:(short *) dFps 
{
    if (dFps) 
        *dFps = 5;
    
    return ResolutionSIF;
}


//
// Do we really need a separate grabbing thread? Let's try without
// 
- (CameraError) decodingThread 
{
    CameraError error = CameraErrorOK;
    BOOL bufferSet, actualFlip;
    
    // Initialize grabbing
    
    error = [self startupGrabbing];
    
    if (error) 
        shouldBeGrabbing = NO;
    
    // Grab until told to stop
    
    if (shouldBeGrabbing) 
    {
        while (shouldBeGrabbing) 
        {
            // Get the data
            
//            [self readEntry:chunkBuffer len:chunkLength];
            
            // Get the buffer ready
            
            [imageBufferLock lock];
            
            lastImageBuffer = nextImageBuffer;
            lastImageBufferBPP = nextImageBufferBPP;
            lastImageBufferRowBytes = nextImageBufferRowBytes;
            
            bufferSet = nextImageBufferSet;
            nextImageBufferSet = NO;
            
            actualFlip = hFlip;
//          actualFlip = [self flipGrabbedImages] ? !hFlip : hFlip;
            
            // Decode into buffer
            
            if (bufferSet) 
            {
//              unsigned char * imageSource = (unsigned char *) (chunkBuffer + chunkHeader);
                unsigned char * imageSource = (unsigned char *) NULL;
                
                [bayerConverter convertFromSrc:imageSource
                                        toDest:lastImageBuffer
                                   srcRowBytes:[self width]
                                   dstRowBytes:lastImageBufferRowBytes
                                        dstBPP:lastImageBufferBPP
                                          flip:actualFlip
                                     rotate180:YES];
                
                [imageBufferLock unlock];
                [self mergeImageReady];
            } 
            else 
            {
                [imageBufferLock unlock];
            }
        }
    }
    
    // close grabbing
    
    [self shutdownGrabbing];
    
    return error;
}    
    

- (CameraError) startupGrabbing 
{
    CameraError error = CameraErrorOK;
    
    switch ([self resolution])
    {
        case ResolutionQSIF:
            break;
            
        case ResolutionSIF:
            break;
            
        case ResolutionVGA:
            break;
            
        default:
            break;
    }
    
    // Initialize Bayer decoder
    
    if (!error) 
    {
        [bayerConverter setSourceWidth:[self width] height:[self height]];
        [bayerConverter setDestinationWidth:[self width] height:[self height]];
        [bayerConverter setSourceFormat:4];
//      [bayerConverter setMakeImageStats:YES];
    }
    
    
    return error;
}


- (CameraError) shutdownGrabbing 
{
    CameraError error = CameraErrorOK;
    
//    free(chunkBuffer);
    
    return error;
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




@implementation SPCA5XX_SONIX


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
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbReadVICmdWithBRequest:reg 
                              wValue:value 
                              wIndex:index 
                                 buf:buffer 
                                 len:length];
}


static void sonixRegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 *buffer, __u16 length)
{
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
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


#pragma mark ----- PAC207 -----

@implementation PAC207


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VISTA_PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Vista Plus", @"name", NULL], 
        
        // Add more entries here
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x00], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Q-TEC Webcam 100 USB", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x01], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 01)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x02], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 02)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x03], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 03)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x04], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 04)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x05], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 05)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x06], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 06)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x07], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 07)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x08], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Common PixArt PAC207 based webcam", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x09], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 09)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0a)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0b)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0d)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x0f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 0f)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x10], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Genius VideoCAM GE112 (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x11], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Genius KYE VideoCAM GE111 (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x12], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 12)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x13], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 13)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x14], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 14)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x15], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 15)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x16], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 16)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x17], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 17)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x18], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 18)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x19], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 19)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1a)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1b)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1d)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x1f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC207 based webcam (previously unknown 1f)", @"name", NULL], 
        
        NULL];
}


static void pac207RegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{   
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbReadVICmdWithBRequest:reg 
                              wValue:value 
                              wIndex:index 
                                 buf:buffer 
                                 len:length];
}


static void pac207RegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 *buffer, __u16 length)
{
    SPCA5XX * driver = (SPCA5XX *) dev->driver;
    
    [driver usbWriteVICmdWithBRequest:reg 
                               wValue:value 
                               wIndex:index 
                                  buf:buffer 
                                  len:length];
}


#include "pac207.h"

// 


- (CameraError) spca5xx_init
{
    pac207_init(spca5xx_struct);
    return CameraErrorOK;
}



- (CameraError) spca5xx_config
{
    pac207_config(spca5xx_struct);
    return CameraErrorOK;
}


- (CameraError) spca5xx_start
{
    pac207_start(spca5xx_struct);
    return CameraErrorOK;
}


- (CameraError) spca5xx_stop
{
    pac207_stop(spca5xx_struct);
    return CameraErrorOK;
}


- (CameraError) spca5xx_shutdown
{
    pac207_shutdown(spca5xx_struct);
    return CameraErrorOK;
}


// brightness also returned in spca5xx_struct

- (CameraError) spca5xx_getbrightness
{
    pac207_getbrightness(spca5xx_struct);
    return CameraErrorOK;
}


// takes brightness from spca5xx_struct

- (CameraError) spca5xx_setbrightness
{
    pac207_setbrightness(spca5xx_struct);
    return CameraErrorOK;
}


// contrast also return in spca5xx_struct

- (CameraError) spca5xx_getcontrast
{
    pac207_getcontrast(spca5xx_struct);
    return CameraErrorOK;
}


// takes contrast from spca5xx_struct

- (CameraError) spca5xx_setcontrast
{
    pac207_setcontrast(spca5xx_struct);
    return CameraErrorOK;
}


// other stuff, including decompression



@end



