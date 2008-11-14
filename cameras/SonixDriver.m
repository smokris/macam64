//
//  SonixDriver.m
//
//  macam - webcam app and QuickTime driver component
//  SonixDriver - example driver to use for drivers based on the spca5xx Linux driver
//  SN9CxxxDriver - example driver to use for drivers based on the spca5xx Linux driver
//
//  Created by HXR on 06/07/2006.
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


/*
USB\VID_0c45 and PID_6005       ; SN9C101 + TAS5110
USB\VID_0c45 and PID_6009       ; SN9C101 + PAS106 

USB\VID_0c45 and PID_6024       ; SN9C102 + TAS5130
USB\VID_0c45 and PID_6025       ; SN9C102 + TAS5130
USB\VID_0c45 and PID_6025  Mi_00; sn9c103 + TAS5130   ???? see sn9c102 ???
USB\VID_0c45 and PID_6027       ; sn9c101 + OV7630
USB\VID_0c45 and PID_6028       ; SN9C102 + PAS202 
USB\VID_0c45 and PID_6029       ; SN9C102 + PAS106 
USB\VID_0c45 and PID_602a       ; SN9C101 + HV7131 D/E
USB\VID_0c45 and PID_602c       ; SN9C102 + OV7630
USB\VID_0c45 and PID_602d       ; SN9C101 + HV7131 R

USB\VID_0c45 and PID_6030       ; SN9C102 + MI0343 MI0360
USB\VID_0c45 and PID_603f       ; SN9C101 + CISVF10

USB\VID_0c45 and PID_6040       ; SN9C102P + MI0360

USB\VID_0c45 and PID_607a       ; SN9C102P + OV7648
USB\VID_0c45 amd PID_607c       ; SN9C102P + HV7131R
USB\VID_0c45 and PID_607e       ; SN9C102P + OV7630

USB\VID_0c45 and PID_6082  Mi_00; sn9c103 + MI0343,MI0360
USB\VID_0c45 and PID_6083  Mi_00; sn9c103 + HY7131D/E
USB\VID_0c45 and PID_608c  Mi_00; sn9c103 + HY7131/R
USB\VID_0c45 and PID_608e  Mi_00; sn9c103 + CISVF10
USB\VID_0c45 and PID_608f  Mi_00; sn9c103 + OV7630

USB\VID_0c45 and PID_60a8  Mi_00; sn9c103 + PAS106
USB\VID_0c45 and PID_60aa  Mi_00; sn9c103 + TAS5130
USB\VID_0c45 and PID_60ab  Mi_00; sn9c103 + TAS5110
USB\VID_0c45 and PID_60af  Mi_00; sn9c103 + PAS202

USB\VID_0c45 and PID_60c0  MI_00; SN9C105 + MI0360

USB\VID_0c45 and PID_60fa  MI_00; SN9C105 + OV7648
USB\VID_0c45 and PID_60fc  MI_00; SN9C105 + HV7131R
USB\VID_0c45 and PID_60fe  MI_00; SN9C105 + OV7630

USB\VID_0c45 and PID_6100       ; SN9C128 + MI0360 / MT9V111 / MI0360B
USB\VID_0c45 and PID_610a       ; SN9C128 + OV7648
USB\VID_0c45 and PID_610c       ; SN9C128 + HV7131R
USB\VID_0c45 and PID_610e       ; SN9C128 + OV7630
USB\VID_0c45 and PID_610b       ; SN9C128 + OV7660

USB\VID_0c45 and PID_6130       ; SN9C120 + MI0360
USB\VID_0c45 and PID_613a       ; SN9C120 + OV7648
USB\VID_0c45 and PID_613c       ; SN9C120 + HV7131R
USB\VID_0c45 and PID_613e       ; SN9C120 + OV7630
*/


#import "SonixDriver.h"

#include "Resolvers.h"
#include "gspcadecoder.h"
#include "USB_VendorProductIDs.h"


// These defines are needed by the spca5xx code

enum 
{
    AnySonixCamera,
    GeniusVideoCamNB,
    SweexTas5110,
    Sonix6025,
    BtcPc380,
    Sonix6019,
    GeniusVideoCamMessenger,
    Lic200,
    Sonix6029,
    TrustWB3400,
    MaxSonixCamera,
    
    AnySN9C1xxCamera,
    AnySN9C20xCamera,
};


@implementation SonixDriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6001], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Genius VideoCAM NB", @"name", NULL], 
        
        NULL];
}


#include "sonix.h"


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    // Set as appropriate
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    decodingSkipBytes = 6;
    
    // This is important
    
    cameraOperation = &fsonix;
    
    // And so is this
    
	init_sonix_decoder(spca50x);
    
    // Set to reflect actual values
    
    spca50x->bridge = BRIDGE_SONIX;
    spca50x->cameratype = SN9C;
    
    spca50x->desc = GeniusVideoCamNB;
    spca50x->sensor = SENSOR_TAS5110;
    spca50x->customid = SN9C102;
    
    spca50x->i2c_ctrl_reg = 0x20;
    spca50x->i2c_base = 0x11;
    spca50x->i2c_trigger_on_write = 0;
    
    compressionType = gspcaCompression;
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  sonixIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                       UInt32 * dataStart, UInt32 * dataLength, 
                                       UInt32 * tailStart, UInt32 * tailLength, 
                                       GenericFrameInfo * frameInfo)
{
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = 0;
    *tailLength = 0;
    
    if (frameLength < 6) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
        printf("Invalid packet!\n");
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
#endif
    
    for (position = 0; position < frameLength - 6; position++) 
    {
        if ((buffer[position+0] == 0xFF) && 
            (buffer[position+1] == 0xFF) && 
            (buffer[position+2] == 0x00) && 
            (buffer[position+3] == 0xC4) && 
            (buffer[position+4] == 0xC4) && 
            (buffer[position+5] == 0x96))
        {
#if REALLY_VERBOSE
            printf("New image start!\n");
#endif
            if (position > 0) 
                *tailLength = position;
            
            *dataStart = position + 6;
            *dataLength = frameLength - *dataStart;
            
            return newChunkFrame;
        }
    }
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = sonixIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:8];
}


- (BOOL) startupGrabStream 
{
    BOOL result = [super startupGrabStream];
    
    // clear interrupt pipe from any stall
    (*streamIntf)->ClearPipeStall(streamIntf, 3);
    
    return result;
}

/*
//
// other stuff, including decompression
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
#if REALLY_VERBOSE
    printf("Need to decode a buffer with %ld bytes.\n", buffer->numBytes);
#endif
    
    if (buffer->numBytes < 2500) 
        return NO;
    
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
	// Decode the bytes
    
    spca50x->frame->hdrwidth = rawWidth;
    spca50x->frame->hdrheight = rawHeight;
    spca50x->frame->data = buffer->buffer + decodingSkipBytes;
    spca50x->frame->tmpbuffer = decodingBuffer;
    spca50x->frame->decoder = &spca50x->maindecode;  // has the code table
    
	sonix_decompress(spca50x->frame);
    
    // Turn the Bayer data into an RGB image
    
    [bayerConverter setSourceFormat:bayerFormat];
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
*/

@end


