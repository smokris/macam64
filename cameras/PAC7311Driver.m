//
//  PAC7311Driver.m
//
//  macam - webcam app and QuickTime driver component
//  PAC7311Driver - driver for PixArt PAC7311 single chip VGA webcam solution
//
//  Created by HXR on 1/15/06.
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net) and Roland Schwemmer (sharoz@gmx.de).
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


#import "PAC7311Driver.h"

#include "USB_VendorProductIDs.h"


@implementation PAC7311Driver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // Most cameras appear to use the PAC7311 chip (according to the gpsca table)
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (0)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SPC_610NC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Philips SPC 610NC (probably)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_TRUST_WB_300P], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Trust WB 300P (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_TRUST_WB_3500P], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Trust WB 3500P (or similar)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PAC7311_GENERIC_F], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"PixArt PAC7311 based camera (F)", @"name", NULL], 
        
        // This supposedly uses a PAC7312 instead, not sure if that makes any difference
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SPC_500NC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Philips SPC 500NC (probably)", @"name", NULL], 
        
        NULL];
}


#define pac7311RegWrite(dev,req,value,index,buffer,length) spca5xxRegWrite(dev,req,value,index,(unsigned char *)buffer,length)
#define pac7311RegRead(dev,req,value,index,buffer,length) spca5xxRegRead(dev,req,value,index,buffer,length)


#include "pac7311.h"

//
// Initialize the camera to use the existing GSPCA code as much as posisble
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    orientation = Rotate180;
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    cameraOperation = &fpac7311;
    
    spca50x->qindex = 4;  // Not sure if this matters?
    
    spca50x->cameratype = PJPG;
    spca50x->bridge = BRIDGE_PAC7311;
    spca50x->sensor = SENSOR_PAC7311;
    
    compressionType = gspcaCompression;
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  pac7311IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength, 
                                         GenericFrameInfo * frameInfo)
{
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
#if REALLY_VERBOSE
//  printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
#endif
    
    if (frameLength < 6) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
//      printf("Invalid frame! (length = %d)\n", frameLength);
#endif
        return invalidFrame;
    }
    
    //  00 1a ff ff 00 ff 96 62 44 // perhaps even more zeroes in front
    
    for (position = 0; position < frameLength - 6; position++) 
    {
        if ((buffer[position+0] == 0xFF) && 
            (buffer[position+1] == 0xFF) && 
            (buffer[position+2] == 0x00) && 
            (buffer[position+3] == 0xFF) && 
            (buffer[position+4] == 0x96))
        {
#if REALLY_VERBOSE
//          printf("New chunk!\n");
#endif
            if (position > 28 && frameInfo != NULL) 
            {
                frameInfo->averageLuminance = buffer[position - 23];
                frameInfo->averageLuminanceSet = 1;
#if REALLY_VERBOSE
//              printf("The average luminance is %d\n", frameInfo->averageLuminance);
#endif
            }
            
            if (position > 0) 
            {
                *tailStart = 0;
                *tailLength = position;
            }
            
            *dataStart = position;
            *dataLength = frameLength - *dataStart;
            
            return newChunkFrame;
        }
    }
    
    return validFrame;
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
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:8];
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = pac7311IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


@end 



#if 0 // Some old code is saved in case it becomes useful in the future

- (void) writeRegister: (UInt16) reg  value: (UInt16) value  buffer: (UInt8 *) buffer  length: (UInt32) length
{
    [self usbWriteCmdWithBRequest:0x00 wValue:value wIndex:reg buf:buffer len:length];
}

- (void) writeRegister: (UInt16) reg  value: (UInt16) value
{
    UInt8 buffer[8];
    
    buffer[0] = value;
    [self usbWriteCmdWithBRequest:0x00 wValue:value wIndex:reg buf:buffer len:1];
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    int maxRate = 0;
    
    switch (res) 
    {
        case ResolutionVGA:
            maxRate = 3;
            break;
            
        case ResolutionCIF:
        case ResolutionSIF:
            maxRate = 12;
            break;
            
        case ResolutionQCIF:
        case ResolutionQSIF:
            maxRate = 30;
            break;
            
        default: 
            return NO;
    }
    
    if (jpegCompression)
        maxRate = 30;
    
    if (rate > maxRate) 
        return NO;
    
    return YES;
}

//
// return number of bytes copied
//
int  pac7311IsocDataCopier(void * destination, const void * source, size_t length, size_t available)
{
    UInt8 * src = (UInt8 *) source;
    int position, end, copied = 0, start = 0;
    
    end = length - 4;
    if (end < 0) 
        end  = 0;
    
    if (length > available-1) 
        length = available-1;
    
    for (position = 0; position < end; position++) 
    {
        if (src[position + 0] == 0xFF && 
            src[position + 1] == 0xFF && 
            src[position + 2] == 0xFF) 
        {
            int tocopy = position - start;
            memcpy(destination, source + start, tocopy);
            
            destination += tocopy;
            copied += tocopy;
            
            start = position + 4;
            position += 3;
        }
    }
    
    memcpy(destination, source + start, length - start);
    
    copied += length - start;
    
    return copied;
}

#endif
