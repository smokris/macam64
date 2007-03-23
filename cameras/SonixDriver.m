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


#import "SonixDriver.h"

#include "MiscTools.h"
#include "spcadecoder.h"
#include "USB_VendorProductIDs.h"


// These defines are needed by the spca5xx code

enum 
{
    GeniusVideoCamNB,
    SweexTas5110,
    Sonix6025,
    BtcPc380,
    Sonix6019,
    GeniusVideoCamMessenger,
    Lic200,
    Sonix6029,
    
    SpeedNVC350K,
    SonixWC311P,
    Pccam168,
    Pccam,
    Sn535,
    Lic300,
    PhilipsSPC700NC,
    Rainbow5790P,
    M$VX1000,
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
    
    // Include if needed
    bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    // Set as appropriate
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    decodingSkipBytes = 6;
    
    // Again, use if needed
    MALLOC(decodingBuffer, UInt8 *, 644 * 484 + 1000, "decodingBuffer");
    
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
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  sonixIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                          UInt32 * dataStart, UInt32 * dataLength, 
                                          UInt32 * tailStart, UInt32 * tailLength)
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
//  return [self usbSetAltInterfaceTo:8 testPipe:[self getGrabbingPipe]];
}


- (BOOL) startupGrabStream 
{
    BOOL result = [super startupGrabStream];
    
    // clear interrupt pipe from any stall
    (*streamIntf)->ClearPipeStall(streamIntf, 3);
    
    return result;
}

//
// other stuff, including decompression
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
#ifdef REALLY_VERBOSE
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
    
    [bayerConverter setSourceFormat:6];
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
    spca50x->i2c_base = 0x11;
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
    
    // Green is like '105 and '120
    // valid up to 0x7f instead of 0x0f
    // into register 0x07 instead of 0x11?
    
//  cameraOperation->set_contrast = fsn9cxx.set_contrast;
    
    spca50x->desc = BtcPc380;
    spca50x->sensor = SENSOR_PAS202;
    spca50x->customid = SN9C103;
    
    spca50x->i2c_ctrl_reg = 0x80;
    spca50x->i2c_base = 0x40;
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
            @"Speed NVC 350K", @"name", NULL], 
        
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
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    // Set as appropriate
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    // This is important
    cameraOperation = &fsn9cxx;
    
    spca50x->qindex = 5; // Should probably be set before init_jpeg_decoder()

    // Set to reflect actual values
    spca50x->bridge = BRIDGE_SN9CXXX;
    spca50x->cameratype = JPGS;	// jpeg 4.2.2 whithout header
    
    spca50x->desc = SpeedNVC350K;
    spca50x->sensor = SENSOR_HV7131R;
    spca50x->customid = SN9C102P;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x11;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}


- (void) startupCamera
{
    [super startupCamera];  // Calls config() and init()
    
    init_jpeg_decoder(spca50x);  // May be irrelevant
}

//
// Scan the frame and return the results
//
IsocFrameResult  sn9cxxxIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                                UInt32 * dataStart, UInt32 * dataLength, 
                                                UInt32 * tailStart, UInt32 * tailLength)
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
        
#ifdef REALLY_VERBOSE
//        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
#ifdef REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [length-64] = 0x%02x 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
//           buffer[0], frameLength, buffer[1], buffer[frameLength-64], buffer[frameLength-63], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    if (position >= 0 && buffer[position] == 0xFF && buffer[position+1] == 0xD9) // JPEG Image-End marker
    {
#ifdef REALLY_VERBOSE
//        printf("New image start!\n");
#endif
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
//  return [self usbSetAltInterfaceTo:8 testPipe:[self getGrabbingPipe]];
}

//
// jpeg decoding here
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
    int i;
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
#ifdef REALLY_VERBOSE
    printf("Need to decode a JPEG buffer with %ld bytes.\n", buffer->numBytes);
#endif
    
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


@implementation SN9CxxxDriverVariant1

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x607c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix WC 311P", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = SonixWC311P;
    spca50x->sensor = SENSOR_HV7131R;
    spca50x->customid = SN9C102P;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x11;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SN9CxxxDriverVariant2

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x613c], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix PC Cam 168", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Pccam168;
    spca50x->sensor = SENSOR_HV7131R;
    spca50x->customid = SN9C120;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x11;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SN9CxxxDriverVariant3

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6130], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix PC Cam", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Pccam;
    spca50x->sensor = SENSOR_MI0360;
    spca50x->customid = SN9C120;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x5d;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SN9CxxxDriverVariant4

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x60c0], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix SN 535", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Sn535;
    spca50x->sensor = SENSOR_MI0360;
    spca50x->customid = SN9C105;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x5d;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SN9CxxxDriverVariant5

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x60fc], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Sonix Lic 300", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Lic300;
    spca50x->sensor = SENSOR_HV7131R;
    spca50x->customid = SN9C105;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x11;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SN9CxxxDriverVariant6

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
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = PhilipsSPC700NC;
    spca50x->sensor = SENSOR_MI0360;
    spca50x->customid = SN9C105;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x5d;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SN9CxxxDriverVariant7

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x60fe], @"idProduct", 
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Rainbow Color Webcam 5790P", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Rainbow5790P;
    spca50x->sensor = SENSOR_OV7630;
    spca50x->customid = SN9C105;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x21;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SN9CxxxDriverVariant8

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x613e], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SONIX], @"idVendor",
            @"Skype Video Pack Camera (Model C7)", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->desc = Pccam168;  // not true
    spca50x->sensor = SENSOR_OV7630;
    spca50x->customid = SN9C120;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x21;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


@implementation SN9CxxxDriverVariant9

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
    
    spca50x->desc = M$VX1000;
//    spca50x->sensor = SENSOR_HV7131R; // NOT in VX-3000 base = 0x11
//    spca50x->sensor = SENSOR_MI0360;  // NOT in VX-3000 base = 0x5d
//    spca50x->sensor = SENSOR_MO4000;  // NOT in VX-3000 base = 0.21 (seems unlikely)
    spca50x->sensor = SENSOR_OV7660;  // for LifeCam VX-1000 base = 0x21, seems to work for VX-3000 as well
    spca50x->customid = SN9C105;
    
    spca50x->i2c_ctrl_reg = 0x81;
    spca50x->i2c_base = 0x21;
    spca50x->i2c_trigger_on_write = 0;
    
	return self;
}

@end


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