@implementation SonixDriverVariant1

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6005], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Swees (TAS5110)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6007], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SONIX 0x6007", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = SweexTas5110;
    spca50x->sensor = SENSOR_TAS5110;
    spca50x->customid = SN9C101;
    
    spca50x->i2c_ctrl_reg = 0x20;
    spca50x->i2c_base = 0x11;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SonixDriverVariant2

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6024], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SONIX 0x6024", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6025], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"XCAM Shanga", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Sonix6025;
    spca50x->sensor = SENSOR_TAS5130CXX;
    spca50x->customid = SN9C102;
    
    spca50x->i2c_ctrl_reg = 0x20;
    spca50x->i2c_base = 0x11;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SonixDriverVariant3

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6028], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix BTC PC380", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = BtcPc380;
    spca50x->sensor = SENSOR_PAS202;
    spca50x->customid = SN9C102;
    
    spca50x->i2c_ctrl_reg = 0x80;
    spca50x->i2c_base = 0x40;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SonixDriverVariant4

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6019], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SONIX 0x6019", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Sonix6019;
    spca50x->sensor = SENSOR_OV7630;
    spca50x->customid = SN9C101;
    
    spca50x->i2c_ctrl_reg = 0x80;
    spca50x->i2c_base = 0x21;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SonixDriverVariant5

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x602c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SONIX 0x602c", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x602e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Genius VideoCam Messenger", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = GeniusVideoCamMessenger;
    spca50x->sensor = SENSOR_OV7630;
    spca50x->customid = SN9C102;
    
    spca50x->i2c_ctrl_reg = 0x80;
    spca50x->i2c_base = 0x21;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SonixDriverVariant5B

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x608f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Genius Look 315FS or Sweex USB Webcam 300K", @"name", NULL], 
        
        // Genius Look 315FS
        // Sweex USB Webcam 300K (JA000060)
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = GeniusVideoCamMessenger;
    spca50x->sensor = SENSOR_OV7630;
    spca50x->customid = SN9C103;
    
    spca50x->i2c_ctrl_reg = 0x80;
    spca50x->i2c_base = 0x21;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SonixDriverVariant6

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x602d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"LG LIC-200", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Lic200;
    spca50x->sensor = SENSOR_HV7131R;
    spca50x->customid = SN9C102;
    
    spca50x->i2c_ctrl_reg = 0x80;
    spca50x->i2c_base = 0x11;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SonixDriverVariant7

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6009], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SONIX 0x6009", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x600d], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Trust 120 Spacecam", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6029], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SONIX 0x6029", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Sonix6029;
    spca50x->sensor = SENSOR_PAS106;
    spca50x->customid = SN9C101;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x40;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SonixDriverVariant8

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // This is actually a SN9C103... hopefully it works anyway
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x60af], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Trust HiRes Webcam WB-3400T", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    decodingSkipBytes = 12;
    
//    bayerFormat = 4;
    
    // Green is like '105 and '120
    // valid up to 0x7f instead of 0x0f
    // into register 0x07 instead of 0x11?
    
//  cameraOperation->set_contrast = fsn9cxx.set_contrast;
    
    spca50x->desc = TrustWB3400;
    spca50x->sensor = SENSOR_PAS202;
    spca50x->customid = SN9C103;
    
    spca50x->i2c_ctrl_reg = 0x80;
    spca50x->i2c_base = 0x40;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SonixDriverOV6650

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6011], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Max Webcam (SN9C101G-OV6650-352x288)", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = MaxSonixCamera;
    spca50x->sensor = SENSOR_OV6650;
    spca50x->customid = SN9C101;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x21;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SN9CxxxDriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6040], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Speed NVC 350K (0x6040)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x607c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix WC 311P (0x607c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x60c0], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix SN 535 (0x60c0)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x60ec], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Talk Cam VX6 (0x60ec)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x60fb], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix (0x60fb)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x60fc], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix Lic 300 (0x60fc)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x60fe], @"idProduct", 
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Rainbow Color Webcam 5790P (0x60fe", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6128], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"iMicro (0x6128)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x612a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix (0x612a)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x612c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Typhoon EasyCam 1.3 (0x612c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x612f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Clone 11086 (0x612f)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6130], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix PC Cam (0x6130)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6138], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix (0x6138)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x613b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix (0x613b)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x613c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix PC Cam 168 (0x613c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x613e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Skype Video Pack Camera (Model C7) (0x613e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6143], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix PC Cam 168 version 2 (0x6143)", @"name", NULL], 
        
        NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral:(id)c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    compressionType = gspcaCompression;
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    hardwareSaturation = YES;
    
    // General bridge settings - These are valid for all the bridges, '102P, '105, '120 etc
    
    cameraOperation = &fsn9cxx;
    spca50x->bridge = BRIDGE_SN9CXXX;
    spca50x->cameratype = JPGS;	// jpeg 4.2.2 whithout header
    spca50x->i2c_ctrl_reg = 0x81;
    
    // Bridge and sensor settings are set up in [startupCamera]
    
    spca50x->customid = SN9C102P;
    spca50x->sensor = SENSOR_HV7131R;
    spca50x->i2c_base = 0x11;
    
    // Sometimes a specific camera needs to be identified in the gspca code
    
    spca50x->desc = AnySN9C1xxCamera; // used to be SpeedNVC350K
    
	return self;
}

//
// Adjust bridge and sensor settings
//
- (void) startupCamera
{
    IOReturn err;
    UInt16 productID;
    
    err = (*streamIntf)->GetDeviceProduct(streamIntf, &productID);
    CheckError(err, "startupCamera-GetDeviceProduct");
    
    // Which bridge is being used?
    
    if (0x6040 <= productID && productID <= 0x607f) 
        spca50x->customid = SN9C102P;
    
    if (0x6080 <= productID && productID <= 0x60bf) 
        spca50x->customid = SN9C103;
    
    if (0x60c0 <= productID && productID <= 0x60ff) 
        spca50x->customid = SN9C105;
    
    if (0x6100 <= productID && productID <= 0x610f) 
        spca50x->customid = SN9C128;
    
    if (0x6120 <= productID && productID <= 0x612f) 
        spca50x->customid = SN9C110;
    
    if (0x6130 <= productID && productID <= 0x613f) 
        spca50x->customid = SN9C120;
    
    if (0x6140 <= productID && productID <= 0x614f) // only sure about 6143
        spca50x->customid = SN9C120;                // SN9C120B actually
    
    if (0x6240 <= productID && productID <= 0x627f) 
        spca50x->customid = SN9C201;
    
    if (0x6280 <= productID && productID <= 0x62bf) 
        spca50x->customid = SN9C202;
    
    // What sensor is being used?
    
    switch (productID & 0x0003F)
    {
        case 0x00: spca50x->sensor = SENSOR_MI0360; break;  // 102P, 105, 128   // for '128 also MT9V111 & MI0360B
        
        case 0x30: spca50x->sensor = SENSOR_MI0360; break;  // 120, 201, 202, 
        case 0x38: spca50x->sensor = SENSOR_MO4000; break;  // 120, 
        case 0x3a: spca50x->sensor = SENSOR_OV7648; break;  // 102P, 105, 120, 
        case 0x3b: spca50x->sensor = SENSOR_OV7660; break;  // 120, 201, 202, 
        case 0x3c: spca50x->sensor = SENSOR_HV7131R;break;  // 102P, 105, 120, 201, 202, 
        case 0x3e: spca50x->sensor = SENSOR_OV7630; break;  // 102P, 105, 120, 
            
        case 0x02: spca50x->sensor = SENSOR_MI0343; break;  // 103, 
        case 0x03: spca50x->sensor = SENSOR_HV7131E;break;  // 103, 
        case 0x0a: spca50x->sensor = SENSOR_OV7648; break;  // 128, 
        case 0x0b: spca50x->sensor = SENSOR_OV7660; break;  // 128, 120, 
        case 0x0c: spca50x->sensor = SENSOR_HV7131R;break;  // 103, 128, 
        case 0x0e: spca50x->sensor = SENSOR_OV7630; break;  // 128,     // for '103 it is CISVF10
        case 0x0f: spca50x->sensor = SENSOR_OV7630; break;  // 103, 
        
        case 0x28: spca50x->sensor = SENSOR_OV7648; break;  // 110?? somewhat of a guess
//      case 0x28: spca50x->sensor = SENSOR_PAS106; break;  // 103, 
        case 0x2a: spca50x->sensor = SENSOR_TAS5130CXX; break;  // 103, 
        case 0x2b: spca50x->sensor = SENSOR_TAS5110; break;  // 103, 
        case 0x2c: spca50x->sensor = SENSOR_MO4000; break;  // 105, 120, 100, 
        case 0x2f: spca50x->sensor = SENSOR_PAS202; break;  // 103, 
        
        default: break;  // No change, probably specified in [init]
    }
    
    if (spca50x->customid == SN9C201 || spca50x->customid == SN9C202) 
    {
        switch (productID & 0x0003F)
        {
            case 0x00: spca50x->sensor = SENSOR_MI1300; break;  // 201, 202, 
            case 0x02: spca50x->sensor = SENSOR_MI1310; break;  // 201, 202, 
            case 0x0a: spca50x->sensor = SENSOR_ICM107; break;  // 202, 
            case 0x0e: spca50x->sensor = SENSOR_SOI968; break;  // 201, 202, 
            case 0x0f: spca50x->sensor = SENSOR_OV9650; break;  // 201, 202, 
        }
    }
    
    // Exceptions:
    
    if (productID == 0x6128) 
        spca50x->sensor = SENSOR_OV7630;    // not sure what this should be yet, try 7660 as well (OV7648 is not supported yet)
    
    if (productID == 0x6143) 
        spca50x->sensor = SENSOR_MI0360;  // actually SP80708, whatever that is
    
    // Now set the i2c base register
    
    switch (spca50x->sensor)
    {
        case SENSOR_OV7630: 
        case SENSOR_OV7648: 
        case SENSOR_OV7660: 
        case SENSOR_MO4000: 
            spca50x->i2c_base = 0x21;
            break;
        
        case SENSOR_PAS106: 
        case SENSOR_PAS202: 
			spca50x->i2c_base = 0x40;
            break;
        
        case SENSOR_HV7131E: 
        case SENSOR_HV7131R: 
            spca50x->i2c_base = 0x11;
            break;
        
        case SENSOR_MI0343: 
        case SENSOR_MI0360: 
			spca50x->i2c_base = 0x5d;
            break;
        
        case SENSOR_TAS5110: 
        case SENSOR_TAS5130CXX: 
			spca50x->i2c_base = 0x11;
            break;
        
        case SENSOR_MI1300: 
        case SENSOR_MI1310: 
			spca50x->i2c_base = 0x4c;  // 0x90 (48) or 0xB8 (5c)
            break;
            
        case SENSOR_SOI968: 
			spca50x->i2c_base = 0x30;  // best guess
            break;
        
        case SENSOR_OV9650: 
			spca50x->i2c_base = 0x30;
            break;
        
        case SENSOR_ICM105A: 
        case SENSOR_ICM107: 
			spca50x->i2c_base = 0x10;
            break;
        
        default:
            break;
    }
    
    // Now we can proceed!
    
    [super startupCamera];  // Calls config() and init()
}

