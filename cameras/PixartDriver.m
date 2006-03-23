//
//  PixartDriver.h
//
//  macam - webcam app and QuickTime driver component
//  PixartDriver - driver for the Pixart PAC207 chip
//
//  Created by HXR on 3/13/06.
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net). 
//  Some code was copied from Hidekazu UCHIDA, who in turn copied from Michel Xhaard
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

//
// Still need to implement the snapshot button
// Snapshot button causes BulkOrInterruptTransfer 0x5a,0x5a
//

#import "PixartDriver.h"

#include "USB_VendorProductIDs.h"

// Prototypes for some decoding functions

static void initPixartDecoder(struct code_table_t * table);
static int pacDecompressRow(struct code_table_t * table, unsigned char * input, unsigned char * output, int width);

static inline unsigned short getShort(unsigned char *pt)
{
	return ((((unsigned short) pt[0]) << 8) | pt[1]);
}

//
// The private interface for the class
//

@interface PixartDriver (Private)

- (BOOL) pixartDecompress: (UInt8 *) inp to: (UInt8 *) outp width: (short) width height: (short) height;

@end

//
// The actual implementation of the class
//

@implementation PixartDriver

//
// Specify which Vendor and Product IDs this driver will work for
//
+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VISTA_PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Vista Plus!", @"name", NULL], 
        
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
    
    MALLOC(decodingBuffer, UInt8 *, 356 * 292 + 1000, "decodingBuffer");

    initPixartDecoder(codeTable);

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
// Perhaps the chip can adjust the brightness
//
- (void) setBrightness: (float) v 
{
	[super setBrightness:v];
    /*
    if (isGrabbing) 
    {
        int val = brightness * 127.0f;
        [self usbWriteCmdWithBRequest:0x00 wValue:val  wIndex:0x0008 buf:NULL len:0];
        [self usbWriteCmdWithBRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
        [self usbWriteCmdWithBRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
    }
    */
}

//
// Perhaps the chip can adjust the contrast
//
- (void) setContrast: (float) v 
{
    [super setContrast:v];
    /*
    if (isGrabbing) 
     {
        int val = brightness * 63.0f;
        [self usbWriteCmdWithBRequest:0x00 wValue:contrast*63.0f wIndex:0x000e buf:NULL len:0];
        [self usbWriteCmdWithBRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
        [self usbWriteCmdWithBRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
    }
    */
}

//
// This chip uses a different pipe for the isochronous input
//
- (UInt8) getGrabbingPipe
{
    return 5;
}

//
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbSetAltInterfaceTo:8 testPipe:[self getGrabbingPipe]];
}

//
// Scan the frame and return the results
//
IsocFrameResult  pixartIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                        UInt32 * dataStart, UInt32 * dataLength, 
                                        UInt32 * tailStart, UInt32 * tailLength)
{
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 6) 
        return invalidFrame;
    
    for (position = 0; position < frameLength - 6; position++) 
    {
        if ((buffer[position+0] == 0xFF) && 
            (buffer[position+1] == 0xFF) && 
            (buffer[position+2] == 0x00) && 
            (buffer[position+3] == 0xFF) && 
            (buffer[position+4] == 0x96))
        {
            if (position > 0) 
            {
                *tailStart = 0;
                *tailLength = position;
            }
            
            *dataStart = position;
            *dataLength = frameLength - position;
            
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
    grabContext.isocFrameScanner = pixartIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError err = CameraErrorOK;
	UInt8 buff[8];
    
	[self usbReadCmdWithBRequest:0x01 wValue:0x00 wIndex:0x0000 buf:buff len:2];
	if (buff[0] != 0x02 || buff[1] != 0x70) 
    {
#ifdef VERBOSE
		NSLog(@"Invalid Sensor or chip");
#endif
		return CameraErrorUSBProblem != CameraErrorOK;
	}
    
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x0041 buf:NULL len:0]; // Bit0=Image Format, Bit1=LED, Bit2=Compression test mode enable
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x000f buf:NULL len:0]; // Power Control
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x30 wIndex:0x0011 buf:NULL len:0]; // Analog Bias
    
	// Front gain 2bits, Color gains 4bits X 3, Global gain 5bits
	// mode 1-5
	// 0x42-0x4A:data rate of compressed image
    
	static UInt8 pac207_sensor_init[][8] = 
    {
        {0x04,0x12,0x0d,0x00,0x6f,0x03,0x29,0x00},		// 0:0x0002
        {0x00,0x96,0x80,0xa0,0x04,0x10,0xF0,0x30},		// 1:0x000a reg_10 digital gain Red Green Blue Ggain
        {0x00,0x00,0x00,0x70,0xA0,0xF8,0x00,0x00},		// 2:0x0012
        {0x00,0x00,0x32,0x00,0x96,0x00,0xA2,0x02},		// 3:0x0040
        {0x32,0x00,0x96,0x00,0xA2,0x02,0xAF,0x00},		// 4:0x0042 reg_66 rate control
        {0x00,0x00,0x36,0x00,   0,   0,   0,   0},		// 5:0x0048 reg_72 rate control end BalSize_4a = 0x36
	};
    
    //	[self usbWriteVICmdWithBRequest:0x00 wValue:0x10 wIndex:0x000f buf:NULL len:0]; // Power Control
    
	[self usbWriteVICmdWithBRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac207_sensor_init[0] len:8]; // 0x0002
	[self usbWriteVICmdWithBRequest:0x01 wValue:0x00 wIndex:0x000a buf:pac207_sensor_init[1] len:8]; // 0x000a
	[self usbWriteVICmdWithBRequest:0x01 wValue:0x00 wIndex:0x0012 buf:pac207_sensor_init[2] len:8]; // 0x0012
	[self usbWriteVICmdWithBRequest:0x01 wValue:0x00 wIndex:0x0040 buf:pac207_sensor_init[3] len:8]; // 0x0040
