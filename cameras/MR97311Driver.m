//
//  MR97311Driver.m
//
//  macam - webcam app and QuickTime driver component
//  MR97311Driver - driver for MR97311-based cameras
//
//  Created by HXR on 3/25/06.
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


#import "MR97311Driver.h"

#include "MiscTools.h"
#include "USB_VendorProductIDs.h"


@implementation MR97311Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PCAM], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Pcam (MR97311)", @"name", NULL], 
        
        // more???
        
        NULL];
}


static int pcam_reg_write(struct usb_device * dev, __u16 index, unsigned char * value, int length)
{
    BOOL ok;
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    ok = [driver usbStreamWritePipe:4 buffer:value length:length];
    
    return (ok) ? 0 : -1;
}


static void MISensor_BulkWrite(struct usb_device * dev, unsigned short * pch, char Address, int length, char controlbyte) 
{
    int dest, src, result;
    unsigned char data[6];
    
    memset(data, 0, 6);
    
    for (dest = 3, src = 0; src < length; src++) 
    {
        data[0] = 0x1f;
        data[1] = controlbyte;
        data[2] = Address + src;
        data[dest] = pch[src] >> 8;	//high byte;
        data[dest + 1] = pch[src];	//low byte;
        data[dest + 2] = 0;
        
        result = pcam_reg_write(dev, Address, data, 5);
        
        PDEBUG(1, "reg write: 0x%02X , result = 0x%x \n", Address, result);
        
        if (result < 0) 
            printk("reg write: error %d \n", result);
    }
}

static int usb_sndintpipe(struct usb_device * dev, int endpoint)
{
    return 5;
}

static int usb_clear_halt(struct usb_device * dev, int pipe)
{
    BOOL ok;
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    ok = [driver usbClearPipeStall:pipe];
    
    return (ok) ? 0 : -1;
}

#include "mr97311.h"

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    hardwareBrightness = NO;
    hardwareContrast = NO;
    
    cameraOperation = &fmr97311;
    
    spca50x->qindex = 5; // Should probably be set before init_jpeg_decoder()
    
    spca50x->cameratype = JPGM;
    spca50x->bridge = BRIDGE_MR97311;
    spca50x->sensor = SENSOR_MI0360; // true for all??
    
    compressionType = gspcaCompression;
    
    spca50x->i2c_ctrl_reg = 0;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  mr97311FrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                     UInt32 * dataStart, UInt32 * dataLength, 
                                     UInt32 * tailStart, UInt32 * tailLength, 
                                     GenericFrameInfo * frameInfo)
{
    static int packet = 0;
    static int lastWasInvalid = 0;
    
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 6) 
    {
        packet = 0;
        lastWasInvalid = 1;
        
        *dataLength = 0;
        
#ifdef REALLY_VERBOSE
        printf("Invalid packet (length = %d.\n", frameLength);
#endif
        return invalidFrame;
    }
    
#ifdef REALLY_VERBOSE
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [129] = 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
           buffer[0], frameLength, buffer[1], buffer[129], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    for (position = 0; position < frameLength - 6; position++) 
    {
        if ((buffer[position+0] == 0xFF) && 
            (buffer[position+1] == 0xFF) && 
            (buffer[position+2] == 0x00) && 
            (buffer[position+3] == 0xFF) && 
            (buffer[position+4] == 0x96) && 
           ((buffer[position+5] == 0x64) || (buffer[position+5] == 0x65) || (buffer[position+5] == 0x66) || (buffer[position+5] == 0x67)))
        {
#if REALLY_VERBOSE
            printf("New chunk! (position = %d\n", position);
#endif
            if (position > 0) 
            {
                *tailStart = 0;
                *tailLength = position;
            }
            
            *dataStart = position + 16;
            *dataLength = frameLength - position - 16;
            
            return newChunkFrame;
        }
    }
    
    lastWasInvalid = 0;
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = mr97311FrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:8];
}


@end


@implementation MR97310Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_TRUST_SPYCAM_100], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_AIPTEK], @"idVendor",
            @"Trust Spycam 100 (MR97310A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PENCAM_VGA_PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_AIPTEK], @"idVendor",
            @"Aiptek Pencam VGA+ or Maxcell Webcam (MR97310A)", @"name", NULL], 
        
        // MR97310A is like STV0680? from mr97310 sourceforge project // unlikely
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_MR97310_TYPE_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Small Generic Camera (MR97310 id 0x010e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_MR97310_TYPE_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Vivicam 55 or similar (MR97310 id 0x010f)", @"name", NULL], 
        
        // more???
        
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
    
    spca50x->cameratype = -1;
    
    compressionType = proprietaryCompression;
    
	return self;
}


- (void) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
}

/***** Still Camera Functionality *****/

- (BOOL) canStoreMedia 
{
    return YES;
}


- (long) numberOfStoredMediaObjects 
{
    return 1;
}


- (NSDictionary*) getStoredMediaObject:(long)idx 
{
    return NULL;
}


- (BOOL) canGetStoredMediaObjectInfo 
{
    return NO;
}


- (NSDictionary*) getStoredMediaObjectInfo:(long)idx 
{
    return NULL;
}


@end


/*
 T:  Bus=05 Lev=01 Prnt=01 Port=00 Cnt=01 Dev#=  2 Spd=12  MxCh= 0
 D:  Ver= 1.10 Cls=ff(vend.) Sub=ff Prot=ff MxPS= 8 #Cfgs=  1
 P:  Vendor=08ca ProdID=0111 Rev= 1.00
 S:  Product=Dual-Mode Digital Camera
 C:* #Ifs= 1 Cfg#= 1 Atr=80 MxPwr=500mA
 I:  If#= 0 Alt= 0 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS=   0 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=   0 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 1 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 128 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 2 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 256 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 3 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 384 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 4 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 512 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 5 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 680 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 6 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 800 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 7 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 900 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 8 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS=1007 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 */