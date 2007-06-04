//
//  PAC207Driver.m
//
//  macam - webcam app and QuickTime driver component
//  PAC207Driver - driver for the Pixart PAC207 chip
//
//  Created by HXR on 3/24/06.
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net). 
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


#import "PAC207Driver.h"

#include "USB_VendorProductIDs.h"
#include "gspcadecoder.h"


@implementation PAC207Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VISTA_PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Vista Plus", @"name", NULL], 
        
        // Add more entries here if somehow these are not enough ;)
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC207_BASE + 0x00], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Q-TEC Webcam 100 USB (or similar)", @"name", NULL], 
        
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
            @"Common PixArt PAC207 based webcam (A)", @"name", NULL], 
        
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
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbReadVICmdWithBRequest:reg 
                              wValue:value 
                              wIndex:index 
                                 buf:buffer 
                                 len:length];
}


static void pac207RegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length)
{
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbWriteVICmdWithBRequest:reg 
                               wValue:value 
                               wIndex:index 
                                  buf:buffer 
                                  len:length];
}


#include "pac207.h"


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
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    MALLOC(decodingBuffer, UInt8 *, 356 * 292 + 1000, "decodingBuffer");
    
    compressionType = proprietaryCompression;
    
    init_pixart_decoder(spca50x);
    
    cameraOperation = &fpac207;
    
	return self;
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionCIF:
            if (rate > 24) 
                return NO;
            return YES;
            break;
            
        case ResolutionQCIF:
            if (rate > 30) 
                return NO;
            return NO; // Not working yet for some unknown reason •••
            break;
            
        default: 
            return NO;
    }
}


- (BOOL) canSetUSBReducedBandwidth
{
    return YES;
}

//
// Returns the pipe used for grabbing
//
- (UInt8) getGrabbingPipe
{
    return 5;
}

//
// Put in the alt-interface with the highest bandwidth (instead of 8)
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:8];
    
    //  return [self usbSetAltInterfaceTo:8 testPipe:[self getGrabbingPipe]];
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = pixartIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


- (CameraError) spca5xx_start
{
    CameraError error = [super spca5xx_start];
    
    [self spca5xx_setbrightness];
    [self spca5xx_setcontrast];
    
    return error;
}

- (CameraError) spca5xx_setAutobright
{
    return CameraErrorUnimplemented;
}

//
// other stuff, including decompression
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
	// Decode the bytes
    
    spca50x->frame->hdrwidth = rawWidth;
    spca50x->frame->hdrheight = rawHeight;
    spca50x->frame->data = buffer->buffer;
    spca50x->frame->tmpbuffer = decodingBuffer;
    spca50x->frame->decoder = &spca50x->maindecode;  // has the code table
    
    pixart_decompress(spca50x->frame);  // Re-use the spca5xx code
    
    // Turn the Bayer data into an RGB image
    
    [bayerConverter setSourceFormat:6];  // GBRG mosaic
    [bayerConverter setSourceWidth:rawWidth height:rawHeight];
    [bayerConverter setDestinationWidth:rawWidth height:rawHeight];
    [bayerConverter convertFromSrc:decodingBuffer
                            toDest:nextImageBuffer
                       srcRowBytes:rawWidth
                       dstRowBytes:nextImageBufferRowBytes
                            dstBPP:nextImageBufferBPP
                              flip:hFlip
                         rotate180:NO];
    
    return YES;
}

@end