//	[self usbWriteVICmdWithBRequest:0x01 wValue:0x00 wIndex:0x0042 buf:pac207_sensor_init[4] len:8]; // 0x0042
	[self usbWriteVICmdWithBRequest:0x01 wValue:0x00 wIndex:0x0048 buf:pac207_sensor_init[5] len:4]; // 0x0048
    
    /*
    if (compression) 
    {
        [self usbWriteCmdWithBRequest:0x00 wValue:0x88 wIndex:0x004a buf:NULL len:0]; // Compression Balance size 0x88
        NSLog(@"compression");
    } 
    else 
    {
        [self usbWriteCmdWithBRequest:0x00 wValue:0xff wIndex:0x004a buf:NULL len:0]; // Compression Balance size
    }
    */
    
//	[self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x004b buf:NULL len:0]; // SRAM test value
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x02 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)
    
	static UInt8 pac207_video_mode[][7] = 
    { 
        {0x07,0x12,0x05,0x52,0x00,0x03,0x29},		// 0:Driver
        {0x04,0x12,0x05,0x0B,0x76,0x02,0x29},		// 1:ResolutionQCIF
        {0x04,0x12,0x05,0x22,0x80,0x00,0x29},		// 2:ResolutionCIF
	};
    
	switch (resolution) 
    {
        case ResolutionQCIF: 
        //  176 x 144
        //	[self usbWriteVICmdWithBRequest:0x00 wValue:0x03 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)
            [self usbWriteVICmdWithBRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac207_video_mode[1] len:7];	// ?????
            break;
            
        case ResolutionCIF: 
        //  352 x 288
        //	[self usbWriteVICmdWithBRequest:0x00 wValue:0x02 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)
            [self usbWriteVICmdWithBRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac207_video_mode[2] len:7];	// ?????
        //	if (compression) 
        //  {
        //		[self usbWriteVICmdWithBRequest:0x00 wValue:0x04 wIndex:0x0002 buf:NULL len:0]; // PXCK = 12MHz /n
        //	} 
        //  else 
        //  {
        //		[self usbWriteVICmdWithBRequest:0x00 wValue:0x0a wIndex:0x0002 buf:NULL len:0]; // PXCK = 12MHz /n
        //	}
            break;
            
        default:
#ifdef VERBOSE
            NSLog(@"startupGrabbing: Invalid resolution!");
#endif
            return CameraErrorUSBProblem != CameraErrorOK;
	}
    
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x0a wIndex:0x000e buf:NULL len:0]; // PGA global gain (Bit 4-0)
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x0018 buf:NULL len:0]; // ???
    
	[self usbWriteVICmdWithBRequest:0x01 wValue:0x00 wIndex:0x0042 buf:pac207_sensor_init[4] len:8]; // 0x0042
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x7e wIndex:0x004a buf:NULL len:0]; // ???
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
	[self usbWriteVICmdWithBRequest:0x00 wValue:0x01 wIndex:0x0040 buf:NULL len:0]; // Start ISO pipe
    
    return err == CameraErrorOK;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    [self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x40 buf:NULL len:0]; // Stop ISO pipe
    [self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x41 buf:NULL len:0]; // Turn off LED
    [self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x0f buf:NULL len:0]; // Power Control
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]];
}

//
// This is the method that takes the raw chunk data and turns it into an image
//
- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
    //	NSLog(@"decode size=%d", [currChunk length]);
    
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
	// Decode the bytes
    
    [self pixartDecompress:buffer->buffer to:decodingBuffer width:rawWidth height:rawHeight];
    
    // Turn the Bayer data into an RGB image
    
    [bayerConverter setSourceFormat:3];
    [bayerConverter setSourceWidth:rawWidth height:rawHeight];
    [bayerConverter setDestinationWidth:rawWidth height:rawHeight];
    [bayerConverter convertFromSrc:decodingBuffer
                            toDest:nextImageBuffer
                       srcRowBytes:rawWidth
                       dstRowBytes:nextImageBufferRowBytes
                            dstBPP:nextImageBufferBPP
                              flip:hFlip
                         rotate180:NO];
}