//
// Scan the frame and return the results
//
IsocFrameResult  sn9cxxxIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength, 
                                         GenericFrameInfo * frameInfo)
{
    int frameLength = frame->frActCount;
    int position = frameLength - 64;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = 0;
    *tailLength = 0;
    
    if (frameLength < 1) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
        printf("Invalid packet (length = %d).\n", frameLength);
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [length-64] = 0x%02x 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
            buffer[0], frameLength, buffer[1], buffer[frameLength-64], buffer[frameLength-63], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (position >= 0 && buffer[position] == 0xFF && buffer[position+1] == 0xD9) // JPEG Image-End marker
    {
#if REALLY_VERBOSE
        printf("New image start!\n");
#endif
        
        if (frameInfo != NULL) 
        {
#if REALLY_VERBOSE
            if (1) 
            {
                int i;
                printf(" average luminance values:");
                for (i = 0; i < 10; i++) 
                    printf(" 0x%02x", buffer[position + 29 + i]);
                printf("\n");
            }
#endif
            
            frameInfo->averageLuminance =  ((buffer[position + 29] << 8) | buffer[position + 30]) >> 6;	// w4
            frameInfo->averageLuminance += ((buffer[position + 33] << 8) | buffer[position + 34]) >> 6;	// w6
            frameInfo->averageLuminance += ((buffer[position + 25] << 8) | buffer[position + 26]) >> 6;	// w2
            frameInfo->averageLuminance += ((buffer[position + 37] << 8) | buffer[position + 38]) >> 6;	// w8               
            frameInfo->averageLuminance += ((buffer[position + 31] << 8) | buffer[position + 32]) >> 4;	// w5
            frameInfo->averageLuminance = frameInfo->averageLuminance >> 4;
            if (frameInfo->averageLuminance != 0) 
                frameInfo->averageLuminanceSet = 1;
#if REALLY_VERBOSE
            printf("The average luminance is %d\n", frameInfo->averageLuminance);
#endif
        }
        
        if (position > 0) 
            *tailLength = position + 2;
        
        *dataStart = frameLength;
        *dataLength = 0; // Skip the rest
        
        return newChunkFrame;
    }
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = sn9cxxxIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:8];
}

@end


@implementation SN9CxxxDriverPhilips1

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0328], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS], @"idVendor",
            @"Philips SPC 700NC", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0327], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS], @"idVendor",
            @"Philips SPC 600NC", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0330], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS], @"idVendor",
            @"Philips SPC 710NC", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->sensor = SENSOR_MI0360;
    spca50x->customid = SN9C105;
    
	return self;
}

@end


@implementation SN9CxxxDriverMicrosoft1

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
/*        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LIFECAM_VX_1000], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MICROSOFT], @"idVendor",
            @"Microsoft LifeCam VX-1000", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LIFECAM_VX_3000], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MICROSOFT], @"idVendor",
            @"Microsoft LifeCam VX-3000", @"name", NULL], 
*/        
        [NSDictionary dictionaryWithObjectsAndKeys: 
            [NSNumber numberWithUnsignedShort:PRODUCT_HERCULES_CLASSIC_SILVER], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_HERCULES], @"idVendor", 
            @"Hercules Classic Silver", @"name", NULL],  
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x3008], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_HERCULES], @"idVendor",
            @"Hercules Deluxe Optical Glass", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->sensor = SENSOR_OV7660;  // for LifeCam VX-1000 base = 0x21, seems to work for VX-3000 as well
    spca50x->customid = SN9C105;
    
	return self;
}

@end


@implementation SN9CxxxDriverGenius1

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x7025], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
            @"Genius Eye 311Q", @"name", NULL], 
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->sensor = SENSOR_MI0360;
    spca50x->customid = SN9C120;
    
	return self;
}

@end


@implementation SN9CxxxDriverGenius2

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x7034], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
            @"Genius Look 313 Media", @"name", NULL], 
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    // Both from Paolo Lima from Genius serviceteam
    
    spca50x->sensor = SENSOR_HV7131R;
    spca50x->customid = SN9C102P;
    
	return self;
}

@end


@implementation SN9C20xDriver

/*

[SN]
;1.3 M
%USBPCamDesc% =    SN.USBPCam,USB\VID_0c45&PID_6240		; SN9C201 + MI1300
%USBPCamDesc% =    SN.USBPCam,USB\VID_0c45&PID_6242		; SN9C201 + MI1310
%USBPCamDesc% =    SN.USBPCam,USB\VID_0c45&PID_624e		; SN9C201 + SOI968
%USBPCamDesc% =    SN.USBPCam,USB\VID_0c45&PID_624f		; SN9C201 + OV9650
%USBPCamDesc% =    SN.USBPCam,USB\VID_0c45&PID_627f		; EEPROM
;VGA Sensor
%USBPCamDesc% =    SN.USBPCam,USB\VID_0c45&PID_6270		; SN9C201 + MI0360
%USBPCamDesc% =    SN.USBPCam,USB\VID_0c45&PID_627c		; SN9C201 + HV7131R
%USBPCamDesc% =    SN.USBPCam,USB\VID_0c45&PID_627b		; SN9C201 + OV7660

;
; Usb2.0 PC Camera with Audio Function
;
%USBPCamMicDesc% = SN.PCamMic,USB\VID_0c45&PID_6280&MI_00	; SN9C202 + MI1300
%USBPCamMicDesc% = SN.PCamMic,USB\VID_0c45&PID_6282&MI_00	; SN9C202 + MI1310
%USBPCamMicDesc% = SN.PCamMic,USB\VID_0c45&PID_628e&MI_00	; SN9C202 + SOI968
%USBPCamMicDesc% = SN.PCamMic,USB\VID_0c45&PID_628f&MI_00	; SN9C202 + OV9650
%USBPCamMicDesc% = SN.PCamMic,USB\VID_0c45&PID_628a&MI_00	; SN9C202 + ICM107
 
%USBPCamMicDesc% = SN.PCamMic,USB\VID_0c45&PID_62b0&MI_00	; SN9C202 + MI0360
%USBPCamMicDesc% = SN.PCamMic,USB\VID_0c45&PID_62bc&MI_00	; SN9C202 + HV7131R
%USBPCamMicDesc% = SN.PCamMic,USB\VID_0c45&PID_62bb&MI_00	; SN9C202 + Ov7660
*/

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
		// SN9C201
		
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6240], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, 1.3M MI1300 (0x0c45:0x6240)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6242], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, 1.3M MI1310 (0x0c45:0x6242)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x624f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, 1.3M OV9650 (0x0c45:0x624f)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x624e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, 1.3M SOI968 (0x0c45:0x624e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6270], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, VGA MI0360 (0x0c45:0x6270)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x627c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, VGA HV7131R (0x0c45:0x627c)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x627b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, VGA OV7660 (0x0c45:0x627b)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x627f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, EEPROM (0x0c45:0x627f)", @"name", NULL], 
        
		// SN9C202
		
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6280], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, 1.3M MI1300 (0x0c45:0x6280)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6282], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, 1.3M MI1310 (0x0c45:0x6282)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x628f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, 1.3M OV9650 (0x0c45:0x628f)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x628e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, 1.3M SOI968 (0x0c45:0x628e)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x628a], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, 1.0M ICM107 (0x0c45:0x628a)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x62b0], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, VGA MI0360 (0x0c45:0x62b0)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x62bb], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, VGA OV7660 (0x0c45:0x62bb)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x62bc], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"SN9C201, VGA HV7131R (0x0c45:0x62bc)", @"name", NULL], 
        
        // Others
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x00f4], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MICROSOFT], @"idVendor",
            @"Microsoft LifeCam VX-6000 (0x045e:0x00f4)", @"name", NULL], 
        
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
    
    // Set as appropriate
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    // This is important
    cameraOperation = &fsn9cxx;
    
    // Set to reflect actual values
    spca50x->bridge = BRIDGE_SN9CXXX;
    spca50x->cameratype = JPGS;	// jpeg 4.2.2 whithout header
    
    spca50x->desc = AnySN9C20xCamera;
    spca50x->sensor = SENSOR_OV9650;
    spca50x->customid = SN9C202;
    spca50x->sensor = SENSOR_OV7630;
    spca50x->customid = SN9C120;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x30;
    
	return self;
}


