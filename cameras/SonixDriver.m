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
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x608f], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Genius Look 315FS or Sweex USB Webcam 300K", @"name", NULL], 
        // Genius Look 315FS
        // Sweex USB Webcam 300K (JA000060)
        // These are actually SN9C103, not 102

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
        printf("Invalid packet.\n");
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
            int i;
            printf(" average luminance values:");
            for (i = 0; i < 10; i++) 
                printf(" 0x%02x", buffer[position + 29 + i]);
            printf("\n");
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
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LIFECAM_VX_1000], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MICROSOFT], @"idVendor",
            @"Microsoft LifeCam VX-1000", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LIFECAM_VX_3000], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MICROSOFT], @"idVendor",
            @"Microsoft LifeCam VX-3000", @"name", NULL], 
        
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
    
    spca50x->sensor = SENSOR_OV7630;  // NO
    spca50x->sensor = SENSOR_MI0360;  // NO
    spca50x->sensor = SENSOR_HV7131R; // NO
    spca50x->sensor = SENSOR_OV7660;  // NO
    spca50x->sensor = SENSOR_TAS5130CXX;  // NO
    spca50x->sensor = SENSOR_MO4000;  // NO
    spca50x->sensor = SENSOR_OV7648;  // not connected
    spca50x->sensor = SENSOR_PAS202;  // NO
    
    // Which sensor is it?
    
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