//
// Decompress the byte stream
//
- (BOOL) pixartDecompress: (UInt8 *) input to: (UInt8 *) output width: (short) width height: (short) height
{
	// We should received a whole frame with header and EOL marker in *input
	// and return a GBRG pattern in *output
	// remove the header then copy line by line EOL is set with 0x0f 0xf0 marker
	// or 0x1e 0xe1 marker for compressed line
    
	unsigned short word;
	int row, bad = 0;
    
	input += 16; // Skip the header
    
	// Go through row by row
    
	for (row = 0; row < height; row++) 
    {
		word = getShort(input);
		switch (word) 
        {
            case 0x0FF0:
                bad = 0;
#ifdef REALLY_VERBOSE
                NSLog(@"0x0FF0");
#endif
                memcpy(output, input + 2, width);
                input += (2 + width);
                break;
                
            case 0x1EE1:
                bad = 0;
    //			NSLog(@"0x1EE1");
                input += pacDecompressRow(codeTable, input, output, width);
                break;
                
            default:
#ifdef REALLY_VERBOSE
                if (bad == 0) 
                    NSLog(@"other EOL 0x%04x", word);
                else 
                    NSLog(@"-- EOL 0x%04x", word);
#endif
                bad++;
                row--; // try again!
                input += 1;
                if (bad > 1) 
                    return YES;
		}
		output += width;
	}
    
	return NO;
}

@end


//
// Initialize the decoding table
//
static void initPixartDecoder(struct code_table_t * table)
{
	int i, is_abs, val, len;

	for (i = 0; i < 256; i++) 
    {
		is_abs = 0;
		val = 0;
		len = 0;
        
		if ((i & 0xC0) == 0) 				// code 00
        {
			val = 0;
			len = 2;
		} 
        else if ((i & 0xC0) == 0x40)        // code 01
        {
			val = -5;
			len = 2;
		} 
        else if ((i & 0xC0) == 0x80)        // code 10
        {
			val = +5;
			len = 2;
		} 
        else if ((i & 0xF0) == 0xC0)        // code 1100
        {
			val = -10;
			len = 4;
		} 
        else if ((i & 0xF0) == 0xD0)        // code 1101
        {
			val = +10;
			len = 4;
		} 
        else if ((i & 0xF8) == 0xE0)        // code 11100
        {
			val = -15;
			len = 5;
		} 
        else if ((i & 0xF8) == 0xE8)        // code 11101
        {
			val = +15;
			len = 5;
		} 
        else if ((i & 0xFC) == 0xF0)        // code 111100
        {
			val = -20;
			len = 6;
		} 
        else if ((i & 0xFC) == 0xF4)        // code 111101
        {
			val = +20;
			len = 6;
		} 
        else if ((i & 0xF8) == 0xF8)        // code 11111xxxxxx
        {
			is_abs = 1;
			val = 0;
			len = 5;
		}
        
		table[i].is_abs = is_abs;
		table[i].val = val;
		table[i].len = len;
	}
}

//
// Get the next word, this works for both little and big endian systems
//
static inline unsigned char getByte(unsigned char * input, unsigned int bitpos)
{
	unsigned char * address;
	address = input + (bitpos >> 3);
	return (address[0] << (bitpos & 7)) | (address[1] >> (8 - (bitpos & 7)));
}

#define CLIP(color) (unsigned char)(((color)>0xFF)?0xff:(((color)<0)?0:(color)))

//
// This function decompresses one row of the image
//
static int pacDecompressRow(struct code_table_t * table, unsigned char * input, unsigned char * output, int width)
{
	int col, val, bitpos;
	unsigned char code;

	// The first two pixels are stored as raw 8-bit numbers
    
	*output++ = input[2];
	*output++ = input[3];
    
	bitpos = 32; // This includes the 2-byte header and the first two bytes

    // Here is the decoding loop
    
	for (col = 2; col < width; col++) 
    {
		// Get the bitcode for the table
        
		code = getByte(input, bitpos);
		bitpos += table[code].len;
        
		// Calculate the actual pixel value
        
		if (table[code].is_abs) // This is an absolute value: get 6 more bits for the actual value
        {
			code = getByte(input, bitpos);
			bitpos += 6;
			*output++ = code & 0xFC; // Use only the high 6 bits
		} 
        else // The value will be relative to left pixel
        {
			val = output[-2] + table[code].val;
			*output++ = CLIP(val);
		}
	}
    
	return 2 * ((bitpos + 15) / 16); // return the number of bytes used for line, rounded up to whole words
}