// only for VX-6000...
- (void) startupCamera
{
    // Initialization sequence
    
    [self spca5xx_config];
    [self spca5xx_init];
}

@end


// Variants?

// - MI1300
// - MI1310
// - OV9650      // doc: 60/61
// - SOI968

// - ICM107      // doc: 20

// - MO4000      // used: 0x21

// - MI0360      // used: 0x5d
// - HV7131R     // used: 0x11 // doc:22H
// - OV7660      // used: 0x21 // doc:42H

// - TAS5110     // used: 0x11
// - TAS5130CXX  // used: 0x11
// - PAS202      // used: 0x40 // doc:100,0000 (7 bit)
// - OV7630      // used: 0x21 // doc:42H
// - PAS106      // used: 0x40 // doc:100,0000 (7 bit)    (0x11 in this file - error)




// Look at the datasheets for all the valid IDs
// Really need to do sensor detection here instead
// Just two classes: proprietary compression or JPEG compression?

// 0x0c45
// 0x608f
// has microphone
//
// SN9C103
// OV7630
// closest to SonixDriverVariant5
// 
// Genius Look 315FS
// Sweex USB Webcam 300K (JA000060)
//
/*
 T:  Bus=02 Lev=01 Prnt=01 Port=01 Cnt=01 Dev#=  4 Spd=12  MxCh= 0
 D:  Ver= 1.10 Cls=00(>ifc ) Sub=00 Prot=00 MxPS=64 #Cfgs=  1
 P:  Vendor=0c45 ProdID=608f Rev= 1.01
 S:  Product=USB camera
 C:* #Ifs= 3 Cfg#= 1 Atr=80 MxPwr=500mA
 I:  If#= 0 Alt= 0 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=sn9c102
 E:  Ad=81(I) Atr=01(Isoc) MxPS=   0 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 I:  If#= 0 Alt= 1 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=sn9c102
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 128 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 I:  If#= 0 Alt= 2 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=sn9c102
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 256 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 I:  If#= 0 Alt= 3 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=sn9c102
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 384 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 I:  If#= 0 Alt= 4 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=sn9c102
 I:  If#= 0 Alt= 8 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=sn9c102
 E:  Ad=81(I) Atr=01(Isoc) MxPS=1003 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 I:  If#= 1 Alt= 0 #EPs= 0 Cls=01(audio) Sub=01 Prot=00 Driver=sn9c102
 I:  If#= 2 Alt= 0 #EPs= 0 Cls=01(audio) Sub=02 Prot=00 Driver=sn9c102
 I:  If#= 2 Alt= 1 #EPs= 1 Cls=01(audio) Sub=02 Prot=00 Driver=sn9c102
 E:  Ad=84(I) Atr=05(Isoc) MxPS=  20 Ivl=1ms
 */


// welcome to the new unified sonix architecture


@implementation SonixSN9CDriver  // Generic for all these chips


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
	return self;
}


- (int) setupSensorCommunication:(Class)sensorClass
{
    i2cBase = [sensorClass i2cWriteAddress] >> 1;
    
    return 0;
}


- (int) getRegister:(UInt16) reg
{
    UInt8 buffer[8];
    
    BOOL ok = [self usbReadVICmdWithBRequest:0x00 wValue:reg wIndex:0x0000 buf:buffer len:1];
    
    return (ok) ? buffer[0] : -1;
}


- (int) getRegisterList:(UInt16) reg number:(int) length into:(UInt8 *) buffer
{
    BOOL ok = [self usbReadVICmdWithBRequest:0x00 wValue:reg wIndex:0x0000 buf:buffer len:length];
    
    return (ok) ? buffer[0] : -1;
}


- (int) setRegister:(UInt16) reg toValue:(UInt16) val
{
    UInt8 buffer[8];
    
    buffer[0] = val;
    
    BOOL ok = [self usbWriteVICmdWithBRequest:0x08 wValue:reg wIndex:0x0000 buf:buffer len:1];
    
    return (ok) ? val : -1;
}


- (int) setRegisterList:(UInt16) reg number:(int) length withValues:(UInt8 *) buffer
{
    BOOL ok = [self usbWriteVICmdWithBRequest:0x08 wValue:reg wIndex:0x0000 buf:buffer len:length];
    
    return (ok) ? length : -1;
}


- (int) setSensorRegister8:(UInt8 *) buffer
{
    return [self setRegisterList:0x08 number:8 withValues:buffer];
}


- (int) waitOnI2C
{
    int i;
    
	for (i = 0; i < 5; i++) 
    {
		int status = [self getRegister:0x08];
        
		if (status < 0) 
            return -1;
        
		if (status & 0x04) 
			return 0;
        
        udelay(5 * 16);
	}
    
	return -1;
}


- (int) getSensorRegister5:(UInt16) reg into:(UInt8 *) values
{
    UInt8 buffer[8];
    
	buffer[0] = 0x81 | 0x10;
	buffer[1] = i2cBase;
	buffer[2] = reg;
	buffer[3] = 0;
	buffer[4] = 0;
	buffer[5] = 0;
	buffer[6] = 0;
	buffer[7] = 0x10;
    
    [self setSensorRegister8:buffer];
    
    wait_ms(2);
    
	buffer[0] = 0x81 | (5 << 4) | 0x02;
	buffer[2] = 0;
    
    [self setSensorRegister8:buffer];
    
    wait_ms(2);
    
    return [self getRegisterList:0x0a number:5 into:values];
}


- (int) getSensorRegister:(UInt16) reg
{
    UInt8 data[8];
    UInt8 buffer[8];
    
	buffer[0] = 0x81 | (1 << 4);
	buffer[1] = i2cBase;
	buffer[2] = reg;
	buffer[3] = 0;
	buffer[4] = 0;
	buffer[5] = 0;
	buffer[6] = 0;
	buffer[7] = 0x10;
    
    [self setSensorRegister8:buffer];
    
    [self waitOnI2C];
    
	buffer[0] = 0x81 | (5 << 4) | 0x02;
	buffer[2] = 0;
    
    [self setSensorRegister8:buffer];
    
    [self waitOnI2C];
    
    [self getRegisterList:0x0a number:5 into:data];
    
    // buffer[0] -       - 0x9F
    // buffer[1] -       - 0x00
    // buffer[2] - data0 - 0x00       - 0xFF
    // buffer[3] - data1 - 0x00       - 0xFF
    // buffer[4] - data2 - 0x0c - returns the register read
    // buffer[5] - data3 - 0x00
    // buffer[6] - data4 - 0xFF
    // buffer[7] -       - 0x00
    
//    printf("\nread sensor register 0x%02x:  0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", reg, data[0], data[1], data[2], data[3], data[4]);
    
    return data[0];
}


