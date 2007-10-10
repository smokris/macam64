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
#include "gspcadecoder.h"
#include "USB_VendorProductIDs.h"


// These defines are needed by the spca5xx code

enum 
{
    Pcam,
};


@implementation MR97311Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PCAM], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Pcam (MR97311)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PENCAM_VGA_PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_AIPTEK], @"idVendor",
            @"Aiptek Pencam VGA+ or Maxcell Webcam (MR97310A)", @"name", NULL], 
        
        // MR97310A is like STV0680? from mr97310 sourceforge project
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_MR97310_TYPE_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Small Generic Camera (MR97310 id 0x010e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_MR97310_TYPE_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Vivicam 55 or similar (MR97310 id 0x010f)", @"name", NULL], 
        
        NULL];
}

#define HZ 100

static int pcam_reg_write(struct usb_device * dev, __u16 index, unsigned char * value, int length)
{
    BOOL ok;
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    /*
    [driver usbWriteVICmdWithBRequest:reg 
                               wValue:value 
                               wIndex:index 
                                  buf:buffer 
                                  len:length];
    
    [driver usbWriteVICmdWithBRequest:0x12 // syncframe? 
                               wValue:index_value 
                               wIndex:index 
                                  buf:value 
                                  len:length];
    */
    
    ok = [driver usbControlCmdWithBRequestType:0xc8 
                                      bRequest:0x12 
                                        wValue:0x00 
                                        wIndex:index 
                                           buf:value 
                                           len:length];

    return (ok) ? 0 : -1;
/**
    
    unsigned char buf[12];
    int rc;
    int i;
    unsigned char index_value = 0;
    
    memset(buf, 0, sizeof(buf));
    
    for (i = 0; i < length; i++)
        buf[i] = value[i];
    
    rc = usb_control_msg(dev,                       // device
                         usb_sndbulkpipe(dev, 4),   // pipe  = PIPE_BULK << 30 | create_pipe(dev, endpoint) = 3 << 30 | devnum << 8 | endpoint << 15 = 3 << 30 | 4 << 15 | 
                         0x12,                      // request 
                         0xc8,                      // request-type
                         index_value,               // value
                         index,                     // index
                         value,                     // data
                         length,                    // size
                         5 * HZ);                   // timeout
    
    PDEBUG(1, "reg write: 0x%02X , result = 0x%x \n", index, rc);
    
    if (rc < 0) {
        PDEBUG(1, "reg write: error %d \n", rc);
    }
    return rc;
**/
}

/**
static void pac207RegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length)
{
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbWriteVICmdWithBRequest:reg 
                               wValue:value 
                               wIndex:index 
                                  buf:buffer 
                                  len:length];
}
**/


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

//      result = usb_control_msg(dev, usb_sndbulkpipe(dev, 4), 0x12, 0xc8, 0, Address, data, 5, 5 * HZ);
        
        PDEBUG(1, "reg write: 0x%02X , result = 0x%x \n", Address, result);
        
        if (result < 0) 
            printk("reg write: error %d \n", result);
    }
}

static int /* intpipe = */ usb_sndintpipe(struct usb_device * dev, int endpoint)
{
    return 5;
}

static int /* err_code = */ usb_clear_halt(struct usb_device * dev, int pipe)
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
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    // Set as appropriate
    hardwareBrightness = NO;
    hardwareContrast = NO;
    
    // This is important
    cameraOperation = &fmr97311;
    
    spca50x->qindex = 5; // Should probably be set before init_jpeg_decoder()
    
    // Set to reflect actual values
    spca50x->bridge = BRIDGE_MR97311;
    spca50x->cameratype = JPGM;
    
    spca50x->desc = Pcam;
    spca50x->sensor = SENSOR_MI0360; // true for all??
    
    spca50x->i2c_ctrl_reg = 0;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionVGA:
            if (rate > 30)  // what is the spec?
                return NO;
            return YES;
            break;
            
        case ResolutionCIF:
            if (rate > 30)  // what is the spec?
                return NO;
            return YES;
            break;
            
        case ResolutionQCIF:
            if (rate > 30)  // what is the spec?
                return NO;
            return YES;
            break;
            
        default: 
            return NO;
    }
}

//
// Scan the frame and return the results
//
IsocFrameResult  mr97311FrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                                UInt32 * dataStart, UInt32 * dataLength, 
                                                UInt32 * tailStart, UInt32 * tailLength)
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
        printf("Invalid packet.\n");
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
            printf("New chunk!\n");
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


//
// jpeg decoding here
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
    int i;
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
//#ifdef REALLY_VERBOSE
    printf("Need to decode a JPEG buffer with %ld bytes.\n", buffer->numBytes);
//#endif
    
    // when jpeg_decode422() is called:
    //   frame.data - points to output buffer
    //   frame.tmpbuffer - points to input buffer
    //   frame.scanlength -length of data (tmpbuffer on input, data on output)
    
    spca50x->frame->width = rawWidth;
    spca50x->frame->height = rawHeight;
    spca50x->frame->hdrwidth = rawWidth;
    spca50x->frame->hdrheight = rawHeight;
    
    spca50x->frame->data = nextImageBuffer;
    spca50x->frame->tmpbuffer = buffer->buffer;
    spca50x->frame->scanlength = buffer->numBytes;
    
    spca50x->frame->decoder = &spca50x->maindecode;
    
    for (i = 0; i < 256; i++) 
    {
        spca50x->frame->decoder->Red[i] = i;
        spca50x->frame->decoder->Green[i] = i;
        spca50x->frame->decoder->Blue[i] = i;
    }
    
    spca50x->frame->cameratype = spca50x->cameratype;
    
    spca50x->frame->format = VIDEO_PALETTE_RGB24;
    
    spca50x->frame->cropx1 = 0;
    spca50x->frame->cropx2 = 0;
    spca50x->frame->cropy1 = 0;
    spca50x->frame->cropy2 = 0;
    
    // reset info.dri
    
    spca50x->frame->decoder->info.dri = 0;
    
    // do jpeg decoding
    
    jpeg_decode422(spca50x->frame, 1);  // bgr = 1 (works better for SPCA508A...)
    
    [LUT processImage:nextImageBuffer numRows:rawHeight rowBytes:nextImageBufferRowBytes bpp:nextImageBufferBPP invert:NO];
    
    return YES;
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