- (int) setSensorRegister:(UInt16) reg toValue:(UInt16) val
{
    UInt8 buffer[8];
    
	buffer[0] = 0x81 | (2 << 4);
	buffer[1] = i2cBase;
	buffer[2] = reg;
	buffer[3] = val;
	buffer[4] = 0;
	buffer[5] = 0;
	buffer[6] = 0;
	buffer[7] = 0x10;
    
    return [self setSensorRegister8:buffer];
}


- (int) dumpRegisters
{
	UInt8 low, high, reg;
    
	printf("Camera Registers: ");
	for (high = 0; high < 0x10; high++) 
    {
		printf("\n    ");
		for (low = 0; low < 0x10; low++) 
        {
            reg = (high << 4) | (low);
			printf(" %02X=%02X", reg, [self getRegister:reg]);
        }
	}
	printf("\n\n");
    
    if ([self getSensorRegister:0x00] < 0) 
        return 0; // probably not implemented
    
	printf("Sensor Registers: ");
    for (high = 0; high < 0x10; high++) 
    {
		printf("\n    ");
		for (low = 0; low < 0x10; low++) 
        {
            reg = (high << 4) | (low);
			printf(" %02X=%02X", reg, [self getSensorRegister:reg]);
        }
	}
    
	printf("\n\n");
    
    return 0;
}



- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:8];
}


@end


@implementation SonixSN9C10xDriver

// weird compression


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    compressionType = proprietaryCompression;
    
	return self;
}


@end


int getJpegHeaderLength(void);
void createJpegHeader(void * buffer, int width, int height, int quality, int samplesY);


@implementation SonixSN9C1xxDriver

// jpeg compression

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    compressionType = jpegCompression;
    jpegVersion = 1;
    
    jpegHeader = malloc(getJpegHeaderLength());
    
	return self;
}


//
// For, this is all that is supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    if (rate < 0 || 30 < rate) 
        return NO;
    
    if (rate < 15 || 15 < rate) 
        return NO;
    
    switch (res) 
    {
        case ResolutionCIF:
            return NO;
            break;
            
        case ResolutionVGA:
            return YES;
            break;
            
        default: 
            return NO;
    }
}


- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 15;
    
	return ResolutionVGA;
}


- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = sn9cxxxIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
    
    // jpeg header
    
    createJpegHeader(jpegHeader, [self width], [self height], 3, 0x21);
    
    grabContext.headerData = jpegHeader;
    grabContext.headerLength = getJpegHeaderLength();    
}

@end


@implementation SonixSN9C20xDriver

// jpeg compression

@end


@implementation SonixSN9C20xxDriver

// weird comprssion

@end




@implementation SonixSN9C105Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LIFECAM_VX_1000], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MICROSOFT], @"idVendor",
            @"Microsoft LifeCam VX-1000", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LIFECAM_VX_3000], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MICROSOFT], @"idVendor",
            @"Microsoft LifeCam VX-3000", @"name", NULL], 
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    usbReducedBandwidth = YES;
    
//    compressionType = jpegCompression;    // Does not work. Some JPEG information missing?
//    jpegVersion = 1;
    
    compressionType = quicktimeImage;
    quicktimeCodec = kJPEGCodecType;

    buttonInterrupt = YES;
    buttonMessageLength = 1;

	return self;
}


- (BOOL) canSetUSBReducedBandwidth
{
    return YES;
}


typedef struct WriteRegisterListBuffer  
{
    UInt8 reg;
    UInt8 len;
    UInt8 buf[31];
} WriteRegisterListBuffer;


- (void) startupCamera
{
    UInt8 val, regF1;
	UInt8 regGpio[] = { 0x29, 0x74 };
    
    [self setRegister:0xf1 toValue:0x01];
    val = [self getRegister:0x00];
    [self setRegister:0xf1 toValue:val];
    regF1 = [self getRegister:0x00];
    
    [self setRegisterList:0x01 number:2 withValues:regGpio];
    
    [self setRegister:0xf1 toValue:0x00];
    
    [self setRegister:0x01 toValue:0x4e];
    [self setRegister:0x01 toValue:0x46];
    [self setRegister:0x01 toValue:0x4e];

    // poll every 100 ms?
    
    printf("VX initialized\n");
    
    [self setRegister:0xf1 toValue:0x00];
    [self setRegister:0x01 toValue:0x21];
    [self getRegister:0x00];
    [self getRegister:0x00];
    
    WriteRegisterListBuffer listBuffer1[] = 
    {
        { 0x01, 2, { 0x63, 0x44 } },
        { 0x08, 2, { 0x81, 0x21 } },
        { 0x17, 5, { 0x00, 0x07, 0x00, 0x00, 0x00 } },
        { 0x9a, 6, { 0x00, 0x40, 0x38, 0x30, 0x00, 0x20 } },
        { 0xd4, 3, { 0x60, 0x00, 0x00 } }, 
        { 0x03, 15, { 0x00, 0x1a, 0x00, 0x00, 0x00, 0x81, 0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00 } }, 
        { 0x00, 0 }
    };
    
    int i;
    
    for (i = 0; listBuffer1[i].len != 0; i++) 
        [self setRegisterList:listBuffer1[i].reg number:listBuffer1[i].len withValues:listBuffer1[i].buf];
    
    [self setRegister:0x01 toValue:0x63];
    [self setRegister:0x17 toValue:0x20];
    [self setRegister:0x01 toValue:0x62];
    [self setRegister:0x01 toValue:0x42];
    
    UInt8 sensorBuffer1[][8] = 
    {
        { 0xa1, 0x21, 0x12, 0x80, 0x00, 0x00, 0x00, 0x10 }, // wait 20 ms after first?
        { 0x00 }
    };
    
    [self setSensorRegister8:sensorBuffer1[0]];
    
    /*
    
    sensor = [Sensor findSensor:self];
    if (sensor == NULL) 
        NSLog(@"Sensor could not be found, this is a big problem!\n");
    
    // Reset the sensor to basic settings, set reisters to default values
    [sensor reset];
    
    if ([sensor isKindOfClass:[OV7660 class]]) 
    {
        NSLog(@"Using an OV7660 sensor");
    }
    
    if ([sensor isKindOfClass:[OV7670 class]]) 
    {
        NSLog(@"Using an OV7670 sensor");
    }
    
    [sensor configure];
    */
    
	[self setBrightness:0.5];
	[self setContrast:0.5];
	[self setSaturation:0.5];
	[self setGamma:0.5];
	[self setSharpness:0.5];
}



- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:8];
}


- (void) initCameraAndSensor
{
    int i;
    
    [self setRegister:0xf1 toValue:0x00];
    [self setRegister:0x01 toValue:0x21];
    [self getRegister:0x00];
    [self getRegister:0x00];
    
    WriteRegisterListBuffer listBuffer1[] = 
    {
        { 0x01, 2, { 0x63, 0x44 } },
        { 0x08, 2, { 0x81, 0x21 } },
        { 0x17, 5, { 0x00, 0x07, 0x00, 0x00, 0x00 } },
        { 0x9a, 6, { 0x00, 0x40, 0x38, 0x30, 0x00, 0x20 } },
        { 0xd4, 3, { 0x60, 0x00, 0x00 } }, 
        { 0x03, 15, { 0x00, 0x1a, 0x00, 0x00, 0x00, 0x81, 0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00 } }, 
        { 0x00, 0 }
    };
    
    for (i = 0; listBuffer1[i].len != 0; i++) 
        [self setRegisterList:listBuffer1[i].reg number:listBuffer1[i].len withValues:listBuffer1[i].buf];
    
    [self setRegister:0x01 toValue:0x63];
    [self setRegister:0x17 toValue:0x20];
    [self setRegister:0x01 toValue:0x62];
    [self setRegister:0x01 toValue:0x42];
    
    UInt8 sensorBuffer1[][8] = 
    {
        { 0xa1, 0x21, 0x12, 0x80, 0x00, 0x00, 0x00, 0x10 }, // wait 20 ms after first?
        { 0xa1, 0x21, 0x12, 0x05, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x13, 0xb8, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x00, 0x01, 0x74, 0x92, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x04, 0x00, 0x7d, 0x62, 0x00, 0x10 }, 
        { 0xb1, 0x21, 0x08, 0x83, 0x01, 0x00, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x0c, 0x00, 0x08, 0x04, 0x6f, 0x10 }, 
        { 0xd1, 0x21, 0x10, 0x7f, 0x40, 0x05, 0xf8, 0x10 }, 
        { 0xc1, 0x21, 0x14, 0x2c, 0x00, 0x02, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x17, 0x10, 0x60, 0x02, 0x7b, 0x10 }, 
        { 0xa1, 0x21, 0x1b, 0x03, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xb1, 0x21, 0x1e, 0x01, 0x0e, 0x00, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x20, 0x07, 0x07, 0x07, 0x07, 0x10 }, 
        { 0xd1, 0x21, 0x24, 0x68, 0x58, 0xd4, 0x80, 0x10 }, 
        { 0xd1, 0x21, 0x28, 0x80, 0x30, 0x00, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x2c, 0x80, 0x00, 0x00, 0x62, 0x10 }, 
        { 0xc1, 0x21, 0x30, 0x08, 0x30, 0xb4, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x33, 0x00, 0x07, 0x84, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x37, 0x0c, 0x02, 0x43, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x3b, 0x02, 0x6c, 0x99, 0x0e, 0x10 }, 
        { 0xd1, 0x21, 0x3f, 0x41, 0xc1, 0x22, 0x08, 0x10 }, 
        { 0xd1, 0x21, 0x43, 0xf0, 0x10, 0x78, 0xa8, 0x10 }, 
        { 0xd1, 0x21, 0x47, 0x60, 0x80, 0x00, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x4b, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x4f, 0x46, 0x36, 0x0f, 0x17, 0x10 }, 
        { 0xd1, 0x21, 0x53, 0x7f, 0x96, 0x40, 0x40, 0x10 }, 
        { 0xb1, 0x21, 0x57, 0x40, 0x0f, 0x00, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x59, 0xba, 0x9a, 0x22, 0xb9, 0x10 }, 
        { 0xd1, 0x21, 0x5d, 0x9b, 0x10, 0xf0, 0x05, 0x10 }, 
        { 0xa1, 0x21, 0x61, 0x60, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x62, 0x00, 0x00, 0x50, 0x30, 0x10 }, 
        { 0xa1, 0x21, 0x66, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x67, 0x80, 0x7a, 0x90, 0x80, 0x10 }, 
        { 0xa1, 0x21, 0x6b, 0x0a, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xd1, 0x21, 0x6c, 0x30, 0x48, 0x80, 0x74, 0x10 }, 
        { 0xd1, 0x21, 0x70, 0x64, 0x60, 0x5c, 0x58, 0x10 }, 
        { 0xd1, 0x21, 0x74, 0x54, 0x4c, 0x40, 0x38, 0x10 }, 
        { 0xd1, 0x21, 0x78, 0x34, 0x30, 0x2f, 0x2b, 0x10 }, 
        { 0xd1, 0x21, 0x7c, 0x03, 0x07, 0x17, 0x34, 0x10 }, 
        { 0xd1, 0x21, 0x80, 0x41, 0x4d, 0x58, 0x63, 0x10 }, 
        { 0xd1, 0x21, 0x84, 0x6e, 0x77, 0x87, 0x95, 0x10 }, 
        { 0xc1, 0x21, 0x88, 0xaf, 0xc7, 0xdf, 0x00, 0x10 }, 
        { 0xc1, 0x21, 0x8b, 0x99, 0x99, 0xcf, 0x00, 0x10 }, 
        { 0xb1, 0x21, 0x92, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0xa1, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        // added
//      { 0xa1, 0x21, 0x13, 0xfc, 0x00, 0x00, 0x00, 0x10 }, // turns on AGC
//      { 0xa1, 0x21, 0x13, 0xff, 0x00, 0x00, 0x00, 0x10 }, // turns on AGC, AWB, AEC
        { 0xa1, 0x21, 0x13, 0xfd, 0x00, 0x00, 0x00, 0x10 }, // turns on AGC, AEC //  best choice
        
        { 0x00 }
    };
    
    for (i = 0; sensorBuffer1[i][0] != 0; i++) 
        [self setSensorRegister8:sensorBuffer1[i]];
    
    [self setRegister:0x15 toValue:0x28];
    [self setRegister:0x16 toValue:0x1e];
    [self setRegister:0x12 toValue:0x01];
    [self setRegister:0x13 toValue:0x01];
    [self setRegister:0x18 toValue:0x07];

    [self setRegister:0xd2 toValue:0x6a];
    [self setRegister:0xd3 toValue:0x50];
    [self setRegister:0xc6 toValue:0x00];
    [self setRegister:0xc7 toValue:0x00];
    [self setRegister:0xc8 toValue:0x50];
    [self setRegister:0xc9 toValue:0x3c];

    [self setRegister:0x18 toValue:0x07];
    [self setRegister:0x17 toValue:0xa0];
    [self setRegister:0x05 toValue:0x00];
    [self setRegister:0x07 toValue:0x00];
    [self setRegister:0x06 toValue:0x00];
    [self setRegister:0x14 toValue:0x06];

    UInt8 listBuffer2[0x11] = { 0x00, 0x30, 0x49, 0x5d, 0x6f, 0x7f, 0x8d, 0x9b, 0xa8, 0xb4, 0xc0, 0xcc, 0xd7, 0xe1, 0xeb, 0xf5, 0xff };
    
    [self setRegisterList:0x20 number:0x11 withValues:listBuffer2];

    UInt8 zeroBuffer[0x15] = { 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00 };
     
    for (i = 0; i < 8; i++) 
        [self setRegisterList:0x84 number:0x15 withValues:zeroBuffer];

    [self setRegister:0x9a toValue:0x02];
    [self setRegister:0x99 toValue:0x80];

    [self setRegisterList:0x84 number:0x15 withValues:zeroBuffer];

    [self setRegister:0x05 toValue:0x20];
    [self setRegister:0x07 toValue:0x20];
    [self setRegister:0x06 toValue:0x20];
     
    [self setRegisterList:0x20 number:0x11 withValues:listBuffer2];
    
    UInt8 sensorBuffer2[][8] = 
    {
        { 0xa1, 0x21, 0x1e, 0x01, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x1e, 0x01, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x03, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x03, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x10, 0x20, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x2d, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x2e, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xb1, 0x21, 0x01, 0x78, 0x78, 0x00, 0x00, 0x10 }, 
        { 0x00 }
    };
     
     for (i = 0; sensorBuffer2[i][0] != 0; i++) 
         [self setSensorRegister8:sensorBuffer2[i]];
     
     [self setRegister:0x05 toValue:0x20];
     [self setRegister:0x07 toValue:0x20];
     [self setRegister:0x06 toValue:0x20];
    
     WriteRegisterListBuffer listBuffer3[] = 
     {
         { 0xc0, 6, { 0x2d, 0x2d, 0x3a, 0x05, 0x04, 0x3f } },
         { 0xca, 4, { 0x28, 0xd8, 0x14, 0xec } },
         { 0xce, 4, { 0x32, 0xdd, 0x32, 0xdd } },
         { 0x00, 0 }
     };
     
     for (i = 0; listBuffer3[i].len != 0; i++) 
         [self setRegisterList:listBuffer3[i].reg number:listBuffer3[i].len withValues:listBuffer3[i].buf];
     
     
     [self setRegister:0x01 toValue:0x42];
     [self setRegister:0x17 toValue:0xa2];
    
     UInt8 sensorBuffer3[][8] = 
     {
        { 0xa1, 0x21, 0x93, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x92, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x2a, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x2b, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0x00 }
     };
     
     for (i = 0; sensorBuffer3[i][0] != 0; i++) 
        [self setSensorRegister8:sensorBuffer3[i]];
     
     UInt8 listBuffer4[0x15] = { 0x18, 0x00, 0x30, 0x00, 0x09, 0x00, 0xed, 0x0f, 0xba, 0x0f, 0x59, 0x00, 0x4d, 0x00, 0xc8, 0x0f, 0xeb, 0x0f, 0x00, 0x00, 0x00 };
     
     [self setRegisterList:0x84 number:0x15 withValues:listBuffer4];

    UInt8 sensorBuffer4[][8] = 
    {
        { 0xa1, 0x21, 0x02, 0x90, 0x00, 0x00, 0x00, 0x10 }, 
        { 0x00 }
    };
    
    for (i = 0; sensorBuffer4[i][0] != 0; i++) 
        [self setSensorRegister8:sensorBuffer4[i]];
    
    [self setRegister:0x05 toValue:0x1f];
    [self setRegister:0x07 toValue:0x20];
    [self setRegister:0x06 toValue:0x1e];
    [self setRegister:0x18 toValue:0x47];

    
    UInt8 jpeg1[64] = { 0x0d, 0x08, 0x08, 0x0d, 0x08, 0x08, 0x0d, 0x0d, 0x0d, 0x0d, 0x11, 0x0d, 0x0d, 0x11, 0x15, 0x21,    
        0x15, 0x15, 0x11, 0x11, 0x15, 0x2a, 0x1d, 0x1d, 0x19, 0x21, 0x32, 0x2a, 0x32, 0x32, 0x2e, 0x2a,    
        0x2e, 0x2e, 0x36, 0x3a, 0x4b, 0x43, 0x36, 0x3a, 0x47, 0x3a, 0x2e, 0x2e, 0x43, 0x5c, 0x43, 0x47,    
        0x4f, 0x54, 0x58, 0x58, 0x58, 0x32, 0x3f, 0x60, 0x64, 0x5c, 0x54, 0x64, 0x4b, 0x54, 0x58, 0x54 };
    
     UInt8 jpeg2[64] = { 0x0d, 0x11, 0x11, 0x15, 0x11, 0x15, 0x26, 0x15, 0x15, 0x26, 0x54, 0x36, 0x2e, 0x36, 0x54, 0x54,    
         0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54,    
         0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54,    
         0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54 };
    
    [self setRegisterList:0x100 number:64 withValues:jpeg1];
    [self setRegisterList:0x140 number:64 withValues:jpeg2];

    [self setRegister:0x18 toValue:0x07];
    [self setRegister:0x01 toValue:0x42];
    [self setRegister:0x17 toValue:0xa2];

    UInt8 sensorBuffer5[][8] = 
    {
        { 0xa1, 0x21, 0x93, 0x01, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x92, 0xfe, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x2a, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0xa1, 0x21, 0x2b, 0x00, 0x00, 0x00, 0x00, 0x10 }, 
        { 0x00 }
    };
    
    for (i = 0; sensorBuffer5[i][0] != 0; i++) 
        [self setSensorRegister8:sensorBuffer5[i]];
    
    [self setRegister:0x01 toValue:0x46];
    [self setRegister:0x15 toValue:0x28];
    
    // more?
}


- (BOOL) startupGrabStream 
{
    BOOL result = TRUE;
    
    [self initCameraAndSensor];
    
    // URB 1338 - 1472
    
    // clear interrupt pipe from any stall
//    (*streamIntf)->ClearPipeStall(streamIntf, 3); // is this necessary??
    
//    (*streamIntf)->ResetPipe(streamIntf, 1);
    
    return result;
}


- (UInt8) getButtonPipe
{
    return 3;
}


- (BOOL) buttonDataHandler:(UInt8 *)data length:(UInt32)length
{
    BOOL result = NO;
    
    if (length == 1) 
    {
        if (data[0] == 0x01) 
        {
            result = YES;
            printf("Button down! 0x%02X\n", data[0]);
        }
    }
    
    return result;
}


@end




// Construct approapriate JPEG header
// 
// JPEG begin marker
// quantization tables
// huffman encoding
// size


static const unsigned char quant[][0x88] = 
{
    // index 0 - Q40
    {
        0xff, 0xd8,                 // jpeg
        0xff, 0xdb, 0x00, 0x84,		// DQT
        0,                          // quantization table part 1
             20, 14, 15, 18, 15, 13, 20, 18, 16, 18, 23, 21, 20, 24, 30, 50,
             33, 30, 28, 28, 30, 61, 44, 46, 36, 50, 73, 64, 76, 75, 71, 64,
             70, 69, 80, 90, 115, 98, 80, 85, 109, 86, 69, 70, 100, 136, 101, 109,
             119, 123, 129, 130, 129, 78, 96, 141, 151, 140, 125, 150, 115, 126, 129, 124,
        1,                          // quantization table part 2
             21, 23, 23, 30, 26, 30, 59, 33, 33, 59, 124, 83, 70, 83, 124, 124,
             124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124,
             124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124,
             124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124 
    },
/* index 1 - Q50 */
    {
	0xff, 0xd8,
	0xff, 0xdb, 0x00, 0x84,		/* DQT */
0,
     16, 11, 12, 14, 12, 10, 16, 14, 13, 14, 18, 17, 16, 19, 24, 40,
     26, 24, 22, 22, 24, 49, 35, 37, 29, 40, 58, 51, 61, 60, 57, 51,
     56, 55, 64, 72, 92, 78, 64, 68, 87, 69, 55, 56, 80, 109, 81, 87,
     95, 98, 103, 104, 103, 62, 77, 113, 121, 112, 100, 120, 92, 101,
     103, 99,
1,
    17, 18, 18, 24, 21, 24, 47, 26, 26, 47, 99, 66, 56, 66, 99, 99,
     99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
     99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
     99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99},
/* index 2 Q60 */
    {
	0xff, 0xd8,
	0xff, 0xdb, 0x00, 0x84,		/* DQT */
0,
     13, 9, 10, 11, 10, 8, 13, 11, 10, 11, 14, 14, 13, 15, 19, 32,
     21, 19, 18, 18, 19, 39, 28, 30, 23, 32, 46, 41, 49, 48, 46, 41,
     45, 44, 51, 58, 74, 62, 51, 54, 70, 55, 44, 45, 64, 87, 65, 70,
     76, 78, 82, 83, 82, 50, 62, 90, 97, 90, 80, 96, 74, 81, 82, 79,
1,
     14, 14, 14, 19, 17, 19, 38, 21, 21, 38, 79, 53, 45, 53, 79, 79,
     79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79,
     79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79,
     79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79, 79},
/* index 3 - Q70 */
    {
	0xff, 0xd8,
	0xff, 0xdb, 0x00, 0x84,		/* DQT */
0,
     10, 7, 7, 8, 7, 6, 10, 8, 8, 8, 11, 10, 10, 11, 14, 24,
     16, 14, 13, 13, 14, 29, 21, 22, 17, 24, 35, 31, 37, 36, 34, 31,
     34, 33, 38, 43, 55, 47, 38, 41, 52, 41, 33, 34, 48, 65, 49, 52,
     57, 59, 62, 62, 62, 37, 46, 68, 73, 67, 60, 72, 55, 61, 62, 59,
1,
     10, 11, 11, 14, 13, 14, 28, 16, 16, 28, 59, 40, 34, 40, 59, 59,
     59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59,
     59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59,
     59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59, 59},
/* index 4 - Q80 */
    {
	0xff, 0xd8,
	0xff, 0xdb, 0x00, 0x84,		/* DQT */
0,
      6, 4, 5, 6, 5, 4, 6, 6, 5, 6, 7, 7, 6, 8, 10, 16,
     10, 10, 9, 9, 10, 20, 14, 15, 12, 16, 23, 20, 24, 24, 23, 20,
     22, 22, 26, 29, 37, 31, 26, 27, 35, 28, 22, 22, 32, 44, 32, 35,
     38, 39, 41, 42, 41, 25, 31, 45, 48, 45, 40, 48, 37, 40, 41, 40,
1,
      7, 7, 7, 10, 8, 10, 19, 10, 10, 19, 40, 26, 22, 26, 40, 40,
     40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40,
     40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40,
     40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40},
/* index 5 - Q85 */
    {
	0xff, 0xd8,
	0xff, 0xdb, 0x00, 0x84,		/* DQT */
0,
     5, 3, 4, 4, 4, 3, 5, 4, 4, 4, 5, 5, 5, 6, 7, 12,
     8, 7, 7, 7, 7, 15, 11, 11, 9, 12, 17, 15, 18, 18, 17, 15,
     17, 17, 19, 22, 28, 23, 19, 20, 26, 21, 17, 17, 24, 33, 24, 26,
     29, 29, 31, 31, 31, 19, 23, 34, 36, 34, 30, 36, 28, 30, 31, 30,
1,
     5, 5, 5, 7, 6, 7, 14, 8, 8, 14, 30, 20, 17, 20, 30, 30,
     30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
     30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
     30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},
/* index 6 - 86 */
{
	0xff, 0xd8,
	0xff, 0xdb, 0x00, 0x84,		/* DQT */
0,
	0x04, 0x03, 0x03, 0x04, 0x03, 0x03, 0x04, 0x04,
	0x04, 0x04, 0x05, 0x05, 0x04, 0x05, 0x07, 0x0B,
	0x07, 0x07, 0x06, 0x06, 0x07, 0x0E, 0x0A, 0x0A,
	0x08, 0x0B, 0x10, 0x0E, 0x11, 0x11, 0x10, 0x0E,
	0x10, 0x0F, 0x12, 0x14, 0x1A, 0x16, 0x12, 0x13,
	0x18, 0x13, 0x0F, 0x10, 0x16, 0x1F, 0x17, 0x18,
	0x1B, 0x1B, 0x1D, 0x1D, 0x1D, 0x11, 0x16, 0x20,
	0x22, 0x1F, 0x1C, 0x22, 0x1A, 0x1C, 0x1D, 0x1C,
1,
	0x05, 0x05, 0x05, 0x07, 0x06, 0x07, 0x0D, 0x07,
	0x07, 0x0D, 0x1C, 0x12, 0x10, 0x12, 0x1C, 0x1C,
	0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
	0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
	0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
	0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
	0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
	0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C,
 },
/* index 7 - 88 */
{
	0xff, 0xd8,
	0xff, 0xdb, 0x00, 0x84,		/* DQT */
0,
	0x04, 0x03, 0x03, 0x03, 0x03, 0x02, 0x04, 0x03,
	0x03, 0x03, 0x04, 0x04, 0x04, 0x05, 0x06, 0x0A,
	0x06, 0x06, 0x05, 0x05, 0x06, 0x0C, 0x08, 0x09,
	0x07, 0x0A, 0x0E, 0x0C, 0x0F, 0x0E, 0x0E, 0x0C,
	0x0D, 0x0D, 0x0F, 0x11, 0x16, 0x13, 0x0F, 0x10,
	0x15, 0x11, 0x0D, 0x0D, 0x13, 0x1A, 0x13, 0x15,
	0x17, 0x18, 0x19, 0x19, 0x19, 0x0F, 0x12, 0x1B,
	0x1D, 0x1B, 0x18, 0x1D, 0x16, 0x18, 0x19, 0x18,
1,
	0x04, 0x04, 0x04, 0x06, 0x05, 0x06, 0x0B, 0x06,
	0x06, 0x0B, 0x18, 0x10, 0x0D, 0x10, 0x18, 0x18,
	0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
	0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
	0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
	0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
	0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
	0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
},
    // index 8 - ??
    {
        0xff, 0xd8,
        0xff, 0xdb, 0x00, 0x84,		/* DQT */
    0,
        0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
        0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x03, 0x05,
        0x03, 0x03, 0x03, 0x03, 0x03, 0x06, 0x04, 0x05,
        0x04, 0x05, 0x07, 0x06, 0x08, 0x08, 0x07, 0x06,
        0x07, 0x07, 0x08, 0x09, 0x0C, 0x0A, 0x08, 0x09,
        0x0B, 0x09, 0x07, 0x07, 0x0A, 0x0E, 0x0A, 0x0B,
        0x0C, 0x0C, 0x0D, 0x0D, 0x0D, 0x08, 0x0A, 0x0E,
        0x0F, 0x0E, 0x0D, 0x0F, 0x0C, 0x0D, 0x0D, 0x0C,
    1,
        0x02, 0x02, 0x02, 0x03, 0x03, 0x03, 0x06, 0x03,
        0x03, 0x06, 0x0C, 0x08, 0x07, 0x08, 0x0C, 0x0C,
        0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C,
        0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C,
        0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C,
        0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C,
        0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C,
        0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C
    }
};

/* huffman table + start of SOF0 */
static unsigned char huffman[] = 
{
	0xff, 0xc4, 0x01, 0xa2,
	0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01,
	0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
	0x07, 0x08, 0x09, 0x0a, 0x0b, 0x01, 0x00, 0x03,
	0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
	0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
	0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
	0x0a, 0x0b, 0x10, 0x00, 0x02, 0x01, 0x03, 0x03,
	0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00,
	0x00, 0x01, 0x7d, 0x01, 0x02, 0x03, 0x00, 0x04,
	0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13,
	0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81,
	0x91, 0xa1, 0x08, 0x23, 0x42, 0xb1, 0xc1, 0x15,
	0x52, 0xd1, 0xf0, 0x24, 0x33, 0x62, 0x72, 0x82,
	0x09, 0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25,
	0x26, 0x27, 0x28, 0x29, 0x2a, 0x34, 0x35, 0x36,
	0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46,
	0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56,
	0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66,
	0x67, 0x68, 0x69, 0x6a, 0x73, 0x74, 0x75, 0x76,
	0x77, 0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86,
	0x87, 0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95,
	0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4,
	0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3,
	0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2,
	0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca,
	0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9,
	0xda, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7,
	0xe8, 0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5,
	0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0x11, 0x00, 0x02,
	0x01, 0x02, 0x04, 0x04, 0x03, 0x04, 0x07, 0x05,
	0x04, 0x04, 0x00, 0x01, 0x02, 0x77, 0x00, 0x01,
	0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06,
	0x12, 0x41, 0x51, 0x07, 0x61, 0x71, 0x13, 0x22,
	0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xa1, 0xb1,
	0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0, 0x15, 0x62,
	0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25,
	0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26, 0x27, 0x28,
	0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a,
	0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a,
	0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a,
	0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a,
	0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a,
	0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
	0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98,
	0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
	0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,
	0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
	0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4,
	0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe2, 0xe3,
	0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf2,
	0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa,
    
	0xff, 0xc0, 0x00, 0x11,		/* SOF0 (start of frame 0 */
	0x08,				/* data precision */
};


/* variable part:
 *	0x01, 0xe0,			 height
 *	0x02, 0x80,			 width
 *	0x03,				 component number
 *		0x01,
 *			0x21,			samples Y
 */

/* end of header */
static unsigned char eoh[] = 
{
			0x00,		/* quant Y */
		0x02, 0x11, 0x01,	/* samples CbCr - quant CbCr */
		0x03, 0x11, 0x01,

	0xff, 0xda, 0x00, 0x0c,		/* SOS (start of scan) */
	0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3f, 0x00
};


// typical: jpeg_put_header(gspca_dev, frame, sd->qindex, 0x21);


int getJpegHeaderLength()
{
    int result = 0;
    
    result += sizeof quant[0];
    result += sizeof huffman;
    result += 7;
    result += sizeof eoh;
    
    return result;
}


void createJpegHeader(void * buffer, int width, int height, int quality, int samplesY)
{
    int current = 0;
	unsigned char tmpbuf[8];
    
    memcpy(buffer + current, (unsigned char *) quant[quality], sizeof quant[0]);
    current += sizeof quant[0];
    
    memcpy(buffer + current, (unsigned char *) huffman, sizeof huffman);
    current += sizeof huffman;
    
	tmpbuf[0] = height >> 8;
	tmpbuf[1] = height & 0xff;
	tmpbuf[2] = width >> 8;
	tmpbuf[3] = width & 0xff;
	tmpbuf[4] = 0x03;		// component number
	tmpbuf[5] = 0x01;		// first component
	tmpbuf[6] = samplesY;
    
    memcpy(buffer + current, (unsigned char *) tmpbuf, 7);
    current += 7;
    
    memcpy(buffer + current, (unsigned char *) eoh, sizeof eoh);
    current += sizeof eoh;
}


